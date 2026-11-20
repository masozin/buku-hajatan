import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'providers.dart';
import 'theme/tema_aplikasi.dart';
import 'screens/belum_konfigurasi.dart';
import 'screens/daftar_acara.dart';
import 'screens/detail_acara.dart';
import 'screens/diblokir.dart';
import 'screens/masuk.dart';
import 'screens/panel_admin.dart';
import 'widgets/keadaan.dart';
import 'widgets/pemeriksa_pembaruan.dart';

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
      // Sistem desain Batch 12: tema zamrud & emas, terang dan
      // gelap mengikuti setelan perangkat.
      theme: TemaAplikasi.terang,
      darkTheme: TemaAplikasi.gelap,
      themeMode: ThemeMode.system,
      // Skala font perangkat DIJEPIT PER ZONA (fix 2026-11-20):
      // setelan ukuran font Android yang besar memperbesar teks
      // tetapi tidak memperbesar kotak tampilannya, sehingga di
      // font sangat besar beberapa tampilan meluber dan kurang
      // rapi. Di sini dipasang PLAFON KONTEN 1,45x — teks isi
      // (nama, alamat, nominal di daftar-daftar) boleh tumbuh
      // sampai segitu karena memang itu yang perlu dibaca.
      // Bagian struktural yang komposisinya rapat (kartu total,
      // kartu bundel, panel ringkasan) dijepit lebih ketat
      // (1,15x) lewat ZonaTeksRapi di widgets/elemen.dart.
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler.clamp(
              minScaleFactor: 0.85,
              maxScaleFactor: 1.45,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      // PemeriksaPembaruan (Batch 21) membungkus gerbang: sekali
      // saat aplikasi dibuka ia memeriksa rilis GitHub yang lebih
      // baru dan menawarkan unduh lewat dialog.
      home: PemeriksaPembaruan(
        child: inisialisasi.when(
          loading: () => const Scaffold(body: TampilMuat()),
          error: (error, _) =>
              BelumKonfigurasiScreen(rincianGalat: error.toString()),
          data: (_) => const _GerbangPengguna(),
        ),
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
        // Belum masuk DAN sesi anonim (pencatat) sama-sama lewat
        // _GerbangMasuk (Batch 18): satu jenis widget di posisi
        // yang sama, agar subtree layar Masuk tidak hancur saat
        // sesi anonim dibuat dari form gabung.
        if (pengguna == null) return const _GerbangMasuk(uid: null);
        if (pengguna.isAnonymous) {
          return _GerbangMasuk(uid: pengguna.uid);
        }
        return _GerbangPemilik(uid: pengguna.uid);
      },
    );
  }
}

/// Gerbang masuk & sesi pencatat (perbaikan gabung 2026-11-17;
/// dirombak Batch 18).
///
/// BUG LAMA: form gabung di tab Pencatat masuk anonim DULU, gerbang
/// langsung menukar layar Masuk dengan Daftar Acara begitu sesi
/// muncul — form hancur sebelum langkah klaim undangan berjalan,
/// klaim tidak pernah selesai dan galatnya (PIN salah dsb.) tidak
/// pernah terlihat. Pencatat berakhir di beranda kosong.
///
/// Batch 14 menahan pencatat anonim tanpa acara di layar Masuk
/// (tab Pencatat). Batch 18 merapikan sisanya: gerbang ini kini
/// melayani DUA keadaan sekaligus — belum masuk (uid null) dan
/// sesi anonim — dan SELALU membungkus layar Masuk dalam
/// StreamBuilder yang sama di posisi yang sama. Akibatnya saat
/// form gabung membuat sesi anonim (tombol Gabung ditekan, Batch
/// 18), subtree layar Masuk TIDAK dibangun ulang: isi form dan
/// galat klaim yang gagal tetap tampil, dan berpindah tab tidak
/// lagi memicu muat ulang layar.
///
/// [_pernahMasuk] mengingat layar Masuk pernah tampil dalam
/// proses ini: selama stream keikutsertaan masih memuat setelah
/// itu, layar Masuk dipertahankan (bukan layar muat). Sebaliknya
/// pada mulai dingin pencatat lama (sesi anonim tersimpan dan
/// punya acara), layar muat tetap tampil sampai datanya tiba —
/// tidak ada kedipan layar Masuk.
class _GerbangMasuk extends ConsumerStatefulWidget {
  const _GerbangMasuk({required this.uid});

  /// Null bila belum ada pengguna masuk.
  final String? uid;

  @override
  ConsumerState<_GerbangMasuk> createState() => _GerbangMasukState();
}

class _GerbangMasukState extends ConsumerState<_GerbangMasuk> {
  bool _pernahMasuk = false;

  /// Keluar sebagai pencatat (Batch 10): lepaskan dulu semua sesi
  /// yang dipegang perangkat ini, baru sign out — supaya nama-nama
  /// pencatatnya bebas dipakai perangkat lain. Gagal melepas sesi
  /// tidak menghalangi keluar (pemilik bisa mereset sesinya).
  Future<void> _keluar() async {
    final uid = widget.uid;
    if (uid == null) return;
    try {
      await ref.read(acaraServiceProvider).lepaskanSemuaSesi(uid);
    } catch (_) {
      // Abaikan — keluar tetap jalan.
    }
    await ref.read(authServiceProvider).keluar();
  }

  @override
  Widget build(BuildContext context) {
    final uid = widget.uid;
    final stream = uid == null
        ? null
        : ref.watch(acaraServiceProvider).acaraDiikutiStream(uid);
    return StreamBuilder(
      stream: stream,
      builder: (context, snapshot) {
        if (uid == null) {
          _pernahMasuk = true;
          return const MasukScreen();
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Setelah layar Masuk tampil, pertahankan selama muat
          // (sesi baru saja dibuat dari form gabung) — jangan
          // menukarnya dengan layar muat.
          return _pernahMasuk
              ? const MasukScreen(tabAwal: 1)
              : const Scaffold(body: TampilMuat());
        }
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Buku Hajatan'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout),
                  tooltip: 'Keluar',
                  onPressed: _keluar,
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
        // Belum mengikuti acara apa pun → tahan di layar Masuk
        // dengan tab Pencatat terbuka; form gabung ada di tab itu.
        _pernahMasuk = true;
        return const MasukScreen(tabAwal: 1);
      },
    );
  }
}
