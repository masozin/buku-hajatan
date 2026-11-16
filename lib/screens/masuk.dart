import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../services/layanan_exception.dart';
import '../widgets/keadaan.dart';
import 'gabung_acara.dart';

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

class _TabPencatat extends StatelessWidget {
  const _TabPencatat();

  @override
  Widget build(BuildContext context) {
    return GabungAcaraForm(
      onBerhasil: (pencatat) {
        // Status pengguna berubah (anonim) -> gerbang menampilkan
        // Daftar Acara. Pesan sambutan ditampilkan dari sini.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Selamat datang, ${pencatat.nama}. Kamu pencatat '
              'prefix ${pencatat.prefix}.',
            ),
          ),
        );
      },
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
        ],
      ),
    );
  }
}
