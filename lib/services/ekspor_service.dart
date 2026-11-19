import 'dart:convert';
import 'dart:io';

import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../core/format.dart';
import '../core/rekap.dart';
import '../models/acara.dart';
import '../models/amplop.dart';
import '../models/tamu_undangan.dart';
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
    List<TamuUndangan>? undangan,
  }) async {
    final baris = buatBarisEkspor(data);
    if (baris.isEmpty) {
      throw const LayananException(
        'Belum ada pengunjung tercatat — tidak ada yang bisa diekspor.',
      );
    }

    final buku = Excel.createExcel();
    final sheet = buku['Buku Pengunjung'];
    buku.delete('Sheet1');

    sheet.setColumnWidth(0, 13);
    sheet.setColumnWidth(1, 5);
    sheet.setColumnWidth(2, 32);
    // Batch 25: kolom Alamat kini gabungan (alamat + dusun +
    // RT/RW) sehingga lebih lebar; kolom Dusun terpisah dihapus.
    sheet.setColumnWidth(3, 46);
    sheet.setColumnWidth(4, 16);
    sheet.setColumnWidth(5, 13);
    sheet.setColumnWidth(6, 28);
    sheet.setColumnWidth(7, 17);

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

    tulisSel(0, 0, TextCellValue('BUKU HAJATAN — REKAP PENGUNJUNG'), tebal: true);
    tulisSel(0, 1, TextCellValue('Acara'));
    tulisSel(1, 1, TextCellValue(acara.namaAcara));
    tulisSel(0, 2, TextCellValue('Tuan Rumah'));
    tulisSel(1, 2, TextCellValue(acara.tuanRumah));
    tulisSel(0, 3, TextCellValue('Jenis / Tanggal'));
    tulisSel(1, 3, TextCellValue('${acara.jenis} / $tanggalTeks'));

    const barisHeader = 5;
    const judulKolom = [
      'Kode Bundel',
      'No',
      'Nama',
      'Alamat',
      'Nominal (Rp)',
      'Jenis',
      'Keterangan',
      'Waktu',
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
        tulisSel(
          3,
          r,
          TextCellValue(
            gabungAlamat(
              alamat: b.alamat,
              dusun: b.dusun,
              rt: b.rt,
              rw: b.rw,
            ),
          ),
        );
        tulisSel(4, r, IntCellValue(b.nominal));
        tulisSel(5, r, TextCellValue(b.labelJenis));
        if (b.keterangan != null && b.keterangan!.isNotEmpty) {
          tulisSel(6, r, TextCellValue(b.keterangan!));
        }
        if (b.waktu != null) {
          tulisSel(7, r, TextCellValue(formatWaktuCsv(b.waktu!)));
        }
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
    tulisSel(2, r, TextCellValue('TOTAL'), tebal: true);
    tulisSel(4, r, IntCellValue(totalRp), tebal: true);
    r += 1;
    tulisSel(
      2,
      r,
      TextCellValue(
        'Jumlah pengunjung: ${baris.length} '
        '(kosong: $jumlahKosong, tanpa nama: $jumlahTanpaNama)',
      ),
    );

    // Batch 34: lembar tambahan Daftar Kehadiran (rancangan §6.4).
    if (undangan != null && undangan.isNotEmpty) {
      _tulisLembarKehadiran(buku, undangan, _nominalPerAmplop(data));
    }

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
    ], text: 'Rekap pengunjung acara ${acara.namaAcara} (Excel)');
  }

  /// Excel DATAR untuk Metode Langsung (Batch 30): satu baris
  /// per pengunjung tanpa pengelompokan bundel — No berjalan,
  /// Nama, Alamat gabungan, Nominal, Jenis, Pencatat (prefix),
  /// Keterangan, Waktu; TOTAL di bawah seperti format buku.
  Future<void> eksporExcelDatar({
    required Acara acara,
    required String tanggalTeks,
    required List<BundelTerisi> data,
    List<TamuUndangan>? undangan,
  }) async {
    final baris = buatBarisEkspor(data);
    if (baris.isEmpty) {
      throw const LayananException(
        'Belum ada pengunjung tercatat — tidak ada yang bisa diekspor.',
      );
    }

    final buku = Excel.createExcel();
    final sheet = buku['Daftar Pengunjung'];
    buku.delete('Sheet1');

    sheet.setColumnWidth(0, 5);
    sheet.setColumnWidth(1, 32);
    sheet.setColumnWidth(2, 46);
    sheet.setColumnWidth(3, 16);
    sheet.setColumnWidth(4, 13);
    sheet.setColumnWidth(5, 11);
    sheet.setColumnWidth(6, 28);
    sheet.setColumnWidth(7, 17);

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

    tulisSel(0, 0, TextCellValue('BUKU HAJATAN — DAFTAR PENGUNJUNG'), tebal: true);
    tulisSel(0, 1, TextCellValue('Acara'));
    tulisSel(1, 1, TextCellValue(acara.namaAcara));
    tulisSel(0, 2, TextCellValue('Tuan Rumah'));
    tulisSel(1, 2, TextCellValue(acara.tuanRumah));
    tulisSel(0, 3, TextCellValue('Jenis / Tanggal'));
    tulisSel(1, 3, TextCellValue('${acara.jenis} / $tanggalTeks'));

    const barisHeader = 5;
    const judulKolom = [
      'No',
      'Nama',
      'Alamat',
      'Nominal (Rp)',
      'Jenis',
      'Pencatat',
      'Keterangan',
      'Waktu',
    ];
    for (var k = 0; k < judulKolom.length; k++) {
      tulisSel(k, barisHeader, TextCellValue(judulKolom[k]), tebal: true);
    }

    var r = barisHeader + 1;
    var totalRp = 0;
    var jumlahKosong = 0;
    var jumlahTanpaNama = 0;
    for (var i = 0; i < baris.length; i++) {
      final b = baris[i];
      tulisSel(0, r, IntCellValue(i + 1));
      tulisSel(1, r, TextCellValue(b.nama));
      tulisSel(
        2,
        r,
        TextCellValue(
          gabungAlamat(
            alamat: b.alamat,
            dusun: b.dusun,
            rt: b.rt,
            rw: b.rw,
          ),
        ),
      );
      tulisSel(3, r, IntCellValue(b.nominal));
      tulisSel(4, r, TextCellValue(b.labelJenis));
      tulisSel(5, r, TextCellValue(b.prefixPencatat));
      if (b.keterangan != null && b.keterangan!.isNotEmpty) {
        tulisSel(6, r, TextCellValue(b.keterangan!));
      }
      if (b.waktu != null) {
        tulisSel(7, r, TextCellValue(formatWaktuCsv(b.waktu!)));
      }
      totalRp += b.nominal;
      if (b.jenis == JenisAmplop.kosong) jumlahKosong++;
      if (b.jenis == JenisAmplop.tanpaNama) jumlahTanpaNama++;
      r++;
    }

    r += 1;
    tulisSel(1, r, TextCellValue('TOTAL'), tebal: true);
    tulisSel(3, r, IntCellValue(totalRp), tebal: true);
    r += 1;
    tulisSel(
      1,
      r,
      TextCellValue(
        'Jumlah pengunjung: ${baris.length} '
        '(kosong: $jumlahKosong, tanpa nama: $jumlahTanpaNama)',
      ),
    );

    // Batch 34: lembar tambahan Daftar Kehadiran (rancangan §6.4).
    if (undangan != null && undangan.isNotEmpty) {
      _tulisLembarKehadiran(buku, undangan, _nominalPerAmplop(data));
    }

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
    ], text: 'Daftar pengunjung acara ${acara.namaAcara} (Excel)');
  }

  /// Buat file .csv lalu buka share sheet.
  Future<void> eksporCsv({
    required Acara acara,
    required List<BundelTerisi> data,
  }) async {
    final baris = buatBarisEkspor(data);
    if (baris.isEmpty) {
      throw const LayananException(
        'Belum ada pengunjung tercatat — tidak ada yang bisa diekspor.',
      );
    }
    // BOM UTF-8 supaya Excel di Windows langsung membaca dengan benar.
    // Batch 30: Metode Langsung memakai CSV datar (tanpa kode bundel).
    final isi =
        '\uFEFF${acara.metodeLangsung ? buatCsvDatar(baris) : buatCsv(baris)}';
    final file = await _tulisFileSementara(
      buatNamaFile(acara.namaAcara, 'csv'),
      utf8.encode(isi),
    );
    await Share.shareXFiles([
      XFile(file.path),
    ], text: 'Rekap pengunjung acara ${acara.namaAcara} (CSV)');
  }

  /// Buat file .pdf lalu buka share sheet (Batch 25, permintaan
  /// Mark): format CETAK — kop berisi detail acara (nama acara,
  /// tuan rumah, tanggal), tabel pengunjung urut ABJAD nama
  /// (No, Nama, Alamat gabungan, Nominal), dan blok rekap di
  /// paling bawah dokumen.
  Future<void> eksporPdf({
    required Acara acara,
    required String tanggalTeks,
    required List<BundelTerisi> data,
  }) async {
    // Ratakan mengikuti urutan bundel, lalu urutkan abjad nama.
    final terurutBundel = [...data]..sort((a, b) {
        final bandingPrefix = a.bundel.prefix.compareTo(b.bundel.prefix);
        return bandingPrefix != 0
            ? bandingPrefix
            : a.bundel.nomor.compareTo(b.bundel.nomor);
      });
    final semua = <Amplop>[
      for (final bt in terurutBundel)
        ...( [...bt.isi]..sort((a, b) => a.urut.compareTo(b.urut))),
    ];
    if (semua.isEmpty) {
      throw const LayananException(
        'Belum ada pengunjung tercatat — tidak ada yang bisa diekspor.',
      );
    }
    final daftar = urutkanAbjad(semua);
    var totalRp = 0;
    var jumlahKosong = 0;
    var jumlahTanpaNama = 0;
    for (final a in daftar) {
      totalRp += a.nominal;
      if (a.jenis == JenisAmplop.kosong) jumlahKosong++;
      if (a.jenis == JenisAmplop.tanpaNama) jumlahTanpaNama++;
    }

    final zamrud = PdfColor.fromHex('#0B6E4F');
    final dokumen = pw.Document();
    dokumen.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 44),
        footer: (konteks) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Halaman ${konteks.pageNumber} dari ${konteks.pagesCount}',
            style: const pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey600,
            ),
          ),
        ),
        build: (konteks) => [
          // --- KOP: detail acara ---
          pw.Center(
            child: pw.Text(
              'BUKU HAJATAN',
              style: pw.TextStyle(
                fontSize: 11,
                letterSpacing: 3,
                color: PdfColors.grey700,
              ),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Center(
            child: pw.Text(
              acara.namaAcara,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
                color: zamrud,
              ),
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Center(
            child: pw.Text(
              'Tuan Rumah: ${acara.tuanRumah}',
              style: const pw.TextStyle(fontSize: 12),
            ),
          ),
          pw.Center(
            child: pw.Text(
              '${acara.jenis} • $tanggalTeks'
              '${acara.lokasi != null && acara.lokasi!.isNotEmpty ? ' • ${acara.lokasi}' : ''}',
              style: const pw.TextStyle(fontSize: 11),
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Divider(thickness: 1.4, color: zamrud),
          pw.SizedBox(height: 12),
          // --- TABEL pengunjung urut abjad ---
          pw.TableHelper.fromTextArray(
            headers: const ['No', 'Nama', 'Alamat', 'Nominal'],
            data: [
              for (var i = 0; i < daftar.length; i++)
                [
                  '${i + 1}',
                  daftar[i].tampilNama,
                  gabungAlamat(
                    alamat: daftar[i].alamat,
                    dusun: daftar[i].dusun,
                    rt: daftar[i].rt,
                    rw: daftar[i].rw,
                  ),
                  formatRupiah(daftar[i].nominal),
                ],
            ],
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
              fontSize: 11,
            ),
            headerDecoration: pw.BoxDecoration(color: zamrud),
            cellStyle: const pw.TextStyle(fontSize: 11),
            cellAlignments: const {
              0: pw.Alignment.center,
              3: pw.Alignment.centerRight,
            },
            columnWidths: const {
              0: pw.FixedColumnWidth(30),
              1: pw.FlexColumnWidth(3),
              2: pw.FlexColumnWidth(4),
              3: pw.FlexColumnWidth(2),
            },
            border: pw.TableBorder.all(
              color: PdfColors.grey300,
              width: 0.5,
            ),
            rowDecoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(
                  color: PdfColors.grey300,
                  width: 0.5,
                ),
              ),
            ),
          ),
          pw.SizedBox(height: 18),
          // --- REKAP di paling bawah ---
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: zamrud, width: 1),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'REKAP',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: zamrud,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text('Total pengunjung: ${daftar.length} orang'),
                pw.Text(
                  'Total uang: ${formatRupiah(totalRp)}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.Text('Pengunjung kosong: $jumlahKosong'),
                pw.Text('Tanpa nama: $jumlahTanpaNama'),
              ],
            ),
          ),
        ],
      ),
    );

    final bytes = await dokumen.save();
    final file = await _tulisFileSementara(
      buatNamaFile(acara.namaAcara, 'pdf'),
      bytes,
    );
    await Share.shareXFiles([
      XFile(file.path),
    ], text: 'Rekap pengunjung acara ${acara.namaAcara} (PDF)');
  }

  /// Nominal per amplop (ID amplop -> nominal) untuk lembar
  /// kehadiran: tamu hadir beramplop menampilkan nominalnya,
  /// hadir tanpa amplop menampilkan sel kosong.
  Map<String, int> _nominalPerAmplop(List<BundelTerisi> data) {
    final peta = <String, int>{};
    for (final bt in data) {
      for (final a in bt.isi) {
        peta[a.id] = a.nominal;
      }
    }
    return peta;
  }

  /// Lembar tambahan 'Daftar Kehadiran' (Batch 34, rancangan
  /// §6.4): seluruh tamu undangan + status + nominal (untuk
  /// yang hadir beramplop). Urut abjad nama, seperti PDF.
  void _tulisLembarKehadiran(
    Excel buku,
    List<TamuUndangan> undangan,
    Map<String, int> nominalPerAmplop,
  ) {
    final sheet = buku['Daftar Kehadiran'];
    sheet.setColumnWidth(0, 5);
    sheet.setColumnWidth(1, 32);
    sheet.setColumnWidth(2, 46);
    sheet.setColumnWidth(3, 16);
    sheet.setColumnWidth(4, 20);
    sheet.setColumnWidth(5, 16);

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

    tulisSel(0, 0, TextCellValue('DAFTAR KEHADIRAN — UNDANGAN'), tebal: true);
    const barisHeader = 2;
    const judulKolom = [
      'No',
      'Nama',
      'Alamat',
      'Kategori',
      'Status',
      'Nominal (Rp)',
    ];
    for (var k = 0; k < judulKolom.length; k++) {
      tulisSel(k, barisHeader, TextCellValue(judulKolom[k]), tebal: true);
    }

    final terurut = [...undangan]
      ..sort(
        (a, b) => a.nama.toLowerCase().compareTo(b.nama.toLowerCase()),
      );
    var r = barisHeader + 1;
    var totalHadirRp = 0;
    var jumlahHadir = 0;
    var jumlahTidak = 0;
    for (var i = 0; i < terurut.length; i++) {
      final t = terurut[i];
      final status = switch (t.statusHadir) {
        StatusHadir.belum => 'Belum ada kabar',
        StatusHadir.hadir =>
          t.amplopId == null ? 'Hadir (tanpa amplop)' : 'Hadir',
        StatusHadir.tidak => 'Tidak hadir',
      };
      tulisSel(0, r, IntCellValue(i + 1));
      tulisSel(1, r, TextCellValue(t.nama));
      tulisSel(
        2,
        r,
        TextCellValue(
          gabungAlamat(
            alamat: t.alamat,
            dusun: t.dusun,
            rt: t.rt,
            rw: t.rw,
          ),
        ),
      );
      if (t.kategori != null && t.kategori!.isNotEmpty) {
        tulisSel(3, r, TextCellValue(t.kategori!));
      }
      tulisSel(4, r, TextCellValue(status));
      if (t.statusHadir == StatusHadir.hadir) {
        jumlahHadir++;
        if (t.amplopId != null) {
          final nominal = nominalPerAmplop[t.amplopId] ?? 0;
          tulisSel(5, r, IntCellValue(nominal));
          totalHadirRp += nominal;
        }
      }
      if (t.statusHadir == StatusHadir.tidak) jumlahTidak++;
      r++;
    }

    r += 1;
    tulisSel(1, r, TextCellValue('TOTAL HADIR'), tebal: true);
    tulisSel(5, r, IntCellValue(totalHadirRp), tebal: true);
    r += 1;
    tulisSel(
      1,
      r,
      TextCellValue(
        'Diundang: ${terurut.length} • Hadir: $jumlahHadir • '
        'Tidak hadir: $jumlahTidak • Belum ada kabar: '
        '${terurut.length - jumlahHadir - jumlahTidak}',
      ),
    );
  }

  Future<File> _tulisFileSementara(String namaFile, List<int> bytes) async {
    final folder = await getTemporaryDirectory();
    final file = File('${folder.path}/$namaFile');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }
}
