import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/admin.dart';
import '../core/format.dart';
import '../models/acara.dart';
import '../models/pemilik.dart';
import '../providers.dart';
import '../services/layanan_exception.dart';
import '../widgets/keadaan.dart';
import 'buat_acara.dart';

/// Detail satu pemilik untuk admin (Batch 6): profil, ringkasan,
/// daftar acaranya, dan aksi Buat Acara / Reset Sandi / Blokir.
/// Dibuka dengan mengetuk kartu pemilik di Panel Admin.
class DetailPemilikScreen extends ConsumerWidget {
  const DetailPemilikScreen({super.key, required this.pemilikAwal});

  final Pemilik pemilikAwal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final admin = ref.watch(adminServiceProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Pemilik')),
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
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _Angka(
                            label: 'Acara',
                            nilai: '${ringkasan.jumlahAcara}',
                          ),
                          _Angka(
                            label: 'Amplop',
                            nilai: '${ringkasan.totalAmplop}',
                          ),
                          _Angka(
                            label: 'Total',
                            nilai: formatRupiah(ringkasan.totalRp),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _DeretAksi(pemilik: pemilik),
                  const SizedBox(height: 20),
                  Text(
                    'Acara Miliknya (${acaranya.length})',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (acaranya.isEmpty)
                    const Text('Belum ada acara untuk pemilik ini.')
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

class _KartuProfil extends StatelessWidget {
  const _KartuProfil({required this.pemilik});

  final Pemilik pemilik;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          radius: 24,
          child: Text(
            pemilik.nama.isEmpty ? '?' : pemilik.nama[0].toUpperCase(),
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        title: Text(pemilik.nama.isEmpty ? '(tanpa nama)' : pemilik.nama),
        subtitle: Text(
          [
            if (pemilik.email != null) pemilik.email!,
            if (pemilik.noHp != null) pemilik.noHp!,
            if (pemilik.createdAt != null)
              'Terdaftar ${formatTanggal(pemilik.createdAt!)}',
          ].join('\n'),
        ),
        isThreeLine: true,
        trailing: Chip(
          label: Text(pemilik.diblokir ? 'Diblokir' : 'Aktif'),
          visualDensity: VisualDensity.compact,
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
    return Column(
      children: [
        Text(nilai, style: Theme.of(context).textTheme.titleMedium),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
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
      _beriTahu(context, 'Pemilik ini belum punya email tersimpan.');
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
        title: Text(memblokir ? 'Blokir pemilik?' : 'Aktifkan kembali?'),
        content: Text(
          memblokir
              ? '${pemilik.nama} tidak akan bisa masuk sebagai pemilik '
                    'atau dibuatkan acara selama diblokir. Data yang '
                    'sudah ada TIDAK dihapus.'
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
        title: Text(acara.namaAcara),
        subtitle: Text(
          '${acara.jenis} • ${formatTanggal(acara.tanggal)} • '
          '${acara.totalAmplop} amplop • ${acara.totalBundel} bundel • '
          '${formatRupiah(acara.totalRp)}\n'
          'Kode gabung: ${acara.kodeGabung}',
        ),
        isThreeLine: true,
        trailing: Chip(
          label: Text(acara.sudahSelesai ? 'Selesai' : 'Aktif'),
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}
