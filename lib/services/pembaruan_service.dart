import 'dart:convert';
import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';

import '../core/pembaruan.dart';

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
}
