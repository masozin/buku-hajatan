import 'package:buku_hajatan/core/format.dart';
import 'package:buku_hajatan/core/pengunjung.dart';
import 'package:buku_hajatan/core/rekap.dart';
import 'package:buku_hajatan/models/amplop.dart';
import 'package:buku_hajatan/models/bundel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

BundelTerisi bundelUji(
  String prefix,
  int nomor,
  List<Amplop> isi,
) {
  return BundelTerisi(
    bundel: Bundel(
      id: 'b-$prefix$nomor',
      acaraId: 'a1',
      pencatatId: 'u$prefix',
      prefix: prefix,
      nomor: nomor,
    ),
    isi: isi,
  );
}

Amplop amplopUji({
  required int urut,
  required String nama,
  String? alamat,
  String? dusun,
  String? keterangan,
  required int nominal,
  DateTime? waktu,
}) {
  return Amplop(
    id: 'amp-$nama-$urut',
    bundelId: 'b',
    urut: urut,
    nama: nama,
    alamat: alamat,
    dusun: dusun,
    keterangan: keterangan,
    nominal: nominal,
    createdAt: waktu,
  );
}

void main() {
  setUpAll(() async {
    // formatWaktuKonteks memakai format tanggal locale id_ID.
    await initializeDateFormatting('id_ID');
  });

  final data = [
    bundelUji('B', 1, [
      amplopUji(
        urut: 1,
        nama: 'Dedi',
        alamat: 'Air Batu',
        nominal: 100000,
        dusun: '2',
      ),
    ]),
    bundelUji('A', 1, [
      amplopUji(
        urut: 1,
        nama: 'Sari',
        alamat: 'Jl. Kenanga',
        dusun: '1',
        nominal: 200000,
        waktu: DateTime(2026, 11, 16, 9, 0),
      ),
      amplopUji(
        urut: 2,
        nama: 'agus',
        keterangan: 'Teman kerja',
        nominal: 50000,
        waktu: DateTime(2026, 11, 16, 10, 30),
      ),
    ]),
  ];

  group('semuaPengunjung', () {
    test('meratakan semua amplop lintas bundel dengan kode bundelnya', () {
      final semua = semuaPengunjung(data);
      expect(semua.length, 3);
      expect(semua.map((d) => d.kodeBundel).toSet(), {'A001', 'B001'});
    });
  });

  group('saringPengunjung', () {
    test('kata kunci kosong mengembalikan semua', () {
      expect(saringPengunjung(semuaPengunjung(data), '').length, 3);
      expect(saringPengunjung(semuaPengunjung(data), '   ').length, 3);
    });

    test('cocok nama (tidak peka huruf), dusun, dan keterangan', () {
      final semua = semuaPengunjung(data);
      expect(saringPengunjung(semua, 'SARI').length, 1);
      expect(saringPengunjung(semua, 'dusun 2').single.amplop.nama, 'Dedi');
      expect(
        saringPengunjung(semua, 'teman').single.amplop.nama,
        'agus',
      );
    });
  });

  group('urutkanPengunjung', () {
    test('nama A-Z tidak peka huruf', () {
      final hasil = urutkanPengunjung(
        semuaPengunjung(data),
        UrutanPengunjung.namaAZ,
      );
      expect(hasil.map((d) => d.amplop.nama).toList(), [
        'agus',
        'Dedi',
        'Sari',
      ]);
    });

    test('nominal terbesar dulu', () {
      final hasil = urutkanPengunjung(
        semuaPengunjung(data),
        UrutanPengunjung.nominalBesar,
      );
      expect(hasil.map((d) => d.amplop.nominal).toList(), [
        200000,
        100000,
        50000,
      ]);
    });

    test('alamat menaik, yang kosong paling belakang', () {
      final hasil = urutkanPengunjung(
        semuaPengunjung(data),
        UrutanPengunjung.alamat,
      );
      expect(hasil.map((d) => d.amplop.nama).toList(), [
        'Dedi',
        'Sari',
        'agus',
      ]);
    });

    test('terbaru berdasarkan timestamp', () {
      final hasil = urutkanPengunjung(
        semuaPengunjung(data),
        UrutanPengunjung.terbaru,
      );
      expect(hasil.first.amplop.nama, 'agus');
      // Tanpa timestamp jatuh ke belakang.
      expect(hasil.last.amplop.nama, 'Dedi');
    });

  });

  group('sugesti alamat (Batch 14)', () {
    test('daftarAlamatUnik menyaring duplikat tanpa peka huruf', () {
      final dataSaran = [
        bundelUji('A', 1, [
          amplopUji(
            urut: 1,
            nama: 'X',
            alamat: 'Cahya Tani',
            nominal: 1000,
          ),
          amplopUji(
            urut: 2,
            nama: 'Y',
            alamat: 'cahya tani',
            nominal: 1000,
          ),
          amplopUji(urut: 3, nama: 'Z', alamat: '  ', nominal: 1000),
          amplopUji(
            urut: 4,
            nama: 'W',
            alamat: 'Baturaja',
            nominal: 1000,
          ),
        ]),
      ];
      expect(daftarAlamatUnik(dataSaran), ['Baturaja', 'Cahya Tani']);
    });

    test('saringSaranAlamat cocok awalan alamat atau katanya', () {
      const saran = ['Baturaja', 'Cahya Tani', 'Tani Baru'];
      expect(saringSaranAlamat(saran, 'c'), ['Cahya Tani']);
      expect(saringSaranAlamat(saran, 'tani'), [
        'Cahya Tani',
        'Tani Baru',
      ]);
      expect(saringSaranAlamat(saran, ''), isEmpty);
      expect(saringSaranAlamat(saran, 'xyz'), isEmpty);
    });
  });

  group('formatWaktuKonteks', () {
    test('hari yang sama cukup jamnya', () {
      expect(
        formatWaktuKonteks(
          DateTime(2026, 11, 16, 9, 5),
          sekarang: DateTime(2026, 11, 16, 18, 0),
        ),
        '09:05',
      );
    });

    test('beda tanggal tampil tanggal + jam', () {
      expect(
        formatWaktuKonteks(
          DateTime(2026, 11, 16, 9, 5),
          sekarang: DateTime(2026, 11, 17, 8, 0),
        ),
        '16 Nov 2026 09:05',
      );
    });
  });
}
