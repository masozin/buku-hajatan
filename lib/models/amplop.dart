import 'package:cloud_firestore/cloud_firestore.dart';

/// Jenis amplop — keputusan Mark 2026-11-16: amplop kosong dan tanpa nama
/// TETAP dicatat dan TETAP dihitung dalam 10 isi bundel.
enum JenisAmplop {
  normal,
  kosong,
  tanpaNama;

  static JenisAmplop dariString(String? nilai) {
    switch (nilai) {
      case 'kosong':
        return JenisAmplop.kosong;
      case 'tanpa_nama':
        return JenisAmplop.tanpaNama;
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
    this.keterangan,
    required this.nominal,
    this.jenis = JenisAmplop.normal,
    this.createdAt,
    this.createdBy,
  });

  final String id;
  final String bundelId;

  /// Posisi dalam bundel, 1..10.
  final int urut;
  final String nama;
  final String? alamat;

  /// Nomor dusun asal tamu (Batch 7 — isinya angka, boleh kosong).
  final int? dusun;

  /// Catatan bebas (Batch 7, boleh kosong).
  final String? keterangan;
  final int nominal;
  final JenisAmplop jenis;

  /// Timestamp pencatatan (server) — kolom "waktu" Batch 7.
  final DateTime? createdAt;

  /// UID pencatat yang menginput.
  final String? createdBy;

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
      dusun: (data['dusun'] as num?)?.toInt(),
      keterangan: data['keterangan'] as String?,
      nominal: (data['nominal'] as num?)?.toInt() ?? 0,
      jenis: JenisAmplop.dariString(data['jenis'] as String?),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      createdBy: data['createdBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'urut': urut,
      'nama': nama,
      'alamat': alamat,
      'dusun': dusun,
      'keterangan': keterangan,
      'nominal': nominal,
      'jenis': jenis.nilaiSimpan,
      'createdAt': createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt!),
      'createdBy': createdBy,
    };
  }
}
