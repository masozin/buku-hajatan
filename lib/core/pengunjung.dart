import 'kode.dart';
import 'rekap.dart';

/// Logika daftar pengunjung untuk tab Pengunjung di Detail Acara
/// (Batch 7): ratakan semua amplop lintas bundel, saring dengan
/// kata kunci, urutkan sesuai pilihan pemilik. Murni, tanpa
/// Firebase — diuji di test/pengunjung_test.dart.

/// Pilihan urutan daftar pengunjung.
enum UrutanPengunjung {
  bundel('Urutan bundel'),
  namaAZ('Nama A–Z'),
  namaZA('Nama Z–A'),
  nominalBesar('Nominal terbesar'),
  nominalKecil('Nominal terkecil'),
  dusun('Dusun'),
  terbaru('Terbaru'),
  terlama('Terlama');

  const UrutanPengunjung(this.label);

  final String label;
}

/// Ratakan seluruh isi acara menjadi daftar pengunjung (satu entri
/// per amplop, membawa kode bundelnya).
List<AmplopDitemukan> semuaPengunjung(List<BundelTerisi> data) {
  final hasil = <AmplopDitemukan>[];
  for (final bt in data) {
    for (final a in bt.isi) {
      hasil.add(
        AmplopDitemukan(
          amplop: a,
          kodeBundel: bt.bundel.kode,
          prefixPencatat: bt.bundel.prefix,
        ),
      );
    }
  }
  return hasil;
}

/// Saring daftar pengunjung dengan kata kunci (nama, alamat, dusun,
/// keterangan, kode bundel). Kata kunci kosong = semua tampil.
List<AmplopDitemukan> saringPengunjung(
  List<AmplopDitemukan> daftar,
  String kataKunci,
) {
  final kunci = normalisasiNama(kataKunci);
  if (kunci.isEmpty) return [...daftar];
  return daftar.where((d) {
    final a = d.amplop;
    return normalisasiNama(a.nama).contains(kunci) ||
        (a.alamat != null && normalisasiNama(a.alamat!).contains(kunci)) ||
        (a.dusun != null && 'dusun ${a.dusun}'.contains(kunci)) ||
        (a.keterangan != null &&
            normalisasiNama(a.keterangan!).contains(kunci)) ||
        normalisasiNama(d.kodeBundel).contains(kunci);
  }).toList();
}

/// Urutkan daftar pengunjung (mengembalikan daftar baru).
List<AmplopDitemukan> urutkanPengunjung(
  List<AmplopDitemukan> daftar,
  UrutanPengunjung urutan,
) {
  final hasil = [...daftar];
  int bandingBundel(AmplopDitemukan x, AmplopDitemukan y) {
    final k = x.kodeBundel.compareTo(y.kodeBundel);
    return k != 0 ? k : x.amplop.urut.compareTo(y.amplop.urut);
  }

  switch (urutan) {
    case UrutanPengunjung.bundel:
      hasil.sort(bandingBundel);
    case UrutanPengunjung.namaAZ:
      hasil.sort((x, y) {
        final n = normalisasiNama(
          x.amplop.tampilNama,
        ).compareTo(normalisasiNama(y.amplop.tampilNama));
        return n != 0 ? n : bandingBundel(x, y);
      });
    case UrutanPengunjung.namaZA:
      hasil.sort((x, y) {
        final n = normalisasiNama(
          y.amplop.tampilNama,
        ).compareTo(normalisasiNama(x.amplop.tampilNama));
        return n != 0 ? n : bandingBundel(x, y);
      });
    case UrutanPengunjung.nominalBesar:
      hasil.sort((x, y) {
        final n = y.amplop.nominal.compareTo(x.amplop.nominal);
        return n != 0 ? n : bandingBundel(x, y);
      });
    case UrutanPengunjung.nominalKecil:
      hasil.sort((x, y) {
        final n = x.amplop.nominal.compareTo(y.amplop.nominal);
        return n != 0 ? n : bandingBundel(x, y);
      });
    case UrutanPengunjung.dusun:
      // Yang tanpa dusun ditaruh paling belakang.
      hasil.sort((x, y) {
        final dx = x.amplop.dusun ?? 1 << 30;
        final dy = y.amplop.dusun ?? 1 << 30;
        final n = dx.compareTo(dy);
        return n != 0 ? n : bandingBundel(x, y);
      });
    case UrutanPengunjung.terbaru:
      hasil.sort((x, y) {
        final wx = x.amplop.createdAt;
        final wy = y.amplop.createdAt;
        if (wx == null && wy == null) return bandingBundel(x, y);
        if (wx == null) return 1;
        if (wy == null) return -1;
        final n = wy.compareTo(wx);
        return n != 0 ? n : bandingBundel(x, y);
      });
    case UrutanPengunjung.terlama:
      hasil.sort((x, y) {
        final wx = x.amplop.createdAt;
        final wy = y.amplop.createdAt;
        if (wx == null && wy == null) return bandingBundel(x, y);
        if (wx == null) return 1;
        if (wy == null) return -1;
        final n = wx.compareTo(wy);
        return n != 0 ? n : bandingBundel(x, y);
      });
  }
  return hasil;
}
