import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/admin.dart';
import '../core/format.dart';
import '../models/acara.dart';
import '../models/pemilik.dart';
import '../providers.dart';
import '../services/layanan_exception.dart';
import '../theme/tema_aplikasi.dart';
import '../widgets/elemen.dart';
import '../widgets/keadaan.dart';
import 'buat_acara.dart';

/// Detail satu pengguna untuk admin (Batch 6): profil, ringkasan,
/// daftar acaranya, dan aksi Buat Acara / Reset Sandi / Blokir.
/// Dibuka dengan mengetuk kartu pengguna di Panel Admin.
///
/// Dirapikan Batch 28 senada Panel Admin: istilah "Pengguna",
/// profil tanpa avatar inisial, dan ringkasan sebagai panel
/// gradasi zamrud.
class DetailPemilikScreen extends ConsumerWidget {
  const DetailPemilikScreen({super.key, required this.pemilikAwal});

  final Pemilik pemilikAwal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final admin = ref.watch(adminServiceProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Pengguna')),
      body: StreamBuilder<List<Pemilik>>(
        stream: admin.semuaPemilikStream(),
        builder: (context, snapPemilik) {
          var pemilik = pemilikAwal;
          for (final p in snapPemilik.data ?? const <Pemilik>[]) {
            if (p.id == pemilikAwal.id) pemilik = p;
          }
          return StreamBuilder<List<Acara>>(
            stream: admin.semuaAcaraStream(),
            builder: (context, snapAcara) {
              if (snapAcara.connectionState == ConnectionState.waiting) {
                return const TampilMuat();
              }
              if (snapAcara.hasError) {
                return TampilGalat(pesan: pesanDari(snapAcara.error!));
              }
              final semuaAcara = snapAcara.data ?? const <Acara>[];
              final acaranya = semuaAcara
                  .where((a) => a.pemilikId == pemilik.id)
                  .toList();
              final ringkasan = ringkasPerPemilik([
                pemilik,
              ], semuaAcara).first;
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _KartuProfil(pemilik: pemilik),
                  const SizedBox(height: 12),
                  _KartuRingkasan(ringkasan: ringkasan),
                  const SizedBox(height: 16),
                  _DeretAksi(pemilik: pemilik),
                  const SizedBox(height: 20),
                  JudulBagian(teks: 'Acara (${acaranya.length})'),
                  const SizedBox(height: 10),
                  if (acaranya.isEmpty)
                    const Text('Belum ada acara untuk pengguna ini.')
                  else
                    for (final a in acaranya) _BarisAcara(acara: a),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// Profil pengguna (Batch 28): nama besar + chip status, lalu
/// rincian berikon (email, no HP, tanggal terdaftar) — tanpa
/// avatar inisial, senada kartu pengguna di Panel Admin.
class _KartuProfil extends StatelessWidget {
  const _KartuProfil({required this.pemilik});

  final Pemilik pemilik;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final skema = tema.colorScheme;
    return Card(
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
                    pemilik.nama.isEmpty ? '(tanpa nama)' : pemilik.nama,
                    style: tema.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Chip(
                  label: Text(pemilik.diblokir ? 'Diblokir' : 'Aktif'),
                  backgroundColor: pemilik.diblokir
                      ? skema.errorContainer
                      : skema.primaryContainer,
                  labelStyle: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: pemilik.diblokir
                        ? skema.onErrorContainer
                        : skema.onPrimaryContainer,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (pemilik.email != null)
              _RincianProfil(
                ikon: Icons.mail_outline,
                teks: pemilik.email!,
              ),
            if (pemilik.noHp != null)
              _RincianProfil(
                ikon: Icons.phone_outlined,
                teks: pemilik.noHp!,
              ),
            if (pemilik.createdAt != null)
              _RincianProfil(
                ikon: Icons.calendar_month_outlined,
                teks: 'Terdaftar ${formatTanggal(pemilik.createdAt!)}',
              ),
          ],
        ),
      ),
    );
  }
}

class _RincianProfil extends StatelessWidget {
  const _RincianProfil({required this.ikon, required this.teks});

  final IconData ikon;
  final String teks;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(ikon, size: 16, color: tema.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              teks,
              style: tema.textTheme.bodyMedium?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ringkasan pengguna (Batch 28): panel gradasi zamrud senada
/// Panel Admin — total terkumpul besar + statistik berikon.
class _KartuRingkasan extends StatelessWidget {
  const _KartuRingkasan({required this.ringkasan});

  final RingkasanPemilikAdmin ringkasan;

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
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Terkumpul',
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
                    _StatRingkasan(
                      ikon: Icons.event_outlined,
                      nilai: '${ringkasan.jumlahAcara}',
                      label: 'Acara',
                    ),
                    _StatRingkasan(
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

class _StatRingkasan extends StatelessWidget {
  const _StatRingkasan({
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

/// Tombol aksi admin untuk pemilik ini: Buat Acara, Reset Sandi,
/// Blokir/Aktifkan.
class _DeretAksi extends ConsumerWidget {
  const _DeretAksi({required this.pemilik});

  final Pemilik pemilik;

  void _beriTahu(BuildContext context, String pesan) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(pesan)));
  }

  Future<void> _resetSandi(BuildContext context, WidgetRef ref) async {
    final email = pemilik.email;
    if (email == null || email.isEmpty) {
      _beriTahu(context, 'Pengguna ini belum punya email tersimpan.');
      return;
    }
    final yakin = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kirim reset kata sandi?'),
        content: Text(
          'Firebase akan mengirim email ke $email berisi tautan '
          'untuk membuat kata sandi baru.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Kirim'),
          ),
        ],
      ),
    );
    if (yakin != true) return;
    try {
      await ref.read(authServiceProvider).kirimResetSandi(email);
      if (context.mounted) {
        _beriTahu(context, 'Email reset sandi terkirim ke $email.');
      }
    } on LayananException catch (e) {
      if (context.mounted) _beriTahu(context, e.pesan);
    } catch (e) {
      if (context.mounted) _beriTahu(context, pesanDari(e));
    }
  }

  Future<void> _ubahBlokir(BuildContext context, WidgetRef ref) async {
    final memblokir = !pemilik.diblokir;
    final yakin = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(memblokir ? 'Blokir pengguna?' : 'Aktifkan kembali?'),
        content: Text(
          memblokir
              ? '${pemilik.nama} tidak akan bisa masuk atau dibuatkan '
                    'acara selama diblokir. Data yang sudah ada '
                    'TIDAK dihapus.'
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
        _beriTahu(
          context,
          memblokir
              ? '${pemilik.nama} diblokir.'
              : '${pemilik.nama} diaktifkan kembali.',
        );
      }
    } catch (e) {
      if (context.mounted) _beriTahu(context, pesanDari(e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.icon(
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
        OutlinedButton.icon(
          onPressed: () => _resetSandi(context, ref),
          icon: const Icon(Icons.lock_reset_outlined),
          label: const Text('Reset Sandi'),
        ),
        OutlinedButton.icon(
          onPressed: () => _ubahBlokir(context, ref),
          icon: Icon(
            pemilik.diblokir ? Icons.lock_open_outlined : Icons.block,
          ),
          label: Text(pemilik.diblokir ? 'Aktifkan' : 'Blokir'),
        ),
      ],
    );
  }
}

class _BarisAcara extends StatelessWidget {
  const _BarisAcara({required this.acara});

  final Acara acara;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(
          acara.namaAcara,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${acara.jenis} • ${formatTanggal(acara.tanggal)} • '
          '${acara.totalAmplop} pengunjung • ${acara.totalBundel} bundel • '
          '${formatRupiah(acara.totalRp)}\n'
          'Kode gabung: ${acara.kodeGabung}',
        ),
        isThreeLine: true,
        trailing: ChipStatusAcara(status: acara.status),
      ),
    );
  }
}
