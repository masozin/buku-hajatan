import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers.dart';
import '../services/kunci_aplikasi.dart';
import '../widgets/elemen.dart';

/// Tombol info di nav atas (Batch 28, permintaan Mark): membuka
/// halaman Info Aplikasi. Dipasang di beranda pemilik, Panel
/// Admin, dan Detail Acara (pemilik & pencatat).
class TombolInfo extends StatelessWidget {
  const TombolInfo({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.info_outline),
      tooltip: 'Info Aplikasi',
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const InfoAplikasiScreen()),
        );
      },
    );
  }
}

/// Halaman Info Aplikasi (Batch 28): info aplikasi, pembuat,
/// kontak pembuat, dan versi aplikasi yang terpasang.
class InfoAplikasiScreen extends StatelessWidget {
  const InfoAplikasiScreen({super.key});

  /// Kontak pembuat (Mark, 2026-11-18): Ahmad Khozin,
  /// WA 0812-7937-3439 — nomor yang sama dengan kontak admin.
  static const _namaPembuat = 'Ahmad Khozin';
  static const _waPembuatTampil = '0812-7937-3439';
  static const _waPembuatUrl = 'https://wa.me/6281279373439';

  static final _infoPaket = PackageInfo.fromPlatform();

  Future<void> _bukaWa() async {
    await launchUrl(
      Uri.parse(_waPembuatUrl),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Info Aplikasi')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
        children: [
          const Center(child: LogoAplikasi(ukuran: 96)),
          const SizedBox(height: 16),
          Text(
            'Buku Hajatan',
            textAlign: TextAlign.center,
            style: tema.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Aplikasi pencatatan pengunjung dan amplop hajatan '
            'secara digital — terbundel rapi per 10 amplop, rekap '
            'otomatis, dan bisa diekspor ke Excel, CSV, dan PDF.',
            textAlign: TextAlign.center,
            style: tema.textTheme.bodyMedium?.copyWith(
              color: tema.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<PackageInfo>(
            future: _infoPaket,
            builder: (context, snap) {
              final info = snap.data;
              return Text(
                info == null
                    ? 'Versi …'
                    : 'Versi ${info.version} (${info.buildNumber})',
                textAlign: TextAlign.center,
                style: tema.textTheme.bodySmall?.copyWith(
                  color: tema.colorScheme.onSurfaceVariant,
                ),
              );
            },
          ),
          const SizedBox(height: 28),
          const Divider(),
          _BarisInfo(
            ikon: Icons.person_outline,
            label: 'Pembuat',
            nilai: _namaPembuat,
          ),
          _BarisInfo(
            ikon: Icons.chat_outlined,
            label: 'Kontak Pembuat',
            nilai: 'WhatsApp $_waPembuatTampil',
            onTap: _bukaWa,
          ),
          const SizedBox(height: 28),
          const Divider(),
          const _BagianKeamanan(),
        ],
      ),
    );
  }
}

class _BarisInfo extends StatelessWidget {
  const _BarisInfo({
    required this.ikon,
    required this.label,
    required this.nilai,
    this.onTap,
  });

  final IconData ikon;
  final String label;
  final String nilai;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(ikon, color: tema.colorScheme.primary),
      title: Text(
        label,
        style: tema.textTheme.bodySmall?.copyWith(
          color: tema.colorScheme.onSurfaceVariant,
        ),
      ),
      subtitle: Text(
        nilai,
        style: tema.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      trailing: onTap == null
          ? null
          : Icon(
              Icons.open_in_new,
              size: 18,
              color: tema.colorScheme.onSurfaceVariant,
            ),
      onTap: onTap,
    );
  }
}

/// Bagian Keamanan (Batch 38): saklar Kunci Sidik Jari untuk
/// PERANGKAT INI. Mengaktifkan = langsung membuktikan sidik
/// jari sekali; setelah itu aplikasi terkunci setiap dibuka
/// dari awal atau kembali dari latar belakang > 60 detik.
/// Mode Buku Tamu dikecualikan (tablet di tangan tamu).
class _BagianKeamanan extends ConsumerStatefulWidget {
  const _BagianKeamanan();

  @override
  ConsumerState<_BagianKeamanan> createState() =>
      _BagianKeamananState();
}

class _BagianKeamananState extends ConsumerState<_BagianKeamanan> {
  bool? _aktif;
  bool _mendukung = false;
  bool _sibuk = false;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    final layanan = ref.read(kunciAplikasiServiceProvider);
    final mendukung = await layanan.perangkatMendukung();
    final aktif = await layanan.aktif();
    if (!mounted) return;
    setState(() {
      _mendukung = mendukung;
      _aktif = aktif;
    });
  }

  Future<void> _ubah(bool nilai) async {
    final layanan = ref.read(kunciAplikasiServiceProvider);
    if (nilai) {
      // Buktikan dulu sidik jarinya bekerja di perangkat ini.
      setState(() => _sibuk = true);
      final ok = await layanan.autentikasi();
      if (!mounted) return;
      setState(() => _sibuk = false);
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Sidik jari tidak terverifikasi — kunci belum '
              'diaktifkan.',
            ),
          ),
        );
        return;
      }
    }
    await layanan.aturAktif(nilai);
    if (!mounted) return;
    setState(() => _aktif = nilai);
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Keamanan',
          style: tema.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.fingerprint),
          title: const Text('Kunci Sidik Jari'),
          subtitle: Text(
            _mendukung
                ? 'Aplikasi terkunci setiap dibuka; membukanya '
                    'cukup sidik jari atau kunci layar HP — tanpa '
                    'mengetik ulang kata sandi/PIN. Berlaku hanya '
                    'di HP ini. Mode Buku Tamu tidak dikunci.'
                : 'Perangkat ini tidak mendukung sidik jari '
                    'maupun kunci layar.',
          ),
          value: _aktif ?? false,
          onChanged: (_mendukung && !_sibuk && _aktif != null)
              ? _ubah
              : null,
        ),
        // Kunci manual (Batch 39): cara lain selain tombol
        // gembok melayang di kiri bawah layar.
        if (_aktif == true)
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => permintaanKunciManual.value++,
              icon: const Icon(Icons.lock_outline),
              label: const Text('Kunci Sekarang'),
            ),
          ),
      ],
    );
  }
}
