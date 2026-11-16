import '../models/acara.dart';
import '../models/pemilik.dart';

/// Logika murni panel admin (Batch 4): agregasi platform & per
/// pemilik dari daftar dokumen. Tanpa Firebase — diuji di
/// test/admin_test.dart.

/// Ringkasan seluruh platform untuk kepala panel admin.
class RingkasanPlatform {
  const RingkasanPlatform({
    required this.totalPemilik,
    required this.totalAcara,
    required this.totalAmplop,
    required this.totalRp,
  });

  final int totalPemilik;
  final int totalAcara;
  final int totalAmplop;
  final int totalRp;
}

RingkasanPlatform ringkasPlatform({
  required List<Pemilik> pemilik,
  required List<Acara> acara,
}) {
  var amplop = 0;
  var rp = 0;
  for (final a in acara) {
    amplop += a.totalAmplop;
    rp += a.totalRp;
  }
  return RingkasanPlatform(
    totalPemilik: pemilik.length,
    totalAcara: acara.length,
    totalAmplop: amplop,
    totalRp: rp,
  );
}

/// Satu pemilik + agregat acaranya untuk daftar di panel admin.
class RingkasanPemilikAdmin {
  const RingkasanPemilikAdmin({
    required this.pemilik,
    required this.jumlahAcara,
    required this.totalAmplop,
    required this.totalRp,
  });

  final Pemilik pemilik;
  final int jumlahAcara;
  final int totalAmplop;
  final int totalRp;
}

/// Agregat per pemilik; pemilik tanpa acara tetap muncul (angka 0).
/// Urut nama pemilik A–Z.
List<RingkasanPemilikAdmin> ringkasPerPemilik(
  List<Pemilik> pemilik,
  List<Acara> acara,
) {
  final perId = <String, RingkasanPemilikAdmin>{};
  for (final p in pemilik) {
    perId[p.id] = RingkasanPemilikAdmin(
      pemilik: p,
      jumlahAcara: 0,
      totalAmplop: 0,
      totalRp: 0,
    );
  }
  for (final a in acara) {
    final lama = perId[a.pemilikId];
    if (lama == null) continue; // acara yatim (pemiliknya terhapus)
    perId[a.pemilikId] = RingkasanPemilikAdmin(
      pemilik: lama.pemilik,
      jumlahAcara: lama.jumlahAcara + 1,
      totalAmplop: lama.totalAmplop + a.totalAmplop,
      totalRp: lama.totalRp + a.totalRp,
    );
  }
  final hasil = perId.values.toList();
  hasil.sort(
    (a, b) => a.pemilik.nama.toLowerCase().compareTo(
      b.pemilik.nama.toLowerCase(),
    ),
  );
  return hasil;
}
