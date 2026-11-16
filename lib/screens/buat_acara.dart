import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../core/kode.dart';
import '../providers.dart';
import '../services/layanan_exception.dart';
import '../widgets/keadaan.dart';

const List<String> pilihanJenisAcara = [
  'Pernikahan',
  'Khitanan',
  'Tasyakuran',
  'Pengajian',
  'Lainnya',
];

/// Form buat acara baru (khusus pemilik). Kode gabung dibuat otomatis
/// di server; PIN gabung disiapkan di sini (bisa diganti pemilik).
class BuatAcaraScreen extends ConsumerStatefulWidget {
  const BuatAcaraScreen({super.key});

  @override
  ConsumerState<BuatAcaraScreen> createState() => _BuatAcaraScreenState();
}

class _BuatAcaraScreenState extends ConsumerState<BuatAcaraScreen> {
  final _namaAcara = TextEditingController();
  final _tuanRumah = TextEditingController();
  final _lokasi = TextEditingController();
  final _pin = TextEditingController(text: buatPinGabung());
  String _jenis = pilihanJenisAcara.first;
  DateTime _tanggal = DateTime.now();
  bool _sibuk = false;
  String? _galat;

  @override
  void dispose() {
    _namaAcara.dispose();
    _tuanRumah.dispose();
    _lokasi.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _pilihTanggal() async {
    final dipilih = await showDatePicker(
      context: context,
      initialDate: _tanggal,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (dipilih != null) setState(() => _tanggal = dipilih);
  }

  Future<void> _simpan() async {
    final pengguna = ref.read(statusPenggunaProvider).valueOrNull;
    if (pengguna == null) return;
    if (_namaAcara.text.trim().isEmpty || _tuanRumah.text.trim().isEmpty) {
      setState(() => _galat = 'Nama acara dan tuan rumah wajib diisi.');
      return;
    }
    if (!RegExp(r'^\d{4,6}$').hasMatch(_pin.text.trim())) {
      setState(() => _galat = 'PIN gabung harus 4-6 digit angka.');
      return;
    }
    setState(() {
      _sibuk = true;
      _galat = null;
    });
    try {
      final acara = await ref
          .read(acaraServiceProvider)
          .buatAcara(
            pemilikId: pengguna.uid,
            namaAcara: _namaAcara.text,
            tuanRumah: _tuanRumah.text,
            jenis: _jenis,
            tanggal: _tanggal,
            lokasi: _lokasi.text,
            pinGabung: _pin.text.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Acara dibuat. Kode gabung pencatat: ${acara.kodeGabung} '
            '(PIN: ${_pin.text.trim()}).',
          ),
          duration: const Duration(seconds: 6),
        ),
      );
      Navigator.of(context).pop();
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
      appBar: AppBar(title: const Text('Buat Acara')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _namaAcara,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nama Acara',
                hintText: 'mis. Pernikahan Sari & Budi',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tuanRumah,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Tuan Rumah',
                hintText: 'mis. Keluarga Bapak Hartono',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _jenis,
              items: pilihanJenisAcara
                  .map((j) => DropdownMenuItem(value: j, child: Text(j)))
                  .toList(),
              onChanged: (v) => setState(() => _jenis = v ?? _jenis),
              decoration: const InputDecoration(
                labelText: 'Jenis Acara',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pilihTanggal,
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text('Tanggal: ${formatTanggal(_tanggal)}'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _lokasi,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Lokasi (opsional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pin,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              decoration: InputDecoration(
                labelText: 'PIN Gabung untuk Pencatat',
                helperText:
                    'Kode gabung dibuat otomatis; PIN ini yang kamu '
                    'bagikan ke pencatat bersama kodenya.',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Buat PIN acak baru',
                  onPressed: () => setState(() => _pin.text = buatPinGabung()),
                ),
              ),
            ),
            if (_galat != null) ...[
              const SizedBox(height: 12),
              Text(
                _galat!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
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
                  : const Icon(Icons.save_outlined),
              label: const Text('Simpan Acara'),
            ),
          ],
        ),
      ),
    );
  }
}
