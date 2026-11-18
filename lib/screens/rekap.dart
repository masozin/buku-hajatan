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
import 'daftar_rekap.dart';

/// Rekap acara (Batch 3) — layar pemilik.
///
/// Realtime tanpa membakar kuota: total dari dokumen acara, rincian
/// per pencatat dari dokumen bundel (stream). Isi amplop hanya
/// dibaca SEKALI saat rekap per alamat atau ekspor dijalankan.
/// (Batch 20: pencarian nama di layar ini dihapus — sudah ada di
/// tab Pengunjung; rincian per bundel diganti per alamat.)
/// (Batch 29: kartu Per Pencatat & Per Alamat / Desa bisa diketuk
/// membuka daftar pengunjung kelompoknya; kelompok alamat urut
/// abjad.)
class RekapScreen extends ConsumerStatefulWidget {
  const RekapScreen({super.key, required this.acaraId});

  final String acaraId;

  @override
  ConsumerState<RekapScreen> createState() => _RekapScreenState();
}

class _RekapScreenState extends ConsumerState<RekapScreen> {
  bool _mengekspor = false;

  void _beriTahu(String pesan) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(pesan)));
  }

  Future<void> _ekspor(Acara acara, String format) async {
    setState(() => _mengekspor = true);
    try {
      final data = await ref
          .read(rekapServiceProvider)
          .ambilDataLengkap(acara.id);
      final ekspor = ref.read(eksporServiceProvider);
      if (format == 'excel') {
        await ekspor.eksporExcel(
          acara: acara,
          tanggalTeks: formatTanggal(acara.tanggal),
          data: data,
        );
      } else if (format == 'pdf') {
        await ekspor.eksporPdf(
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
                onExcel: () => _ekspor(acara, 'excel'),
                onCsv: () => _ekspor(acara, 'csv'),
                onPdf: () => _ekspor(acara, 'pdf'),
              ),
              const SizedBox(height: 16),
              _PerPencatat(acaraId: acara.id, sudahSelesai: acara.sudahSelesai),
              const SizedBox(height: 16),
              _PerAlamat(acaraId: acara.id, sudahSelesai: acara.sudahSelesai),
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
                    label: 'Kosong',
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
    // Batch 20: susunan MENUMPUK (ikon di atas, angka, label) —
    // susunan lama (ikon di samping kolom teks setinggi ikon)
    // memunculkan peringatan "height overflowed" di HP Mark.
    // Kolom vertikal di dalam ListView tidak bisa meluap.
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
            const SizedBox(height: 10),
            Text(
              nilai,
              style: tema.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              style: tema.textTheme.bodySmall?.copyWith(
                color: skema.onSurfaceVariant,
              ),
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
    required this.onPdf,
  });

  final bool sibuk;
  final VoidCallback onExcel;
  final VoidCallback onCsv;
  final VoidCallback onPdf;

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
            const SizedBox(height: 12),
            // Batch 25: ekspor PDF untuk dicetak — kop detail
            // acara, tabel urut abjad, rekap di bawah.
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: sibuk ? null : onPdf,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('PDF — daftar abjad untuk dicetak'),
              ),
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

/// Rincian per pencatat dari stream bundel.
class _PerPencatat extends ConsumerWidget {
  const _PerPencatat({required this.acaraId, required this.sudahSelesai});

  final String acaraId;

  /// Diteruskan ke daftar grup: menentukan hak Ubah/Hapus di
  /// lembar detail (koreksi pemilik hanya setelah selesai).
  final bool sudahSelesai;

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
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        // Batch 29: ketuk kartu membuka daftar
                        // pengunjung pencatat ini.
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => DaftarRekapGrupScreen(
                                acaraId: acaraId,
                                sudahSelesai: sudahSelesai,
                                judul: r.nama.isEmpty
                                    ? 'Pencatat ${r.prefix}'
                                    : r.nama,
                                pencatatId: r.pencatatId,
                              ),
                            ),
                          );
                        },
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
                                          '${r.jumlahAmplop} pengunjung • '
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
                                  const SizedBox(width: 2),
                                  Icon(
                                    Icons.chevron_right,
                                    size: 20,
                                    color: skema.onSurfaceVariant,
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
                    ),
              ],
            );
          },
        );
      },
    );
  }
}
/// Rincian per alamat (Batch 20): semua pengunjung dibaca SEKALI
/// (pola yang sama dengan ekspor), lalu dikelompokkan per alamat
/// oleh rekapPerAlamat. Menggantikan rincian per bundel — rincian
/// per bundel tetap ada di tab Bundel Detail Acara.
/// Batch 29: kelompok urut ABJAD (nama desanya), dan kartunya
/// bisa diketuk membuka daftar pengunjung kelompok itu — pulang
/// dari daftar, ringkasan di sini dimuat ulang.
class _PerAlamat extends ConsumerStatefulWidget {
  const _PerAlamat({required this.acaraId, required this.sudahSelesai});

  final String acaraId;

  /// Diteruskan ke daftar grup: hak Ubah/Hapus di lembar detail.
  final bool sudahSelesai;

  @override
  ConsumerState<_PerAlamat> createState() => _PerAlamatState();
}

class _PerAlamatState extends ConsumerState<_PerAlamat> {
  late Future<List<BundelTerisi>> _data;

  Future<List<BundelTerisi>> _muat() =>
      ref.read(rekapServiceProvider).ambilDataLengkap(widget.acaraId);

  @override
  void initState() {
    super.initState();
    _data = _muat();
  }

  void _segarkan() {
    setState(() => _data = _muat());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const JudulBagian(teks: 'Per Alamat / Desa'),
        const SizedBox(height: 10),
        FutureBuilder<List<BundelTerisi>>(
          future: _data,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const TampilMuat();
            }
            if (snapshot.hasError) {
              return TampilGalat(pesan: pesanDari(snapshot.error!));
            }
            final ringkasan = rekapPerAlamat(
              snapshot.data ?? const <BundelTerisi>[],
            );
            if (ringkasan.isEmpty) {
              return const Text('Belum ada pengunjung tercatat.');
            }
            return Column(
              children: [
                for (final r in ringkasan)
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      title: Text(
                        r.alamat,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text('${r.jumlahPengunjung} pengunjung'),
                      // Batch 29: ketuk membuka daftar pengunjung
                      // alamat/desa ini.
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => DaftarRekapGrupScreen(
                              acaraId: widget.acaraId,
                              sudahSelesai: widget.sudahSelesai,
                              judul: r.alamat,
                              kunciAlamat: r.kunci,
                            ),
                          ),
                        );
                        if (mounted) _segarkan();
                      },
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            formatRupiah(r.totalRp),
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(width: 2),
                          const Icon(Icons.chevron_right, size: 20),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
