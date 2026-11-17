/// Logika murni pemeriksa pembaruan (Batch 21): mengurai JSON rilis
/// GitHub dan membandingkan versi. Tanpa dependensi Flutter/Firebase
/// — bisa diuji unit.
///
/// Sumber pembaruan: GitHub Releases repo buku-hajatan (publik).
/// Konvensi tag rilis: `v` + versi pubspec persis, mis. pubspec
/// `1.1.0+2` → tag `v1.1.0+2`. Kode versi (bagian `+2`) yang
/// menentukan ada pembaruan; bila tag ditulis tanpa kode, nama
/// versinya yang dibandingkan. Rilis yang catatan rilisnya memuat
/// penanda `[WAJIB]` dianggap wajib: dialognya tidak bisa ditunda.

/// Satu rilis GitHub (hasil urai releases/latest).
class InfoRilis {
  const InfoRilis({
    required this.versiNama,
    this.kodeVersi,
    this.urlApk,
    required this.urlHalaman,
    required this.catatan,
    required this.wajib,
  });

  /// Nama versi rilis, mis. `1.1.0` (tanpa awalan `v`, tanpa kode).
  final String versiNama;

  /// Kode versi dari tag (bagian `+2`), bila ditulis di tag.
  final int? kodeVersi;

  /// Tautan unduh langsung APK dari aset rilis; null bila rilis
  /// tidak punya aset .apk (pemanggil memakai [urlHalaman]).
  final String? urlApk;

  /// Halaman rilis di GitHub.
  final String urlHalaman;

  /// Catatan rilis (teks apa adanya dari GitHub).
  final String catatan;

  /// true bila catatan rilis memuat penanda [WAJIB].
  final bool wajib;

  /// Tautan yang dibuka tombol Unduh.
  String get urlUnduh => urlApk ?? urlHalaman;
}

/// Urai JSON `GET /repos/{owner}/{repo}/releases/latest`.
/// Mengembalikan null bila bentuknya tidak dikenali.
InfoRilis? uraiRilisGithub(Map<String, dynamic> json) {
  final tag = (json['tag_name'] as String?)?.trim() ?? '';
  if (tag.isEmpty) return null;
  final tanpaV = (tag.startsWith('v') || tag.startsWith('V'))
      ? tag.substring(1)
      : tag;
  final bagian = tanpaV.split('+');
  final nama = bagian.first.trim();
  if (nama.isEmpty) return null;
  final kode = bagian.length > 1 ? int.tryParse(bagian[1].trim()) : null;
  String? urlApk;
  final aset = json['assets'];
  if (aset is List) {
    for (final a in aset) {
      if (a is Map<String, dynamic>) {
        final namaAset = (a['name'] as String?) ?? '';
        if (namaAset.toLowerCase().endsWith('.apk')) {
          urlApk = a['browser_download_url'] as String?;
          break;
        }
      }
    }
  }
  final catatan = (json['body'] as String?) ?? '';
  return InfoRilis(
    versiNama: nama,
    kodeVersi: kode,
    urlApk: urlApk,
    urlHalaman: (json['html_url'] as String?) ?? '',
    catatan: catatan,
    wajib: catatan.contains('[WAJIB]'),
  );
}

/// Bandingkan dua nama versi bertitik (`1.1.0` vs `1.0.9`):
/// negatif bila a < b, 0 bila sama, positif bila a > b. Bagian
/// bukan angka dianggap 0; panjang berbeda dilengkapi 0.
int bandingNamaVersi(String a, String b) {
  List<int> pecah(String v) =>
      v.split('.').map((s) => int.tryParse(s.trim()) ?? 0).toList();
  final pa = pecah(a);
  final pb = pecah(b);
  final n = pa.length > pb.length ? pa.length : pb.length;
  for (var i = 0; i < n; i++) {
    final x = i < pa.length ? pa[i] : 0;
    final y = i < pb.length ? pb[i] : 0;
    if (x != y) return x.compareTo(y);
  }
  return 0;
}

/// true bila [rilis] lebih baru daripada aplikasi terpasang.
/// Kode versi didahulukan — itulah yang Android pakai untuk
/// menerima pemasangan pembaruan; tanpa kode, bandingkan nama.
bool rilisLebihBaru({
  required InfoRilis rilis,
  required String versiTerpasang,
  required int kodeTerpasang,
}) {
  if (rilis.kodeVersi != null) return rilis.kodeVersi! > kodeTerpasang;
  return bandingNamaVersi(rilis.versiNama, versiTerpasang) > 0;
}
