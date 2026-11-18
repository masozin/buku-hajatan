import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/pembaruan.dart';
import 'layanan_exception.dart';

/// Pemeriksa pembaruan aplikasi (Batch 21): bertanya ke GitHub
/// Releases repo buku-hajatan (publik, tanpa kunci API) apakah ada
/// rilis lebih baru daripada versi terpasang.
///
/// Semua kegagalan — offline, batas kuota GitHub, bentuk respons
/// tak terduga — dijawab null: urusan pembaruan TIDAK PERNAH boleh
/// mengganggu pemakaian aplikasi.
class PembaruanService {
  static const String _urlRilisTerbaru =
      'https://api.github.com/repos/masozin/buku-hajatan/releases/latest';

  /// Jembatan ke MainActivity untuk membuka pemasang paket
  /// Android (Batch 24).
  static const _saluranPasang = MethodChannel('bukuhajatan/pembaruan');

  /// Info rilis bila ada yang lebih baru; null bila tidak ada
  /// pembaruan atau pemeriksaan tidak bisa dilakukan.
  Future<InfoRilis?> periksaPembaruan() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final kodeTerpasang = int.tryParse(info.buildNumber) ?? 0;
      final klien = HttpClient()
        ..connectionTimeout = const Duration(seconds: 10);
      try {
        final permintaan = await klien.getUrl(Uri.parse(_urlRilisTerbaru));
        permintaan.headers.set(
          HttpHeaders.userAgentHeader,
          'BukuHajatan/${info.version} (pemeriksa pembaruan)',
        );
        permintaan.headers.set(
          HttpHeaders.acceptHeader,
          'application/vnd.github+json',
        );
        final respons = await permintaan.close();
        if (respons.statusCode != 200) return null;
        final teks = await respons.transform(utf8.decoder).join();
        final json = jsonDecode(teks);
        if (json is! Map<String, dynamic>) return null;
        final rilis = uraiRilisGithub(json);
        if (rilis == null) return null;
        return rilisLebihBaru(
              rilis: rilis,
              versiTerpasang: info.version,
              kodeTerpasang: kodeTerpasang,
            )
            ? rilis
            : null;
      } finally {
        klien.close(force: true);
      }
    } catch (_) {
      return null;
    }
  }

  /// Unduh APK rilis DI DALAM aplikasi (Batch 24, permintaan
  /// Mark: tanpa beralih ke browser) ke folder cache aplikasi,
  /// sambil melaporkan progres lewat [onProgres] (bita diterima
  /// dan total bila server memberitahunya). Mengembalikan berkas
  /// hasil unduhan; melempar pengecualian bila gagal — pemanggil
  /// menampilkan pesan dan menawarkan jalur browser sebagai
  /// cadangan.
  Future<File> unduhApk(
    String url, {
    required void Function(int diterima, int? total) onProgres,
  }) async {
    final klien = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15)
      ..idleTimeout = const Duration(seconds: 20);
    try {
      final permintaan = await klien.getUrl(Uri.parse(url));
      permintaan.headers.set(
        HttpHeaders.userAgentHeader,
        'BukuHajatan (pengunduh pembaruan)',
      );
      final respons = await permintaan.close();
      if (respons.statusCode != 200) {
        throw LayananException(
          'Unduhan gagal (kode ${respons.statusCode}). Periksa '
          'koneksi lalu coba lagi.',
        );
      }
      final berkas = File(
        '${Directory.systemTemp.path}/pembaruan-buku-hajatan.apk',
      );
      final tulis = berkas.openWrite();
      var diterima = 0;
      final total =
          respons.contentLength > 0 ? respons.contentLength : null;
      await for (final potong in respons) {
        tulis.add(potong);
        diterima += potong.length;
        onProgres(diterima, total);
      }
      await tulis.close();
      return berkas;
    } finally {
      klien.close(force: true);
    }
  }

  /// Minta Android membuka pemasang paket untuk APK yang sudah
  /// diunduh (Batch 24): MethodChannel ke MainActivity, yang
  /// membagikan berkas lewat FileProvider dan menyalakan Intent
  /// ACTION_VIEW.
  ///
  /// Mengembalikan null bila pemasang berhasil dibuka; bila
  /// gagal, mengembalikan RINCIAN sebabnya (Batch 27 — sebelumnya
  /// sebab asli ditelan dan dialog hanya menampilkan pesan umum
  /// "tidak bisa dibuka", sehingga kegagalan tidak terlacak).
  Future<String?> pasangApk(File berkas) async {
    if (!await berkas.exists()) {
      return 'berkas hasil unduhan tidak ditemukan';
    }
    try {
      final hasil = await _saluranPasang.invokeMethod<bool>(
        'pasangApk',
        {'path': berkas.path},
      );
      return hasil == true ? null : 'pemasang menolak dibuka';
    } on PlatformException catch (e) {
      return '${e.code}: ${e.message ?? 'tanpa keterangan'}';
    } catch (e) {
      return '$e';
    }
  }
}
