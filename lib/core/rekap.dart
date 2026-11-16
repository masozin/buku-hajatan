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
    final dasar =
        lama ??
        RingkasanPencatat(pencatatId: b.pencatatId, nama: '', prefix: b.prefix);
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
    required this.urut,
    required this.nama,
    required this.alamat,
    required this.nominal,
    required this.jenis,
  });

  final String kodeBundel;
  final int urut;
  final String nama;
  final String alamat;
  final int nominal;
  final JenisAmplop jenis;
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
          urut: a.urut,
          nama: a.tampilNama,
          alamat: a.alamat ?? '',
          nominal: a.nominal,
          jenis: a.jenis,
        ),
      );
    }
  }
  return baris;
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
  sb.writeln('Kode Bundel,No,Nama,Alamat,Nominal (Rp),Jenis');
  for (final b in baris) {
    sb.writeln(
      [
        selCsv(b.kodeBundel),
        b.urut.toString(),
        selCsv(b.nama),
        selCsv(b.alamat),
        b.nominal.toString(),
        selCsv(b.jenis.label),
      ].join(','),
    );
  }
  return sb.toString();
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
  });

  final Amplop amplop;
  final String kodeBundel;
  final String prefixPencatat;
}

/// Cari amplop yang namanya (atau alamatnya) mengandung [kataKunci],
/// tidak peka huruf besar/kecil. Pencarian di memori atas data yang
/// sudah dibaca — untuk skala hajatan (±1.000 amplop) ini cukup dan
/// tidak membakar kuota baca tambahan.
List<AmplopDitemukan> cariDalamData(List<BundelTerisi> data, String kataKunci) {
  final kunci = normalisasiNama(kataKunci);
  if (kunci.isEmpty) return const [];
  final hasil = <AmplopDitemukan>[];
  for (final bt in data) {
    for (final a in bt.isi) {
      final cocokNama = normalisasiNama(a.nama).contains(kunci);
      final cocokAlamat =
          a.alamat != null && normalisasiNama(a.alamat!).contains(kunci);
      if (cocokNama || cocokAlamat) {
        hasil.add(
          AmplopDitemukan(
            amplop: a,
            kodeBundel: bt.bundel.kode,
            prefixPencatat: bt.bundel.prefix,
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
