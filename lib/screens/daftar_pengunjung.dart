import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../core/pengunjung.dart';
import '../core/rekap.dart';
import '../models/amplop.dart';
import '../models/bundel.dart';
import '../providers.dart';
import '../services/layanan_exception.dart';
import '../widgets/detail_pengunjung.dart';
import '../widgets/keadaan.dart';
import 'koreksi_amplop.dart';

/// Tab Pengunjung di Detail Acara (Batch 7): seluruh amplop dari
/// semua bundel dalam satu daftar — ada kolom pencarian dan pilihan
/// urutan (nama, nominal, dusun, waktu, bundel).
///
/// Data dibaca SEKALI jalan lewat RekapService (bukan listener,
/// hemat kuota baca); tombol muat ulang / tarik ke bawah untuk
/// menyegarkan selama acara berjalan.
///
/// Sejak Batch 9 tiap baris bisa diketuk: muncul pratinjau data
/// lengkapnya, dan bila acara sudah selesai pemilik dapat langsung
/// mengedit amplop itu dari pratinjau (form koreksi Batch 6).
///
/// Sejak Batch 11 tab ini juga dipakai PENCATAT (modePencatat):
/// semua pengunjung tetap terlihat, tetapi tombol Ubah di
/// pratinjau hanya muncul untuk amplop inputannya SENDIRI dan
/// hanya selama acara masih aktif (hak ubah pencatat, Batch 8).
class DaftarPengunjungTab extends ConsumerStatefulWidget {
  const DaftarPengunjungTab({
    super.key,
    required this.acaraId,
    required this.sudahSelesai,
    this.modePencatat = false,
    this.pencatatIdSaya,
    this.metodeLangsung = false,
  });

  final String acaraId;

  /// true = acara sudah ditandai selesai → pratinjau menawarkan
  /// tombol Ubah (mode koreksi pemilik).
  final bool sudahSelesai;

  /// true bila yang membuka adalah pencatat (Batch 11).
  final bool modePencatat;

  /// ID tetap pencatat yang membuka (mode pencatat) — penentu
  /// amplop mana yang boleh ia ubah. Null = sesi tidak ditemukan,
  /// tidak ada hak ubah sama sekali.
  final String? pencatatIdSaya;

  /// Metode Langsung (Batch 30): kode bundel disembunyikan.
  final bool metodeLangsung;

  @override
  ConsumerState<DaftarPengunjungTab> createState() =>
      _DaftarPengunjungTabState();
}

class _DaftarPengunjungTabState extends ConsumerState<DaftarPengunjungTab> {
  final _cari = TextEditingController();
  late Future<List<BundelTerisi>> _muatan;
  // Batch 13: tampilan bawaan adalah yang terbaru dicatat.
  UrutanPengunjung _urutan = UrutanPengunjung.terbaru;
  String _kataKunci = '';

  @override
  void initState() {
    super.initState();
    _muatan = _muat();
  }

  @override
  void dispose() {
    _cari.dispose();
    super.dispose();
  }

  Future<List<BundelTerisi>> _muat() =>
      ref.read(rekapServiceProvider).ambilDataLengkap(widget.acaraId);

  Future<void> _segarkan() async {
    final baru = _muat();
    setState(() => _muatan = baru);
    await baru;
  }

