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
  DateTime? _keLatar;

  KunciAplikasiService get _layanan =>
      ref.read(kunciAplikasiServiceProvider);

  bool get _sudahMasuk =>
      ref.read(authServiceProvider).penggunaSekarang != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _periksaAwal();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _periksaAwal() async {
    if (!await _layanan.aktif() || !_sudahMasuk) return;
    if (!mounted) return;
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
    return Stack(
      children: [
        widget.child,
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
