import 'package:cloud_firestore/cloud_firestore.dart';

/// Status acara: masih berjalan atau sudah ditutup pemiliknya.
enum StatusAcara {
  aktif,
  selesai;

  static StatusAcara dariString(String? nilai) {
    return nilai == 'selesai' ? StatusAcara.selesai : StatusAcara.aktif;
  }

  String get label => this == StatusAcara.aktif ? 'Aktif' : 'Selesai';
}

/// Satu hajatan. Dokumen: `acara/{acaraId}`.
///
/// Field [totalAmplop], [totalRp], [totalBundel] adalah AGREGAT yang
/// diperbarui dalam batch tulis yang sama dengan tiap amplop (Batch 2),
/// supaya rekap realtime cukup membaca dokumen ini + dokumen bundel —
/// tidak membaca semua amplop (hemat kuota Spark, lihat rancangan §3).
///
/// PIN gabung TIDAK disimpan di sini; PIN ada di `kodeAcara/{kodeGabung}`.
class Acara {
  const Acara({
    required this.id,
    required this.pemilikId,
    required this.namaAcara,
    required this.tuanRumah,
    required this.jenis,
    required this.tanggal,
    this.lokasi,
    this.status = StatusAcara.aktif,
    required this.kodeGabung,
    this.totalAmplop = 0,
    this.totalRp = 0,
    this.totalBundel = 0,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String pemilikId;
  final String namaAcara;
  final String tuanRumah;

  /// Jenis hajatan, teks bebas dari pilihan: Pernikahan, Khitanan,
  /// Tasyakuran, Pengajian, Lainnya.
  final String jenis;
  final DateTime tanggal;
  final String? lokasi;
  final StatusAcara status;

  /// Kode 6 karakter untuk pencatat bergabung (pasangannya: PIN gabung).
  final String kodeGabung;

  final int totalAmplop;
  final int totalRp;
  final int totalBundel;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get sudahSelesai => status == StatusAcara.selesai;

  factory Acara.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Acara.dariMap(doc.id, data);
  }

  factory Acara.dariMap(String id, Map<String, dynamic> data) {
    return Acara(
      id: id,
      pemilikId: (data['pemilikId'] as String?) ?? '',
      namaAcara: (data['namaAcara'] as String?) ?? '',
      tuanRumah: (data['tuanRumah'] as String?) ?? '',
      jenis: (data['jenis'] as String?) ?? '',
      tanggal: (data['tanggal'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lokasi: data['lokasi'] as String?,
      status: StatusAcara.dariString(data['status'] as String?),
      kodeGabung: (data['kodeGabung'] as String?) ?? '',
      totalAmplop: (data['totalAmplop'] as num?)?.toInt() ?? 0,
      totalRp: (data['totalRp'] as num?)?.toInt() ?? 0,
      totalBundel: (data['totalBundel'] as num?)?.toInt() ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'pemilikId': pemilikId,
      'namaAcara': namaAcara,
      'tuanRumah': tuanRumah,
      'jenis': jenis,
      'tanggal': Timestamp.fromDate(tanggal),
      'lokasi': lokasi,
      'status': status.name,
      'kodeGabung': kodeGabung,
      'totalAmplop': totalAmplop,
      'totalRp': totalRp,
      'totalBundel': totalBundel,
      'createdAt': createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt!),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
