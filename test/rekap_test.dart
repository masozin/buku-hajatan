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
  required int nominal,
  JenisAmplop jenis = JenisAmplop.normal,
}) {
  return Amplop(
    id: 'a$urut$nama',
    bundelId: 'b1',
    urut: urut,
    nama: nama,
    alamat: alamat,
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
          userId: 'uB',
          nama: 'Bambang',
          prefix: 'B',
        ),
        const Pencatat(
          id: 'uA',
          acaraId: 'acara1',
          userId: 'uA',
          nama: 'Andi',
          prefix: 'A',
        ),
        const Pencatat(
          id: 'uC',
          acaraId: 'acara1',
          userId: 'uC',
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
        'Kode Bundel,No,Nama,Alamat,Dusun,Nominal (Rp),Jenis,Keterangan,Waktu',
      );
      expect(
        barisCsv[1],
        'A001,1,"Sari, S.Pd","Dusun ""Melati""",,200000,Normal,,',
      );
      expect(barisCsv[2], 'A001,2,(Tanpa Nama),,,50000,Tanpa Nama,,');
      expect(barisCsv[3], 'B001,1,Dedi,,,100000,Normal,,');
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
}
