import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../core/pencatatan.dart';
import '../core/rekap.dart';
import '../models/amplop.dart';
import '../models/bundel.dart';
import '../providers.dart';
import '../services/layanan_exception.dart';
import '../widgets/keadaan.dart';
import '../widgets/kolom_form.dart';

/// Form koreksi amplop oleh pemilik SETELAH acara selesai (Batch 6):
/// tambah amplop yang terlewat, atau ubah amplop yang salah catat.
/// Validasi & aturan jenis memakai logika pencatatan yang sama.
///
/// Pada mode tambah, [bundel] adalah tujuan tetap (dari FAB:
/// bundel khusus pemilik; dari tab Bundel: bundel itu sendiri).
/// Batch 25 menghapus pemilih "Ganti Bundel" dari form —
/// permintaan Mark, dianggap tidak perlu.
class KoreksiAmplopScreen extends ConsumerStatefulWidget {
  const KoreksiAmplopScreen({
    super.key,
    required this.acaraId,
    required this.bundel,
    this.amplopLama,
    this.pencatatId,
  });

  final String acaraId;
  final Bundel bundel;

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
  late final TextEditingController _rt;
  late final TextEditingController _rw;
  late final TextEditingController _nominal;
  late final TextEditingController _keterangan;
  late JenisAmplop _jenis;
  late Bundel _bundel;
  bool _sibuk = false;
  String? _galat;

  /// Sugesti alamat untuk kolom Alamat (Batch 14).
  List<String> _saranAlamat = const [];

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
    _rt = TextEditingController(
      text: lama?.rt == null ? '' : '${lama!.rt}',
    );
    _rw = TextEditingController(
      text: lama?.rw == null ? '' : '${lama!.rw}',
    );
    _nominal = TextEditingController(
      text: lama == null ? '' : '${lama.nominal}',
    );
    _keterangan = TextEditingController(text: lama?.keterangan ?? '');
    _jenis = lama?.jenis ?? JenisAmplop.normal;
    _muatSaranAlamat();
  }

  Future<void> _muatSaranAlamat() async {
    try {
      final data = await ref
          .read(rekapServiceProvider)
          .ambilDataLengkap(widget.acaraId);
      if (mounted) {
        setState(() => _saranAlamat = daftarAlamatUnik(data));
      }
    } catch (_) {
      // Sugesti hanya pelengkap — abaikan bila gagal dimuat.
    }
  }

  @override
  void dispose() {
    _nama.dispose();
    _alamat.dispose();
    _dusun.dispose();
    _rt.dispose();
    _rw.dispose();
    _nominal.dispose();
    _keterangan.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    // Batch 14: mode TAMBAH mengetik nominal dalam ribu (dikali
    // 1000); mode UBAH memakai angka apa adanya — sesuai
    // permintaan Mark, perkalian hanya saat input baru.
    final nominalMentah = parseNominal(_nominal.text);
    final nominal = _modeUbah ? nominalMentah : nominalMentah * 1000;
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
              rt: int.tryParse(_rt.text.trim()),
              rw: int.tryParse(_rw.text.trim()),
              keterangan: _keterangan.text,
              jenis: _jenis,
              nominal: nominal,
            );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pengunjung diperbarui.')),
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
          rt: int.tryParse(_rt.text.trim()),
          rw: int.tryParse(_rw.text.trim()),
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
          rt: int.tryParse(_rt.text.trim()),
          rw: int.tryParse(_rw.text.trim()),
          keterangan: _keterangan.text,
          jenis: _jenis,
          nominal: nominal,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _modeUbah ? 'Pengunjung diperbarui.' : 'Pengunjung ditambahkan.',
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

  @override
  Widget build(BuildContext context) {
    final tanpaNama = _jenis == JenisAmplop.tanpaNama;
    final kosong = _jenis == JenisAmplop.kosong;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _modeUbah
              ? 'Ubah Pengunjung — Bundel ${_bundel.kode}'
              : 'Tambah Pengunjung — Bundel ${_bundel.kode}',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Batch 25 (permintaan Mark): teks "Mode koreksi…",
            // keterangan bundel tujuan, dan tombol Ganti Bundel
            // dihapus — judul AppBar sudah menyebut bundelnya,
            // sisanya dianggap tidak perlu.
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
              ),
            ),
            const SizedBox(height: 12),
            KolomAlamat(controller: _alamat, saran: _saranAlamat),
            const SizedBox(height: 12),
            KolomDusun(controller: _dusun),
            const SizedBox(height: 12),
            // Batch 25: RT & RW berdampingan, stepper − / + sama
            // seperti dusun.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: KolomDusun(
                    controller: _rt,
                    label: 'RT (angka, boleh kosong)',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: KolomDusun(
                    controller: _rw,
                    label: 'RW (angka, boleh kosong)',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _nominal,
              builder: (context, nilaiTeks, _) {
                final n = parseNominal(nilaiTeks.text);
                return TextField(
                  controller: _nominal,
                  enabled: !kosong,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: InputDecoration(
                    labelText: kosong
                        ? 'Nominal (kosong = Rp 0)'
                        : _modeUbah
                        ? 'Nominal (Rp)'
                        : 'Nominal (ribu Rp)',
                    prefixText: kosong ? null : 'Rp ',
                    helperText: kosong || _modeUbah
                        ? null
                        : n > 0
                        ? '= ${formatRupiah(n * 1000)}'
                        : 'Ketik dalam ribu: 50 = Rp 50.000',
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _keterangan,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Keterangan (boleh kosong)',
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
              label: Text(_modeUbah ? 'Simpan Perubahan' : 'Tambah Pengunjung'),
            ),
          ],
        ),
      ),
    );
  }
}
