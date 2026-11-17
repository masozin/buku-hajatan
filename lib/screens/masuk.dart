import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../services/layanan_exception.dart';
import '../widgets/elemen.dart';
import 'gabung_acara.dart';
import '../widgets/keadaan.dart';

/// Layar masuk: dua tab sesuai Auth Opsi A.
/// - Pemilik: email + kata sandi. Sejak Batch 5 akun pemilik
///   DIBUATKAN oleh admin — tidak ada pendaftaran mandiri di sini.
/// - Pencatat: gabung acara dengan kode + nama + PIN, tanpa email.
///
/// Ditata ulang Batch 12: kepala merek (logo + nama + tagline)
/// dan pemilih tab berbentuk pil ala kendali segmen.
class MasukScreen extends StatelessWidget {
  const MasukScreen({super.key, this.tabAwal = 0});

  /// Tab yang dibuka pertama kali: 0 = Pemilik, 1 = Pencatat.
  /// Gerbang memakai 1 untuk sesi anonim yang belum mengikuti
  /// acara apa pun (Batch 14) — form gabung kini langsung di tab
  /// Pencatat, bukan halaman tersendiri.
  final int tabAwal;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final skema = tema.colorScheme;
    return DefaultTabController(
      length: 2,
      initialIndex: tabAwal,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              const Center(child: LogoAplikasi(ukuran: 76)),
              const SizedBox(height: 18),
              Text(
                'Buku Hajatan',
                textAlign: TextAlign.center,
                style: tema.textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'Buku tamu digital untuk amplop hajatan — rapi, '
                  'aman, dan tersinkron realtime.',
                  textAlign: TextAlign.center,
                  style: tema.textTheme.bodyMedium?.copyWith(
                    color: skema.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: skema.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const TabBar(
                  tabs: [
                    Tab(text: 'Pemilik Acara'),
                    Tab(text: 'Pencatat'),
                  ],
                ),
              ),
              const Expanded(
                child: TabBarView(
                  children: [_TabPemilik(), _TabPencatat()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tab Pencatat: sesi anonim dibuat otomatis saat tab dibuka
/// (Batch 13), dan form gabung kode+nama+PIN kini LANGSUNG di
/// tab ini (Batch 14) — gerbang menahan sesi anonim tanpa acara
/// di layar Masuk sehingga form tidak hancur di tengah jalan.
/// SENGAJA tidak ditaruh di sini lagi (perbaikan gabung
/// 2026-11-17): form itu masuk anonim dulu baru mengklaim, dan
/// gerbang menukar layar begitu sesi muncul — form hancur di tengah
/// jalan dan klaim tidak pernah selesai. Sekarang: ketuk tombol →
/// sesi anonim dibuat → gerbang menampilkan form gabung sebagai
/// beranda pencatat (form stabil di sana, galat tampil normal).
class _TabPencatat extends ConsumerStatefulWidget {
  const _TabPencatat();

  @override
  ConsumerState<_TabPencatat> createState() => _TabPencatatState();
}

class _TabPencatatState extends ConsumerState<_TabPencatat> {
  bool _sibuk = false;
  bool _sudahMulai = false;
  String? _galat;
  TabController? _kontrolTab;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final kontrol = DefaultTabController.of(context);
    if (kontrol != _kontrolTab) {
      _kontrolTab?.removeListener(_periksaTab);
      _kontrolTab = kontrol;
      _kontrolTab?.addListener(_periksaTab);
    }
    _periksaTab();
  }

  @override
  void dispose() {
    _kontrolTab?.removeListener(_periksaTab);
    super.dispose();
  }

  /// Batch 13: sesi anonim dibuat OTOMATIS begitu tab Pencatat
  /// dibuka — tidak perlu mengetuk tombol lagi. Tombol tetap ada
  /// sebagai jalan mencoba ulang bila pembuatan sesi gagal.
  void _periksaTab() {
    if (_kontrolTab?.index == 1 && !_sudahMulai && !_sibuk) {
      _masuk();
    }
  }

  Future<void> _masuk() async {
    if (_sudahMulai) return;
    _sudahMulai = true;
    setState(() {
      _sibuk = true;
      _galat = null;
    });
    try {
      await ref.read(authServiceProvider).masukAnonim();
      // Berhasil: gerbang berpindah ke form gabung pencatat.
    } on LayananException catch (e) {
      _sudahMulai = false;
      if (mounted) setState(() => _galat = e.pesan);
    } catch (e) {
      _sudahMulai = false;
      if (mounted) setState(() => _galat = pesanDari(e));
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  /// Keluar dari sesi anonim (Batch 14): untuk pengguna yang
  /// membuka tab Pencatat tetapi batal bergabung — melepas sesi
  /// perangkat lalu sign out, kembali ke keadaan belum masuk.
  Future<void> _keluarSesi() async {
    final auth = ref.read(authServiceProvider);
    final layananAcara = ref.read(acaraServiceProvider);
    final uid = ref.read(statusPenggunaProvider).valueOrNull?.uid;
    if (uid != null) {
      try {
        await layananAcara.lepaskanSemuaSesi(uid);
      } catch (_) {
        // Abaikan — keluar tetap jalan.
      }
    }
    await auth.keluar();
  }

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final pengguna = ref.watch(statusPenggunaProvider).valueOrNull;
    final sesiAktif = pengguna?.isAnonymous ?? false;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.badge_rounded,
                    color: skema.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Untuk petugas pencatat amplop. Isi kode '
                      'acara, namamu (sesuai yang didaftarkan '
                      'pemilik), dan PIN-mu untuk bergabung.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_galat != null) ...[
            const SizedBox(height: 12),
            Text(
              _galat!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 16),
          // Batch 14: form gabung LANGSUNG di tab ini (permintaan
          // Mark) — bukan halaman tersendiri lagi. Aman dari bug
          // gabung lama karena gerbang kini menahan sesi anonim
          // tanpa acara di layar Masuk (tab Pencatat), jadi form
          // tidak hancur saat sesi dibuat.
          GabungAcaraForm(
            tampilkanPengantar: false,
            onBerhasil: (pencatat) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Selamat datang, ${pencatat.nama}. Kamu pencatat '
                    'prefix ${pencatat.prefix}.',
                  ),
                ),
              );
              // Gerbang berpindah sendiri begitu stream
              // keikutsertaan terisi.
            },
          ),
          if (sesiAktif) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _keluarSesi,
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Keluar sesi pencatat'),
            ),
          ],
        ],
      ),
    );
  }
}

