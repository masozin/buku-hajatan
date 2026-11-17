import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/pencatat.dart';
import '../providers.dart';
import '../services/layanan_exception.dart';
import '../widgets/keadaan.dart';

/// Form gabung pencatat: kode acara + nama (sesuai yang
/// didaftarkan pemilik) + PIN PRIBADI pencatat itu (Batch 10;
/// sebelumnya PIN acara). Dipakai LANGSUNG di tab Pencatat layar
/// Masuk (Batch 14 — gerbang menahan sesi anonim tanpa acara di
/// layar Masuk, jadi form aman di sana) dan sebagai layar
/// tersendiri untuk gabung acara lain. Batch 18: form inilah yang
/// membuat sesi anonim (di _gabung, saat tombol ditekan) — tab
/// Pencatat tidak lagi membuatnya otomatis saat dibuka.
class GabungAcaraForm extends ConsumerStatefulWidget {
  const GabungAcaraForm({
    super.key,
    required this.onBerhasil,
    this.tampilkanPengantar = true,
  });

  final void Function(Pencatat pencatat) onBerhasil;

  /// Teks pengantar di atas form. Di tab Pencatat layar Masuk
  /// sudah ada kartu penjelasan sendiri, jadi di sana dimatikan.
  final bool tampilkanPengantar;

  @override
  ConsumerState<GabungAcaraForm> createState() => _GabungAcaraFormState();
}

class _GabungAcaraFormState extends ConsumerState<GabungAcaraForm> {
  final _kode = TextEditingController();
  final _nama = TextEditingController();
  final _pin = TextEditingController();
  bool _sibuk = false;
  String? _galat;

  @override
  void dispose() {
    _kode.dispose();
    _nama.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _gabung() async {
    setState(() {
      _sibuk = true;
      _galat = null;
    });
    // Ambil service SEBELUM await pertama: masukAnonim dapat memicu
    // pergantian layar oleh gerbang, dan ref tidak boleh dipakai
    // lagi setelah widget dilepas.
    final auth = ref.read(authServiceProvider);
    final acaraService = ref.read(acaraServiceProvider);
    try {
      final user = await auth.masukAnonim();
      final pencatat = await acaraService.gabungAcara(
        uid: user.uid,
        kodeInput: _kode.text,
        namaInput: _nama.text,
        pinInput: _pin.text,
      );
      if (!mounted) return;
      widget.onBerhasil(pencatat);
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.tampilkanPengantar) ...[
          const Text(
            'Untuk petugas pencatat pengunjung. Kode acara & PIN '
            'pribadimu didapat dari pemilik acara; namamu harus '
            'sudah didaftarkan pemilik acara.',
          ),
          const SizedBox(height: 16),
        ],
        TextField(
          controller: _kode,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
            LengthLimitingTextInputFormatter(6),
          ],
          decoration: const InputDecoration(
            labelText: 'Kode Acara',
            hintText: 'mis. K7QX2M',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _nama,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Namamu (sesuai pendaftaran)',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _pin,
          keyboardType: TextInputType.number,
          obscureText: true,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          decoration: const InputDecoration(
            labelText: 'PIN Pribadimu',
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
        FilledButton.icon(
          onPressed: _sibuk ? null : _gabung,
          icon: _sibuk
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.login),
          label: const Text('Gabung Acara'),
        ),
      ],
    );
  }
}

/// Layar tersendiri berisi [GabungAcaraForm] — untuk pencatat yang
/// sudah masuk dan mau bergabung ke acara lain.
class GabungAcaraScreen extends StatelessWidget {
  const GabungAcaraScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gabung Acara')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: GabungAcaraForm(
          onBerhasil: (pencatat) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Berhasil bergabung sebagai pencatat '
                  '${pencatat.prefix} (${pencatat.nama}).',
                ),
              ),
            );
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }
}
