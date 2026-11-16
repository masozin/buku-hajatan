import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'services/acara_service.dart';
import 'services/admin_service.dart';
import 'services/auth_service.dart';
import 'services/ekspor_service.dart';
import 'services/pencatatan_service.dart';
import 'services/provisioning_service.dart';
import 'services/rekap_service.dart';

/// Inisialisasi Firebase. Gagal (error) berarti google-services.json
/// belum terpasang / Firebase belum disiapkan — aplikasi menampilkan
/// layar petunjuk, BUKAN crash (lihat screens/belum_konfigurasi.dart).
final inisialisasiFirebaseProvider = FutureProvider<void>((ref) async {
  await Firebase.initializeApp();
});

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final acaraServiceProvider = Provider<AcaraService>((ref) => AcaraService());

final pencatatanServiceProvider = Provider<PencatatanService>(
  (ref) => PencatatanService(),
);

final rekapServiceProvider = Provider<RekapService>((ref) => RekapService());

final eksporServiceProvider = Provider<EksporService>((ref) => EksporService());

final adminServiceProvider = Provider<AdminService>((ref) => AdminService());

final provisioningServiceProvider = Provider<ProvisioningService>(
  (ref) => ProvisioningService(),
);

/// True bila pengguna yang sedang masuk adalah admin platform
/// (dokumen `admin/{uid}` ada). Sesi anonim tidak pernah admin.
final statusAdminProvider = StreamProvider<bool>((ref) {
  final pengguna = ref.watch(statusPenggunaProvider).valueOrNull;
  if (pengguna == null || pengguna.isAnonymous) {
    return Stream<bool>.value(false);
  }
  return ref.watch(adminServiceProvider).statusAdminStream(pengguna.uid);
});

/// Pengguna yang sedang masuk (null = belum masuk).
/// Hanya boleh dibaca SETELAH inisialisasi Firebase berhasil.
final statusPenggunaProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).perubahanPengguna;
});
