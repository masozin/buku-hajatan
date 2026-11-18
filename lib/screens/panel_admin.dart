import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/admin.dart';
import '../core/format.dart';
import '../models/acara.dart';
import '../models/pemilik.dart';
import '../providers.dart';
import '../theme/tema_aplikasi.dart';
import '../widgets/elemen.dart';
import '../widgets/keadaan.dart';
import 'buat_acara.dart';
import 'detail_pemilik.dart';
import 'info_aplikasi.dart';
import 'tambah_pemilik.dart';

/// Panel Admin platform (Batch 4) — hanya terbuka untuk akun admin
/// (`admin/{uid}` ada; dibuat lewat Firebase Console). Isi: ringkasan
/// platform dan daftar pengguna + blokir/aktifkan.
/// Semua data dibaca lewat stream; rules yang menjaga servernya.
///
/// Dipoles Batch 28 atas permintaan Mark: tombol home & bagian
/// Semua Acara dihapus, istilah "Pemilik" menjadi "Pengguna",
/// tombol Buat Acara di atas dihapus (buat acara tetap ada per
/// kartu pengguna), Tambah Pengguna pindah ke bawah daftar,
/// kartu ringkasan bergaya panel gradasi, dan kartu pengguna
/// tanpa avatar inisial (detail di kiri, ringkasan di kanan).
class PanelAdminScreen extends ConsumerWidget {
  const PanelAdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adalahAdmin = ref.watch(statusAdminProvider).valueOrNull ?? false;
    if (!adalahAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Panel Admin')),
        body: const TampilKosong(
          teks: 'Halaman ini khusus admin Buku Hajatan.',
        ),
      );
    }
    final admin = ref.watch(adminServiceProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel Admin'),
        actions: [
          const TombolInfo(),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Keluar',
            onPressed: () => _konfirmasiKeluar(context, ref),
          ),
        ],
      ),
      body: StreamBuilder<List<Pemilik>>(
        stream: admin.semuaPemilikStream(),
        builder: (context, snapPemilik) {
          if (snapPemilik.connectionState == ConnectionState.waiting) {
            return const TampilMuat();
          }
          if (snapPemilik.hasError) {
            return TampilGalat(pesan: pesanDari(snapPemilik.error!));
          }
          final pemilik = snapPemilik.data ?? const <Pemilik>[];
          return StreamBuilder<List<Acara>>(
            stream: admin.semuaAcaraStream(),
            builder: (context, snapAcara) {
              if (snapAcara.connectionState == ConnectionState.waiting) {
                return const TampilMuat();
              }
              if (snapAcara.hasError) {
                return TampilGalat(pesan: pesanDari(snapAcara.error!));
              }
              final acara = snapAcara.data ?? const <Acara>[];
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _Ringkasan(
                    ringkasan: ringkasPlatform(
                      pemilik: pemilik,
                      acara: acara,
                    ),
                  ),
                  const SizedBox(height: 20),
                  JudulBagian(teks: 'Pengguna (${pemilik.length})'),
                  const SizedBox(height: 10),
                  if (pemilik.isEmpty)
                    const Text('Belum ada pengguna terdaftar.')
                  else
                    for (final r in ringkasPerPemilik(pemilik, acara))
                      _KartuPemilik(ringkasan: r),
                  const SizedBox(height: 12),
                  // Batch 28: tambah pengguna kini di bawah daftar.
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const TambahPemilikScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.person_add_outlined),
                    label: const Text('Tambah Pengguna'),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _konfirmasiKeluar(BuildContext context, WidgetRef ref) async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar dari Buku Hajatan?'),
        content: const Text(
          'Kamu akan keluar dari sesi admin ini.',
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
    if (yakin == true) {
      await ref.read(authServiceProvider).keluar();
    }
  }
}

/// Kartu ringkasan platform (Batch 28): panel gradasi zamrud
/// senada KartuTotalAcara — total terkumpul sebagai angka utama,
/// lalu statistik berikon (pengguna, acara, pengunjung).
class _Ringkasan extends StatelessWidget {
  const _Ringkasan({required this.ringkasan});

  final RingkasanPlatform ringkasan;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        gradient: TemaAplikasi.gradasiPahlawan,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: TemaAplikasi.zamrud.withValues(alpha: 0.30),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            top: -46,
            right: -30,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -24,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: TemaAplikasi.emasTerang.withValues(alpha: 0.14),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Terkumpul Semua Acara',
                  style: tema.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatRupiah(ringkasan.totalRp),
                  style: tema.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    _StatHero(
                      ikon: Icons.groups_outlined,
                      nilai: '${ringkasan.totalPemilik}',
                      label: 'Pengguna',
                    ),
                    _StatHero(
                      ikon: Icons.event_outlined,
                      nilai: '${ringkasan.totalAcara}',
                      label: 'Acara',
                    ),
                    _StatHero(
                      ikon: Icons.people_outline,
                      nilai: '${ringkasan.totalAmplop}',
                      label: 'Pengunjung',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatHero extends StatelessWidget {
  const _StatHero({
    required this.ikon,
    required this.nilai,
    required this.label,
  });

  final IconData ikon;
  final String nilai;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ikon, size: 20, color: Colors.white.withValues(alpha: 0.85)),
          const SizedBox(height: 6),
          Text(
            nilai,
            style: tema.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: tema.textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }
}

class _KartuPemilik extends ConsumerWidget {
  const _KartuPemilik({required this.ringkasan});

  final RingkasanPemilikAdmin ringkasan;

  Future<void> _ubahBlokir(BuildContext context, WidgetRef ref) async {
    final pemilik = ringkasan.pemilik;
    final memblokir = !pemilik.diblokir;
    final yakin = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(memblokir ? 'Blokir pengguna?' : 'Aktifkan kembali?'),
        content: Text(
          memblokir
              ? '${pemilik.nama} tidak akan bisa masuk atau membuat '
                    'acara selama diblokir. Acara & data yang sudah '
                    'ada TIDAK dihapus.'
              : '${pemilik.nama} akan bisa memakai aplikasinya lagi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(memblokir ? 'Blokir' : 'Aktifkan'),
          ),
        ],
      ),
    );
    if (yakin != true) return;
    try {
      await ref
          .read(adminServiceProvider)
          .setDiblokir(pemilik.id, memblokir);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              memblokir
                  ? '${pemilik.nama} diblokir.'
                  : '${pemilik.nama} diaktifkan kembali.',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(pesanDari(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pemilik = ringkasan.pemilik;
    final tema = Theme.of(context);
    final skema = tema.colorScheme;
    // Batch 28: tanpa avatar inisial — detail pengguna di kiri,
    // ringkasan (Rp + ikon acara & pengunjung) di kanan.
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DetailPemilikScreen(pemilikAwal: pemilik),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pemilik.nama.isEmpty
                              ? '(tanpa nama)'
                              : pemilik.nama,
                          style: tema.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (pemilik.email != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            pemilik.email!,
                            style: tema.textTheme.bodySmall?.copyWith(
                              color: skema.onSurfaceVariant,
                            ),
                          ),
                        ],
                        if (pemilik.noHp != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            pemilik.noHp!,
                            style: tema.textTheme.bodySmall?.copyWith(
                              color: skema.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (pemilik.diblokir) ...[
                        Chip(
                          label: const Text('Diblokir'),
                          backgroundColor: skema.errorContainer,
                          labelStyle: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: skema.onErrorContainer,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        const SizedBox(height: 6),
                      ],
                      Text(
                        formatRupiah(ringkasan.totalRp),
                        style: tema.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.event_outlined,
                            size: 15,
                            color: skema.onSurfaceVariant,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${ringkasan.jumlahAcara}',
                            style: tema.textTheme.bodySmall,
                          ),
                          const SizedBox(width: 10),
                          Icon(
                            Icons.people_outline,
                            size: 15,
                            color: skema.onSurfaceVariant,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${ringkasan.totalAmplop}',
                            style: tema.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          OverflowBar(
            alignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: pemilik.diblokir
                    ? null
                    : () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => BuatAcaraScreen(
                              modeAdmin: true,
                              pemilikTetap: pemilik.id,
                              namaPemilikTetap: pemilik.nama,
                            ),
                          ),
                        );
                      },
                icon: const Icon(Icons.event_outlined),
                label: const Text('Buat Acara'),
              ),
              TextButton(
                onPressed: () => _ubahBlokir(context, ref),
                child: Text(pemilik.diblokir ? 'Aktifkan' : 'Blokir'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


