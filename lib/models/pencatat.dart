import 'package:cloud_firestore/cloud_firestore.dart';

/// Pencatat yang SUDAH bergabung ke acara.
///
/// Sejak Batch 10 identitas pencatat adalah catatan TETAP: dokumen
/// `acara/{acaraId}/pencatat/{idTetap}` — ID-nya bukan lagi UID
/// perangkat (untuk klaim baru = ID undangannya). Yang mengikat
/// pencatat ke perangkat adalah KUNCI SESI: field [uidAktif] berisi
/// UID anonim perangkat yang sedang memegang sesi, ditambah dokumen
/// pendamping `pencatatSesi/{uid}`. Masuk dari perangkat lain
/// memakai nama + PIN pribadi (di dokumen undangan); sesi hanya
/// boleh dipegang SATU perangkat — perangkat kedua ditolak sampai
/// perangkat pertama keluar atau pemilik mereset sesinya.
///
/// Data lama (Batch 1–9) ber-ID = UID dan ber-field `userId`;
/// [uidAktif] dibaca dari `userId` sebagai cadangan agar sesi lama
/// yang belum keluar tetap dikenali.
class Pencatat {
  const Pencatat({
    required this.id,
    required this.acaraId,
    required this.nama,
    required this.prefix,
    this.undanganId,
    this.uidAktif,
    this.pinPribadi,
    this.nomorBundelTerakhir = 0,
    this.aktif = true,
    this.createdAt,
  });

  final String id;
  final String acaraId;
  final String nama;
  final String prefix;

  /// ID dokumen undangan asal pencatat ini (Batch 10).
  final String? undanganId;

  /// UID anonim perangkat yang sedang memegang sesi pencatat ini;
  /// null = tidak ada perangkat yang sedang masuk.
  final String? uidAktif;

  /// Salinan PIN pribadi (sumber resminya di dokumen undangan) —
  /// untuk ditampilkan pemilik di daftar pencatat.
  final String? pinPribadi;

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
      nama: (data['nama'] as String?) ?? '',
      prefix: (data['prefix'] as String?) ?? '',
      undanganId: data['undanganId'] as String?,
      uidAktif:
          (data['uidAktif'] as String?) ?? (data['userId'] as String?),
      pinPribadi: data['pinPribadi'] as String?,
      nomorBundelTerakhir: (data['nomorBundelTerakhir'] as num?)?.toInt() ?? 0,
      aktif: (data['aktif'] as bool?) ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      // userId dipertahankan (= uidAktif) untuk kompatibilitas
      // indeks & data lama; sumber sesi resmi adalah uidAktif.
      'userId': uidAktif,
      'uidAktif': uidAktif,
      'undanganId': undanganId,
      'pinPribadi': pinPribadi,
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
    this.pinPribadi,
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

  /// PIN pribadi pencatat ini (Batch 10): kata sandi pribadinya
  /// untuk masuk dari perangkat mana pun, dibuatkan/diatur pemilik.
  /// Sumber resmi PIN — dokumen pencatat hanya menyimpan salinan.
  final String? pinPribadi;
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
      pinPribadi: data['pinPribadi'] as String?,
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
      'pinPribadi': pinPribadi,
      'status': sudahDiklaim ? 'diklaim' : 'menunggu',
      'claimedBy': claimedBy,
      'createdAt': createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt!),
    };
  }
}
