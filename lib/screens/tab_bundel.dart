import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../models/acara.dart';
import '../models/bundel.dart';
import '../models/pencatat.dart';
import '../providers.dart';
import '../services/layanan_exception.dart';
import '../services/pencatatan_service.dart';
import '../widgets/baris_amplop.dart';
import '../widgets/keadaan.dart';
import 'koreksi_amplop.dart';

/// Tab Bundel di Detail Acara pemilik (Batch 9, menggantikan
/// tombol "Lihat Semua Bundel"): tiap bundel tampil sebagai
/// baris dropdown berisi kode bundel, jumlah amplop, dan total
/// Rp — dibuka untuk melihat daftar pengunjung di dalamnya.
///
/// Setelah acara selesai, baris amplop di dalam dropdown ikut
/// mendapat tombol ubah/hapus + tambah amplop (mode koreksi
/// pemilik, sama seperti layar Isi Bundel).
class DaftarBundelTab extends ConsumerWidget {
  const DaftarBundelTab({super.key, required this.acara});

  final Acara acara;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layanan = ref.watch(pencatatanServiceProvider);
    return StreamBuilder<List<Bundel>>(
      stream: layanan.semuaBundelStream(acara.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const TampilMuat();
        }
        if (snapshot.hasError) {
          return TampilGalat(pesan: pesanDari(snapshot.error!));
        }
        final daftar = snapshot.data ?? const <Bundel>[];
        if (daftar.isEmpty) {
          return const TampilKosong(
            teks: 'Belum ada bundel. Bundel pertama dibuat pencatat '
                'saat mulai mencatat.',
            ikon: Icons.inventory_2_outlined,
          );
        }
        return StreamBuilder<List<Pencatat>>(
          stream: ref.watch(acaraServiceProvider).pencatatStream(acara.id),
          builder: (context, snapPencatat) {
            final namaPencatat = <String, String>{
              for (final p in snapPencatat.data ?? const <Pencatat>[])
                p.id: p.nama,
            };
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: daftar.length,
              itemBuilder: (context, i) {
                final b = daftar[i];
                final penuh = b.status == StatusBundel.penuh;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ExpansionTile(
                    leading: CircleAvatar(child: Text(b.prefix)),
                    title: Text('Bundel ${b.kode}'),
                    subtitle: Text(
                      '${b.jumlahAmplop}/10 amplop • '
                      '${formatRupiah(b.totalRp)}'
                      '${penuh ? ' • Penuh' : ''}'
                      '\nPencatat: ${namaPencatat[b.pencatatId] ?? '—'}',
                    ),
                    children: [
                      _IsiBundelDropdown(acara: acara, bundel: b),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

/// Isi satu dropdown bundel: daftar amplopnya (stream), plus —
/// dalam mode koreksi (acara selesai) — aksi ubah/hapus per baris
/// dan tambah amplop bila bundel belum penuh.
class _IsiBundelDropdown extends ConsumerWidget {
  const _IsiBundelDropdown({required this.acara, required this.bundel});

  final Acara acara;
  final Bundel bundel;

  Future<void> _hapus(
    BuildContext context,
    WidgetRef ref,
    AmplopTercatat tercatat,
  ) async {
    final amplop = tercatat.amplop;
    final yakin = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus amplop?'),
        content: Text(
          'Amplop ${amplop.tampilNama} (${formatRupiah(amplop.nominal)}) '
          'akan dihapus dari bundel ${bundel.kode}. Total bundel & '
          'acara ikut berkurang.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (yakin != true) return;
    try {
      await ref
          .read(koreksiServiceProvider)
          .hapusAmplop(
            acaraId: acara.id,
            bundelId: bundel.id,
            amplop: amplop,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Amplop dihapus.')),
        );
      }
    } on LayananException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.pesan)));
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
    final bisaKoreksi = acara.sudahSelesai;
    return StreamBuilder<List<AmplopTercatat>>(
      stream: ref
          .watch(pencatatanServiceProvider)
          .amplopBundelStream(acara.id, bundel.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: TampilMuat(),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: TampilGalat(pesan: pesanDari(snapshot.error!)),
          );
        }
        final isi = snapshot.data ?? const <AmplopTercatat>[];
        return Column(
          children: [
            if (isi.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Bundel ini masih kosong.'),
              ),
            for (final tercatat in isi)
              BarisAmplop(
                tercatat: tercatat,
                onUbah: bisaKoreksi
                    ? () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => KoreksiAmplopScreen(
                              acaraId: acara.id,
                              bundel: bundel,
                              amplopLama: tercatat.amplop,
                            ),
                          ),
                        );
                      }
                    : null,
                onHapus: bisaKoreksi
                    ? () => _hapus(context, ref, tercatat)
                    : null,
              ),
            if (bisaKoreksi && bundel.jumlahAmplop < 10)
              ListTile(
                leading: const Icon(Icons.add_circle_outline),
                title: const Text('Tambah amplop ke bundel ini'),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => KoreksiAmplopScreen(
                        acaraId: acara.id,
                        bundel: bundel,
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
