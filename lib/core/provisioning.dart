/// Logika murni provisioning admin (Batch 5): validasi form pemilik
/// baru yang dibuatkan akunnya oleh admin. Tanpa Firebase — diuji di
/// test/provisioning_test.dart.

/// Mengembalikan pesan galat pertama, atau null bila form sah.
String? galatPemilikBaru({
  required String nama,
  required String email,
  required String kataSandi,
  required String konfirmasiSandi,
}) {
  if (nama.trim().isEmpty) return 'Nama pemilik wajib diisi.';
  final e = email.trim();
  if (!e.contains('@') || !e.contains('.') || e.contains(' ')) {
    return 'Alamat email tidak valid.';
  }
  if (kataSandi.length < 6) return 'Kata sandi awal minimal 6 karakter.';
  if (kataSandi != konfirmasiSandi) {
    return 'Konfirmasi kata sandi tidak sama.';
  }
  return null;
}
