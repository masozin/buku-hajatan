import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/kode.dart';

/// Status bundel: masih diisi, atau sudah penuh (10 amplop) & masuk kotak.
enum StatusBundel {
  terbuka,
  penuh;

  static StatusBundel dariString(String? nilai) {
    return nilai == 'penuh' ? StatusBundel.penuh : StatusBundel.terbuka;
  }
}

/// Bundel = sekumpulan maks. 10 amplop milik satu pencatat.
/// Dokumen: `acara/{acaraId}/bundel/{bundelId}`.
///
/// Model ini dipakai penuh mulai Batch 2 (pencatatan); didefinisikan
/// sekarang supaya struktur data Firestore sesuai rancangan sejak awal.
class Bundel {
  const Bundel({
    required this.id,
    required this.acaraId,
    required this.pencatatId,
    required this.prefix,
    required this.nomor,
    this.status = StatusBundel.terbuka,
    this.jumlahAmplop = 0,
    this.totalRp = 0,
    this.jumlahKosong = 0,
    this.jumlahTanpaNama = 0,
    this.createdAt,
    this.ditutupAt,
  });

  final String id;
  final String acaraId;

  /// UID pencatat pemilik bundel (= ID dokumen pencatat).
  final String pencatatId;
  final String prefix;
  final int nomor;
  final StatusBundel status;
  final int jumlahAmplop;
  final int totalRp;
  final int jumlahKosong;
  final int jumlahTanpaNama;
  final DateTime? createdAt;
  final DateTime? ditutupAt;

  /// Kode bundel seperti di buku manual, mis. `A003`.
  String get kode => buatKodeBundel(prefix, nomor);

  bool get sudahPenuh => status == StatusBundel.penuh || jumlahAmplop >= 10;

  factory Bundel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc, {
    required String acaraId,
  }) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Bundel(
      id: doc.id,
      acaraId: acaraId,
      pencatatId: (data['pencatatId'] as String?) ?? '',
      prefix: (data['prefix'] as String?) ?? '',
      nomor: (data['nomor'] as num?)?.toInt() ?? 0,
      status: StatusBundel.dariString(data['status'] as String?),
      jumlahAmplop: (data['jumlahAmplop'] as num?)?.toInt() ?? 0,
      totalRp: (data['totalRp'] as num?)?.toInt() ?? 0,
      jumlahKosong: (data['jumlahKosong'] as num?)?.toInt() ?? 0,
      jumlahTanpaNama: (data['jumlahTanpaNama'] as num?)?.toInt() ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      ditutupAt: (data['ditutupAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'pencatatId': pencatatId,
      'prefix': prefix,
      'nomor': nomor,
      'kode': kode,
      'status': status.name,
      'jumlahAmplop': jumlahAmplop,
      'totalRp': totalRp,
      'jumlahKosong': jumlahKosong,
      'jumlahTanpaNama': jumlahTanpaNama,
      'createdAt': createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt!),
      'ditutupAt': ditutupAt == null
          ? null
          : Timestamp.fromDate(ditutupAt!),
    };
  }
}
