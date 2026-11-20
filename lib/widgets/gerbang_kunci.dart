import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/kunci.dart';
import '../providers.dart';
import '../services/kunci_aplikasi.dart';
import 'elemen.dart';

/// Gerbang kunci sidik jari (Batch 38): membungkus seluruh
/// aplikasi SETELAH gerbang masuk. Mengunci pada dua saat:
/// (1) aplikasi dibuka dari awal dalam keadaan sudah masuk,
/// (2) aplikasi kembali dari latar belakang setelah lebih
/// dari ambangKunciLatar (60 detik). Selama terkunci, isi
/// aplikasi tertutup lapisan kunci; membuka = autentikasi
/// perangkat (sidik jari / kunci layar HP).
///
/// Tidak mengunci bila: kunci belum diaktifkan di perangkat
/// ini, belum ada yang masuk, atau Mode Buku Tamu sedang
/// tampil (tablet di tangan tamu — lihat
/// penandaBukuTamuAktif).
class GerbangKunciAplikasi extends ConsumerStatefulWidget {
  const GerbangKunciAplikasi({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<GerbangKunciAplikasi> createState() =>
      _GerbangKunciAplikasiState();
}

class _GerbangKunciAplikasiState
    extends ConsumerState<GerbangKunciAplikasi>
    with WidgetsBindingObserver {
  bool _terkunci = false;
  bool _sedangAuth = false;
  bool _kunciAktif = false;
  DateTime? _keLatar;

  KunciAplikasiService get _layanan =>
      ref.read(kunciAplikasiServiceProvider);

  bool get _sudahMasuk =>
      ref.read(authServiceProvider).penggunaSekarang != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    permintaanKunciManual.addListener(_kunciManual);
    _periksaAwal();
  }

  @override
  void dispose() {
    permintaanKunciManual.removeListener(_kunciManual);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Kunci manual (Batch 39): langsung mengunci, dialog
  /// sidik jari TIDAK langsung dimunculkan — petugas memang
  /// sedang ingin menutup aplikasi dari orang lain.
  Future<void> _kunciManual() async {
    if (_terkunci || penandaBukuTamuAktif.value) return;
    if (!await _layanan.aktif() || !_sudahMasuk) return;
    if (!mounted) return;
    setState(() => _terkunci = true);
  }

  Future<void> _periksaAwal() async {
    final aktif = await _layanan.aktif();
    if (!mounted) return;
    setState(() => _kunciAktif = aktif);
    if (!aktif || !_sudahMasuk) return;
    setState(() => _terkunci = true);
    await _mintaBuka();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Dialog autentikasi sendiri juga membuat aplikasi
      // berhenti sesaat — jangan catat itu sebagai ke latar.
      if (!_sedangAuth) _keLatar = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      _periksaKembali();
    }
  }

  Future<void> _periksaKembali() async {
    // Segarkan status saklar (mungkin baru diubah di Info
    // Aplikasi) agar tombol gembok tampil/sembunyi tepat.
    final aktifSegar = await _layanan.aktif();
    if (mounted && aktifSegar != _kunciAktif) {
      setState(() => _kunciAktif = aktifSegar);
    }
    if (_sedangAuth || _terkunci || penandaBukuTamuAktif.value) {
      return;
    }
    if (!perluKunciSetelahLatar(
      terakhirKeLatar: _keLatar,
      sekarang: DateTime.now(),
    )) {
      return;
    }
    _keLatar = null;
    if (!await _layanan.aktif() || !_sudahMasuk) return;
    if (!mounted) return;
    setState(() => _terkunci = true);
    await _mintaBuka();
  }

  Future<void> _mintaBuka() async {
    if (_sedangAuth) return;
    _sedangAuth = true;
    final ok = await _layanan.autentikasi();
    _sedangAuth = false;
    if (ok && mounted) setState(() => _terkunci = false);
  }

  @override
  Widget build(BuildContext context) {
    final sudahMasuk =
        ref.watch(statusPenggunaProvider).valueOrNull != null;
    return Stack(
      children: [
        widget.child,
        // Tombol kunci manual (Batch 39): gembok kecil melayang
        // di kiri bawah — jauh dari tombol + melayang kanan
        // bawah milik layar-layar. Hanya tampil bila kunci
        // aktif, ada yang masuk, dan bukan Mode Buku Tamu.
        if (!_terkunci && _kunciAktif && sudahMasuk)
          Positioned(
            left: 16,
            bottom: 16,
            child: ValueListenableBuilder<bool>(
              valueListenable: penandaBukuTamuAktif,
              builder: (context, bukuTamu, _) {
                if (bukuTamu) return const SizedBox.shrink();
                return FloatingActionButton.small(
                  heroTag: 'kunciManual',
                  tooltip: 'Kunci Sekarang',
                  onPressed: () =>
                      permintaanKunciManual.value++,
                  child: const Icon(Icons.lock_outline),
                );
              },
            ),
          ),
        if (_terkunci) _LayarTerkunci(onBuka: _mintaBuka),
      ],
    );
  }
}

class _LayarTerkunci extends StatelessWidget {
  const _LayarTerkunci({required this.onBuka});

  final VoidCallback onBuka;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Material(
      color: tema.colorScheme.surface,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const LogoAplikasi(ukuran: 88),
                const SizedBox(height: 20),
                Text(
                  'Aplikasi Terkunci',
                  style: tema.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Buka dengan sidik jari atau kunci layar HP '
                  'untuk melanjutkan.',
                  textAlign: TextAlign.center,
                  style: tema.textTheme.bodyMedium?.copyWith(
                    color: tema.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: onBuka,
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('Buka dengan Sidik Jari'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
