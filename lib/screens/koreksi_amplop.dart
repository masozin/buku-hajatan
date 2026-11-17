import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/pencatatan.dart';
import '../models/amplop.dart';
import '../models/bundel.dart';
import '../providers.dart';
import '../services/layanan_exception.dart';
import '../widgets/keadaan.dart';

/// Form koreksi amplop oleh pemilik SETELAH acara selesai (Batch 6):
/// tambah amplop yang terlewat, atau ubah amplop yang salah catat.
/// Validasi & aturan jenis memakai logika pencatatan yang sama.
///
/// Pada mode tambah, [bundel] adalah tujuan awal (dari FAB: bundel
/// belum penuh yang terakhir); bila [bundelLain] tidak kosong,
/// pemilik bisa mengganti bundel tujuan dari dalam form.
class KoreksiAmplopScreen extends ConsumerStatefulWidget {
  const KoreksiAmplopScreen({
    super.key,
    required this.acaraId,
    required this.bundel,
    this.bundelLain = const [],
    this.amplopLama,
    this.pencatatId,
  });

  final String acaraId;
  final Bundel bundel;
  final List<Bundel> bundelLain;

  /// Null = mode tambah; terisi = mode ubah amplop ini.
  final Amplop? amplopLama;

  /// Terisi = mode ubah oleh PENCATAT penginput (Batch 8, acara
  /// masih aktif, simpan lewat PencatatanService). Kosong = mode
  /// pemilik (koreksi setelah selesai, lewat KoreksiService).
  final String? pencatatId;

  @override
  ConsumerState<KoreksiAmplopScreen> createState() =>
      _KoreksiAmplopScreenState();
}

class _KoreksiAmplopScreenState extends ConsumerState<KoreksiAmplopScreen> {
  late final TextEditingController _nama;
  late final TextEditingController _alamat;
  late final TextEditingController _dusun;
  late final TextEditingController _nominal;
  late final TextEditingController _keterangan;
  late JenisAmplop _jenis;
  late Bundel _bundel;
  bool _sibuk = false;
  String? _galat;

  bool get _modeUbah => widget.amplopLama != null;

  @override
  void initState() {
    super.initState();
    _bundel = widget.bundel;
    final lama = widget.amplopLama;
    _nama = TextEditingController(text: lama?.nama ?? '');
    _alamat = TextEditingController(text: lama?.alamat ?? '');
    _dusun = TextEditingController(
      text: lama?.dusun == null ? '' : '${lama!.dusun}',
    );
    _nominal = TextEditingController(
      text: lama == null ? '' : '${lama.nominal}',
    );
    _keterangan = TextEditingController(text: lama?.keterangan ?? '');
    _jenis = lama?.jenis ?? JenisAmplop.normal;
  }

