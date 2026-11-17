import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../models/acara.dart';
import '../providers.dart';
import '../widgets/elemen.dart';
import '../widgets/keadaan.dart';
import 'detail_acara.dart';
import 'gabung_acara.dart';
import 'panel_admin.dart';

/// Halaman utama setelah masuk:
/// - "Acara Saya" — milik pemilik yang sedang masuk (disembunyikan
///   untuk sesi anonim pencatat).
/// - "Saya Ikuti sebagai Pencatat" — HANYA untuk sesi anonim
///   pencatat (beranda mereka). Untuk sesi pemilik bagian ini
///   disembunyikan sejak Batch 7 atas permintaan Mark.
class DaftarAcaraScreen extends ConsumerWidget {
  const DaftarAcaraScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pengguna = ref.watch(statusPenggunaProvider).valueOrNull;
    if (pengguna == null) return const Scaffold(body: TampilMuat());
    final anonim = pengguna.isAnonymous;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Buku Hajatan'),
        actions: [
          // Pintu Panel Admin — hanya tampil untuk akun admin
          // (Batch 4); statusAdminProvider false untuk yang lain.
          if (ref.watch(statusAdminProvider).valueOrNull ?? false)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings_outlined),
              tooltip: 'Panel Admin',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PanelAdminScreen(),
                  ),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Keluar',
            onPressed: () => _konfirmasiKeluar(context, ref),
          ),
        ],
      ),
      // Sejak Batch 5 tidak ada tombol Buat Acara di sini: acara
      // dibuatkan oleh admin lewat Panel Admin, pemilik tinggal
      // menerima & mengelolanya.
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          if (!anonim) ...[
            _SapaanPemilik(uid: pengguna.uid),
            const SizedBox(height: 20),
            const JudulBagian(teks: 'Acara Saya'),
            const SizedBox(height: 10),
            _DaftarMilikSaya(uid: pengguna.uid),
          ],
          if (anonim) ...[
            JudulBagian(
              teks: 'Saya Ikuti sebagai Pencatat',
              aksi: TextButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const GabungAcaraScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.group_add_outlined),
                label: const Text('Gabung'),
              ),
            ),
            const SizedBox(height: 10),
            _DaftarDiikuti(uid: pengguna.uid),
          ],
        ],
      ),
    );
  }

  Future<void> _konfirmasiKeluar(BuildContext context, WidgetRef ref) async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar dari aplikasi?'),
        content: const Text(
          'Data yang sudah tersinkron tetap aman di server. '
          'Untuk masuk lagi sebagai pencatat, kamu perlu kode acara '
          'dan PIN dari pemilik acara.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (yakin != true) return;
    // Batch 10 + perbaikan Batch 13: sesi pencatat dilepas dulu
    // sebelum keluar; layanan ditangkap SEBELUM menunggu (gerbang
    // bisa menukar layar di tengah jalan — lihat Detail Acara).
    final auth = ref.read(authServiceProvider);
    final layananAcara = ref.read(acaraServiceProvider);
    final uid = ref.read(statusPenggunaProvider).valueOrNull?.uid;
    if (uid != null) {
      try {
        await layananAcara.lepaskanSemuaSesi(uid);
      } catch (_) {
        // Abaikan — keluar tetap jalan.
      }
    }
    await auth.keluar();
  }
}

class _DaftarMilikSaya extends ConsumerWidget {
  const _DaftarMilikSaya({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stream = ref.watch(acaraServiceProvider).acaraMilikSayaStream(uid);
    return StreamBuilder<List<Acara>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const TampilMuat();
        }
        if (snapshot.hasError) {
          return TampilGalat(pesan: pesanDari(snapshot.error!));
        }
        final daftar = snapshot.data ?? const <Acara>[];
        if (daftar.isEmpty) {
          return const TampilKosong(
            teks: 'Belum ada acara. Acara dibuatkan oleh admin '
                'untukmu — hubungi admin bila belum dibuatkan.',
            ikon: Icons.celebration_outlined,
          );
        }
        return Column(
          children: [
            for (final acara in daftar)
              _KartuAcara(
                acara: acara,
                onKetuk: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DetailAcaraScreen(
                        acaraId: acara.id,
                        sebagaiPemilik: true,
                      ),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

class _DaftarDiikuti extends ConsumerWidget {
  const _DaftarDiikuti({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stream = ref.watch(acaraServiceProvider).acaraDiikutiStream(uid);
    return StreamBuilder(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const TampilMuat();
        }
        if (snapshot.hasError) {
          return TampilGalat(pesan: pesanDari(snapshot.error!));
        }
        final daftar = snapshot.data ?? const [];
        if (daftar.isEmpty) {
          return const TampilKosong(
            teks: 'Belum mengikuti acara apa pun sebagai pencatat.',
            ikon: Icons.badge_outlined,
          );
        }
        return Column(
          children: [
            for (final ikut in daftar)
              _KartuAcara(
                acara: ikut.acara,
                keteranganTambahan:
                    'Kamu pencatat ${ikut.pencatat.prefix} '
                    '(${ikut.pencatat.nama})',
                onKetuk: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DetailAcaraScreen(
                        acaraId: ikut.acara.id,
                        sebagaiPemilik: false,
                      ),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

class _KartuAcara extends StatelessWidget {
  const _KartuAcara({
    required this.acara,
    required this.onKetuk,
    this.keteranganTambahan,
  });

  final Acara acara;
  final VoidCallback onKetuk;
  final String? keteranganTambahan;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final skema = tema.colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onKetuk,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      acara.namaAcara,
                      style: tema.textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ChipStatusAcara(status: acara.status),
                ],
              ),
              const SizedBox(height: 10),
              _MetaAcara(
                ikon: Icons.celebration_rounded,
                teks:
                    '${acara.jenis} • ${formatTanggalSingkat(acara.tanggal)}',
              ),
              const SizedBox(height: 4),
              _MetaAcara(
                ikon: Icons.home_rounded,
                teks: 'Tuan rumah: ${acara.tuanRumah}',
              ),
              if (keteranganTambahan != null) ...[
                const SizedBox(height: 4),
                _MetaAcara(
                  ikon: Icons.badge_rounded,
                  teks: keteranganTambahan!,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    formatRupiah(acara.totalRp),
                    style: tema.textTheme.titleMedium?.copyWith(
                      color: skema.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '  •  ${acara.totalAmplop} amplop',
                    style: TextStyle(
                      fontSize: 13,
                      color: skema.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: skema.onSurfaceVariant,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Satu baris meta berketerangan ikon di kartu acara.
class _MetaAcara extends StatelessWidget {
  const _MetaAcara({required this.ikon, required this.teks});

  final IconData ikon;
  final String teks;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(ikon, size: 16, color: skema.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            teks,
            style: TextStyle(fontSize: 13.5, color: skema.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

/// Sapaan berisi nama pemilik dari dokumen `pemilik/{uid}`.
class _SapaanPemilik extends ConsumerWidget {
  const _SapaanPemilik({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    return FutureBuilder(
      future: ref.read(authServiceProvider).ambilProfilPemilik(uid),
      builder: (context, snapshot) {
        final nama = snapshot.data?.nama;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              nama == null ? 'Halo!' : 'Halo, $nama!',
              style: tema.textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Kelola acara hajatanmu — pantau amplop masuk '
              'secara realtime.',
              style: tema.textTheme.bodyMedium?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );
      },
    );
  }
}
