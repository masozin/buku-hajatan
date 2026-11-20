import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../core/kode.dart';
import '../models/acara.dart';
import '../models/bundel.dart';
import '../models/pencatat.dart';
import '../providers.dart';
import '../services/layanan_exception.dart';
import '../services/pencatatan_service.dart';
import '../widgets/baris_amplop.dart';
import '../widgets/detail_pengunjung.dart';
import '../widgets/keadaan.dart';
import 'koreksi_amplop.dart';

/// Tab Bundel di Detail Acara pemilik (Batch 9, menggantikan
/// tombol "Lihat Semua Bundel"): tiap bundel tampil sebagai
/// baris dropdown berisi kode bundel, jumlah amplop, dan total
/// Rp — dibuka untuk melihat daftar pengunjung di dalamnya.
///
/// Setelah acara selesai, pemilik mendapat aksi koreksi penuh
/// (tambah amplop ke bundel belum penuh; ubah/hapus per pengunjung
/// lewat lembar detail, Batch 29).
///
/// Sejak Batch 11 tab ini juga dipakai PENCATAT: hanya bundel
/// MILIKNYA yang tampil, dan selama acara aktif ia bisa mengubah
/// amplop inputannya sendiri lewat lembar detail yang sama
/// (hak ubah pencatat, Batch 8 — tanpa hapus, tanpa tambah).
class DaftarBundelTab extends ConsumerWidget {
  const DaftarBundelTab({super.key, required this.acara, this.pencatatIdSaya});

  final Acara acara;

  /// ID tetap pencatat yang membuka (Batch 11): non-null = mode
  /// pencatat (hanya bundel miliknya). Null = mode pemilik.
  final String? pencatatIdSaya;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layanan = ref.watch(pencatatanServiceProvider);
    return StreamBuilder<List<Bundel>>(
      stream: pencatatIdSaya == null
          ? layanan.semuaBundelStream(acara.id)
          : layanan.bundelPencatatStream(acara.id, pencatatIdSaya!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const TampilMuat();
        }
        if (snapshot.hasError) {
          return TampilGalat(pesan: pesanDari(snapshot.error!));
        }
        // Bundel bebas (wadah Buku Tamu / Metode Langsung)
        // bukan bundel fisik — tidak ditampilkan di tab ini.
        final daftar = (snapshot.data ?? const <Bundel>[])
            .where((b) => !b.bebas)
            .toList();
        if (daftar.isEmpty) {
          return TampilKosong(
            teks: pencatatIdSaya == null
                ? 'Belum ada bundel. Bundel pertama dibuat pencatat '
                      'saat mulai mencatat.'
                : 'Belum ada bundel milikmu. Bundel pertama dibuat '
                      'saat kamu mulai mencatat.',
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
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ExpansionTile(
                    // Batch 13: kepala dropdown disederhanakan —
                    // cukup kode + total, lalu pencatat & batang
                    // kemajuan. Tanpa kotak inisial, tanpa kata
                    // "Bundel", tanpa lencana Penuh.
                    title: Text(
                      // Batch 35: di mode pencatat, total per
                      // bundel ikut ditutup bila pemilik
                      // menyalakan sembunyikanTotal.
                      (acara.sembunyikanTotal && pencatatIdSaya != null)
                          ? '${b.kode} • Rp •••••••'
                          : '${b.kode} • ${formatRupiah(b.totalRp)}',
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontSize: 15),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            b.prefix == prefixBundelPemilik
                                ? 'Pemilik acara'
                                : 'Pencatat: '
                                      '${namaPencatat[b.pencatatId] ?? '—'}',
                          ),
                          const SizedBox(height: 7),
                          Row(
                            children: [
                              Expanded(
                                child: LinearProgressIndicator(
                                  value: b.jumlahAmplop / 10,
                                  minHeight: 6,
                                  borderRadius: BorderRadius.circular(
                                    999,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${b.jumlahAmplop}/10',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    children: [
                      _IsiBundelDropdown(
                        acara: acara,
                        bundel: b,
                        pencatatIdSaya: pencatatIdSaya,
                      ),
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
/// dalam mode koreksi pemilik (acara selesai) — tambah amplop
/// bila bundel belum penuh. Baris amplopnya sendiri TANPA tombol
/// aksi (Batch 29): ketuk baris membuka lembar detail bersama
/// yang memuat tombol Ubah/Hapus sesuai hak.
class _IsiBundelDropdown extends ConsumerWidget {
  const _IsiBundelDropdown({
    required this.acara,
    required this.bundel,
    this.pencatatIdSaya,
  });

  final Acara acara;
  final Bundel bundel;

  /// Non-null = mode pencatat (Batch 11).
  final String? pencatatIdSaya;

  /// Hapus satu pengunjung (koreksi pemilik, Batch 29):
  /// dijalankan lembar detail SETELAH dialog konfirmasinya
  /// sendiri; true = berhasil terhapus.
  Future<bool> _eksekusiHapus(
    BuildContext context,
    WidgetRef ref,
    AmplopTercatat tercatat,
  ) async {
    try {
      await ref
          .read(koreksiServiceProvider)
          .hapusAmplop(
            acaraId: acara.id,
            bundelId: bundel.id,
            amplop: tercatat.amplop,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pengunjung dihapus.')),
        );
      }
      return true;
    } on LayananException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.pesan)));
      }
      return false;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(pesanDari(e))));
      }
      return false;
    }
  }