class _TabPemilik extends ConsumerStatefulWidget {
  const _TabPemilik();

  @override
  ConsumerState<_TabPemilik> createState() => _TabPemilikState();
}

class _TabPemilikState extends ConsumerState<_TabPemilik> {
  final _email = TextEditingController();
  final _sandi = TextEditingController();
  bool _sibuk = false;
  String? _galat;

  @override
  void dispose() {
    _email.dispose();
    _sandi.dispose();
    super.dispose();
  }

  /// Minta email atur ulang sandi untuk alamat yang sedang diketik
  /// (Batch 6) — Firebase mengirim tautan pembuat sandi baru.
  Future<void> _lupaSandi() async {
    if (_email.text.trim().isEmpty) {
      setState(() => _galat = 'Isi email dulu, lalu ketuk Lupa kata sandi.');
      return;
    }
    setState(() {
      _sibuk = true;
      _galat = null;
    });
    try {
      await ref.read(authServiceProvider).kirimResetSandi(_email.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Email atur ulang sandi terkirim ke ${_email.text.trim()}. '
              'Periksa kotak masuk (dan folder spam).',
            ),
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } on LayananException catch (e) {
      if (mounted) setState(() => _galat = e.pesan);
    } catch (e) {
      if (mounted) setState(() => _galat = pesanDari(e));
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  Future<void> _kirim() async {
    setState(() {
      _sibuk = true;
      _galat = null;
    });
    try {
      await ref
          .read(authServiceProvider)
          .masukPemilik(email: _email.text, kataSandi: _sandi.text);
      // Berhasil: statusPenggunaProvider berubah, gerbang berpindah
      // ke Daftar Acara dengan sendirinya.
    } on LayananException catch (e) {
      if (mounted) setState(() => _galat = e.pesan);
    } catch (e) {
      if (mounted) setState(() => _galat = pesanDari(e));
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Masuk sebagai pemilik acara untuk memantau acara '
            'hajatanmu. Akun dibuatkan oleh admin Buku Hajatan — '
            'hubungi admin bila belum punya akun.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.mail_outline_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _sandi,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Kata Sandi',
              prefixIcon: Icon(Icons.lock_outline_rounded),
            ),
          ),
          if (_galat != null) ...[
            const SizedBox(height: 12),
            Text(
              _galat!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _sibuk ? null : _kirim,
            child: _sibuk
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Masuk'),
          ),
          TextButton(
            onPressed: _sibuk ? null : _lupaSandi,
            child: const Text('Lupa kata sandi?'),
          ),
        ],
      ),
    );
  }
}
