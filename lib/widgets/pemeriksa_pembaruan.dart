import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/pembaruan.dart';
import '../providers.dart';
import '../services/layanan_exception.dart';

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
    await showDialog<void>(
      context: context,
      barrierDismissible: !rilis.wajib,
      builder: (konteksDialog) => _DialogPembaruan(rilis: rilis),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Tahap dialog pembaruan (Batch 24).
enum _TahapUnduh { awal, mengunduh, siapPasang, gagal }

/// Dialog pembaruan ber-State (Batch 24): unduhan kini berjalan
/// DI DALAM aplikasi dengan indikator progres, dan begitu
/// selesai muncul tombol Pasang yang membuka pemasang paket
/// Android. Jalur browser lama tetap tersedia sebagai cadangan
/// bila unduhan dalam aplikasi gagal atau pemasang tidak bisa
/// dibuka. Rilis [WAJIB] tetap tidak bisa ditutup atau ditunda
/// di semua tahap.
class _DialogPembaruan extends ConsumerStatefulWidget {
  const _DialogPembaruan({required this.rilis});

  final InfoRilis rilis;

  @override
  ConsumerState<_DialogPembaruan> createState() =>
      _DialogPembaruanState();
}

class _DialogPembaruanState extends ConsumerState<_DialogPembaruan> {
  _TahapUnduh _tahap = _TahapUnduh.awal;
  int _diterima = 0;
  int? _total;
  File? _berkas;
  String? _pesanGagal;

  Future<void> _mulaiUnduh() async {
    setState(() {
      _tahap = _TahapUnduh.mengunduh;
      _diterima = 0;
      _total = null;
      _pesanGagal = null;
    });
    try {
      final berkas = await ref.read(pembaruanServiceProvider).unduhApk(
            widget.rilis.urlUnduh,
            onProgres: (diterima, total) {
              if (!mounted) return;
              setState(() {
                _diterima = diterima;
                _total = total;
              });
            },
          );
      if (!mounted) return;
      setState(() {
        _berkas = berkas;
        _tahap = _TahapUnduh.siapPasang;
      });
    } on LayananException catch (e) {
      if (!mounted) return;
      setState(() {
        _tahap = _TahapUnduh.gagal;
        _pesanGagal = e.pesan;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _tahap = _TahapUnduh.gagal;
        _pesanGagal =
            'Unduhan gagal. Periksa koneksi internet lalu coba lagi.';
      });
    }
  }

  Future<void> _pasang() async {
    final berkas = _berkas;
    if (berkas == null) return;
    final sebab =
        await ref.read(pembaruanServiceProvider).pasangApk(berkas);
    if (!mounted) return;
    if (sebab != null) {
      setState(() {
        _tahap = _TahapUnduh.gagal;
        // Batch 27: sertakan sebab asli dari sisi Android supaya
        // kegagalan pemasang bisa didiagnosis, bukan ditebak.
        _pesanGagal =
            'Pemasang tidak bisa dibuka ($sebab). '
            'Coba unduh lewat browser.';
      });
    }
    // Bila pemasang terbuka, dialog DIBIARKAN: pengguna kembali
    // ke sini sesudah memasang (aplikasi mulai ulang sendiri
    // dengan versi baru) atau sesudah membatalkannya.
  }

  Future<void> _bukaBrowser() async {
    final terbuka = await launchUrl(
      Uri.parse(widget.rilis.urlUnduh),
      mode: LaunchMode.externalApplication,
    );
    if (!mounted) return;
    if (!terbuka) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak bisa membuka tautan unduhan.'),
        ),
      );
      return;
    }
    if (!widget.rilis.wajib) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final rilis = widget.rilis;
    final catatanBersih = rilis.catatan.replaceAll('[WAJIB]', '').trim();
    final bisaDitutup = !rilis.wajib && _tahap != _TahapUnduh.mengunduh;
    return PopScope(
      canPop: bisaDitutup,
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
              if (_tahap == _TahapUnduh.awal) ...[
                Text(
                  'Versi ${rilis.versiNama} sudah tersedia. Unduh '
                  'dan pasang untuk mendapatkan perbaikan & fitur '
                  'terbaru — data dan login kamu tetap aman.',
                ),
                if (catatanBersih.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    catatanBersih,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
              if (_tahap == _TahapUnduh.mengunduh) ...[
                const Text('Sedang mengunduh pembaruan…'),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: _total == null ? null : _diterima / _total!,
                ),
                const SizedBox(height: 8),
                Text(
                  _total == null
                      ? '${formatUkuran(_diterima)} terunduh'
                      : '${(_diterima / _total! * 100).floor()}% • '
                          '${formatUkuran(_diterima)} dari '
                          '${formatUkuran(_total!)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (_tahap == _TahapUnduh.siapPasang) ...[
                Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('Unduhan selesai.')),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ketuk Pasang untuk memasang versi baru sekarang.',
                ),
              ],
              if (_tahap == _TahapUnduh.gagal)
                Text(
                  _pesanGagal ?? 'Terjadi kesalahan.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
            ],
          ),
        ),
        actions: [
          if (bisaDitutup)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Nanti Saja'),
            ),
          if (_tahap == _TahapUnduh.gagal)
            TextButton(
              onPressed: _bukaBrowser,
              child: const Text('Buka di Browser'),
            ),
          if (_tahap == _TahapUnduh.awal)
            FilledButton(
              onPressed: _mulaiUnduh,
              child: const Text('Unduh Sekarang'),
            ),
          if (_tahap == _TahapUnduh.gagal)
            FilledButton(
              onPressed: _mulaiUnduh,
              child: const Text('Coba Lagi'),
            ),
          if (_tahap == _TahapUnduh.siapPasang)
            FilledButton(
              onPressed: _pasang,
              child: const Text('Pasang'),
            ),
        ],
      ),
    );
  }
}
