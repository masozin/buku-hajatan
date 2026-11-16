import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/pemilik.dart';
import 'layanan_exception.dart';

/// Urusan login — Auth Opsi A (keputusan Mark 2026-11-16):
/// - Pemilik acara: email + password, profilnya di `pemilik/{uid}`.
/// - Pencatat: login anonim (tanpa email), lalu klaim undangan acara
///   lewat kode gabung + nama + PIN (lihat AcaraService.gabungAcara).
class AuthService {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  User? get penggunaSekarang => _auth.currentUser;

  Stream<User?> get perubahanPengguna => _auth.authStateChanges();

  bool get adalahAnonim => _auth.currentUser?.isAnonymous ?? false;

  /// Daftar sebagai pemilik acara baru.
  Future<Pemilik> daftarPemilik({
    required String email,
    required String kataSandi,
    required String nama,
    String? noHp,
  }) async {
    try {
      final kredensial = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: kataSandi,
      );
      final user = kredensial.user!;
      await user.updateDisplayName(nama.trim());
      final pemilik = Pemilik(
        id: user.uid,
        nama: nama.trim(),
        email: email.trim(),
        noHp: (noHp == null || noHp.trim().isEmpty) ? null : noHp.trim(),
      );
      await _db.collection('pemilik').doc(user.uid).set(pemilik.toMap());
      return pemilik;
    } on FirebaseAuthException catch (e) {
      throw LayananException(pesanGalatAuth(e));
    }
  }

  /// Masuk sebagai pemilik acara.
  Future<User> masukPemilik({
    required String email,
    required String kataSandi,
  }) async {
    try {
      // Bila HP ini sedang dipakai sesi anonim pencatat, keluar dulu
      // supaya tidak ada dua identitas tercampur.
      final sekarang = _auth.currentUser;
      if (sekarang != null && sekarang.isAnonymous) {
        await _auth.signOut();
      }
      final kredensial = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: kataSandi,
      );
      await _lengkapiEmailProfil(kredensial.user!);
      return kredensial.user!;
    } on FirebaseAuthException catch (e) {
      throw LayananException(pesanGalatAuth(e));
    }
  }

  /// Masuk anonim untuk pencatat. Mengembalikan user yang aktif
  /// (bila sudah ada sesi, sesi itu dipakai kembali).
  Future<User> masukAnonim() async {
    try {
      final sekarang = _auth.currentUser;
      if (sekarang != null) return sekarang;
      final kredensial = await _auth.signInAnonymously();
      return kredensial.user!;
    } on FirebaseAuthException catch (e) {
      throw LayananException(pesanGalatAuth(e));
    }
  }

  Future<Pemilik?> ambilProfilPemilik(String uid) async {
    final doc = await _db.collection('pemilik').doc(uid).get();
    if (!doc.exists) return null;
    return Pemilik.fromFirestore(doc);
  }

  /// Profil pemilik sebagai stream — dipakai gerbang aplikasi untuk
  /// memeriksa status blokir (Batch 4) secara realtime.
  Stream<Pemilik?> profilPemilikStream(String uid) {
    return _db.collection('pemilik').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Pemilik.fromFirestore(doc);
    });
  }

  /// Akun lama (sebelum Batch 4) belum menyimpan email di dokumen
  /// pemilik — lengkapi sekali saat masuk. Kegagalan di sini TIDAK
  /// boleh menggagalkan proses masuk.
  Future<void> _lengkapiEmailProfil(User user) async {
    try {
      if (user.email == null) return;
      final ref = _db.collection('pemilik').doc(user.uid);
      final doc = await ref.get();
      if (doc.exists && doc.data()?['email'] == null) {
        await ref.update({'email': user.email});
      }
    } catch (_) {
      // Abaikan: email profil bisa dilengkapi pada masuk berikutnya.
    }
  }

  Future<void> keluar() => _auth.signOut();

  /// Kirim email atur ulang kata sandi (Batch 6). Dipakai admin dari
  /// Detail Pemilik dan pemilik sendiri dari layar Masuk ("Lupa kata
  /// sandi?"). Firebase yang mengirim emailnya; pemilik mengikuti
  /// tautan di email untuk membuat sandi baru.
  Future<void> kirimResetSandi(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw LayananException(pesanGalatAuth(e));
    }
  }

  /// Terjemahkan kode galat Firebase Auth ke pesan Indonesia yang jelas.
  String pesanGalatAuth(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Alamat email tidak valid.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email atau kata sandi salah.';
      case 'email-already-in-use':
        return 'Email ini sudah terdaftar. Silakan masuk saja.';
      case 'weak-password':
        return 'Kata sandi terlalu lemah (minimal 6 karakter).';
      case 'network-request-failed':
        return 'Tidak ada jaringan. Periksa koneksi internet HP.';
      case 'operation-not-allowed':
        return 'Metode masuk ini belum diaktifkan di Firebase Console '
            '(Authentication > Sign-in method).';
      case 'too-many-requests':
        return 'Terlalu banyak percobaan. Tunggu sebentar lalu coba lagi.';
      default:
        return 'Gagal masuk (${e.code}). Coba lagi.';
    }
  }
}
