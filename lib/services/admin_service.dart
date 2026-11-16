import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/acara.dart';
import '../models/pemilik.dart';

/// Panel admin (Batch 4) — hanya untuk akun yang dokumennya ada di
/// koleksi `admin/{uid}` (dibuat sekali lewat Firebase Console;
/// lihat README). Semua baca di sini mengandalkan rules: non-admin
/// akan ditolak server, jadi panel memang tidak bisa dibobol dari
/// aplikasi yang dimodifikasi.
class AdminService {
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// True selama dokumen admin/{uid} ada (stream — panel muncul/
  /// hilang sendiri bila status admin berubah).
  Stream<bool> statusAdminStream(String uid) {
    return _db
        .collection('admin')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists);
  }

  /// Semua pemilik, urut nama (pengurutan di sisi aplikasi).
  Stream<List<Pemilik>> semuaPemilikStream() {
    return _db.collection('pemilik').snapshots().map((qs) {
      final daftar = qs.docs.map(Pemilik.fromFirestore).toList();
      daftar.sort(
        (a, b) => a.nama.toLowerCase().compareTo(b.nama.toLowerCase()),
      );
      return daftar;
    });
  }

  /// Semua acara di platform, urut tanggal terbaru dulu.
  Stream<List<Acara>> semuaAcaraStream() {
    return _db.collection('acara').snapshots().map((qs) {
      final daftar = qs.docs.map(Acara.fromFirestore).toList();
      daftar.sort((a, b) => b.tanggal.compareTo(a.tanggal));
      return daftar;
    });
  }

  /// Blokir / aktifkan kembali seorang pemilik. Hanya field
  /// `diblokir` yang disentuh — sesuai izin rules untuk admin.
  Future<void> setDiblokir(String uid, bool nilai) {
    return _db.collection('pemilik').doc(uid).update({'diblokir': nilai});
  }
}
