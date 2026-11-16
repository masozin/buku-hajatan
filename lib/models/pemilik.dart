import 'package:cloud_firestore/cloud_firestore.dart';

/// Pemilik acara — pengguna yang mendaftar dengan email + password
/// (Auth Opsi A). Dokumen: `pemilik/{uid}`.
class Pemilik {
  const Pemilik({
    required this.id,
    required this.nama,
    this.noHp,
    this.createdAt,
  });

  final String id;
  final String nama;
  final String? noHp;
  final DateTime? createdAt;

  factory Pemilik.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Pemilik(
      id: doc.id,
      nama: (data['nama'] as String?) ?? '',
      noHp: data['noHp'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'nama': nama,
      'noHp': noHp,
      'createdAt': createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt!),
    };
  }
}
