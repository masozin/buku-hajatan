import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../services/layanan_exception.dart';
import '../widgets/keadaan.dart';
import 'gabung_acara.dart';

/// Layar masuk: dua tab sesuai Auth Opsi A.
/// - Pemilik: email + kata sandi (masuk / daftar).
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
  final _nama = TextEditingController();
  final _noHp = TextEditingController();
  final _email = TextEditingController();
  final _sandi = TextEditingController();
  bool _modeDaftar = false;
  bool _sibuk = false;
  String? _galat;

  @override
  void dispose() {
    _nama.dispose();
    _noHp.dispose();
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
      final auth = ref.read(authServiceProvider);
      if (_modeDaftar) {
        if (_nama.text.trim().isEmpty) {
          throw const LayananException('Nama pemilik belum diisi.');
        }
        await auth.daftarPemilik(
          email: _email.text,
          kataSandi: _sandi.text,
          nama: _nama.text,
          noHp: _noHp.text,
        );
      } else {
        await auth.masukPemilik(email: _email.text, kataSandi: _sandi.text);
      }
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
            _modeDaftar
                ? 'Daftar sebagai pemilik acara. Akun ini yang membuat '
                      'acara dan mendaftarkan para pencatat.'
                : 'Masuk sebagai pemilik acara untuk membuat & '
                      'memantau acara hajatanmu.',
          ),
          const SizedBox(height: 16),
          if (_modeDaftar) ...[
            TextField(
              controller: _nama,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nama Pemilik',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noHp,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'No. HP (opsional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
          ],
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
                : Text(_modeDaftar ? 'Daftar' : 'Masuk'),
          ),
          TextButton(
            onPressed: _sibuk
                ? null
                : () => setState(() {
                    _modeDaftar = !_modeDaftar;
                    _galat = null;
                  }),
            child: Text(
              _modeDaftar
                  ? 'Sudah punya akun? Masuk'
                  : 'Belum punya akun? Daftar sebagai pemilik',
            ),
          ),
        ],
      ),
    );
  }
}
