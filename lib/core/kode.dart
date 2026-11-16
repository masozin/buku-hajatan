import 'dart:math';

/// Util murni (tanpa dependensi Flutter/Firebase) untuk kode & penomoran.
///
/// Aturan main dari rancangan teknis:
/// - Setiap pencatat punya prefix unik per acara: A, B, C, ... lalu AA, AB, ...
/// - Kode bundel = prefix + nomor 3 digit, mis. `A001`, `B012`.
/// - Kode gabung acara = 6 karakter acak yang tidak ambigu (tanpa 0/O/1/I).

/// Huruf prefix untuk pencatat ke-[urutan] (0-based):
/// 0 -> A, 1 -> B, ..., 25 -> Z, 26 -> AA, 27 -> AB, ...
String hurufPrefix(int urutan) {
  if (urutan < 0) {
    throw ArgumentError.value(urutan, 'urutan', 'tidak boleh negatif');
  }
  var n = urutan;
  var hasil = '';
  do {
    hasil = String.fromCharCode(65 + (n % 26)) + hasil;
    n = (n ~/ 26) - 1;
  } while (n >= 0);
  return hasil;
}

/// Kode bundel dari prefix + nomor urut, mis. (`A`, 3) -> `A003`.
/// Nomor di atas 999 dibiarkan apa adanya (`A1000`), tidak terpotong.
String buatKodeBundel(String prefix, int nomor) {
  return '$prefix${nomor.toString().padLeft(3, '0')}';
}

/// Normalisasi nama untuk pencocokan klaim undangan pencatat:
/// huruf kecil, spasi berlebih dibuang. "  Budi   Santoso " -> "budi santoso".
String normalisasiNama(String nama) {
  return nama.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

const String _alfabetKodeGabung = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

/// Kode gabung acara acak 6 karakter, mis. `K7QX2M`.
/// Dipakai pencatat untuk menemukan acara; pasangan pengamannya adalah
/// PIN gabung yang disimpan di dokumen `kodeAcara/{kode}` (bukan di dokumen
/// acara, supaya PIN tidak ikut terbaca siapa pun yang melihat acara).
String buatKodeGabung([Random? acak]) {
  final rng = acak ?? Random.secure();
  return List.generate(
    6,
    (_) => _alfabetKodeGabung[rng.nextInt(_alfabetKodeGabung.length)],
  ).join();
}

/// PIN gabung 4 digit acak, mis. `0427` (nol di depan dipertahankan).
String buatPinGabung([Random? acak]) {
  final rng = acak ?? Random.secure();
  return rng.nextInt(10000).toString().padLeft(4, '0');
}
