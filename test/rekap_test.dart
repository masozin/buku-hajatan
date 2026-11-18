import 'package:buku_hajatan/core/rekap.dart';
import 'package:buku_hajatan/models/amplop.dart';
import 'package:buku_hajatan/models/bundel.dart';
import 'package:buku_hajatan/models/pencatat.dart';
import 'package:flutter_test/flutter_test.dart';

Bundel bundelUji({
  required String id,
  required String pencatatId,
  required String prefix,
  required int nomor,
  int jumlahAmplop = 0,
  int totalRp = 0,
  int jumlahKosong = 0,
  int jumlahTanpaNama = 0,
}) {
  return Bundel(
    id: id,
    acaraId: 'acara1',
    pencatatId: pencatatId,
    prefix: prefix,
    nomor: nomor,
    jumlahAmplop: jumlahAmplop,
    totalRp: totalRp,
    jumlahKosong: jumlahKosong,
    jumlahTanpaNama: jumlahTanpaNama,
  );
}

Amplop amplopUji({
  required int urut,
  required String nama,
  String? alamat,
  int? dusun,
  int? rt,
  int? rw,
  required int nominal,
  JenisAmplop jenis = JenisAmplop.normal,
}) {
  return Amplop(
    id: 'a$urut$nama',
    bundelId: 'b1',
    urut: urut,
    nama: nama,
    alamat: alamat,
    dusun: dusun,
    rt: rt,
    rw: rw,
    nominal: nominal,
    jenis: jenis,
  );
}

