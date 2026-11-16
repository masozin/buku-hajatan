import 'package:cloud_firestore/cloud_firestore.dart';

/// Pemilik acara — pengguna yang mendaftar dengan email + password
/// (Auth Opsi A). Dokumen: `pemilik/{uid}`.
///
/// Field `diblokir` (Batch 4, panel admin) TIDAK ditulis lewat
/// [toMap]: hanya admin yang boleh mengubahnya (diatur di rules),
/// lewat update satu field. Dokumen lama tanpa field ini terbaca
/// sebagai tidak diblokir.
class Pemilik {
  const Pemilik({
    required this.id,
    required this.nama,
    this.email,
    this.noHp,
    this.diblokir = false,
    this.createdAt,
  });

  final String id;
  final String nama;
  final String? email;
  final String? noHp;
  final bool diblokir;
  final DateTime? createdAt;

  factory Pemilik.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Pemilik(
      id: doc.id,
      nama: (data['nama'] as String?) ?? '',
      email: data['email'] as String?,
      noHp: data['noHp'] as String?,
      diblokir: (data['diblokir'] as bool?) ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'nama': nama,
      'email': email,
      'noHp': noHp,
      'createdAt': createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt!),
    };
  }
}
