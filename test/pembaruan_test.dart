import 'package:buku_hajatan/core/pembaruan.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> jsonRilis({
  String tag = 'v1.1.0+2',
  String isi = 'Perbaikan dan fitur baru.',
  bool denganApk = true,
}) {
  return <String, dynamic>{
    'tag_name': tag,
    'html_url': 'https://github.com/masozin/buku-hajatan/releases/tag/$tag',
    'body': isi,
    'assets': [
      if (denganApk)
        <String, dynamic>{
          'name': 'buku-hajatan-v1.1.0.apk',
          'browser_download_url':
              'https://github.com/masozin/buku-hajatan/releases/download/$tag/buku-hajatan-v1.1.0.apk',
        },
      <String, dynamic>{
        'name': 'catatan.txt',
        'browser_download_url': 'https://contoh.invalid/catatan.txt',
      },
    ],
  };
}

void main() {
  group('uraiRilisGithub', () {
    test('mengurai tag berkode, memilih aset .apk, membaca halaman', () {
      final rilis = uraiRilisGithub(jsonRilis())!;
      expect(rilis.versiNama, '1.1.0');
      expect(rilis.kodeVersi, 2);
      expect(rilis.urlApk, contains('.apk'));
      expect(rilis.urlUnduh, rilis.urlApk);
      expect(rilis.wajib, isFalse);
    });

    test('tag tanpa kode dan tanpa aset apk: urlUnduh = halaman', () {
      final rilis = uraiRilisGithub(
        jsonRilis(tag: 'v1.2.0', denganApk: false),
      )!;
      expect(rilis.versiNama, '1.2.0');
      expect(rilis.kodeVersi, isNull);
      expect(rilis.urlApk, isNull);
      expect(rilis.urlUnduh, rilis.urlHalaman);
    });

    test('penanda [WAJIB] di catatan membuat rilis wajib', () {
      final rilis = uraiRilisGithub(jsonRilis(isi: '[WAJIB] Perbaikan penting.'))!;
      expect(rilis.wajib, isTrue);
    });

    test('tag kosong menghasilkan null', () {
      expect(uraiRilisGithub(jsonRilis(tag: '')), isNull);
      expect(uraiRilisGithub(const {}), isNull);
    });
  });

  group('bandingNamaVersi', () {
    test('membandingkan per bagian angka', () {
      expect(bandingNamaVersi('1.1.0', '1.0.9'), greaterThan(0));
      expect(bandingNamaVersi('1.0.9', '1.1.0'), lessThan(0));
      expect(bandingNamaVersi('1.1.0', '1.1.0'), 0);
      expect(bandingNamaVersi('1.1', '1.1.0'), 0);
      expect(bandingNamaVersi('2.0.0', '1.9.9'), greaterThan(0));
    });
  });

  group('rilisLebihBaru', () {
    test('kode versi menentukan bila ada', () {
      final rilis = uraiRilisGithub(jsonRilis(tag: 'v1.0.0+3'))!;
      expect(
        rilisLebihBaru(rilis: rilis, versiTerpasang: '1.1.0', kodeTerpasang: 2),
        isTrue,
      );
      expect(
        rilisLebihBaru(rilis: rilis, versiTerpasang: '1.0.0', kodeTerpasang: 3),
        isFalse,
      );
    });

    test('tanpa kode: nama versi menentukan', () {
      final rilis = uraiRilisGithub(jsonRilis(tag: 'v1.2.0'))!;
      expect(
        rilisLebihBaru(rilis: rilis, versiTerpasang: '1.1.0', kodeTerpasang: 2),
        isTrue,
      );
      expect(
        rilisLebihBaru(rilis: rilis, versiTerpasang: '1.2.0', kodeTerpasang: 9),
        isFalse,
      );
    });
  });

  group('formatUkuran', () {
    test('KB tanpa desimal, MB satu desimal berkoma', () {
      expect(formatUkuran(512 * 1024), '512 KB');
      expect(formatUkuran(2 * 1024 * 1024), '2,0 MB');
      expect(formatUkuran(15 * 1024 * 1024 + 512 * 1024), '15,5 MB');
    });
  });
}
