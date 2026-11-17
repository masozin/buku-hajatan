import 'package:buku_hajatan/core/koreksi.dart';
import 'package:buku_hajatan/models/amplop.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('deltaUbahAmplop', () {
    test('hanya nominal berubah', () {
      final d = deltaUbahAmplop(
        jenisLama: JenisAmplop.normal,
        nominalLama: 100000,
        jenisBaru: JenisAmplop.normal,
        nominalBaru: 150000,
      );
      expect(d.deltaRp, 50000);
      expect(d.deltaKosong, 0);
      expect(d.deltaTanpaNama, 0);
    });

    test('normal menjadi kosong: Rp turun ke 0, kosong +1', () {
      final d = deltaUbahAmplop(
        jenisLama: JenisAmplop.normal,
        nominalLama: 100000,
        jenisBaru: JenisAmplop.kosong,
        nominalBaru: 0,
      );
      expect(d.deltaRp, -100000);
      expect(d.deltaKosong, 1);
      expect(d.deltaTanpaNama, 0);
    });

    test('tanpa nama menjadi normal: tanpaNama -1', () {
      final d = deltaUbahAmplop(
        jenisLama: JenisAmplop.tanpaNama,
        nominalLama: 50000,
        jenisBaru: JenisAmplop.normal,
        nominalBaru: 50000,
      );
      expect(d.deltaRp, 0);
      expect(d.deltaKosong, 0);
      expect(d.deltaTanpaNama, -1);
    });

    test('kosong menjadi tanpa nama: hitungan bertukar', () {
      final d = deltaUbahAmplop(
        jenisLama: JenisAmplop.kosong,
        nominalLama: 0,
        jenisBaru: JenisAmplop.tanpaNama,
        nominalBaru: 75000,
      );
      expect(d.deltaRp, 75000);
      expect(d.deltaKosong, -1);
      expect(d.deltaTanpaNama, 1);
    });

    test('tidak ada perubahan menghasilkan nol semua', () {
      final d = deltaUbahAmplop(
        jenisLama: JenisAmplop.normal,
        nominalLama: 200000,
        jenisBaru: JenisAmplop.normal,
        nominalBaru: 200000,
      );
      expect(d.deltaRp, 0);
      expect(d.deltaKosong, 0);
      expect(d.deltaTanpaNama, 0);
    });
  });

  group('slotUrutKosong', () {
    test('bundel kosong -> slot 1', () {
      expect(slotUrutKosong(const []), 1);
    });

    test('isi berurutan 1..3 -> slot 4', () {
      expect(slotUrutKosong(const [1, 2, 3]), 4);
    });

    test('hapus urut 5 dari bundel penuh -> slot 5, bukan 10', () {
      // Kasus nyata: 9 isi bernomor 1,2,3,4,6,7,8,9,10. jumlah+1
      // (= 10) sudah terpakai — slot kosongnya adalah 5.
      expect(
        slotUrutKosong(const [1, 2, 3, 4, 6, 7, 8, 9, 10]),
        5,
      );
    });

    test('hapus urut terakhir -> slot 10', () {
      expect(slotUrutKosong(const [1, 2, 3, 4, 5, 6, 7, 8, 9]), 10);
    });

    test('bundel penuh 1..10 -> null', () {
      expect(
        slotUrutKosong(const [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]),
        isNull,
      );
    });
  });
}