  /// Buka lembar detail bersama (Batch 29) untuk satu pengunjung
  /// di bundel ini — tombol Ubah/Hapus di dalamnya sesuai hak
  /// yang diteruskan pemanggil.
  Future<void> _bukaDetail(
    BuildContext context,
    WidgetRef ref,
    AmplopTercatat tercatat, {
    required bool bisaUbah,
    required bool bisaHapus,
  }) async {
    final hasil = await tampilkanDetailPengunjung(
      context: context,
      amplop: tercatat.amplop,
      kodeBundel: bundel.kode,
      bisaUbah: bisaUbah,
      bisaHapus: bisaHapus,
      onHapus: bisaHapus
          ? () => _eksekusiHapus(context, ref, tercatat)
          : null,
      pesanKunci: (bisaUbah || bisaHapus)
          ? null
          : pencatatIdSaya != null
          ? 'Acara sudah selesai — perubahan data kini '
                'lewat pemilik acara.'
          : 'Acara masih berlangsung — ubah & hapus dibuka '
                'setelah acara ditandai selesai.',
    );
    if (hasil != 'ubah' || !context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => KoreksiAmplopScreen(
          acaraId: acara.id,
          bundel: bundel,
          amplopLama: tercatat.amplop,
          // Mode pencatat: jalur ubah pencatat (Batch 8); mode
          // pemilik pencatatIdSaya null (jalur koreksi).
          pencatatId: pencatatIdSaya,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Pemilik: koreksi penuh setelah acara selesai. Pencatat:
    // ubah amplop di bundel miliknya selama acara aktif (Batch 8).
    final bisaKoreksi = pencatatIdSaya == null && acara.sudahSelesai;
    final bisaUbahPencatat =
        pencatatIdSaya != null && !acara.sudahSelesai;
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
                // Batch 29: baris bersih dari tombol aksi —
                // ketuk membuka lembar detail bersama; hak
                // ubahnya pencatat hanya untuk inputannya sendiri.
                onTap: () => _bukaDetail(
                  context,
                  ref,
                  tercatat,
                  bisaUbah:
                      bisaKoreksi ||
                      (bisaUbahPencatat &&
                          tercatat.amplop.createdBy == pencatatIdSaya),
                  bisaHapus: bisaKoreksi,
                ),
              ),
            if (bisaKoreksi && bundel.jumlahAmplop < 10)
              ListTile(
                leading: const Icon(Icons.add_circle_outline),
                title: const Text('Tambah pengunjung ke bundel ini'),
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
