import 'dart:convert';
import 'dart:io';

import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/rekap.dart';
import '../models/acara.dart';
import '../models/amplop.dart';
import 'layanan_exception.dart';

/// Pembuatan file ekspor rekap (Batch 3) + membagikannya lewat
/// share sheet Android (WhatsApp, email, Drive, simpan file, ...).
///
/// Inilah arsip/cadangan utama acara di paket Spark (rancangan §11):
/// setelah acara selesai, pemilik mengekspor dan menyimpan file ini
/// di luar Firebase.
///
/// - Excel meniru buku manual: kode bundel tercetak SEKALI per
///   kelompok bundel (sel digabung vertikal).
/// - CSV untuk diolah lagi di komputer: kode bundel di setiap baris.
class EksporService {
  /// Buat file .xlsx lalu buka share sheet.
  Future<void> eksporExcel({
    required Acara acara,
    required String tanggalTeks,
    required List<BundelTerisi> data,
  }) async {
    final baris = buatBarisEkspor(data);
    if (baris.isEmpty) {
      throw const LayananException(
        'Belum ada amplop tercatat — tidak ada yang bisa diekspor.',
      );
    }

    final buku = Excel.createExcel();
    final sheet = buku['Buku Amplop'];
    buku.delete('Sheet1');

    sheet.setColumnWidth(0, 13);
    sheet.setColumnWidth(1, 5);
    sheet.setColumnWidth(2, 32);
    sheet.setColumnWidth(3, 36);
    sheet.setColumnWidth(4, 16);
    sheet.setColumnWidth(5, 13);

    void tulisSel(
      int kolom,
      int barisKe,
      CellValue nilai, {
      bool tebal = false,
    }) {
      final sel = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: kolom, rowIndex: barisKe),
      );
      sel.value = nilai;
      if (tebal) sel.cellStyle = CellStyle(bold: true);
    }

    tulisSel(0, 0, TextCellValue('BUKU HAJATAN — REKAP AMPLOP'), tebal: true);
    tulisSel(0, 1, const TextCellValue('Acara'));
    tulisSel(1, 1, TextCellValue(acara.namaAcara));
    tulisSel(0, 2, const TextCellValue('Tuan Rumah'));
    tulisSel(1, 2, TextCellValue(acara.tuanRumah));
    tulisSel(0, 3, const TextCellValue('Jenis / Tanggal'));
    tulisSel(1, 3, TextCellValue('${acara.jenis} / $tanggalTeks'));

    const barisHeader = 5;
    const judulKolom = [
      'Kode Bundel',
      'No',
      'Nama',
      'Alamat',
      'Nominal (Rp)',
      'Jenis',
    ];
    for (var k = 0; k < judulKolom.length; k++) {
      tulisSel(k, barisHeader, TextCellValue(judulKolom[k]), tebal: true);
    }

    var r = barisHeader + 1;
    var totalRp = 0;
    var jumlahKosong = 0;
    var jumlahTanpaNama = 0;
    var i = 0;
    while (i < baris.length) {
      // Satu kelompok bundel: baris-baris berkode sama yang berurutan.
      final mulaiKelompok = r;
      final kode = baris[i].kodeBundel;
      while (i < baris.length && baris[i].kodeBundel == kode) {
        final b = baris[i];
        tulisSel(1, r, IntCellValue(b.urut));
        tulisSel(2, r, TextCellValue(b.nama));
        tulisSel(3, r, TextCellValue(b.alamat));
        tulisSel(4, r, IntCellValue(b.nominal));
        tulisSel(5, r, TextCellValue(b.jenis.label));
        totalRp += b.nominal;
        if (b.jenis == JenisAmplop.kosong) jumlahKosong++;
        if (b.jenis == JenisAmplop.tanpaNama) jumlahTanpaNama++;
        r++;
        i++;
      }
      // Kode bundel ditulis sekali, digabung vertikal seperti di buku.
      if (r - 1 > mulaiKelompok) {
        sheet.merge(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: mulaiKelompok),
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r - 1),
          customValue: TextCellValue(kode),
        );
      } else {
        tulisSel(0, mulaiKelompok, TextCellValue(kode));
      }
    }

    r += 1;
    tulisSel(2, r, const TextCellValue('TOTAL'), tebal: true);
    tulisSel(4, r, IntCellValue(totalRp), tebal: true);
    r += 1;
    tulisSel(
      2,
      r,
      TextCellValue(
        'Jumlah amplop: ${baris.length} '
        '(kosong: $jumlahKosong, tanpa nama: $jumlahTanpaNama)',
      ),
    );

    final bytes = buku.encode();
    if (bytes == null) {
      throw const LayananException('Gagal membuat file Excel.');
    }
    final file = await _tulisFileSementara(
      buatNamaFile(acara.namaAcara, 'xlsx'),
      bytes,
    );
    await Share.shareXFiles([
      XFile(file.path),
    ], text: 'Rekap amplop acara ${acara.namaAcara} (Excel)');
  }

  /// Buat file .csv lalu buka share sheet.
  Future<void> eksporCsv({
    required Acara acara,
    required List<BundelTerisi> data,
  }) async {
    final baris = buatBarisEkspor(data);
    if (baris.isEmpty) {
      throw const LayananException(
        'Belum ada amplop tercatat — tidak ada yang bisa diekspor.',
      );
    }
    // BOM UTF-8 supaya Excel di Windows langsung membaca dengan benar.
    final isi = '\uFEFF${buatCsv(baris)}';
    final file = await _tulisFileSementara(
      buatNamaFile(acara.namaAcara, 'csv'),
      utf8.encode(isi),
    );
    await Share.shareXFiles([
      XFile(file.path),
    ], text: 'Rekap amplop acara ${acara.namaAcara} (CSV)');
  }

  Future<File> _tulisFileSementara(String namaFile, List<int> bytes) async {
    final folder = await getTemporaryDirectory();
    final file = File('${folder.path}/$namaFile');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }
}
