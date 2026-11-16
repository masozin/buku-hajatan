import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'services/acara_service.dart';
import 'services/auth_service.dart';

/// Inisialisasi Firebase. Gagal (error) berarti google-services.json
/// belum terpasang / Firebase belum disiapkan — aplikasi menampilkan
/// layar petunjuk, BUKAN crash (lihat screens/belum_konfigurasi.dart).
final inisialisasiFirebaseProvider = FutureProvider<void>((ref) async {
  await Firebase.initializeApp();
});

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final acaraServiceProvider = Provider<AcaraService>((ref) => AcaraService());

/// Pengguna yang sedang masuk (null = belum masuk).
/// Hanya boleh dibaca SETELAH inisialisasi Firebase berhasil.
final statusPenggunaProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).perubahanPengguna;
});
