import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../core/pengunjung.dart';
import '../core/rekap.dart';
import '../models/bundel.dart';
import '../providers.dart';
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
class DaftarPengunjungTab extends ConsumerStatefulWidget {
  const DaftarPengunjungTab({
    super.key,
    required this.acaraId,
    required this.sudahSelesai,
  });

  final String acaraId;

  /// true = acara sudah ditandai selesai → pratinjau menawarkan
  /// tombol Ubah (mode koreksi pemilik).
  final bool sudahSelesai;

  @override
  ConsumerState<DaftarPengunjungTab> createState() =>
      _DaftarPengunjungTabState();
}

class _DaftarPengunjungTabState extends ConsumerState<DaftarPengunjungTab> {
  final _cari = TextEditingController();
  late Future<List<BundelTerisi>> _muatan;
  UrutanPengunjung _urutan = UrutanPengunjung.bundel;
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
                    border: OutlineInputBorder(),
                    isDense: true,
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
              final semua = semuaPengunjung(
                snapshot.data ?? const <BundelTerisi>[],
              );
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
                    return _BarisPengunjung(ditemukan: tampil[i - 1]);
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

class _BarisPengunjung extends StatelessWidget {
  const _BarisPengunjung({required this.ditemukan});

  final AmplopDitemukan ditemukan;

  @override
  Widget build(BuildContext context) {
    final a = ditemukan.amplop;
    final rincian = [
      if (a.alamat != null && a.alamat!.isNotEmpty) a.alamat!,
      if (a.dusun != null) 'Dusun ${a.dusun}',
      if (a.keterangan != null && a.keterangan!.isNotEmpty) a.keterangan!,
      if (a.jenis.label != 'Normal') a.jenis.label,
    ].join(' • ');
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(a.tampilNama),
        subtitle: Text(
          [
            if (rincian.isNotEmpty) rincian,
            'Bundel ${ditemukan.kodeBundel} no. ${a.urut}'
                '${a.createdAt == null ? '' : ' • ${formatTanggalJam(a.createdAt!)}'}',
          ].join('\n'),
        ),
        isThreeLine: true,
        trailing: Text(
          formatRupiah(a.nominal),
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ),
    );
  }
}
