import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../core/rekap.dart';
import '../models/acara.dart';
import '../models/bundel.dart';
import '../models/pencatat.dart';
import '../providers.dart';
import '../services/layanan_exception.dart';
import '../widgets/elemen.dart';
import '../widgets/kartu_total.dart';
import '../widgets/keadaan.dart';

/// Rekap acara (Batch 3) — layar pemilik.
///
/// Realtime tanpa membakar kuota: total dari dokumen acara, rincian
/// per pencatat & per bundel dari dokumen bundel (stream). Isi amplop
/// hanya dibaca SEKALI saat pencarian nama atau ekspor dijalankan.
class RekapScreen extends ConsumerStatefulWidget {
  const RekapScreen({super.key, required this.acaraId});

  final String acaraId;

  @override
  ConsumerState<RekapScreen> createState() => _RekapScreenState();
}

class _RekapScreenState extends ConsumerState<RekapScreen> {
  final _kataCari = TextEditingController();
  List<AmplopDitemukan>? _hasilCari;
  bool _mencari = false;
  bool _mengekspor = false;

  @override
  void dispose() {
    _kataCari.dispose();
    super.dispose();
  }

  void _beriTahu(String pesan) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(pesan)));
  }

  Future<void> _cari(Acara acara) async {
    final kata = _kataCari.text.trim();
    if (kata.length < 2) {
      _beriTahu('Ketik minimal 2 huruf untuk mencari.');
      return;
    }
    setState(() {
      _mencari = true;
      _hasilCari = null;
    });
    try {
      final hasil = await ref
          .read(rekapServiceProvider)
          .cariNama(acara.id, kata);
      if (mounted) setState(() => _hasilCari = hasil);
    } catch (e) {
      _beriTahu(pesanDari(e));
    } finally {
      if (mounted) setState(() => _mencari = false);
    }
  }

  Future<void> _ekspor(Acara acara, {required bool excel}) async {
    setState(() => _mengekspor = true);
    try {
      final data = await ref
          .read(rekapServiceProvider)
          .ambilDataLengkap(acara.id);
      final ekspor = ref.read(eksporServiceProvider);
      if (excel) {
        await ekspor.eksporExcel(
          acara: acara,
          tanggalTeks: formatTanggal(acara.tanggal),
          data: data,
        );
      } else {
        await ekspor.eksporCsv(acara: acara, data: data);
      }
    } on LayananException catch (e) {
      _beriTahu(e.pesan);
    } catch (e) {
      _beriTahu(pesanDari(e));
    } finally {
      if (mounted) setState(() => _mengekspor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final acaraStream = ref
        .watch(acaraServiceProvider)
        .acaraStream(widget.acaraId);
    return Scaffold(
      appBar: AppBar(title: const Text('Rekap Acara')),
      body: StreamBuilder<Acara?>(
        stream: acaraStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const TampilMuat();
          }
          if (snapshot.hasError) {
            return TampilGalat(pesan: pesanDari(snapshot.error!));
          }
          final acara = snapshot.data;
          if (acara == null) {
            return const TampilKosong(teks: 'Acara tidak ditemukan.');
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _RingkasanTotal(acara: acara),
              const SizedBox(height: 16),
              _KartuEkspor(
                sibuk: _mengekspor,
                onExcel: () => _ekspor(acara, excel: true),
                onCsv: () => _ekspor(acara, excel: false),
              ),
              const SizedBox(height: 16),
              _PerPencatatDanBundel(acaraId: acara.id),
              const SizedBox(height: 16),
              _KartuPencarian(
                controller: _kataCari,
                mencari: _mencari,
                hasil: _hasilCari,
                onCari: () => _cari(acara),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RingkasanTotal extends ConsumerWidget {
  const _RingkasanTotal({required this.acara});

  final Acara acara;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundelStream = ref
        .watch(pencatatanServiceProvider)
        .semuaBundelStream(acara.id);
    return StreamBuilder<List<Bundel>>(
      stream: bundelStream,
      builder: (context, snapshot) {
        final bundels = snapshot.data ?? const <Bundel>[];
        var kosong = 0;
        var tanpaNama = 0;
        for (final b in bundels) {
          kosong += b.jumlahKosong;
          tanpaNama += b.jumlahTanpaNama;
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              acara.namaAcara,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              '${acara.jenis} • ${formatTanggal(acara.tanggal)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            KartuTotalAcara(acara: acara),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MiniStatistik(
                    ikon: Icons.mail_outline_rounded,
                    label: 'Amplop Kosong',
                    nilai: '$kosong',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MiniStatistik(
                    ikon: Icons.person_off_outlined,
                    label: 'Tanpa Nama',
                    nilai: '$tanpaNama',
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Kartu statistik kecil (ikon + label + angka) di bawah kartu
/// total Rekap.
class _MiniStatistik extends StatelessWidget {
  const _MiniStatistik({
    required this.ikon,
    required this.label,
    required this.nilai,
  });

  final IconData ikon;
  final String label;
  final String nilai;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final skema = tema.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: skema.tertiaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(ikon, color: skema.onTertiaryContainer, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nilai, style: tema.textTheme.titleMedium),
                Text(
                  label,
                  style: tema.textTheme.bodySmall?.copyWith(
                    color: skema.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _KartuEkspor extends StatelessWidget {
  const _KartuEkspor({
    required this.sibuk,
    required this.onExcel,
    required this.onCsv,
  });

  final bool sibuk;
  final VoidCallback onExcel;
  final VoidCallback onCsv;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ekspor / Arsip Acara',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            const Text(
              'File hasil ekspor adalah arsip utama acara ini — '
              'simpan di tempat aman (Drive/email) setelah acara selesai.',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: sibuk ? null : onExcel,
                    icon: const Icon(Icons.table_view_outlined),
                    label: const Text('Excel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: sibuk ? null : onCsv,
                    icon: const Icon(Icons.description_outlined),
                    label: const Text('CSV'),
                  ),
                ),
              ],
            ),
            if (sibuk) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }
}

/// Rincian per pencatat + daftar per bundel dari stream bundel.
class _PerPencatatDanBundel extends ConsumerWidget {
  const _PerPencatatDanBundel({required this.acaraId});

  final String acaraId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundelStream = ref
        .watch(pencatatanServiceProvider)
        .semuaBundelStream(acaraId);
    final pencatatStream = ref
        .watch(acaraServiceProvider)
        .pencatatStream(acaraId);
    return StreamBuilder<List<Bundel>>(
      stream: bundelStream,
      builder: (context, snapBundel) {
        if (snapBundel.connectionState == ConnectionState.waiting) {
          return const TampilMuat();
        }
        if (snapBundel.hasError) {
          return TampilGalat(pesan: pesanDari(snapBundel.error!));
        }
        final bundels = snapBundel.data ?? const <Bundel>[];
        return StreamBuilder<List<Pencatat>>(
          stream: pencatatStream,
          builder: (context, snapPencatat) {
            final pencatats = snapPencatat.data ?? const <Pencatat>[];
            final ringkasan = ringkasPerPencatat(bundels, pencatats);
            final tema = Theme.of(context);
            final skema = tema.colorScheme;
            var totalTerbesar = 0;
            for (final r in ringkasan) {
              if (r.totalRp > totalTerbesar) totalTerbesar = r.totalRp;
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const JudulBagian(teks: 'Per Pencatat'),
                const SizedBox(height: 10),
                if (ringkasan.isEmpty)
                  const Text('Belum ada pencatat.')
                else
                  for (final r in ringkasan)
                    Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: skema.primaryContainer,
                                  child: Text(
                                    r.prefix,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: skema.onPrimaryContainer,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        r.nama.isEmpty
                                            ? 'Pencatat ${r.prefix}'
                                            : r.nama,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        '${r.jumlahBundel} bundel • '
                                        '${r.jumlahAmplop} amplop • '
                                        'kosong ${r.jumlahKosong} • '
                                        'tanpa nama ${r.jumlahTanpaNama}',
                                        style: tema.textTheme.bodySmall
                                            ?.copyWith(
                                              color:
                                                  skema.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  formatRupiah(r.totalRp),
                                  style: tema.textTheme.titleSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            LinearProgressIndicator(
                              value: totalTerbesar == 0
                                  ? 0
                                  : r.totalRp / totalTerbesar,
                              minHeight: 6,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ],
                        ),
                      ),
                    ),
                const SizedBox(height: 16),
                const JudulBagian(teks: 'Per Bundel'),
                const SizedBox(height: 10),
                if (bundels.isEmpty)
                  const Text('Belum ada bundel.')
                else
                  for (final b in bundels)
                    Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: skema.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            b.kode,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        title: Text(
                          formatRupiah(b.totalRp),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          'Pencatat ${b.prefix} • ${b.jumlahAmplop}/10 '
                          'amplop • kosong ${b.jumlahKosong} • '
                          'tanpa nama ${b.jumlahTanpaNama}',
                        ),
                        trailing: Chip(
                          label: Text(
                            b.status == StatusBundel.penuh
                                ? 'Penuh'
                                : 'Terbuka',
                          ),
                          backgroundColor:
                              b.status == StatusBundel.penuh
                              ? skema.tertiaryContainer
                              : skema.primaryContainer,
                          labelStyle: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: b.status == StatusBundel.penuh
                                ? skema.onTertiaryContainer
                                : skema.onPrimaryContainer,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
              ],
            );
          },
        );
      },
    );
  }
}

class _KartuPencarian extends StatelessWidget {
  const _KartuPencarian({
    required this.controller,
    required this.mencari,
    required this.hasil,
    required this.onCari,
  });

  final TextEditingController controller;
  final bool mencari;
  final List<AmplopDitemukan>? hasil;
  final VoidCallback onCari;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cari Nama Tamu',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            const Text(
              'Berguna saat mau membalas amplop: siapa memberi berapa, '
              'di bundel mana.',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nama / alamat',
                    ),
                    onSubmitted: (_) => onCari(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: mencari ? null : onCari,
                  child: mencari
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Cari'),
                ),
              ],
            ),
            if (hasil != null) ...[
              const SizedBox(height: 12),
              if (hasil!.isEmpty)
                const Text('Tidak ditemukan.')
              else
                for (final h in hasil!)
                  ListTile(
                    dense: true,
                    title: Text(h.amplop.tampilNama),
                    subtitle: Text(
                      'Bundel ${h.kodeBundel} (pencatat '
                      '${h.prefixPencatat})'
                      '${h.amplop.alamat == null ? '' : ' • ${h.amplop.alamat}'}'
                      ' • ${h.amplop.jenis.label}',
                    ),
                    trailing: Text(
                      formatRupiah(h.amplop.nominal),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }
}
