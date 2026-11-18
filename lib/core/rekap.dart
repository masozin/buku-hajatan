import '../models/amplop.dart';
import '../models/bundel.dart';
import '../models/pencatat.dart';
import 'kode.dart';

/// Logika rekap & ekspor murni (tanpa Flutter/Firebase) — bisa diuji unit.
///
/// Sumber kebenaran rekap (rancangan teknis §3): dokumen acara memegang
/// total keseluruhan; rincian per pencatat & per bundel dihitung dari
/// dokumen-dokumen bundel (satu dokumen per bundel, berisi agregatnya),
/// BUKAN dari membaca semua amplop. Amplop hanya dibaca saat pencarian
/// nama dan saat ekspor.

/// Ringkasan satu pencatat, dihitung dari bundel-bundelnya.
class RingkasanPencatat {
  const RingkasanPencatat({
    required this.pencatatId,
    required this.nama,
    required this.prefix,
    this.jumlahBundel = 0,
    this.jumlahAmplop = 0,
    this.totalRp = 0,
    this.jumlahKosong = 0,
    this.jumlahTanpaNama = 0,
  });

  final String pencatatId;
  final String nama;
  final String prefix;
  final int jumlahBundel;
  final int jumlahAmplop;
  final int totalRp;
  final int jumlahKosong;
  final int jumlahTanpaNama;
}

/// Kelompokkan bundel per pencatat. Pencatat tanpa bundel tetap muncul
/// (semua angka 0). Urut berdasarkan prefix.
List<RingkasanPencatat> ringkasPerPencatat(
  List<Bundel> semuaBundel,
  List<Pencatat> semuaPencatat,
) {
  final perId = <String, RingkasanPencatat>{};
  for (final p in semuaPencatat) {
    perId[p.id] = RingkasanPencatat(
      pencatatId: p.id,
      nama: p.nama,
      prefix: p.prefix,
    );
  }
  for (final b in semuaBundel) {
    final lama = perId[b.pencatatId];
    // Bundel khusus pemilik (Batch 20, prefix PM) tidak punya
    // dokumen pencatat — tampil sebagai "Pemilik".
    final dasar =
        lama ??
        RingkasanPencatat(
          pencatatId: b.pencatatId,
          nama: b.prefix == prefixBundelPemilik ? 'Pemilik' : '',
          prefix: b.prefix,
        );
    perId[b.pencatatId] = RingkasanPencatat(
      pencatatId: dasar.pencatatId,
      nama: dasar.nama,
      prefix: dasar.prefix.isEmpty ? b.prefix : dasar.prefix,
      jumlahBundel: dasar.jumlahBundel + 1,
      jumlahAmplop: dasar.jumlahAmplop + b.jumlahAmplop,
      totalRp: dasar.totalRp + b.totalRp,
      jumlahKosong: dasar.jumlahKosong + b.jumlahKosong,
      jumlahTanpaNama: dasar.jumlahTanpaNama + b.jumlahTanpaNama,
    );
  }
  final hasil = perId.values.toList();
  hasil.sort((a, b) => a.prefix.compareTo(b.prefix));
  return hasil;
}

/// Satu bundel beserta seluruh isi amplopnya (urut 1..10),
/// untuk pencarian & ekspor.
class BundelTerisi {
  const BundelTerisi({required this.bundel, required this.isi});

  final Bundel bundel;
  final List<Amplop> isi;
}

/// Satu baris ekspor (satu amplop), siap ditulis ke Excel/CSV.
class BarisEkspor {
  const BarisEkspor({
    required this.kodeBundel,
    this.prefixPencatat = '',
    required this.urut,
    required this.nama,
    required this.alamat,
    required this.nominal,
    required this.jenis,
    this.dusun,
    this.rt,
    this.rw,
    this.keterangan,
    this.waktu,
    this.dihitung = true,
  });

  final String kodeBundel;

  /// Prefix pencatat pemilik bundel (Batch 30, untuk kolom
  /// Pencatat di ekspor datar Metode Langsung).
  final String prefixPencatat;
  final int urut;
  final String nama;
  final String alamat;
  final int nominal;
  final JenisAmplop jenis;

