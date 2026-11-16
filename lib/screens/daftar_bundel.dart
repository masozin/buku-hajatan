import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../models/bundel.dart';
import '../providers.dart';
import '../services/pencatatan_service.dart';
import '../widgets/baris_amplop.dart';
import '../widgets/keadaan.dart';

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

/// Isi satu bundel (baca saja): daftar amplop 1..10 + total bundel.
class IsiBundelScreen extends ConsumerWidget {
  const IsiBundelScreen({
    super.key,
    required this.acaraId,
    required this.bundel,
  });

  final String acaraId;
  final Bundel bundel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layanan = ref.watch(pencatatanServiceProvider);
    return Scaffold(
      appBar: AppBar(title: Text('Bundel ${bundel.kode}')),
      body: ListView(
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
                    nilai: '${bundel.jumlahAmplop}/10',
                  ),
                  _Angka(
                    label: 'Total',
                    nilai: formatRupiah(bundel.totalRp),
                  ),
                  _Angka(
                    label: 'Status',
                    nilai: bundel.status == StatusBundel.penuh
                        ? 'Penuh'
                        : 'Terbuka',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          StreamBuilder<List<AmplopTercatat>>(
            stream: layanan.amplopBundelStream(acaraId, bundel.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const TampilMuat();
              }
              if (snapshot.hasError) {
                return TampilGalat(pesan: pesanDari(snapshot.error!));
              }
              final isi = snapshot.data ?? const <AmplopTercatat>[];
              if (isi.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Bundel ini masih kosong.'),
                );
              }
              return Card(
                child: Column(
                  children: [
                    for (final tercatat in isi)
                      BarisAmplop(tercatat: tercatat),
                  ],
                ),
              );
            },
          ),
        ],
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
