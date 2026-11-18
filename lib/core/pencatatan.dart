import '../models/amplop.dart';

/// Logika pencatatan murni (tanpa Flutter/Firebase) — bisa diuji unit.
///
/// Aturan main dari rancangan teknis §2:
/// - Satu bundel = maks. 10 amplop; amplop ke-10 menutup bundel.
/// - Amplop kosong: nama tetap dicatat, nominal dipaksa Rp 0.
/// - Amplop tanpa nama: nama disimpan kosong (tampil "(Tanpa Nama)"),
///   nominal wajib > 0.
/// - Keduanya tetap dihitung dalam 10 isi bundel.

/// "Rp 150.000" / "150000" / "150.000" -> 150000. Bukan angka -> 0.
int parseNominal(String teks) {
  final angkaSaja = teks.replaceAll(RegExp(r'[^0-9]'), '');
  if (angkaSaja.isEmpty) return 0;
  return int.tryParse(angkaSaja) ?? 0;
}

/// Validasi satu amplop sebelum disimpan; null = sah, berisi pesan galat.
String? validasiAmplop({
  required JenisAmplop jenis,
  required String nama,
  required int nominal,
}) {
  switch (jenis) {
    case JenisAmplop.normal:
      if (nama.trim().isEmpty) return 'Nama tamu belum diisi.';
      if (nominal <= 0) {
        return 'Nominal harus lebih dari Rp 0 untuk jenis Normal.';
      }
      return null;
    case JenisAmplop.kosong:
      // Amplop kosong: nama tetap wajib (itu yang membedakannya dari
      // tanpa nama); nominal berapa pun akan dipaksa 0 saat disimpan.
      if (nama.trim().isEmpty) {
        return 'Nama pengunjung belum diisi (yang kosong pun tetap dicatat namanya).';
      }
      return null;
    case JenisAmplop.tanpaNama:
      if (nominal <= 0) {
        return 'Nominal harus diisi untuk pengunjung tanpa nama.';
      }
      return null;
    case JenisAmplop.hadir:
      // Hadir saja tanpa amplop (ditetapkan di Mode Hitung):
      // nama wajib ada, nominal selalu dipaksa 0 saat disimpan.
      if (nama.trim().isEmpty) {
        return 'Nama pengunjung belum diisi.';
      }
      return null;
  }
}

/// Nama yang disimpan ke Firestore (tanpa nama -> string kosong).
String namaSimpan(JenisAmplop jenis, String nama) {
  if (jenis == JenisAmplop.tanpaNama) return '';
  return nama.trim();
}

/// Nominal yang disimpan ke Firestore (kosong/hadir -> 0).
int nominalSimpan(JenisAmplop jenis, int nominal) {
  if (jenis == JenisAmplop.kosong || jenis == JenisAmplop.hadir) {
    return 0;
  }
  return nominal;
}

/// Urut amplop berikutnya di bundel yang sudah berisi [jumlahAmplop].
int urutBerikutnya(int jumlahAmplop) => jumlahAmplop + 1;

/// Apakah amplop yang disimpan ke bundel berisi [jumlahAmplop] ini
/// adalah amplop ke-10, alias menutup bundel?
bool amplopIniMenutupBundel(int jumlahAmplop) => jumlahAmplop == 9;

/// Apakah bundel berisi [jumlahAmplop] sudah penuh?
bool bundelPenuh(int jumlahAmplop) => jumlahAmplop >= 10;