  /// Kolom Batch 7: nomor dusun, catatan, timestamp pencatatan.
  /// RT/RW menyusul di Batch 25.
  final int? dusun;
  final int? rt;
  final int? rw;
  final String? keterangan;
  final DateTime? waktu;

  /// Batch 32: false = entri Buku Tamu yang nominalnya belum
  /// dihitung — kolom Jenis di ekspor menampilkannya sebagai
  /// "Belum Dihitung" agar Rp 0-nya tidak dibaca sebagai amplop
  /// kosong / hadir saja.
  final bool dihitung;

  /// Label kolom Jenis untuk ekspor (Batch 32).
  String get labelJenis => dihitung ? jenis.label : 'Belum Dihitung';
}

/// Ratakan data ekspor menjadi baris-baris, urut bundel (prefix, nomor)
/// lalu urut amplop di dalam bundel. Nama memakai tampilan buku:
/// amplop tanpa nama tampil "(Tanpa Nama)".
List<BarisEkspor> buatBarisEkspor(List<BundelTerisi> data) {
  final terurut = [...data];
  terurut.sort((a, b) {
    final bandingPrefix = a.bundel.prefix.compareTo(b.bundel.prefix);
    return bandingPrefix != 0
        ? bandingPrefix
        : a.bundel.nomor.compareTo(b.bundel.nomor);
  });
  final baris = <BarisEkspor>[];
  for (final bt in terurut) {
    final isi = [...bt.isi]..sort((a, b) => a.urut.compareTo(b.urut));
    for (final a in isi) {
      baris.add(
        BarisEkspor(
          kodeBundel: bt.bundel.kode,
          prefixPencatat: bt.bundel.prefix,
          urut: a.urut,
          nama: a.tampilNama,
          alamat: a.alamat ?? '',
          nominal: a.nominal,
          jenis: a.jenis,
          dusun: a.dusun,
          rt: a.rt,
          rw: a.rw,
          keterangan: a.keterangan,
          waktu: a.createdAt,
          dihitung: a.dihitung,
        ),
      );
    }
  }
  return baris;
}

/// Alamat lengkap satu baris (Batch 25, permintaan Mark): gabungan
/// alamat + dusun + RT/RW, hanya bagian yang terisi yang tampil,
/// disambung koma. Contoh: "Krajan, Dusun 2, RT 03/RW 04".
/// Dipakai kolom Alamat di semua ekspor (Excel, CSV, PDF).
String gabungAlamat({String? alamat, int? dusun, int? rt, int? rw}) {
  String dua(int n) => n.toString().padLeft(2, '0');
  final bagian = <String>[];
  if (alamat != null && alamat.trim().isNotEmpty) {
    bagian.add(alamat.trim());
  }
  if (dusun != null) bagian.add('Dusun $dusun');
  if (rt != null && rw != null) {
    bagian.add('RT ${dua(rt)}/RW ${dua(rw)}');
  } else if (rt != null) {
    bagian.add('RT ${dua(rt)}');
  } else if (rw != null) {
    bagian.add('RW ${dua(rw)}');
  }
  return bagian.join(', ');
}

/// Urutan nama abjad untuk ekspor PDF (Batch 25): pengunjung
/// bernama diurutkan A–Z (tidak peka huruf besar/kecil); yang
/// tanpa nama ditaruh paling akhir, mengikuti urutan asalnya.
List<Amplop> urutkanAbjad(List<Amplop> daftar) {
  bool bernama(Amplop a) =>
      a.jenis != JenisAmplop.tanpaNama && a.nama.trim().isNotEmpty;
  final terurut = daftar.where(bernama).toList()
    ..sort(
      (a, b) => a.nama.toLowerCase().compareTo(b.nama.toLowerCase()),
    );
  final tanpaNama = daftar.where((a) => !bernama(a)).toList();
  return [...terurut, ...tanpaNama];
}

