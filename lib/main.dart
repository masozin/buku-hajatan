import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'providers.dart';
import 'screens/belum_konfigurasi.dart';
import 'screens/daftar_acara.dart';
import 'screens/detail_acara.dart';
import 'screens/diblokir.dart';
import 'screens/gabung_acara.dart';
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
        // bisa diblokir. Lewat gerbang pencatat dulu (lihat bawah).
        if (pengguna.isAnonymous) return _GerbangPencatat(uid: pengguna.uid);
        return _GerbangPemilik(uid: pengguna.uid);
      },
    );
  }
}

/// Gerbang sesi pencatat (perbaikan gabung, 2026-11-17).
///
/// BUG LAMA: form gabung di tab Pencatat masuk anonim DULU, gerbang
/// langsung menukar layar Masuk dengan Daftar Acara begitu sesi
/// muncul — form hancur sebelum langkah klaim undangan berjalan,
/// klaim tidak pernah selesai dan galatnya (PIN salah dsb.) tidak
/// pernah terlihat. Pencatat berakhir di beranda kosong.
///
/// SEKARANG: pencatat anonim yang BELUM mengikuti acara apa pun
/// mendarat di form gabung sebagai berandanya (sesinya sudah aktif,
/// form stabil, galat tampil normal). Begitu klaim berhasil, stream
/// keikutsertaan terisi dan gerbang berpindah ke Daftar Acara
/// dengan sendirinya.
class _GerbangPencatat extends ConsumerWidget {
  const _GerbangPencatat({required this.uid});

  final String uid;

  /// Keluar sebagai pencatat (Batch 10): lepaskan dulu semua sesi
  /// yang dipegang perangkat ini, baru sign out — supaya nama-nama
  /// pencatatnya bebas dipakai perangkat lain. Gagal melepas sesi
  /// tidak menghalangi keluar (pemilik bisa mereset sesinya).
  Future<void> _keluar(WidgetRef ref) async {
    try {
      await ref.read(acaraServiceProvider).lepaskanSemuaSesi(uid);
    } catch (_) {
      // Abaikan — keluar tetap jalan.
    }
    await ref.read(authServiceProvider).keluar();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stream = ref.watch(acaraServiceProvider).acaraDiikutiStream(uid);
    return StreamBuilder(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: TampilMuat());
        }
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Buku Hajatan'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout),
                  tooltip: 'Keluar',
                  onPressed: () => _keluar(ref),
                ),
              ],
            ),
            body: TampilGalat(pesan: pesanDari(snapshot.error!)),
          );
        }
        final daftar = snapshot.data ?? const [];
        // Pencatat yang hanya mengikuti SATU acara langsung masuk
        // ke panel acaranya (Batch 8) — tidak perlu mengetuk daftar
        // dulu. Lebih dari satu acara: pilih dari daftar seperti
        // biasa.
        if (daftar.length == 1) {
          return DetailAcaraScreen(
            acaraId: daftar.first.acara.id,
            sebagaiPemilik: false,
          );
        }
        if (daftar.isNotEmpty) return const DaftarAcaraScreen();
        return Scaffold(
          appBar: AppBar(
            title: const Text('Gabung Acara'),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'Keluar',
                onPressed: () => _keluar(ref),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: GabungAcaraForm(
              onBerhasil: (pencatat) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Selamat datang, ${pencatat.nama}. Kamu pencatat '
                      'prefix ${pencatat.prefix}.',
                    ),
                  ),
                );
                // Gerbang berpindah ke Daftar Acara dengan sendirinya
                // begitu stream keikutsertaan terisi.
              },
            ),
          ),
        );
      },
    );
  }
}
