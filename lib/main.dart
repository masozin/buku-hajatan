import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'providers.dart';
import 'screens/belum_konfigurasi.dart';
import 'screens/daftar_acara.dart';
import 'screens/masuk.dart';
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
        return const DaftarAcaraScreen();
      },
    );
  }
}
