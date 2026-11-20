import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/rekap.dart';
import '../models/amplop.dart';

/// Lembar detail satu pengunjung (Batch 29) — dipakai BERSAMA oleh
/// tab Pengunjung, tab Bundel, dan daftar grup di Rekap, supaya
/// ketukan pada baris pengunjung di mana pun membuka tampilan yang
/// sama persis (permintaan Mark: baris cukup nama, alamat, nominal,
/// ikon sinkron — semua tombol aksi pindah ke dalam detail ini).
///
/// Isi: data lengkap pengunjung, lalu tombol aksi SESUAI HAK
/// pemanggil:
/// - [bisaUbah]: tombol Ubah tampil. Lembar ditutup dengan hasil
///   'ubah'; pemanggil yang membuka form koreksinya (form butuh
///   bundel & mode pemanggil yang berbeda-beda di tiap tempat).
/// - [bisaHapus] + [onHapus]: tombol Hapus tampil. Setelah dialog
///   konfirmasi, [onHapus] menjalankan penghapusannya (pemanggil
///   yang memegang service & menampilkan snackbar hasilnya);
///   true = berhasil, lembar ditutup dengan hasil 'hapus'.
/// - Bila tidak ada hak aksi dan [pesanKunci] diisi, tampil catatan
///   penjelas kenapa tidak ada tombol.
///
/// Hasil: 'ubah' | 'hapus' | null (ditutup biasa).
Future<String?> tampilkanDetailPengunjung({
  required BuildContext context,
  required Amplop amplop,
  required String kodeBundel,
  bool bisaUbah = false,
  bool bisaHapus = false,
  Future<bool> Function()? onHapus,
  String? pesanKunci,
}) {
  final a = amplop;
  final baris = <(String, String)>[
    // Batch 32: entri Buku Tamu belum dihitung — nominalnya
    // memang belum ada, bukan Rp 0.
    ('Nominal', a.dihitung ? formatRupiah(a.nominal) : 'Belum dihitung'),
    // Metode Langsung (Batch 30): kodeBundel dikirim kosong —
    // tidak ada bundel, tampilkan nomor urut saja.
    if (kodeBundel.isNotEmpty)
      ('Bundel', '$kodeBundel • nomor ${a.urut}')
    else
      ('Nomor urut', '${a.urut}'),
    if (a.alamat != null && a.alamat!.isNotEmpty) ('Alamat', a.alamat!),
    if (a.dusun != null)
      (
        // Batch 36: label mengikuti isi — angka murni "Dusun",
        // teks berlabel ("SP 2") "Dusun/Kampung".
        dusunNumerik(a.dusun) ? 'Dusun' : 'Dusun/Kampung',
        a.dusun!,
      ),
    if (a.rt != null) ('RT', '${a.rt}'),
    if (a.rw != null) ('RW', '${a.rw}'),
    if (a.keterangan != null && a.keterangan!.isNotEmpty)
      ('Keterangan', a.keterangan!),
    ('Jenis', a.jenis.label),
    if (a.createdAt != null) ('Dicatat', formatTanggalJam(a.createdAt!)),
  ];
  final adaHapus = bisaHapus && onHapus != null;
  return showModalBottomSheet<String>(
    context: context,
    builder: (sheetContext) {
      final tema = Theme.of(sheetContext);
      final skema = tema.colorScheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(a.tampilNama, style: tema.textTheme.titleLarge),
              const SizedBox(height: 12),
              for (final (label, nilai) in baris)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 96,
                        child: Text(
                          label,
                          style: tema.textTheme.bodySmall,
                        ),
                      ),
                      Expanded(child: Text(nilai)),
                    ],
                  ),
                ),
              if (!bisaUbah && !adaHapus && pesanKunci != null) ...[
                const SizedBox(height: 12),
                Text(pesanKunci, style: tema.textTheme.bodySmall),
              ],
              if (bisaUbah) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () =>
                      Navigator.of(sheetContext).pop('ubah'),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Ubah Pengunjung'),
                ),
              ],
              if (adaHapus) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final yakin = await showDialog<bool>(
                      context: sheetContext,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('Hapus pengunjung?'),
                        content: Text(
                          kodeBundel.isEmpty
                              ? 'Pengunjung ${a.tampilNama} '
                                    '(${formatRupiah(a.nominal)}) akan '
                                    'dihapus. Total acara ikut berkurang.'
                              : 'Pengunjung ${a.tampilNama} '
                                    '(${formatRupiah(a.nominal)}) akan '
                                    'dihapus dari bundel $kodeBundel. '
                                    'Total bundel & acara ikut berkurang.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(false),
                            child: const Text('Batal'),
                          ),
                          FilledButton(
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(true),
                            child: const Text('Hapus'),
                          ),
                        ],
                      ),
                    );
                    if (yakin != true) return;
                    final berhasil = await onHapus();
                    if (berhasil && sheetContext.mounted) {
                      Navigator.of(sheetContext).pop('hapus');
                    }
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Hapus Pengunjung'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: skema.error,
                    side: BorderSide(color: skema.error),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