void main() {
  group('ringkasPerPencatat', () {
    test('mengagregasi bundel per pencatat, urut prefix', () {
      final pencatats = [
        const Pencatat(
          id: 'uB',
          acaraId: 'acara1',
          uidAktif: 'uB',
          nama: 'Bambang',
          prefix: 'B',
        ),
        const Pencatat(
          id: 'uA',
          acaraId: 'acara1',
          uidAktif: 'uA',
          nama: 'Andi',
          prefix: 'A',
        ),
        const Pencatat(
          id: 'uC',
          acaraId: 'acara1',
          uidAktif: 'uC',
          nama: 'Citra',
          prefix: 'C',
        ),
      ];
      final bundels = [
        bundelUji(
          id: 'b1',
          pencatatId: 'uA',
          prefix: 'A',
          nomor: 1,
          jumlahAmplop: 10,
          totalRp: 500000,
          jumlahKosong: 1,
        ),
        bundelUji(
          id: 'b2',
          pencatatId: 'uA',
          prefix: 'A',
          nomor: 2,
          jumlahAmplop: 3,
          totalRp: 150000,
          jumlahTanpaNama: 1,
        ),
        bundelUji(
          id: 'b3',
          pencatatId: 'uB',
          prefix: 'B',
          nomor: 1,
          jumlahAmplop: 10,
          totalRp: 750000,
        ),
      ];

      final hasil = ringkasPerPencatat(bundels, pencatats);
      expect(hasil.map((r) => r.prefix).toList(), ['A', 'B', 'C']);
      expect(hasil[0].jumlahBundel, 2);
      expect(hasil[0].jumlahAmplop, 13);
      expect(hasil[0].totalRp, 650000);
      expect(hasil[0].jumlahKosong, 1);
      expect(hasil[0].jumlahTanpaNama, 1);
      expect(hasil[1].totalRp, 750000);
      // Pencatat tanpa bundel tetap muncul dengan angka 0.
      expect(hasil[2].nama, 'Citra');
      expect(hasil[2].jumlahAmplop, 0);
    });
  });

  group('buatBarisEkspor & buatCsv', () {
    final data = [
      BundelTerisi(
        bundel: bundelUji(id: 'b2', pencatatId: 'uB', prefix: 'B', nomor: 1),
        isi: [amplopUji(urut: 1, nama: 'Dedi', nominal: 100000)],
      ),
      BundelTerisi(
        bundel: bundelUji(id: 'b1', pencatatId: 'uA', prefix: 'A', nomor: 1),
        isi: [
          amplopUji(
            urut: 2,
            nama: '',
            nominal: 50000,
            jenis: JenisAmplop.tanpaNama,
          ),
          amplopUji(
            urut: 1,
            nama: 'Sari, S.Pd',
            alamat: 'Dusun "Melati"',
            nominal: 200000,
          ),
        ],
      ),
    ];

    test('baris urut per bundel lalu urut amplop; tanpa nama tampil label', () {
      final baris = buatBarisEkspor(data);
      expect(baris.map((b) => b.kodeBundel).toList(), ['A001', 'A001', 'B001']);
      expect(baris[0].nama, 'Sari, S.Pd');
      expect(baris[1].nama, '(Tanpa Nama)');
    });

    test('csv mengutip sel berkoma/berkutip', () {
      final csv = buatCsv(buatBarisEkspor(data));
      final barisCsv = csv.trim().split('\n');
      expect(
        barisCsv[0],
        'Kode Bundel,No,Nama,Alamat,Nominal (Rp),Jenis,Keterangan,Waktu',
      );
      expect(
        barisCsv[1],
        'A001,1,"Sari, S.Pd","Dusun ""Melati""",200000,Normal,,',
      );
      expect(barisCsv[2], 'A001,2,(Tanpa Nama),,50000,Tanpa Nama,,');
      expect(barisCsv[3], 'B001,1,Dedi,,100000,Normal,,');
    });
  });

  group('gabungAlamat', () {
    test('menggabungkan bagian yang terisi saja', () {
      expect(
        gabungAlamat(alamat: 'Krajan', dusun: 2, rt: 3, rw: 4),
        'Krajan, Dusun 2, RT 03/RW 04',
      );
      expect(gabungAlamat(alamat: 'Krajan'), 'Krajan');
      expect(gabungAlamat(rt: 7), 'RT 07');
      expect(gabungAlamat(rw: 1), 'RW 01');
      expect(gabungAlamat(), '');
    });
  });

  group('urutkanAbjad', () {
    test('bernama A-Z tidak peka huruf, tanpa nama paling akhir', () {
      final daftar = [
        amplopUji(urut: 1, nama: 'zulaikha', nominal: 1),
        amplopUji(
          urut: 2,
          nama: '',
          nominal: 1,
          jenis: JenisAmplop.tanpaNama,
        ),
        amplopUji(urut: 3, nama: 'Budi', nominal: 1),
        amplopUji(urut: 4, nama: 'andi', nominal: 1),
      ];
      final hasil = urutkanAbjad(daftar);
      expect(
        hasil.map((a) => a.tampilNama).toList(),
        ['andi', 'Budi', 'zulaikha', '(Tanpa Nama)'],
      );
    });
  });

  group('cariDalamData', () {
    test('cocok nama & alamat, tidak peka huruf', () {
      final data = [
        BundelTerisi(
          bundel: bundelUji(id: 'b1', pencatatId: 'uA', prefix: 'A', nomor: 1),
          isi: [
            amplopUji(
              urut: 1,
              nama: 'Budi Santoso',
              alamat: 'Totorejo',
              nominal: 100000,
            ),
            amplopUji(urut: 2, nama: 'Ani', nominal: 50000),
          ],
        ),
      ];
      expect(cariDalamData(data, 'budi').length, 1);
      expect(cariDalamData(data, 'TOTOREJO').length, 1);
      expect(cariDalamData(data, 'budi').first.kodeBundel, 'A001');
      expect(cariDalamData(data, 'zzz'), isEmpty);
      expect(cariDalamData(data, '  '), isEmpty);
    });
  });

  group('buatNamaFile', () {
    test('membersihkan nama acara menjadi nama file aman', () {
      expect(
        buatNamaFile('Pernikahan Sari & Budi', 'xlsx'),
        'buku-hajatan-pernikahan-sari-budi.xlsx',
      );
      expect(buatNamaFile('  ', 'csv'), 'buku-hajatan-acara.csv');
    });
  });

  group('rekapPerAlamat', () {
    test('mengelompokkan per alamat, urut ABJAD nama desa, '
        'tanpa alamat paling akhir', () {
      final data = [
        BundelTerisi(
          bundel: bundelUji(id: 'b1', pencatatId: 'uA', prefix: 'A', nomor: 1),
          isi: [
            amplopUji(
              urut: 1,
              nama: 'Budi',
              alamat: 'Totorejo',
              nominal: 100000,
            ),
            amplopUji(
              urut: 2,
              nama: 'Ani',
              alamat: 'totorejo',
              nominal: 50000,
            ),
            amplopUji(urut: 3, nama: 'Cici', nominal: 200000),
          ],
        ),
        BundelTerisi(
          bundel: bundelUji(id: 'b2', pencatatId: 'uA', prefix: 'A', nomor: 2),
          isi: [
            amplopUji(
              urut: 1,
              nama: 'Dedi',
              alamat: 'Margo Mulyo',
              nominal: 75000,
            ),
          ],
        ),
      ];
      final hasil = rekapPerAlamat(data);
      expect(hasil.length, 3);
      // Batch 29: urut ABJAD nama desa — Margo Mulyo sebelum
      // Totorejo, tanpa peduli totalnya.
      expect(hasil[0].alamat, 'Margo Mulyo');
      expect(hasil[0].kunci, 'margo mulyo');
      expect(hasil[0].totalRp, 75000);
      // Totorejo: 2 pengunjung, Rp 150.000 — ejaan pertama menang,
      // huruf besar/kecil menyatu.
      expect(hasil[1].alamat, 'Totorejo');
      expect(hasil[1].kunci, 'totorejo');
      expect(hasil[1].jumlahPengunjung, 2);
      expect(hasil[1].totalRp, 150000);
      // Tanpa alamat: total paling besar pun tetap paling akhir.
      expect(hasil[2].alamat, '(Tanpa alamat)');
      expect(hasil[2].kunci, '');
      expect(hasil[2].jumlahPengunjung, 1);
      expect(hasil[2].totalRp, 200000);
    });

    test('data kosong menghasilkan daftar kosong', () {
      expect(rekapPerAlamat(const []), isEmpty);
    });
  });

  group('pengunjungPerPencatat & pengunjungPerAlamat', () {
    final data = [
      BundelTerisi(
        bundel: bundelUji(id: 'b2', pencatatId: 'uB', prefix: 'B', nomor: 1),
        isi: [
          amplopUji(urut: 1, nama: 'Dedi', alamat: 'Krajan', nominal: 75000),
        ],
      ),
      BundelTerisi(
        bundel: bundelUji(id: 'b1', pencatatId: 'uA', prefix: 'A', nomor: 1),
        isi: [
          amplopUji(urut: 2, nama: 'Zahra', alamat: 'krajan', nominal: 50000),
          amplopUji(urut: 1, nama: 'Budi', alamat: 'Krajan', nominal: 100000),
          amplopUji(
            urut: 3,
            nama: '',
            nominal: 20000,
            jenis: JenisAmplop.tanpaNama,
          ),
        ],
      ),
    ];

    test('per pencatat: hanya bundelnya, urut bundel lalu urut amplop', () {
      final hasil = pengunjungPerPencatat(data, 'uA');
      expect(hasil.map((d) => d.amplop.nama).toList(), ['Budi', 'Zahra', '']);
      expect(hasil.first.kodeBundel, 'A001');
      expect(pengunjungPerPencatat(data, 'uB').length, 1);
      expect(pengunjungPerPencatat(data, 'tidak-ada'), isEmpty);
    });

    test('per alamat: kunci ternormalisasi, nama A-Z', () {
      final hasil = pengunjungPerAlamat(data, 'krajan');
      expect(
        hasil.map((d) => d.amplop.tampilNama).toList(),
        ['Budi', 'Dedi', 'Zahra'],
      );
      // Amplop tanpa alamat masuk kelompok kunci kosong.
      final tanpaAlamat = pengunjungPerAlamat(data, '');
      expect(tanpaAlamat.length, 1);
      expect(tanpaAlamat.single.amplop.jenis, JenisAmplop.tanpaNama);
    });
  });

  group('buatCsvDatar (Batch 30, Metode Langsung)', () {
    test('header tanpa kode bundel; nomor berjalan; ada kolom pencatat', () {
      final data = [
        BundelTerisi(
          bundel: bundelUji(id: 'b1', pencatatId: 'pA', prefix: 'A', nomor: 0),
          isi: [
            amplopUji(urut: 1, nama: 'Dedi', nominal: 100000),
            amplopUji(
              urut: 2,
              nama: 'Sari',
              alamat: 'Krajan',
              nominal: 50000,
            ),
          ],
        ),
        BundelTerisi(
          bundel: bundelUji(id: 'b2', pencatatId: 'pB', prefix: 'B', nomor: 0),
          isi: [amplopUji(urut: 1, nama: 'Joko', nominal: 25000)],
        ),
      ];
      final baris = buatBarisEkspor(data);
      // Prefix pencatat terbawa ke baris ekspor.
      expect(baris.map((b) => b.prefixPencatat).toList(), ['A', 'A', 'B']);
      final csv = buatCsvDatar(baris);
      final barisCsv = csv.trim().split('\n');
      expect(
        barisCsv.first,
        'No,Nama,Alamat,Nominal (Rp),Jenis,Pencatat,Keterangan,Waktu',
      );
      expect(barisCsv.length, 4);
      expect(barisCsv[1], startsWith('1,Dedi,,100000,Normal,A,,'));
      expect(barisCsv[2], startsWith('2,Sari,Krajan,50000,Normal,A,,'));
      expect(barisCsv[3], startsWith('3,Joko,,25000,Normal,B,,'));
      // Tidak ada kode bundel di format datar.
      expect(csv.contains('A000'), isFalse);
    });
  });

  group('ringkasPerPencatat bundel pemilik', () {
    test('bundel PM tampil sebagai Pemilik', () {
      final hasil = ringkasPerPencatat(
        [
          bundelUji(
            id: 'bpm',
            pencatatId: 'uidPemilik',
            prefix: 'PM',
            nomor: 1,
            jumlahAmplop: 3,
            totalRp: 150000,
          ),
        ],
        const [],
      );
      expect(hasil.length, 1);
      expect(hasil.single.nama, 'Pemilik');
      expect(hasil.single.prefix, 'PM');
      expect(hasil.single.jumlahAmplop, 3);
    });
  });
}
