import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'providers.dart';
import 'screens/belum_konfigurasi.dart';
import 'screens/daftar_acara.dart';
import 'screens/diblokir.dart';
import 'screens/masuk.dart';
import 'screens/panel_admin.dart';
import 'widgets/keadaan.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Simbol tanggal Indonesia untuk formatTanggal (intl).
  await initializeDateFormatting('id_ID');
  runApp(const ProviderScope(child: BukuHajatanApp()));
}

/// Akar aplikasi Buku Hajatan.
///
/// Alur gerbang:
/// 1. Inisialisasi Firebase — gagal berarti belum dikonfigurasi,
///    tampilkan layar petunjuk (bukan crash).
/// 2. Belum ada pengguna masuk -> layar Masuk (Pemilik / Pencatat).
/// 3. Sudah masuk -> Daftar Acara.
class BukuHajatanApp extends ConsumerWidget {
  const BukuHajatanApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inisialisasi = ref.watch(inisialisasiFirebaseProvider);
    return MaterialApp(
      title: 'Buku Hajatan',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF386641)),
        useMaterial3: true,
      ),
      home: inisialisasi.when(
        loading: () => const Scaffold(body: TampilMuat()),
        error: (error, _) =>
            BelumKonfigurasiScreen(rincianGalat: error.toString()),
        data: (_) => const _GerbangPengguna(),
      ),
    );
  }
}

/// Gerbang kedua untuk sesi pemilik: pemilik yang diblokir admin
/// (Batch 4) melihat layar pemberitahuan, bukan daftar acaranya.
/// Admin (Batch 6) langsung masuk ke Panel Admin sebagai beranda.
/// Galat baca profil TIDAK mengunci pemilik — tetap diteruskan.
class _GerbangPemilik extends ConsumerWidget {
  const _GerbangPemilik({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilStream = ref
        .watch(authServiceProvider)
        .profilPemilikStream(uid);
    return StreamBuilder(
      stream: profilStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: TampilMuat());
        }
        final pemilik = snapshot.data;
        if (pemilik != null && pemilik.diblokir) {
          return const DiblokirScreen();
        }
        final adalahAdmin =
            ref.watch(statusAdminProvider).valueOrNull ?? false;
        if (adalahAdmin) return const PanelAdminScreen();
        return const DaftarAcaraScreen();
      },
    );
  }
}

class _GerbangPengguna extends ConsumerWidget {
  const _GerbangPengguna();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(statusPenggunaProvider);
    return status.when(
      loading: () => const Scaffold(body: TampilMuat()),
      error: (error, _) => Scaffold(body: TampilGalat(pesan: pesanDari(error))),
      data: (pengguna) {
        if (pengguna == null) return const MasukScreen();
        // Sesi anonim = pencatat; tidak ada profil pemilik & tidak
        // bisa diblokir — langsung ke daftar acara.
        if (pengguna.isAnonymous) return const DaftarAcaraScreen();
        return _GerbangPemilik(uid: pengguna.uid);
      },
    );
  }
}
