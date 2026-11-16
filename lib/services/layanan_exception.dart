/// Kesalahan layanan yang pesannya AMAN dan layak ditampilkan langsung
/// ke pengguna (Bahasa Indonesia, tanpa istilah teknis mentah).
class LayananException implements Exception {
  const LayananException(this.pesan);

  final String pesan;

  @override
  String toString() => pesan;
}