/// Escape satu sel CSV (RFC 4180): bungkus tanda kutip bila mengandung
/// koma, kutip, atau baris baru; kutip di dalam digandakan.
String selCsv(String nilai) {
  if (nilai.contains(',') || nilai.contains('"') || nilai.contains('\n')) {
    return '"${nilai.replaceAll('"', '""')}"';
  }
  return nilai;
}

/// Isi file CSV untuk arsip. Berbeda dengan Excel (yang meniru buku,
/// kode bundel digabung per kelompok), di CSV kode bundel ditulis di
/// SETIAP baris supaya mudah diolah lagi (filter/pivot) di komputer.
String buatCsv(List<BarisEkspor> baris) {
  final sb = StringBuffer();
  // Batch 25: kolom Alamat kini gabungan alamat + dusun + RT/RW
  // (kolom Dusun terpisah dihapus — satu alamat lengkap).
  sb.writeln(
    'Kode Bundel,No,Nama,Alamat,Nominal (Rp),Jenis,Keterangan,Waktu',
  );
  for (final b in baris) {
    sb.writeln(
      [
        selCsv(b.kodeBundel),
        b.urut.toString(),
        selCsv(b.nama),
        selCsv(
          gabungAlamat(
            alamat: b.alamat,
            dusun: b.dusun,
            rt: b.rt,
            rw: b.rw,
          ),
        ),
        b.nominal.toString(),
        selCsv(b.labelJenis),
        selCsv(b.keterangan ?? ''),
        selCsv(b.waktu == null ? '' : formatWaktuCsv(b.waktu!)),
      ].join(','),
    );
  }
  return sb.toString();
}

/// CSV DATAR untuk Metode Langsung (Batch 30): tanpa kolom kode
/// bundel (tidak ada bundel) — nomor berjalan 1..N mengikuti
/// urutan baris (per pencatat, lalu urut catat), plus kolom
/// Pencatat berisi prefix pencatatnya.
String buatCsvDatar(List<BarisEkspor> baris) {
  final sb = StringBuffer();
  sb.writeln('No,Nama,Alamat,Nominal (Rp),Jenis,Pencatat,Keterangan,Waktu');
  var no = 0;
  for (final b in baris) {
    no++;
    sb.writeln(
      [
        no.toString(),
        selCsv(b.nama),
        selCsv(
          gabungAlamat(
            alamat: b.alamat,
            dusun: b.dusun,
            rt: b.rt,
            rw: b.rw,
          ),
        ),
        b.nominal.toString(),
        selCsv(b.labelJenis),
        selCsv(b.prefixPencatat),
        selCsv(b.keterangan ?? ''),
        selCsv(b.waktu == null ? '' : formatWaktuCsv(b.waktu!)),
      ].join(','),
    );
  }
  return sb.toString();
}

/// Timestamp untuk CSV: "2026-11-16 14:35" (tanpa intl, supaya
/// core/rekap tetap bebas dependensi format tampilan).
String formatWaktuCsv(DateTime w) {
  String dua(int n) => n.toString().padLeft(2, '0');
  return '${w.year}-${dua(w.month)}-${dua(w.day)} '
      '${dua(w.hour)}:${dua(w.minute)}';
}

/// Nama file ekspor yang aman: "Pernikahan Sari & Budi" ->
/// "buku-hajatan-pernikahan-sari-budi.xlsx".
String buatNamaFile(String namaAcara, String ekstensi) {
  final bersih = normalisasiNama(namaAcara)
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  final dasar = bersih.isEmpty ? 'acara' : bersih;
  return 'buku-hajatan-$dasar.$ekstensi';
}

/// Hasil pencarian nama: amplop + konteks bundelnya.
class AmplopDitemukan {
  const AmplopDitemukan({
    required this.amplop,
    required this.kodeBundel,
    required this.prefixPencatat,
    this.bebas = false,
  });

  final Amplop amplop;
  final String kodeBundel;
  final String prefixPencatat;

  /// Bundelnya bundel BEBAS (Batch 30/32): wadah mengalir Buku
  /// Tamu / Metode Langsung — kode bundelnya tidak ditampilkan.
  final bool bebas;
}

