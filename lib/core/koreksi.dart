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

/// Slot urut terkecil 1..10 yang belum terpakai, atau null bila bundel
/// sudah penuh. Dipakai tambah-koreksi, BUKAN `jumlahAmplop + 1`:
/// setelah hapus di tengah bundel, jumlahnya turun tapi nomor lama
/// tetap terpakai — mis. hapus urut 5 dari bundel penuh menyisakan
/// 9 isi bernomor 1,2,3,4,6,7,8,9,10; tambah berikutnya harus memakai
/// slot 5 yang kosong, bukan 10 yang sudah ada (duplikat urut membuat
/// dua baris bernomor sama di ekspor Excel).
int? slotUrutKosong(Iterable<int> urutTerpakai) {
  final terpakai = urutTerpakai.toSet();
  for (var urut = 1; urut <= 10; urut++) {
    if (!terpakai.contains(urut)) return urut;
  }
  return null;
}
