import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../services/layanan_exception.dart';
import '../widgets/keadaan.dart';

/// Layar masuk: dua tab sesuai Auth Opsi A.
/// - Pemilik: email + kata sandi. Sejak Batch 5 akun pemilik
///   DIBUATKAN oleh admin — tidak ada pendaftaran mandiri di sini.
/// - Pencatat: gabung acara dengan kode + nama + PIN, tanpa email.
class MasukScreen extends StatelessWidget {
  const MasukScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Buku Hajatan'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.home_outlined), text: 'Pemilik Acara'),
              Tab(icon: Icon(Icons.badge_outlined), text: 'Pencatat'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _TabPemilik(),
            SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: _TabPencatat(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tab Pencatat: tombol masuk anonim saja. Form kode+nama+PIN
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
  String? _galat;

  Future<void> _masuk() async {
    setState(() {
      _sibuk = true;
      _galat = null;
    });
    try {
      await ref.read(authServiceProvider).masukAnonim();
      // Berhasil: gerbang berpindah ke form gabung pencatat.
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
          const Text(
            'Untuk petugas pencatat amplop. Kamu akan diminta kode '
            'acara, namamu (sesuai yang didaftarkan pemilik), dan PIN '
            'pribadimu di langkah berikutnya.',
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
          FilledButton.icon(
            onPressed: _sibuk ? null : _masuk,
            icon: _sibuk
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.badge_outlined),
            label: const Text('Masuk sebagai Pencatat'),
          ),
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
          const Text(
            'Masuk sebagai pemilik acara untuk memantau acara '
            'hajatanmu. Akun dibuatkan oleh admin Buku Hajatan — '
            'hubungi admin bila belum punya akun.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _sandi,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Kata Sandi',
              border: OutlineInputBorder(),
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
