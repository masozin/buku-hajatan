import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Penanda Mode Buku Tamu sedang tampil. Selama true, gerbang
/// kunci TIDAK mengunci: tablet buku tamu memang dipegang
/// tamu bergantian, dan mode itu sudah punya gerbangnya
/// sendiri (keluar wajib PIN pencatat). Diatur oleh
/// BukuTamuScreen saat masuk/keluar mode.
final penandaBukuTamuAktif = ValueNotifier<bool>(false);

/// Kunci aplikasi sidik jari (Batch 38, permintaan Mark):
/// gembok di depan sesi yang SUDAH masuk — bukan pengganti
/// login. Tujuannya: HP yang terpegang orang lain tidak bisa
/// membuka isi aplikasi, sementara pemilik/petugas yang sah
/// masuk lagi cukup dengan sidik jari (atau PIN/pola kunci
/// layar HP sebagai cadangan), tanpa mengetik ulang
/// email/kode/nama/PIN aplikasi.
///
/// Pilihan aktif/tidak disimpan PER PERANGKAT
/// (SharedPreferences) — HP suami dan istri boleh berbeda
/// keputusannya. Berlaku untuk semua peran yang sedang masuk
/// (pemilik, admin, pencatat).
class KunciAplikasiService {
  static const _kunciPref = 'kunci_sidk_jari_aktif';

  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> aktif() async {
    final pref = await SharedPreferences.getInstance();
    return pref.getBool(_kunciPref) ?? false;
  }

  Future<void> aturAktif(bool nilai) async {
    final pref = await SharedPreferences.getInstance();
    await pref.setBool(_kunciPref, nilai);
  }

  /// True bila perangkat punya cara membuka kunci biometrik
  /// ATAU kunci layar (PIN/pola/kata sandi perangkat).
  Future<bool> perangkatMendukung() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  /// Tampilkan dialog autentikasi perangkat. biometricOnly
  /// false: bila sidik jari gagal/tidak ada, Android otomatis
  /// menawarkan PIN/pola kunci layar HP. True = terverifikasi.
  Future<bool> autentikasi() async {
    try {
      return await _auth.authenticate(
        localizedReason:
            'Buka Buku Hajatan dengan sidik jari atau kunci layar HP.',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
    } on PlatformException {
      return false;
    }
  }
}