  @override
  void dispose() {
    _nama.dispose();
    _alamat.dispose();
    _dusun.dispose();
    _nominal.dispose();
    _keterangan.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    final nominal = parseNominal(_nominal.text);
    final galat = validasiAmplop(
      jenis: _jenis,
      nama: _nama.text,
      nominal: nominal,
    );
    if (galat != null) {
      setState(() => _galat = galat);
      return;
    }
    final pengguna = ref.read(statusPenggunaProvider).valueOrNull;
    if (pengguna == null) return;
    setState(() {
      _sibuk = true;
      _galat = null;
    });
    try {
      if (widget.pencatatId != null) {
        // Mode pencatat (Batch 8): ubah amplop inputan sendiri.
        await ref
            .read(pencatatanServiceProvider)
            .ubahAmplop(
              acaraId: widget.acaraId,
              pencatatId: widget.pencatatId!,
              bundelId: _bundel.id,
              amplopLama: widget.amplopLama!,
              nama: _nama.text,
              alamat: _alamat.text,
              dusun: int.tryParse(_dusun.text.trim()),
              keterangan: _keterangan.text,
              jenis: _jenis,
              nominal: nominal,
            );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Amplop diperbarui.')),
        );
        Navigator.of(context).pop();
        return;
      }
      final koreksi = ref.read(koreksiServiceProvider);
      if (_modeUbah) {
        await koreksi.ubahAmplop(
          acaraId: widget.acaraId,
          bundelId: _bundel.id,
          amplopLama: widget.amplopLama!,
          nama: _nama.text,
          alamat: _alamat.text,
          dusun: int.tryParse(_dusun.text.trim()),
          keterangan: _keterangan.text,
          jenis: _jenis,
          nominal: nominal,
        );
      } else {
        await koreksi.tambahAmplop(
          acaraId: widget.acaraId,
          bundelId: _bundel.id,
          pemilikId: pengguna.uid,
          nama: _nama.text,
          alamat: _alamat.text,
          dusun: int.tryParse(_dusun.text.trim()),
          keterangan: _keterangan.text,
          jenis: _jenis,
          nominal: nominal,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _modeUbah ? 'Amplop diperbarui.' : 'Amplop ditambahkan.',
          ),
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

  Future<void> _gantiBundel() async {
    final semua = [widget.bundel, ...widget.bundelLain];
    final terpilih = await showModalBottomSheet<Bundel>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Masukkan ke bundel mana?')),
            for (final b in semua)
              ListTile(
                leading: CircleAvatar(child: Text(b.prefix)),
                title: Text('Bundel ${b.kode}'),
                subtitle: Text('${b.jumlahAmplop}/10 amplop'),
                trailing: b.id == _bundel.id
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.of(context).pop(b),
              ),
          ],
        ),
      ),
    );
    if (terpilih != null) setState(() => _bundel = terpilih);
  }

  @override
  Widget build(BuildContext context) {
    final tanpaNama = _jenis == JenisAmplop.tanpaNama;
    final kosong = _jenis == JenisAmplop.kosong;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _modeUbah
              ? 'Ubah Amplop — Bundel ${_bundel.kode}'
              : 'Tambah Amplop — Bundel ${_bundel.kode}',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.pencatatId != null
                  ? 'Kamu mengubah amplop yang kamu input sendiri. '
                        'Perubahan langsung menyesuaikan total bundel '
                        '& acara.'
                  : 'Mode koreksi: perubahan langsung menyesuaikan total '
                        'bundel & acara.',
            ),
            if (!_modeUbah) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Amplop ini masuk ke bundel ${_bundel.kode} '
                      '(${_bundel.jumlahAmplop}/10).',
                    ),
                  ),
                  if (widget.bundelLain.isNotEmpty)
                    TextButton(
                      onPressed: _gantiBundel,
                      child: const Text('Ganti Bundel'),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            SegmentedButton<JenisAmplop>(
              segments: const [
                ButtonSegment(
                  value: JenisAmplop.normal,
                  label: Text('Normal'),
                ),
                ButtonSegment(
                  value: JenisAmplop.kosong,
                  label: Text('Kosong'),
                ),
                ButtonSegment(
                  value: JenisAmplop.tanpaNama,
                  label: Text('Tanpa Nama'),
                ),
              ],
              selected: {_jenis},
              onSelectionChanged: (pilihan) =>
                  setState(() => _jenis = pilihan.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nama,
              enabled: !tanpaNama,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: tanpaNama
                    ? 'Nama (otomatis "(Tanpa Nama)")'
                    : 'Nama tamu',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _alamat,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Alamat',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _dusun,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Dusun (angka, boleh kosong)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nominal,
              enabled: !kosong,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: kosong
                    ? 'Nominal (amplop kosong = Rp 0)'
                    : 'Nominal (Rp)',
                prefixText: kosong ? null : 'Rp ',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _keterangan,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Keterangan (boleh kosong)',
                border: OutlineInputBorder(),
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
                  : const Icon(Icons.save_outlined),
              label: Text(_modeUbah ? 'Simpan Perubahan' : 'Tambah Amplop'),
            ),
          ],
        ),
      ),
    );
  }
}
