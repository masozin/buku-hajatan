import 'package:buku_hajatan/core/kode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('hurufPrefix', () {
    test('urutan awal A, B, C', () {
      expect(hurufPrefix(0), 'A');
      expect(hurufPrefix(1), 'B');
      expect(hurufPrefix(2), 'C');
    });

    test('setelah Z lanjut AA, AB', () {
      expect(hurufPrefix(25), 'Z');
      expect(hurufPrefix(26), 'AA');
      expect(hurufPrefix(27), 'AB');
      expect(hurufPrefix(51), 'AZ');
      expect(hurufPrefix(52), 'BA');
    });

    test('negatif ditolak', () {
      expect(() => hurufPrefix(-1), throwsArgumentError);
    });
  });

  group('buatKodeBundel', () {
    test('nomor dipadatkan 3 digit', () {
      expect(buatKodeBundel('A', 1), 'A001');
      expect(buatKodeBundel('B', 12), 'B012');
      expect(buatKodeBundel('C', 123), 'C123');
    });

    test('nomor di atas 999 tidak terpotong', () {
      expect(buatKodeBundel('A', 1000), 'A1000');
    });
  });

  group('normalisasiNama', () {
    test('huruf kecil + spasi dibersihkan', () {
      expect(normalisasiNama('  Budi   Santoso '), 'budi santoso');
      expect(normalisasiNama('SITI'), 'siti');
    });
  });

  group('buatKodeGabung & buatPinGabung', () {
    test('kode gabung 6 karakter tanpa karakter ambigu', () {
      for (var i = 0; i < 50; i++) {
        final kode = buatKodeGabung();
        expect(kode.length, 6);
        expect(kode.contains('0'), isFalse);
        expect(kode.contains('O'), isFalse);
        expect(kode.contains('1'), isFalse);
        expect(kode.contains('I'), isFalse);
      }
    });

    test('PIN selalu 4 digit', () {
      for (var i = 0; i < 50; i++) {
        expect(buatPinGabung().length, 4);
      }
    });
  });
}
