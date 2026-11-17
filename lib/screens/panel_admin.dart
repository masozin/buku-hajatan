import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/admin.dart';
import '../core/format.dart';
import '../models/acara.dart';
import '../models/pemilik.dart';
import '../providers.dart';
import '../widgets/elemen.dart';
import '../widgets/keadaan.dart';
import 'buat_acara.dart';
import 'daftar_acara.dart';
import 'detail_pemilik.dart';
import 'tambah_pemilik.dart';

/// Panel Admin platform (Batch 4) — hanya terbuka untuk akun admin
/// (`admin/{uid}` ada; dibuat lewat Firebase Console). Isi: ringkasan
/// platform, daftar pemilik + blokir/aktifkan, daftar semua acara.
/// Semua data dibaca lewat stream; rules yang menjaga servernya.
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
          // Panel ini beranda utama admin (Batch 6) — sediakan jalan
          // ke tampilan pemilik & keluar dari sini juga.
          IconButton(
            icon: const Icon(Icons.home_outlined),
            tooltip: 'Tampilan Pemilik',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const DaftarAcaraScreen(),
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
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    const TambahPemilikScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.person_add_outlined),
                          label: const Text('Tambah Pemilik'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const BuatAcaraScreen(
                                  modeAdmin: true,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.event_outlined),
                          label: const Text('Buat Acara'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _Ringkasan(
                    ringkasan: ringkasPlatform(
                      pemilik: pemilik,
                      acara: acara,
                    ),
                  ),
                  const SizedBox(height: 20),
                  JudulBagian(teks: 'Pemilik (${pemilik.length})'),
                  const SizedBox(height: 10),
                  if (pemilik.isEmpty)
                    const Text('Belum ada pemilik terdaftar.')
                  else
                    for (final r in ringkasPerPemilik(pemilik, acara))
                      _KartuPemilik(ringkasan: r),
                  const SizedBox(height: 20),
                  JudulBagian(teks: 'Semua Acara (${acara.length})'),
                  const SizedBox(height: 10),
                  if (acara.isEmpty)
                    const Text('Belum ada acara.')
                  else
                    for (final a in acara)
                      _BarisAcara(
                        acara: a,
                        namaPemilik: _namaPemilik(pemilik, a.pemilikId),
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

  String _namaPemilik(List<Pemilik> pemilik, String uid) {
    for (final p in pemilik) {
      if (p.id == uid) return p.nama.isEmpty ? '(tanpa nama)' : p.nama;
    }
    return '(pemilik tidak ditemukan)';
  }
}

class _Ringkasan extends StatelessWidget {
  const _Ringkasan({required this.ringkasan});

  final RingkasanPlatform ringkasan;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _Angka(label: 'Pemilik', nilai: '${ringkasan.totalPemilik}'),
            _Angka(label: 'Acara', nilai: '${ringkasan.totalAcara}'),
            _Angka(label: 'Pengunjung', nilai: '${ringkasan.totalAmplop}'),
            _Angka(label: 'Total', nilai: formatRupiah(ringkasan.totalRp)),
          ],
        ),
      ),
    );
  }
}

class _Angka extends StatelessWidget {
  const _Angka({required this.label, required this.nilai});

  final String label;
  final String nilai;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Column(
      children: [
        Text(
          nilai,
          style: tema.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: tema.textTheme.bodySmall?.copyWith(
            color: tema.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
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
        title: Text(memblokir ? 'Blokir pemilik?' : 'Aktifkan kembali?'),
        content: Text(
          memblokir
              ? '${pemilik.nama} tidak akan bisa masuk sebagai pemilik '
                    'atau membuat acara selama diblokir. Acara & data '
                    'yang sudah ada TIDAK dihapus.'
              : '${pemilik.nama} akan bisa memakai aplikasinya lagi '
                    'sebagai pemilik.',
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
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          ListTile(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DetailPemilikScreen(pemilikAwal: pemilik),
                ),
              );
            },
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                pemilik.nama.isEmpty ? '?' : pemilik.nama[0].toUpperCase(),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Theme.of(
                    context,
                  ).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            title: Text(
              pemilik.nama.isEmpty ? '(tanpa nama)' : pemilik.nama,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              [
                if (pemilik.email != null) pemilik.email!,
                if (pemilik.noHp != null) pemilik.noHp!,
                '${ringkasan.jumlahAcara} acara • ${ringkasan.totalAmplop} '
                    'pengunjung • ${formatRupiah(ringkasan.totalRp)}',
              ].join('\n'),
            ),
            trailing: pemilik.diblokir
                ? Chip(
                    label: const Text('Diblokir'),
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.errorContainer,
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(
                        context,
                      ).colorScheme.onErrorContainer,
                    ),
                    visualDensity: VisualDensity.compact,
                  )
                : null,
            isThreeLine: true,
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

class _BarisAcara extends StatelessWidget {
  const _BarisAcara({required this.acara, required this.namaPemilik});

  final Acara acara;
  final String namaPemilik;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(acara.namaAcara),
        subtitle: Text(
          'Pemilik: $namaPemilik\n'
          '${acara.jenis} • ${formatTanggal(acara.tanggal)} • '
          '${acara.totalAmplop} pengunjung • ${acara.totalBundel} bundel • '
          '${formatRupiah(acara.totalRp)}',
        ),
        isThreeLine: true,
        trailing: ChipStatusAcara(status: acara.status),
      ),
    );
  }
}
