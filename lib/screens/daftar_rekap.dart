import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../core/rekap.dart';
import '../models/amplop.dart';
import '../models/bundel.dart';
import '../providers.dart';
import '../services/layanan_exception.dart';
import '../widgets/detail_pengunjung.dart';
import '../widgets/keadaan.dart';
import 'koreksi_amplop.dart';

/// Daftar pengunjung satu kelompok Rekap (Batch 29, permintaan
/// Mark): dibuka dari kartu Per Pencatat atau Per Alamat / Desa di
/// RekapScreen. Isinya nama, alamat, nominal (+ ikon sinkron) per
/// pengunjung; ketuk satu baris membuka lembar detail BERSAMA
/// (widgets/detail_pengunjung.dart) — tombol Ubah & Hapus tampil
/// bila diizinkan.
///
/// Layar Rekap hanya dibuka PEMILIK, jadi hak aksinya hak koreksi
/// pemilik: ubah + hapus hanya setelah acara selesai; selama acara
/// berlangsung detail tampil tanpa tombol (pemilik memantau).
///
/// Tepat satu dari [pencatatId] / [kunciAlamat] yang diisi —
/// penentu kelompoknya.
class DaftarRekapGrupScreen extends ConsumerStatefulWidget {
  const DaftarRekapGrupScreen({
    super.key,
    required this.acaraId,
    required this.sudahSelesai,
    required this.judul,
    this.pencatatId,
    this.kunciAlamat,
    this.tanpaBundel = false,
  });

  final String acaraId;

  /// true = acara sudah selesai → detail menawarkan Ubah & Hapus.
  final bool sudahSelesai;

  /// Judul kelompok: nama pencatat atau nama alamat/desanya.
  final String judul;

  /// Kelompok per pencatat: ID tetap pencatatnya (bundel PM
  /// memakai UID pemilik, sama seperti ringkasPerPencatat).
  final String? pencatatId;

  /// Kelompok per alamat: RingkasanAlamat.kunci ('' = tanpa
  /// alamat).
  final String? kunciAlamat;

  /// Metode Langsung (Batch 30): kode bundel disembunyikan.
  final bool tanpaBundel;

  @override
  ConsumerState<DaftarRekapGrupScreen> createState() =>
      _DaftarRekapGrupScreenState();
}

class _DaftarRekapGrupScreenState
    extends ConsumerState<DaftarRekapGrupScreen> {
  late Future<List<BundelTerisi>> _muatan;

  @override
  void initState() {
    super.initState();
    _muatan = _muat();
  }

  Future<List<BundelTerisi>> _muat() =>
      ref.read(rekapServiceProvider).ambilDataLengkap(widget.acaraId);

  Future<void> _segarkan() async {
    final baru = _muat();
    setState(() => _muatan = baru);
    await baru;
  }

  /// Hapus satu pengunjung (koreksi pemilik): dipanggil lembar
  /// detail SETELAH dialog konfirmasinya; true = terhapus.
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

  Future<void> _tampilkanDetail(
    AmplopDitemukan ditemukan,
    Bundel? bundel,
  ) async {
    final Bundel? b = bundel;
    final bisa = widget.sudahSelesai && b != null;
    final hasil = await tampilkanDetailPengunjung(
      context: context,
      amplop: ditemukan.amplop,
      kodeBundel: widget.tanpaBundel ? '' : ditemukan.kodeBundel,
      bisaUbah: bisa,
      bisaHapus: bisa,
      onHapus: (bisa && b != null)
          ? () => _hapusAmplop(ditemukan.amplop, b)
          : null,
      pesanKunci: bisa
          ? null
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
            amplopLama: ditemukan.amplop,
          ),
        ),
      );
      if (mounted) await _segarkan();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.judul)),
      body: FutureBuilder<List<BundelTerisi>>(
        future: _muatan,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const TampilMuat();
          }
          if (snapshot.hasError) {
            return TampilGalat(pesan: pesanDari(snapshot.error!));
          }
          final data = snapshot.data ?? const <BundelTerisi>[];
          final petaBundel = <String, Bundel>{
            for (final bt in data) bt.bundel.kode: bt.bundel,
          };
          final tampil = widget.pencatatId != null
              ? pengunjungPerPencatat(data, widget.pencatatId!)
              : pengunjungPerAlamat(data, widget.kunciAlamat ?? '');
          if (tampil.isEmpty) {
            return const TampilKosong(
              teks: 'Belum ada pengunjung di kelompok ini.',
              ikon: Icons.people_outline,
            );
          }
          var total = 0;
          for (final d in tampil) {
            total += d.amplop.nominal;
          }
          return RefreshIndicator(
            onRefresh: _segarkan,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              itemCount: tampil.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      '${tampil.length} pengunjung • '
                      'Total ${formatRupiah(total)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  );
                }
                final ditemukan = tampil[i - 1];
                return _BarisItemRekap(
                  ditemukan: ditemukan,
                  tampilkanKode: !widget.tanpaBundel,
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
    );
  }
}

/// Satu baris pengunjung di daftar grup Rekap (Batch 29): nama +
/// alamat gabungan di kiri; nominal + ikon sinkron dan kode
/// bundel-urut di kanan — bahasa visual yang sama dengan baris
/// tab Pengunjung, tanpa tombol aksi (aksi ada di detail).
class _BarisItemRekap extends StatelessWidget {
  const _BarisItemRekap({
    required this.ditemukan,
    this.tampilkanKode = true,
    this.onTap,
  });

  final AmplopDitemukan ditemukan;

  /// false pada Metode Langsung (Batch 30).
  final bool tampilkanKode;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final skema = tema.colorScheme;
    final a = ditemukan.amplop;
    final meta = gabungAlamat(
      alamat: a.alamat,
      dusun: a.dusun,
      rt: a.rt,
      rw: a.rw,
    );
    final gayaSamping = tema.textTheme.bodySmall?.copyWith(
      color: skema.onSurfaceVariant,
    );
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
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        formatRupiah(a.nominal),
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
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
