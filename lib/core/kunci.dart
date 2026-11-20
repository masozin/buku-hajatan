/// Logika kunci aplikasi murni (Batch 38) — bisa diuji unit.

/// Berapa lama aplikasi boleh di latar belakang sebelum
/// dikunci lagi. Singkat saja tidak dikunci (mis. sekadar
/// membalas notifikasi atau dialog sistem sesaat), agar
/// petugas tidak terus-terusan diminta sidik jari.
const ambangKunciLatar = Duration(seconds: 60);

/// True bila aplikasi perlu dikunci setelah kembali dari
/// latar belakang: pernah ke latar DAN sudah melewati
/// [ambangKunciLatar].
bool perluKunciSetelahLatar({
  required DateTime? terakhirKeLatar,
  required DateTime sekarang,
}) {
  if (terakhirKeLatar == null) return false;
  return sekarang.difference(terakhirKeLatar) >= ambangKunciLatar;
}
