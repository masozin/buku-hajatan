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
}
