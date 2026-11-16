import 'package:cloud_firestore/cloud_firestore.dart';

/// Pencatat yang SUDAH bergabung ke acara (Auth Opsi A: login anonim,
/// klaim undangan dengan kode gabung + nama + PIN).
///
/// Dokumen: `acara/{acaraId}/pencatat/{uid}` — ID dokumen = UID Firebase
/// si pencatat, supaya Security Rules bisa memeriksa keanggotaan dengan
/// `exists(...)` tanpa query. Field [userId] diduplikasi di dalam dokumen
/// agar bisa dicari lewat collectionGroup query ("acara yang saya ikuti").
class Pencatat {
  const Pencatat({
    required this.id,
    required this.acaraId,
    required this.userId,
    required this.nama,
    required this.prefix,
    this.nomorBundelTerakhir = 0,
    this.aktif = true,
    this.createdAt,
  });

  final String id;
  final String acaraId;
  final String userId;
  final String nama;
  final String prefix;

  /// Nomor bundel terakhir yang dibuka pencatat ini di acara ini.
  /// Bundel yang sedang aktif bernomor [nomorBundelTerakhir] (bila > 0);
  /// penomoran lanjut dari sini bila pencatat ganti HP (rancangan §2).
  final int nomorBundelTerakhir;
  final bool aktif;
  final DateTime? createdAt;

  factory Pencatat.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    required String acaraId,
  }) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Pencatat(
      id: doc.id,
      acaraId: acaraId,
      userId: (data['userId'] as String?) ?? doc.id,
      nama: (data['nama'] as String?) ?? '',
      prefix: (data['prefix'] as String?) ?? '',
      nomorBundelTerakhir:
          (data['nomorBundelTerakhir'] as num?)?.toInt() ?? 0,
      aktif: (data['aktif'] as bool?) ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'userId': userId,
      'nama': nama,
      'prefix': prefix,
      'nomorBundelTerakhir': nomorBundelTerakhir,
      'aktif': aktif,
      'createdAt': createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt!),
    };
  }
}

/// Undangan pencatat yang dibuat pemilik SEBELUM hari-H: nama + prefix
/// sudah ditentukan, tinggal diklaim oleh orangnya saat bergabung.
///
/// Dokumen: `acara/{acaraId}/undanganPencatat/{undanganId}`.
class UndanganPencatat {
  const UndanganPencatat({
    required this.id,
    required this.acaraId,
    required this.nama,
    required this.namaNormalisasi,
    required this.prefix,
    this.sudahDiklaim = false,
    this.claimedBy,
    this.createdAt,
  });

  final String id;
  final String acaraId;
  final String nama;

  /// Nama versi normalisasi (huruf kecil) untuk pencocokan saat klaim.
  final String namaNormalisasi;
  final String prefix;
  final bool sudahDiklaim;
  final String? claimedBy;
  final DateTime? createdAt;

  factory UndanganPencatat.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    required String acaraId,
  }) {
    final data = doc.data() ?? const <String, dynamic>{};
    return UndanganPencatat(
      id: doc.id,
      acaraId: acaraId,
      nama: (data['nama'] as String?) ?? '',
      namaNormalisasi: (data['namaNormalisasi'] as String?) ?? '',
      prefix: (data['prefix'] as String?) ?? '',
      sudahDiklaim: (data['status'] as String?) == 'diklaim',
      claimedBy: data['claimedBy'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'nama': nama,
      'namaNormalisasi': namaNormalisasi,
      'prefix': prefix,
      'status': sudahDiklaim ? 'diklaim' : 'menunggu',
      'claimedBy': claimedBy,
      'createdAt': createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt!),
    };
  }
}
