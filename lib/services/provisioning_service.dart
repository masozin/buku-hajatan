import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/pemilik.dart';
import 'auth_service.dart';
import 'layanan_exception.dart';

/// Provisioning oleh admin (Batch 5): membuatkan akun pemilik baru
/// TANPA mengorbankan sesi admin yang sedang masuk.
///
/// Caranya: pembuatan user dilakukan lewat instance Firebase kedua
/// ("app sekunder") — createUserWithEmailAndPassword di app utama
/// akan menimpa sesi admin. Setelah user terbuat, dokumen
/// pemilik/{uid} ditulis memakai koneksi utama (admin), lalu app
/// sekunder dibersihkan.
class ProvisioningService {
  Future<Pemilik> buatAkunPemilik({
    required String nama,
    required String email,
    required String kataSandi,
    String? noHp,
  }) async {
    final namaApp =
        'provisioning-${DateTime.now().millisecondsSinceEpoch}';
    FirebaseApp? appSekunder;
    try {
      appSekunder = await Firebase.initializeApp(
        name: namaApp,
        options: Firebase.app().options,
      );
      final authSekunder = FirebaseAuth.instanceFor(app: appSekunder);
      final kredensial = await authSekunder.createUserWithEmailAndPassword(
        email: email.trim(),
        password: kataSandi,
      );
      final userBaru = kredensial.user!;
      await userBaru.updateDisplayName(nama.trim());

      final pemilik = Pemilik(
        id: userBaru.uid,
        nama: nama.trim(),
        email: email.trim(),
        noHp: (noHp == null || noHp.trim().isEmpty) ? null : noHp.trim(),
      );
      // Tulis profil lewat koneksi utama (admin) — diizinkan rules
      // khusus untuk admin (Batch 5).
      await FirebaseFirestore.instance
          .collection('pemilik')
          .doc(userBaru.uid)
          .set(pemilik.toMap());
      await authSekunder.signOut();
      return pemilik;
    } on FirebaseAuthException catch (e) {
      throw LayananException(AuthService().pesanGalatAuth(e));
    } on FirebaseException catch (e) {
      throw LayananException(
        'Akun Auth mungkin sudah terbuat, tapi profilnya gagal '
        'disimpan (${e.code}). Coba buat lagi dengan email lain, '
        'atau periksa koleksi pemilik di Firebase Console.',
      );
    } finally {
      await appSekunder?.delete();
    }
  }
}
