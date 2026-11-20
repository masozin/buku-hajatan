import 'package:cloud_firestore/cloud_firestore.dart';

/// Jenis amplop — keputusan Mark 2026-11-16: amplop kosong dan tanpa nama
/// TETAP dicatat dan TETAP dihitung dalam 10 isi bundel.
enum JenisAmplop {
  normal,
  kosong,
  tanpaNama,

  /// Tamu hadir (tercatat di Buku Tamu) tetapi ternyata tidak
  /// menyerahkan amplop — ditetapkan saat Mode Hitung (Batch 32),
  /// nominal selalu Rp 0. Tidak pernah dibuat langsung dari form
  /// pencatatan.
  hadir;

  static JenisAmplop dariString(String? nilai) {
    switch (nilai) {
      case 'kosong':
        return JenisAmplop.kosong;
      case 'tanpa_nama':
        return JenisAmplop.tanpaNama;
      case 'hadir':
        return JenisAmplop.hadir;
      default:
        return JenisAmplop.normal;
    }
  }

  /// Nilai yang disimpan di Firestore.
  String get nilaiSimpan {
    switch (this) {
      case JenisAmplop.normal:
        return 'normal';
      case JenisAmplop.kosong:
        return 'kosong';
      case JenisAmplop.tanpaNama:
        return 'tanpa_nama';
      case JenisAmplop.hadir:
        return 'hadir';
    }
  }

  String get label {
    switch (this) {
      case JenisAmplop.normal:
        return 'Normal';
      case JenisAmplop.kosong:
        return 'Kosong';
      case JenisAmplop.tanpaNama:
        return 'Tanpa Nama';
      case JenisAmplop.hadir:
        return 'Hadir Saja';
    }
  }
}

/// Satu amplop tamu. Dokumen:
/// `acara/{acaraId}/bundel/{bundelId}/amplop/{amplopId}`.
///
/// Dipakai penuh mulai Batch 2; didefinisikan sekarang mengikuti
/// rancangan teknis §1.
class Amplop {
  const Amplop({
    required this.id,
    required this.bundelId,
    required this.urut,
    required this.nama,
    this.alamat,
    this.dusun,
    this.rt,
    this.rw,
    this.keterangan,
    required this.nominal,
    this.jenis = JenisAmplop.normal,
    this.createdAt,
    this.createdBy,
    this.menungguSinkron = false,
    this.dihitung = true,
    this.dihitungOleh,
    this.tamuId,
  });

  final String id;
  final String bundelId;

  /// Posisi dalam bundel, 1..10.
  final int urut;
  final String nama;
  final String? alamat;

  /// Dusun/kampung asal tamu (Batch 7; Batch 36 menjadi TEKS
  /// bebas — "2", "SP 2", "RK 1", "Krajan" — karena sebutan
  /// wilayah beragam). Dokumen lama yang menyimpan ANGKA tetap
  /// terbaca sebagai teks angka yang sama; tidak ada migrasi.
  final String? dusun;

  /// Nomor RT / RW asal tamu (Batch 25 — angka, boleh kosong).
  final int? rt;
  final int? rw;

  /// Catatan bebas (Batch 7, boleh kosong).
  final String? keterangan;
  final int nominal;
  final JenisAmplop jenis;

  /// Timestamp pencatatan (server) — kolom "waktu" Batch 7.
  final DateTime? createdAt;

  /// UID pencatat yang menginput.
  final String? createdBy;

  /// Status sinkron dokumen ini (Batch 28): true bila salinan
  /// lokal belum terkirim ke server (metadata hasPendingWrites).
  /// BUKAN field Firestore — tidak ikut toMap; diisi dari
  /// metadata snapshot saat fromFirestore. Dipakai ikon sinkron
  /// di tab Pengunjung (di pencatatan status ini dibawa
  /// AmplopTercatat).
  final bool menungguSinkron;

  /// Status penghitungan nominal (Batch 32): entri dari Mode
  /// Buku Tamu lahir dengan false — tamu hanya mengisi identitas,
  /// nominalnya diisi belakangan lewat Mode Hitung (yang
  /// mengubahnya menjadi true). Dokumen lama tanpa field ini
  /// terbaca true: mereka memang sudah ternominal sejak dicatat.
  final bool dihitung;

  /// Siapa yang menghitung entri ini (Batch 33): ID pencatat
  /// atau UID pemilik yang mengisi nominalnya lewat Mode
  /// Hitung / ubah manual. Jejak audit uang — dengan banyak
  /// tablet buku tamu dan satu kotak, penghitungnya bisa
  /// berbeda dari pencatat entri.
  final String? dihitungOleh;

  /// Tautan ke Daftar Undangan (Batch 34): ID dokumen tamu
  /// undangan bila amplop ini dibuat lewat tandai-hadir atau
  /// sebagai walk-in otomatis; null untuk catatan manual biasa.
  /// Dipakai Mode Hitung & koreksi untuk menyesuaikan
  /// `acara.totalRpHadir` saat nominal amplop ini berubah.
  final String? tamuId;

  /// Nama untuk ditampilkan: amplop tanpa nama tampil "(Tanpa Nama)".
  String get tampilNama {
    if (jenis == JenisAmplop.tanpaNama || nama.trim().isEmpty) {
      return '(Tanpa Nama)';
    }
    return nama;
  }

  factory Amplop.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    required String bundelId,
  }) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Amplop(
      id: doc.id,
      bundelId: bundelId,
      urut: (data['urut'] as num?)?.toInt() ?? 0,
      nama: (data['nama'] as String?) ?? '',
      alamat: data['alamat'] as String?,
      // Batch 36: toleran angka (data lama) maupun teks.
      dusun: data['dusun']?.toString(),
      rt: (data['rt'] as num?)?.toInt(),
      rw: (data['rw'] as num?)?.toInt(),
      keterangan: data['keterangan'] as String?,
      nominal: (data['nominal'] as num?)?.toInt() ?? 0,
      jenis: JenisAmplop.dariString(data['jenis'] as String?),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      createdBy: data['createdBy'] as String?,
      menungguSinkron: doc.metadata.hasPendingWrites,
      dihitung: data['dihitung'] != false,
      dihitungOleh: data['dihitungOleh'] as String?,
      tamuId: data['tamuId'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'urut': urut,
      'nama': nama,
      'alamat': alamat,
      'dusun': dusun,
      'rt': rt,
      'rw': rw,
      'keterangan': keterangan,
      'nominal': nominal,
      'jenis': jenis.nilaiSimpan,
      'dihitung': dihitung,
      'dihitungOleh': dihitungOleh,
      'tamuId': tamuId,
      'createdAt': createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt!),
      'createdBy': createdBy,
    };
  }
}
