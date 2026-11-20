import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../models/acara.dart';
import '../providers.dart';
import '../widgets/keadaan.dart';
import 'buat_acara.dart' show pilihanJenisAcara;

/// Ubah Detail Acara (Batch 35): pemilik mengoreksi nama acara,
/// tuan rumah, jenis, tanggal, dan lokasi acaranya sendiri —
/// sebelumnya detail ini hanya bisa diisi admin saat membuat
/// acara dan tidak pernah bisa diubah lagi. Metode, fitur,
/// status, dan kode gabung diatur di tempat lain (kartu Metode
/// & Fitur di Ringkasan), tidak di sini.
class UbahAcaraScreen extends ConsumerStatefulWidget {
  const UbahAcaraScreen({super.key, required this.acara});

  final Acara acara;

  @override
  ConsumerState<UbahAcaraScreen> createState() => _UbahAcaraScreenState();
}

class _UbahAcaraScreenState extends ConsumerState<UbahAcaraScreen> {
  late final TextEditingController _namaAcara;
  late final TextEditingController _tuanRumah;
  late final TextEditingController _lokasi;
  late String _jenis;
  late DateTime _tanggal;
  var _sibuk = false;
  String? _galat;

  @override
  void initState() {
    super.initState();
    final acara = widget.acara;
    _namaAcara = TextEditingController(text: acara.namaAcara);
    _tuanRumah = TextEditingController(text: acara.tuanRumah);
    _lokasi = TextEditingController(text: acara.lokasi ?? '');
    // Jenis lama di luar daftar pilihan (mis. teks bebas lama)
    // ditampung sebagai pilihan pertama agar dropdown valid.
    _jenis = pilihanJenisAcara.contains(acara.jenis)
        ? acara.jenis
        : pilihanJenisAcara.first;
    _tanggal = acara.tanggal;
  }

  @override
  void dispose() {
    _namaAcara.dispose();
    _tuanRumah.dispose();
    _lokasi.dispose();
    super.dispose();
  }

  Future<void> _pilihTanggal() async {
    final dipilih = await showDatePicker(
      context: context,
      initialDate: _tanggal,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 2)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (dipilih != null) setState(() => _tanggal = dipilih);
  }

  Future<void> _simpan() async {
    final nama = _namaAcara.text.trim();
    final tuanRumah = _tuanRumah.text.trim();
    if (nama.isEmpty || tuanRumah.isEmpty) {
      setState(() => _galat = 'Nama acara dan tuan rumah wajib diisi.');
      return;
    }
    setState(() {
      _sibuk = true;
      _galat = null;
    });
    try {
      final lokasi = _lokasi.text.trim();
      await ref
          .read(acaraServiceProvider)
          .ubahDetailAcara(
            widget.acara.id,
            namaAcara: nama,
            tuanRumah: tuanRumah,
            jenis: _jenis,
            tanggal: _tanggal,
            lokasi: lokasi.isEmpty ? null : lokasi,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Detail acara diperbarui.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _sibuk = false;
          _galat = pesanDari(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ubah Detail Acara')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _namaAcara,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Nama Acara',
              hintText: 'mis. Pernikahan Sari & Budi',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tuanRumah,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Tuan Rumah',
              hintText: 'mis. Keluarga Bapak Hartono',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _jenis,
            items: pilihanJenisAcara
                .map((j) => DropdownMenuItem(value: j, child: Text(j)))
                .toList(),
            onChanged: (v) => setState(() => _jenis = v ?? _jenis),
            decoration: const InputDecoration(labelText: 'Jenis Acara'),
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
            label: const Text('Simpan Perubahan'),
          ),
        ],
      ),
    );
  }
}
