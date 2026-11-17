import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../models/acara.dart';
import '../models/bundel.dart';
import '../providers.dart';
import '../services/layanan_exception.dart';
import '../services/pencatatan_service.dart';
import '../widgets/baris_amplop.dart';
import '../widgets/keadaan.dart';
import 'koreksi_amplop.dart';

/// Daftar bundel (Batch 2).
///
/// - Pencatat: bundel miliknya sendiri di acara ini.
/// - Pemilik: semua bundel di acaranya (per pencatat).
/// Ketuk satu bundel untuk melihat isinya (baca saja).
class DaftarBundelScreen extends ConsumerWidget {
  const DaftarBundelScreen({
    super.key,
    required this.acaraId,
    this.pencatatId,
    required this.sebagaiPemilik,
  });

  final String acaraId;

  /// Bila null, tampilkan semua bundel (pemilik).
  final String? pencatatId;
  final bool sebagaiPemilik;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layanan = ref.watch(pencatatanServiceProvider);
    final stream = pencatatId == null
        ? layanan.semuaBundelStream(acaraId)
        : layanan.bundelPencatatStream(acaraId, pencatatId!);
    return Scaffold(
      appBar: AppBar(
        title: Text(sebagaiPemilik ? 'Semua Bundel' : 'Bundel Saya'),
      ),
      body: StreamBuilder<List<Bundel>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const TampilMuat();
          }
          if (snapshot.hasError) {
            return TampilGalat(pesan: pesanDari(snapshot.error!));
          }
          final daftar = [...(snapshot.data ?? const <Bundel>[])];
          // Terbaru dulu (nomor menurun; pemilik: prefix dulu).
          daftar.sort((a, b) {
            final bandingPrefix = a.prefix.compareTo(b.prefix);
            if (bandingPrefix != 0) return bandingPrefix;
            return b.nomor.compareTo(a.nomor);
          });
          if (daftar.isEmpty) {
            return const TampilKosong(
              teks: 'Belum ada bundel. Bundel pertama dibuat saat '
                  'pencatat mulai mencatat.',
              ikon: Icons.inventory_2_outlined,
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: daftar.length,
            itemBuilder: (context, i) {
              final bundel = daftar[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: CircleAvatar(child: Text(bundel.prefix)),
                  title: Text(bundel.kode),
                  subtitle: Text(
                    '${bundel.jumlahAmplop}/10 amplop • '
                    '${formatRupiah(bundel.totalRp)}'
                    '${bundel.jumlahKosong > 0 ? ' • Kosong: ${bundel.jumlahKosong}' : ''}'
                    '${bundel.jumlahTanpaNama > 0 ? ' • Tanpa nama: ${bundel.jumlahTanpaNama}' : ''}',
                  ),
                  trailing: Chip(
                    label: Text(
                      bundel.status == StatusBundel.penuh
                          ? 'Penuh'
                          : 'Terbuka',
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => IsiBundelScreen(
                          acaraId: acaraId,
                          bundel: bundel,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Isi satu bundel: daftar amplop 1..10 + total bundel.
///
/// Umumnya baca saja. Pengecualian (Batch 6): bila yang membuka
/// adalah PEMILIK dan acaranya SUDAH SELESAI, layar ini masuk mode
/// koreksi — tiap baris dapat diubah/dihapus dan ada tombol tambah
/// (ke bundel yang belum penuh). Selama acara aktif pemilik hanya
/// memantau, sesuai aturan mainnya.
class IsiBundelScreen extends ConsumerWidget {
  const IsiBundelScreen({
    super.key,
    required this.acaraId,
    required this.bundel,
  });

  final String acaraId;
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
          .hapusAmplop(acaraId: acaraId, bundelId: bundel.id, amplop: amplop);
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
    final layanan = ref.watch(pencatatanServiceProvider);
    final pengguna = ref.watch(statusPenggunaProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(title: Text('Bundel ${bundel.kode}')),
      body: StreamBuilder<Acara?>(
        stream: ref.watch(acaraServiceProvider).acaraStream(acaraId),
        builder: (context, snapAcara) {
          final acara = snapAcara.data;
          final sayaPemilik =
              acara != null &&
              pengguna != null &&
              acara.pemilikId == pengguna.uid;
          final bisaKoreksi = sayaPemilik && acara.sudahSelesai;
          return StreamBuilder<List<Bundel>>(
            stream: layanan.semuaBundelStream(acaraId),
            builder: (context, snapBundel) {
              // Bundel segar dari stream (agregat berubah setelah
              // koreksi); fallback ke bundel bawaan navigasi.
              var segar = bundel;
              for (final b in snapBundel.data ?? const <Bundel>[]) {
                if (b.id == bundel.id) segar = b;
              }
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _Angka(
                            label: 'Amplop',
                            nilai: '${segar.jumlahAmplop}/10',
                          ),
                          _Angka(
                            label: 'Total',
                            nilai: formatRupiah(segar.totalRp),
                          ),
                          _Angka(
                            label: 'Status',
                            nilai: segar.status == StatusBundel.penuh
                                ? 'Penuh'
                                : 'Terbuka',
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (bisaKoreksi) ...[
                    const SizedBox(height: 12),
                    const Card(
                      child: ListTile(
                        leading: Icon(Icons.edit_note_outlined),
                        title: Text('Mode koreksi aktif'),
                        subtitle: Text(
                          'Acara sudah selesai — amplop dapat ditambah, '
                          'diubah, dan dihapus bila perlu.',
                        ),
                      ),
                    ),
                  ] else if (sayaPemilik) ...[
                    const SizedBox(height: 12),
                    const Card(
                      child: ListTile(
                        leading: Icon(Icons.visibility_outlined),
                        title: Text('Mode memantau'),
                        subtitle: Text(
                          'Acara masih berlangsung — koreksi data '
                          'dibuka setelah acara ditandai selesai.',
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  StreamBuilder<List<AmplopTercatat>>(
                    stream: layanan.amplopBundelStream(acaraId, bundel.id),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const TampilMuat();
                      }
                      if (snapshot.hasError) {
                        return TampilGalat(
                          pesan: pesanDari(snapshot.error!),
                        );
                      }
                      final isi =
                          snapshot.data ?? const <AmplopTercatat>[];
                      if (isi.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text('Bundel ini masih kosong.'),
                        );
                      }
                      // Pencatat yang membuka bundel MILIKNYA saat
                      // acara aktif juga dapat tombol ubah (Batch 8,
                      // hanya untuk amplop inputannya sendiri —
                      // ditegakkan service & rules).
                      final bisaUbahPencatat =
                          !bisaKoreksi &&
                          acara != null &&
                          !acara.sudahSelesai &&
                          pengguna != null &&
                          segar.pencatatId == pengguna?.uid;
                      return Card(
                        child: Column(
                          children: [
                            for (final tercatat in isi)
                              BarisAmplop(
                                tercatat: tercatat,
                                onUbah: bisaKoreksi
                                    ? () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                KoreksiAmplopScreen(
                                                  acaraId: acaraId,
                                                  bundel: segar,
                                                  amplopLama:
                                                      tercatat.amplop,
                                                ),
                                          ),
                                        );
                                      }
                                    : bisaUbahPencatat
                                    ? () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                KoreksiAmplopScreen(
                                                  acaraId: acaraId,
                                                  bundel: segar,
                                                  amplopLama:
                                                      tercatat.amplop,
                                                  pencatatId:
                                                      segar.pencatatId,
                                                ),
                                          ),
                                        );
                                      }
                                    : null,
                                onHapus: bisaKoreksi
                                    ? () =>
                                          _hapus(context, ref, tercatat)
                                    : null,
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                  if (bisaKoreksi && segar.jumlahAmplop < 10) ...[
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => KoreksiAmplopScreen(
                              acaraId: acaraId,
                              bundel: segar,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Tambah Amplop'),
                    ),
                  ],
                ],
              );
            },
          );
        },
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
