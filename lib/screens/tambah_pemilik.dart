import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/provisioning.dart';
import '../providers.dart';
import '../services/layanan_exception.dart';
import '../widgets/keadaan.dart';

/// Form Tambah Pemilik (Batch 5, khusus admin): admin membuatkan
/// akun pemilik baru — nama, email, no HP, kata sandi awal. Kata
/// sandi awal disampaikan admin ke pemilik di luar aplikasi; sesi
/// admin sendiri tidak terganggu (lihat ProvisioningService).
class TambahPemilikScreen extends ConsumerStatefulWidget {
  const TambahPemilikScreen({super.key});

  @override
  ConsumerState<TambahPemilikScreen> createState() =>
      _TambahPemilikScreenState();
}

class _TambahPemilikScreenState extends ConsumerState<TambahPemilikScreen> {
  final _nama = TextEditingController();
  final _email = TextEditingController();
  final _noHp = TextEditingController();
  final _sandi = TextEditingController();
  final _konfirmasi = TextEditingController();
  bool _sibuk = false;
  String? _galat;

  @override
  void dispose() {
    _nama.dispose();
    _email.dispose();
    _noHp.dispose();
    _sandi.dispose();
    _konfirmasi.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    final galat = galatPemilikBaru(
      nama: _nama.text,
      email: _email.text,
      kataSandi: _sandi.text,
      konfirmasiSandi: _konfirmasi.text,
    );
    if (galat != null) {
      setState(() => _galat = galat);
      return;
    }
    setState(() {
      _sibuk = true;
      _galat = null;
    });
    try {
      final pemilik = await ref
          .read(provisioningServiceProvider)
          .buatAkunPemilik(
            nama: _nama.text,
            email: _email.text,
            kataSandi: _sandi.text,
            noHp: _noHp.text,
          );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Akun pengguna dibuat'),
          content: Text(
            '${pemilik.nama} (${pemilik.email}) sudah bisa masuk.\n\n'
            'Sampaikan kata sandi awal yang baru dibuat ke penggunanya '
            '(mis. lewat WhatsApp). Setelah itu buat acaranya dari '
            'kartu pengguna di Panel Admin.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Selesai'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.of(context).pop();
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
    return Scaffold(
      appBar: AppBar(title: const Text('Tambah Pengguna')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Akun ini dibuatkan oleh admin. Pengguna tinggal masuk '
              'dengan email & kata sandi awal di bawah ini.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nama,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nama Pengguna',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noHp,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'No. HP (opsional)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _sandi,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Kata Sandi Awal (min. 6 karakter)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _konfirmasi,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Konfirmasi Kata Sandi Awal',
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
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _sibuk ? null : _simpan,
              icon: _sibuk
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.person_add_outlined),
              label: const Text('Buat Akun'),
            ),
          ],
        ),
      ),
    );
  }
}
