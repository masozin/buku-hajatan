import 'package:buku_hajatan/core/pencatatan.dart';
import 'package:buku_hajatan/models/amplop.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseNominal', () {
    test('angka polos dan berformat Rp', () {
      expect(parseNominal('150000'), 150000);
      expect(parseNominal('Rp 150.000'), 150000);
      expect(parseNominal('1.500.000'), 1500000);
    });

    test('kosong / bukan angka -> 0', () {
      expect(parseNominal(''), 0);
      expect(parseNominal('abc'), 0);
    });
  });

  group('validasiAmplop', () {
    test('normal wajib nama + nominal > 0', () {
      expect(
        validasiAmplop(
          jenis: JenisAmplop.normal,
          nama: '',
          nominal: 50000,
        ),
        isNotNull,
      );
      expect(
        validasiAmplop(
          jenis: JenisAmplop.normal,
          nama: 'Budi',
          nominal: 0,
        ),
        isNotNull,
      );
      expect(
        validasiAmplop(
          jenis: JenisAmplop.normal,
          nama: 'Budi',
          nominal: 50000,
        ),
        isNull,
      );
    });

    test('kosong wajib nama, nominal boleh 0', () {
      expect(
        validasiAmplop(
          jenis: JenisAmplop.kosong,
          nama: '',
          nominal: 0,
        ),
        isNotNull,
      );
      expect(
        validasiAmplop(
          jenis: JenisAmplop.kosong,
          nama: 'Budi',
          nominal: 0,
        ),
        isNull,
      );
    });

    test('tanpa nama wajib nominal > 0, nama boleh kosong', () {
      expect(
        validasiAmplop(
          jenis: JenisAmplop.tanpaNama,
          nama: '',
          nominal: 0,
        ),
        isNotNull,
      );
      expect(
        validasiAmplop(
          jenis: JenisAmplop.tanpaNama,
          nama: '',
          nominal: 100000,
        ),
        isNull,
      );
    });
  });

  group('namaSimpan & nominalSimpan', () {
    test('kosong -> nominal 0, nama tetap', () {
      expect(nominalSimpan(JenisAmplop.kosong, 50000), 0);
      expect(namaSimpan(JenisAmplop.kosong, 'Budi'), 'Budi');
    });

    test('tanpa nama -> nama kosong, nominal tetap', () {
      expect(namaSimpan(JenisAmplop.tanpaNama, 'Budi'), '');
      expect(nominalSimpan(JenisAmplop.tanpaNama, 100000), 100000);
    });
  });

  group('penomoran bundel', () {
    test('urut berikutnya = jumlah + 1', () {
      expect(urutBerikutnya(0), 1);
      expect(urutBerikutnya(4), 5);
      expect(urutBerikutnya(9), 10);
    });

    test('hanya amplop ke-10 yang menutup bundel', () {
      expect(amplopIniMenutupBundel(8), isFalse);
      expect(amplopIniMenutupBundel(9), isTrue);
      expect(bundelPenuh(9), isFalse);
      expect(bundelPenuh(10), isTrue);
    });
  });
}