/// Cari amplop yang nama/alamat/dusun/keterangannya mengandung
/// [kataKunci], tidak peka huruf besar/kecil. Pencarian di memori
/// atas data yang sudah dibaca — untuk skala hajatan (±1.000
/// amplop) ini cukup dan tidak membakar kuota baca tambahan.
List<AmplopDitemukan> cariDalamData(List<BundelTerisi> data, String kataKunci) {
  final kunci = normalisasiNama(kataKunci);
  if (kunci.isEmpty) return const [];
  final hasil = <AmplopDitemukan>[];
  for (final bt in data) {
    for (final a in bt.isi) {
      final cocokNama = normalisasiNama(a.nama).contains(kunci);
      final cocokAlamat =
          a.alamat != null && normalisasiNama(a.alamat!).contains(kunci);
      final cocokDusun =
          a.dusun != null && 'dusun ${a.dusun}'.contains(kunci);
      final cocokKeterangan = a.keterangan != null &&
          normalisasiNama(a.keterangan!).contains(kunci);
      if (cocokNama || cocokAlamat || cocokDusun || cocokKeterangan) {
        hasil.add(
          AmplopDitemukan(
            amplop: a,
            kodeBundel: bt.bundel.kode,
            prefixPencatat: bt.bundel.prefix,
            bebas: bt.bundel.bebas,
          ),
        );
      }
    }
  }
  hasil.sort((a, b) {
    final bandingNama = normalisasiNama(a.amplop.nama)
        .compareTo(normalisasiNama(b.amplop.nama));
    return bandingNama != 0
        ? bandingNama
        : a.kodeBundel.compareTo(b.kodeBundel);
  });
  return hasil;
}

/// Daftar alamat unik yang pernah dipakai di acara ini (Batch 14)
/// — bahan sugesti kolom Alamat pada form pencatatan & koreksi.
/// Duplikat disaring tanpa peka huruf (ejaan pertama yang
/// menang), hasil terurut A–Z.
List<String> daftarAlamatUnik(List<BundelTerisi> data) {
  final terlihat = <String, String>{};
  for (final bt in data) {
    for (final a in bt.isi) {
      final alamat = a.alamat?.trim() ?? '';
      if (alamat.isEmpty) continue;
      terlihat.putIfAbsent(normalisasiNama(alamat), () => alamat);
    }
  }
  final hasil = terlihat.values.toList()
    ..sort((x, y) => normalisasiNama(x).compareTo(normalisasiNama(y)));
  return hasil;
}

/// Saring [saran] alamat untuk teks yang sedang diketik
/// (Batch 14): cocok bila alamatnya — atau salah satu katanya —
/// berawalan teks itu, tanpa peka huruf. Maksimal 8 sugesti.
List<String> saringSaranAlamat(List<String> saran, String teks) {
  final kunci = normalisasiNama(teks);
  if (kunci.isEmpty) return const [];
  return saran
      .where((a) {
        final na = normalisasiNama(a);
        return na.startsWith(kunci) ||
            na.split(' ').any((kata) => kata.startsWith(kunci));
      })
      .take(8)
      .toList();
}

/// Ringkasan satu alamat untuk Rekap per Alamat (Batch 20).
class RingkasanAlamat {
  const RingkasanAlamat({
    required this.kunci,
    required this.alamat,
    required this.jumlahPengunjung,
    required this.totalRp,
  });

  /// Kunci kelompok ternormalisasi (Batch 29) — bahan menyaring
  /// daftar pengunjung kelompok ini lewat pengunjungPerAlamat.
  /// Kosong ('') = kelompok tanpa alamat.
  final String kunci;

  /// Alamat tampilan (ejaan pertama yang tercatat); alamat kosong
  /// tampil sebagai '(Tanpa alamat)'.
  final String alamat;
  final int jumlahPengunjung;
  final int totalRp;
}