  /// Pratinjau satu pengunjung (Batch 9, diseragamkan Batch 29):
  /// lembar detail BERSAMA (widgets/detail_pengunjung.dart) — data
  /// lengkap plus tombol Ubah & Hapus SESUAI HAK:
  /// - Pemilik: ubah + hapus, hanya setelah acara selesai
  ///   (koreksi, Batch 6/9).
  /// - Pencatat (Batch 11): ubah saja — hanya amplop inputannya
  ///   sendiri dan hanya selama acara aktif (Batch 8); hapus tetap
  ///   khusus pemilik pasca-selesai.
  /// Sesudah ubah/hapus, daftar dimuat ulang agar perubahan
  /// terlihat.
  Future<void> _tampilkanDetail(
    AmplopDitemukan ditemukan,
    Bundel? bundel,
  ) async {
    final a = ditemukan.amplop;
    final Bundel? b = bundel;
    final milikSaya =
        widget.pencatatIdSaya != null &&
        a.createdBy == widget.pencatatIdSaya;
    final bisaUbah =
        b != null &&
        (widget.modePencatat
            ? (milikSaya && !widget.sudahSelesai)
            : widget.sudahSelesai);
    final bisaHapus =
        b != null && !widget.modePencatat && widget.sudahSelesai;
    final hasil = await tampilkanDetailPengunjung(
      context: context,
      amplop: a,
      kodeBundel: (widget.metodeLangsung || ditemukan.bebas)
          ? ''
          : ditemukan.kodeBundel,
      bisaUbah: bisaUbah,
      bisaHapus: bisaHapus,
      onHapus: (bisaHapus && b != null) ? () => _hapusAmplop(a, b) : null,
      pesanKunci: (bisaUbah || bisaHapus)
          ? null
          : widget.modePencatat
          ? (milikSaya
                ? 'Acara sudah selesai — perubahan data kini '
                      'lewat pemilik acara.'
                : 'Ini catatan pencatat lain — kamu hanya bisa '
                      'mengubah catatanmu sendiri.')
          : 'Acara masih berlangsung — ubah & hapus dibuka '
                'setelah acara ditandai selesai.',
    );
    if (!mounted || b == null) return;
    if (hasil == 'hapus') {
      await _segarkan();
    } else if (hasil == 'ubah') {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => KoreksiAmplopScreen(
            acaraId: widget.acaraId,
            bundel: b,
            amplopLama: a,
            // Mode pencatat: simpan lewat jalur ubah pencatat
            // (Batch 8); pemilik membiarkannya null (jalur koreksi).
            pencatatId: widget.modePencatat ? widget.pencatatIdSaya : null,
          ),
        ),
      );
      if (mounted) await _segarkan();
    }
  }

  /// Hapus satu pengunjung (koreksi pemilik, Batch 29): dipanggil
  /// lembar detail SETELAH dialog konfirmasinya sendiri; hasil
  /// true berarti terhapus. Snackbar hasil ditampilkan di sini.
  Future<bool> _hapusAmplop(Amplop a, Bundel bundel) async {
    try {
      await ref
          .read(koreksiServiceProvider)
          .hapusAmplop(
            acaraId: widget.acaraId,
            bundelId: bundel.id,
            amplop: a,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pengunjung dihapus.')),
        );
      }
      return true;
    } on LayananException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.pesan)));
      }
      return false;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(pesanDari(e))));
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _cari,
                  decoration: const InputDecoration(
                    labelText: 'Cari nama, alamat, dusun, keterangan…',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) => setState(() => _kataKunci = v),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<UrutanPengunjung>(
                tooltip: 'Urutkan',
                icon: const Icon(Icons.sort),
                initialValue: _urutan,
                onSelected: (u) => setState(() => _urutan = u),
                itemBuilder: (context) => [
                  for (final u in UrutanPengunjung.values)
                    PopupMenuItem(
                      value: u,
                      child: Text(
                        u == _urutan ? '✓ ${u.label}' : u.label,
                      ),
                    ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Muat ulang',
                onPressed: _segarkan,
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<BundelTerisi>>(
            future: _muatan,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const TampilMuat();
              }
              if (snapshot.hasError) {
                return TampilGalat(pesan: pesanDari(snapshot.error!));
              }
              final dataLengkap = snapshot.data ?? const <BundelTerisi>[];
              // Peta kode bundel → bundelnya, untuk membuka form
              // koreksi dari pratinjau (Batch 9).
              final petaBundel = <String, Bundel>{
                for (final bt in dataLengkap) bt.bundel.kode: bt.bundel,
              };
              final semua = semuaPengunjung(dataLengkap);
              final tampil = urutkanPengunjung(
                saringPengunjung(semua, _kataKunci),
                _urutan,
              );
              if (semua.isEmpty) {
                return const TampilKosong(
                  teks: 'Belum ada pengunjung tercatat.',
                  ikon: Icons.people_outline,
                );
              }
              return RefreshIndicator(
                onRefresh: _segarkan,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                  itemCount: tampil.length + 1,
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          '${tampil.length} pengunjung'
                          '${_kataKunci.isEmpty ? '' : ' cocok pencarian'}'
                          ' • Urutan: ${_urutan.label}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      );
                    }
                    final ditemukan = tampil[i - 1];
                    return _BarisPengunjung(
                      ditemukan: ditemukan,
                      tampilkanKode:
                          !widget.metodeLangsung && !ditemukan.bebas,
                      onTap: () => _tampilkanDetail(
                        ditemukan,
                        petaBundel[ditemukan.kodeBundel],
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Satu baris pengunjung (Batch 13, disederhanakan atas
/// permintaan Mark): nama + alamat/dusun kecil di bawahnya;
/// sisi kanan berisi nominal, lalu kode bundel-urut (mis.
/// "A001-1") dan cap waktu di bawahnya. Tanpa avatar inisial.
class _BarisPengunjung extends StatelessWidget {
  const _BarisPengunjung({
    required this.ditemukan,
    this.tampilkanKode = true,
    this.onTap,
  });

  final AmplopDitemukan ditemukan;

  /// false pada Metode Langsung (Batch 30): baris kode-urut
  /// disembunyikan karena tidak ada bundel.
  final bool tampilkanKode;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final skema = tema.colorScheme;
    final a = ditemukan.amplop;
    final meta = [
      if (a.alamat != null && a.alamat!.isNotEmpty) a.alamat!,
      if (a.dusun != null) 'Dusun ${a.dusun}',
      if (a.rt != null || a.rw != null)
        [
          if (a.rt != null) 'RT ${a.rt}',
          if (a.rw != null) 'RW ${a.rw}',
        ].join('/'),
    ].join(' • ');
    final gayaSamping = tema.textTheme.bodySmall?.copyWith(
      color: skema.onSurfaceVariant,
    );
    // Batch 14: BUKAN ListTile lagi — kolom kanan berisi tiga
    // baris (nominal, kode-urut, waktu) dan ListTile membatasi
    // tinggi sisinya sehingga meluap ("bottom overflowed").
    // Kini baris bebas: tinggi mengikuti isi terpanjang.
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.tampilNama,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        meta,
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
                  // Batch 28: ikon sinkron di samping nominal,
                  // bahasa visual yang sama dengan baris
                  // pencatatan — emas = menunggu terkirim,
                  // zamrud = sudah tersinkron.
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        // Batch 32: entri Buku Tamu yang belum
                        // dihitung nominalnya belum ada — jangan
                        // tampilkan Rp 0.
                        a.dihitung
                            ? formatRupiah(a.nominal)
                            : 'Belum dihitung',
                        style: tema.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        a.menungguSinkron
                            ? Icons.cloud_upload_outlined
                            : Icons.cloud_done_outlined,
                        size: 16,
                        color: a.menungguSinkron
                            ? skema.tertiary
                            : skema.primary,
                      ),
                    ],
                  ),
                  if (tampilkanKode) ...[
                    const SizedBox(height: 3),
                    Text(
                      '${ditemukan.kodeBundel}-${a.urut}',
                      style: gayaSamping,
                    ),
                  ],
                  if (a.createdAt != null)
                    Text(
                      formatWaktuKonteks(a.createdAt!),
                      style: gayaSamping,
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
