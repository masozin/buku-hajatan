import 'package:buku_hajatan/core/kode.dart';
import 'package:buku_hajatan/core/undangan.dart';
import 'package:buku_hajatan/models/tamu_undangan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseTempelUndangan', () {
    test('satu baris satu tamu; alamat & kategori boleh kosong', () {
      final hasil = parseTempelUndangan(
        'Budi Santoso, Krajan\nSiti\n\nAhmad, Dusun 2, Keluarga',
      );
      expect(hasil.length, 3);
      expect(hasil[0].nama, 'Budi Santoso');
      expect(hasil[0].alamat, 'Krajan');
      expect(hasil[0].kategori, isNull);
      expect(hasil[1].nama, 'Siti');
      expect(hasil[1].alamat, isNull);
      expect(hasil[2].nama, 'Ahmad');
      expect(hasil[2].alamat, 'Dusun 2');
      expect(hasil[2].kategori, 'Keluarga');
    });

    test('baris kosong dan tanpa nama dilewati', () {
      expect(parseTempelUndangan('\n  \n, Krajan\n'), isEmpty);
    });
  });

  group('parseCsvUndangan', () {
    test('header dilewati; angka dusun/RT/RW dibaca', () {
      final hasil = parseCsvUndangan(
        'Nama,Alamat,Dusun,RT,RW,Kategori\n'
        'Budi Santoso,Krajan,2,03,04,Keluarga\n'
        'Siti,,,,,Tetangga',
      );
      expect(hasil.length, 2);
      expect(hasil[0].nama, 'Budi Santoso');
      expect(hasil[0].alamat, 'Krajan');
      expect(hasil[0].dusun, 2);
      expect(hasil[0].rt, 3);
      expect(hasil[0].rw, 4);
      expect(hasil[0].kategori, 'Keluarga');
      expect(hasil[1].nama, 'Siti');
      expect(hasil[1].alamat, isNull);
      expect(hasil[1].kategori, 'Tetangga');
    });

    test('tanpa header tetap dibaca; baris tanpa nama dilewati', () {
      final hasil = parseCsvUndangan('Budi,Krajan\n,Krajan\nSiti,');
      expect(hasil.map((b) => b.nama), ['Budi', 'Siti']);
    });
  });

  group('hitungBelumHadir', () {
    test('sisa = diundang - hadir - tidak', () {
      expect(
        hitungBelumHadir(
          totalUndangan: 10,
          totalHadir: 3,
          totalTidakHadir: 2,
        ),
        5,
      );
    });

    test('tidak pernah negatif (walk-in menaikkan total)', () {
      expect(
        hitungBelumHadir(
          totalUndangan: 5,
          totalHadir: 6,
          totalTidakHadir: 0,
        ),
        0,
      );
    });
  });

  group('cocokUndangan', () {
    test('cocok nama atau alamat, tanpa peduli kapital', () {
      expect(
        cocokUndangan(nama: 'Budi Santoso', alamat: 'Krajan', kueri: 'budi'),
        isTrue,
      );
      expect(
        cocokUndangan(nama: 'Budi Santoso', alamat: 'Krajan', kueri: 'KRAJAN'),
        isTrue,
      );
      expect(
        cocokUndangan(nama: 'Budi Santoso', alamat: 'Krajan', kueri: 'siti'),
        isFalse,
      );
      expect(
        cocokUndangan(nama: 'Budi Santoso', alamat: 'Krajan', kueri: ''),
        isTrue,
      );
    });
  });

  group('buatKodeTamu', () {
    test('8 karakter, tanpa huruf/angka ambigu, unik', () {
      final kode = buatKodeTamu();
      expect(kode.length, 8);
      expect(RegExp(r'^[A-Z0-9]+$').hasMatch(kode), isTrue);
      expect(kode.contains('0'), isFalse);
      expect(kode.contains('O'), isFalse);
      expect(kode.contains('1'), isFalse);
      expect(kode.contains('I'), isFalse);
      final semua = {for (var i = 0; i < 1000; i++) buatKodeTamu()};
      expect(semua.length, 1000);
    });
  });

  group('StatusHadir', () {
    test('dariString: bawaan belum; nilai tak dikenal jadi belum', () {
      expect(StatusHadir.dariString(null), StatusHadir.belum);
      expect(StatusHadir.dariString('hadir'), StatusHadir.hadir);
      expect(StatusHadir.dariString('tidak'), StatusHadir.tidak);
      expect(StatusHadir.dariString('aneh'), StatusHadir.belum);
    });
  });
}
