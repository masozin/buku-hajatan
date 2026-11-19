/// Logika Daftar Undangan murni (tanpa Flutter/Firebase) — bisa
/// diuji unit (Batch 34, rancangan multi-metode v2 §6).
///
/// - Tempel teks: satu baris = satu tamu, `Nama, Alamat`.
/// - Impor CSV: kolom Nama, Alamat, Dusun, RT, RW, Kategori;
///   baris pertama boleh header (`Nama,...`) dan dilewati.
///   Pemisah koma sederhana — koma di dalam tanda kutip TIDAK
///   didukung (daftar dari Excel sebaiknya disimpan sebagai CSV
///   tanpa koma di dalam nama/alamat).

/// Satu baris tamu hasil parse (sebelum diberi kode tamu & ID).
typedef BarisTamu = ({
  String nama,
  String? alamat,
  int? dusun,
  int? rt,
  int? rw,
  String? kategori,
});

String? _bersih(String? nilai) {
  final t = nilai?.trim();
  return (t == null || t.isEmpty) ? null : t;
}

int? _angka(String? nilai) {
  final t = _bersih(nilai);
  if (t == null) return null;
  return int.tryParse(t.replaceAll(RegExp(r'[^0-9]'), ''));
}

/// Parse teks tempelan: satu baris = satu tamu (`Nama, Alamat` —
/// alamat boleh kosong). Baris tanpa nama dilewati.
List<BarisTamu> parseTempelUndangan(String teks) {
  final hasil = <BarisTamu>[];
  for (final baris in teks.split('\n')) {
    final t = baris.trim();
    if (t.isEmpty) continue;
    final kolom = t.split(',');
    final nama = kolom.first.trim();
    if (nama.isEmpty) continue;
    hasil.add((
      nama: nama,
      alamat: kolom.length > 1 ? _bersih(kolom[1]) : null,
      dusun: null,
      rt: null,
      rw: null,
      kategori: kolom.length > 2 ? _bersih(kolom[2]) : null,
    ));
  }
  return hasil;
}

/// Parse teks CSV: kolom Nama, Alamat, Dusun, RT, RW, Kategori.
/// Baris pertama dilewati bila tampak seperti header (memuat kata
/// "nama"). Baris tanpa nama dilewati.
List<BarisTamu> parseCsvUndangan(String teks) {
  final baris = teks
      .split('\n')
      .map((b) => b.trim())
      .where((b) => b.isNotEmpty)
      .toList();
  if (baris.isEmpty) return const [];
  var mulai = 0;
  if (baris.first.toLowerCase().contains('nama')) mulai = 1;
  final hasil = <BarisTamu>[];
  for (var i = mulai; i < baris.length; i++) {
    final kolom = baris[i].split(',').map((k) => k.trim()).toList();
    final nama = kolom.first;
    if (nama.isEmpty) continue;
    hasil.add((
      nama: nama,
      alamat: kolom.length > 1 ? _bersih(kolom[1]) : null,
      dusun: kolom.length > 2 ? _angka(kolom[2]) : null,
      rt: kolom.length > 3 ? _angka(kolom[3]) : null,
      rw: kolom.length > 4 ? _angka(kolom[4]) : null,
      kategori: kolom.length > 5 ? _bersih(kolom[5]) : null,
    ));
  }
  return hasil;
}

/// "Belum ada kabar" = diundang − hadir − tidak hadir (dijaga
/// tidak negatif bila ada walk-in yang menaikkan total).
int hitungBelumHadir({
  required int totalUndangan,
  required int totalHadir,
  required int totalTidakHadir,
}) {
  final sisa = totalUndangan - totalHadir - totalTidakHadir;
  return sisa < 0 ? 0 : sisa;
}

/// Apakah tamu ini cocok dengan kueri pencarian (nama atau
/// alamat, tanpa peduli huruf besar/kecil)?
bool cocokUndangan({
  required String nama,
  String? alamat,
  required String kueri,
}) {
  final k = kueri.trim().toLowerCase();
  if (k.isEmpty) return true;
  if (nama.toLowerCase().contains(k)) return true;
  if ((alamat ?? '').toLowerCase().contains(k)) return true;
  return false;
}