/// Kelompokkan semua pengunjung per ALAMAT (Batch 20 — menggantikan
/// rincian per bundel di layar Rekap; rincian per bundel tetap ada
/// di tab Bundel). Pengelompokan tidak peka huruf/spasi berlebih;
/// ejaan pertama yang menang untuk tampilan. Urut sejak Batch 29
/// (permintaan Mark): ABJAD A–Z mengikuti nama desanya; kelompok
/// tanpa alamat selalu paling akhir.
List<RingkasanAlamat> rekapPerAlamat(List<BundelTerisi> data) {
  final tampil = <String, String>{};
  final jumlah = <String, int>{};
  final total = <String, int>{};
  for (final bt in data) {
    for (final a in bt.isi) {
      final mentah = a.alamat?.trim() ?? '';
      final kunci = normalisasiNama(mentah);
      tampil.putIfAbsent(
        kunci,
        () => kunci.isEmpty ? '(Tanpa alamat)' : mentah,
      );
      jumlah[kunci] = (jumlah[kunci] ?? 0) + 1;
      total[kunci] = (total[kunci] ?? 0) + a.nominal;
    }
  }
  final hasil = [
    for (final kunci in tampil.keys)
      RingkasanAlamat(
        kunci: kunci,
        alamat: tampil[kunci]!,
        jumlahPengunjung: jumlah[kunci]!,
        totalRp: total[kunci]!,
      ),
  ];
  hasil.sort((x, y) {
    final xKosong = x.kunci.isEmpty;
    final yKosong = y.kunci.isEmpty;
    if (xKosong != yKosong) return xKosong ? 1 : -1;
    return x.kunci.compareTo(y.kunci);
  });
  return hasil;
}

/// Daftar pengunjung milik satu PENCATAT (Batch 29) — isi yang
/// tampil saat kartu Per Pencatat di Rekap diketuk. Urut bundel
/// (prefix, nomor) lalu nomor urut amplop, sama seperti buku.
List<AmplopDitemukan> pengunjungPerPencatat(
  List<BundelTerisi> data,
  String pencatatId,
) {
  final terurut = [...data]
    ..sort((a, b) {
      final bandingPrefix = a.bundel.prefix.compareTo(b.bundel.prefix);
      return bandingPrefix != 0
          ? bandingPrefix
          : a.bundel.nomor.compareTo(b.bundel.nomor);
    });
  final hasil = <AmplopDitemukan>[];
  for (final bt in terurut) {
    if (bt.bundel.pencatatId != pencatatId) continue;
    final isi = [...bt.isi]..sort((a, b) => a.urut.compareTo(b.urut));
    for (final a in isi) {
      hasil.add(
        AmplopDitemukan(
          amplop: a,
          kodeBundel: bt.bundel.kode,
          prefixPencatat: bt.bundel.prefix,
          bebas: bt.bundel.bebas,
        ),
      );
    }
  }
  return hasil;
}

/// Daftar pengunjung satu kelompok ALAMAT (Batch 29) — isi yang
/// tampil saat kartu Per Alamat di Rekap diketuk. [kunci] adalah
/// RingkasanAlamat.kunci (nama ternormalisasi; '' = tanpa alamat).
/// Urut nama A–Z; yang tanpa nama paling akhir, mengikuti urutan
/// asalnya.
List<AmplopDitemukan> pengunjungPerAlamat(
  List<BundelTerisi> data,
  String kunci,
) {
  final hasil = <AmplopDitemukan>[];
  for (final bt in data) {
    for (final a in bt.isi) {
      if (normalisasiNama(a.alamat?.trim() ?? '') != kunci) continue;
      hasil.add(
        AmplopDitemukan(
          amplop: a,
          kodeBundel: bt.bundel.kode,
          prefixPencatat: bt.bundel.prefix,
          bebas: bt.bundel.bebas,
        ),
      );
    }
  }
  bool bernama(AmplopDitemukan d) =>
      d.amplop.jenis != JenisAmplop.tanpaNama &&
      d.amplop.nama.trim().isNotEmpty;
  hasil.sort((x, y) {
    final xBernama = bernama(x);
    final yBernama = bernama(y);
    if (xBernama != yBernama) return xBernama ? -1 : 1;
    if (!xBernama) return 0;
    return normalisasiNama(
      x.amplop.nama,
    ).compareTo(normalisasiNama(y.amplop.nama));
  });
  return hasil;
}
