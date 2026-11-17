import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/pembaruan.dart';
import '../providers.dart';

/// Pembungkus akar aplikasi (Batch 21): sekali saat aplikasi
/// dibuka, periksa apakah ada rilis lebih baru di GitHub Releases;
/// bila ada, tawarkan unduh lewat dialog. Pemeriksaan yang gagal
/// (offline dsb.) diam saja — tidak pernah mengganggu pemakaian.
///
/// Rilis berpenanda [WAJIB] di catatan rilisnya tidak bisa
/// ditunda: dialognya tanpa tombol "Nanti Saja" dan tidak bisa
/// ditutup dengan ketuk di luar atau tombol kembali.
class PemeriksaPembaruan extends ConsumerStatefulWidget {
  const PemeriksaPembaruan({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PemeriksaPembaruan> createState() =>
      _PemeriksaPembaruanState();
}

class _PemeriksaPembaruanState extends ConsumerState<PemeriksaPembaruan> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _periksa());
  }

  Future<void> _periksa() async {
    // Beri waktu gerbang masuk menetap dulu — dialog pembaruan
    // tidak perlu berebut tampil di detik pertama.
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    final rilis = await ref
        .read(pembaruanServiceProvider)
        .periksaPembaruan();
    if (rilis == null || !mounted) return;
    await _tampilkanDialog(rilis);
  }

  Future<void> _tampilkanDialog(InfoRilis rilis) async {
    final catatanBersih = rilis.catatan.replaceAll('[WAJIB]', '').trim();
    await showDialog<void>(
      context: context,
      barrierDismissible: !rilis.wajib,
      builder: (konteksDialog) => PopScope(
        canPop: !rilis.wajib,
        child: AlertDialog(
          title: Text(
            rilis.wajib
                ? 'Pembaruan Wajib Tersedia'
                : 'Ada Pembaruan Aplikasi',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Versi ${rilis.versiNama} sudah tersedia. Unduh '
                  'dan pasang untuk mendapatkan perbaikan & fitur '
                  'terbaru — data dan login kamu tetap aman.',
                ),
                if (catatanBersih.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    catatanBersih,
                    style: Theme.of(konteksDialog).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            if (!rilis.wajib)
              TextButton(
                onPressed: () => Navigator.of(konteksDialog).pop(),
                child: const Text('Nanti Saja'),
              ),
            FilledButton(
              onPressed: () async {
                final terbuka = await launchUrl(
                  Uri.parse(rilis.urlUnduh),
                  mode: LaunchMode.externalApplication,
                );
                if (!terbuka) {
                  if (konteksDialog.mounted) {
                    ScaffoldMessenger.of(konteksDialog).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Tidak bisa membuka tautan unduhan. '
                          'Coba lagi nanti.',
                        ),
                      ),
                    );
                  }
                  return;
                }
                // Rilis biasa: dialog ditutup setelah browser
                // terbuka. Rilis wajib: dialog DIBIARKAN — pengguna
                // kembali ke sini setelah memasang (aplikasi akan
                // mulai ulang dengan versi baru), atau mengetuk
                // Unduh lagi bila belum jadi memasang.
                if (!rilis.wajib && konteksDialog.mounted) {
                  Navigator.of(konteksDialog).pop();
                }
              },
              child: const Text('Unduh Sekarang'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
