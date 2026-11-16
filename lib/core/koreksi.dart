import '../models/amplop.dart';

/// Logika murni koreksi data oleh pemilik SETELAH acara selesai
/// (Batch 6). Tanpa Firebase — diuji di test/koreksi_test.dart.

/// Selisih agregat yang harus diterapkan ke bundel & acara saat
/// sebuah amplop diubah (edit). Jumlah amplop tidak berubah.
class DeltaAmplop {
  const DeltaAmplop({
    required this.deltaRp,
    required this.deltaKosong,
    required this.deltaTanpaNama,
  });

  final int deltaRp;
  final int deltaKosong;
  final int deltaTanpaNama;
}

DeltaAmplop deltaUbahAmplop({
  required JenisAmplop jenisLama,
  required int nominalLama,
  required JenisAmplop jenisBaru,
  required int nominalBaru,
}) {
  int hitung(JenisAmplop jenis, JenisAmplop target) =>
      jenis == target ? 1 : 0;
  return DeltaAmplop(
    deltaRp: nominalBaru - nominalLama,
    deltaKosong:
        hitung(jenisBaru, JenisAmplop.kosong) -
        hitung(jenisLama, JenisAmplop.kosong),
    deltaTanpaNama:
        hitung(jenisBaru, JenisAmplop.tanpaNama) -
        hitung(jenisLama, JenisAmplop.tanpaNama),
  );
}
