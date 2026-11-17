import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../core/pencatatan.dart';
import '../models/amplop.dart';
import '../models/bundel.dart';
import '../providers.dart';
import '../services/layanan_exception.dart';
import '../services/pencatatan_service.dart';
import '../widgets/baris_amplop.dart';
import '../widgets/keadaan.dart';
import 'daftar_bundel.dart';

/// Layar utama pencatat di hari-H (Batch 2).
///
/// Di atas: kode bundel aktif + posisi n/10 + total bundel berjalan.
/// Di tengah: form cepat nama–alamat–nominal + pilihan jenis amplop
/// (Normal / Kosong / Tanpa Nama); simpan -> form kosong lagi.
/// Di bawah: isi bundel berjalan, tiap baris berpenanda
/// "menunggu sinkron" (oranye) atau "terkirim" (hijau).
/// Amplop ke-10 menutup bundel: dialog "masukkan ke kotak", lalu
/// bundel berikutnya langsung terbuka.
class PencatatanScreen extends ConsumerStatefulWidget {
  const PencatatanScreen({
    super.key,
    required this.acaraId,
    required this.pencatatId,
  });

  final String acaraId;
  final String pencatatId;

  @override
  ConsumerState<PencatatanScreen> createState() => _PencatatanScreenState();
}

class _PencatatanScreenState extends ConsumerState<PencatatanScreen> {
  final _nama = TextEditingController();
  final _alamat = TextEditingController();
  final _dusun = TextEditingController();
  final _nominal = TextEditingController();
  final _keterangan = TextEditingController();
  final _fokusNama = FocusNode();
  var _jenis = JenisAmplop.normal;
  var _sibuk = false;
  var _sudahBuka = false;
  String? _galatBuka;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bukaBundel());
  }

  @override
  void dispose() {
    _nama.dispose();
    _alamat.dispose();
    _dusun.dispose();
    _nominal.dispose();
    _keterangan.dispose();
    _fokusNama.dispose();
    super.dispose();
  }

  Future<void> _bukaBundel() async {
    if (_sudahBuka) return;
    _sudahBuka = true;
    try {
      await ref
          .read(pencatatanServiceProvider)
          .bukaBundelAktif(
            acaraId: widget.acaraId,
            pencatatId: widget.pencatatId,
          );
    } on LayananException catch (e) {
      if (mounted) {
        setState(() => _galatBuka = e.pesan);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.pesan)));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _galatBuka = pesanDari(e));
      }
    }
  }

  void _gantiJenis(JenisAmplop jenis) {
    setState(() {
      _jenis = jenis;
      if (jenis == JenisAmplop.kosong) _nominal.clear();
      if (jenis == JenisAmplop.tanpaNama) _nama.clear();
    });
  }

  Future<void> _simpan(Bundel bundel) async {
    final nominal = parseNominal(_nominal.text);
    final galat = validasiAmplop(
      jenis: _jenis,
      nama: _nama.text,
      nominal: nominal,
    );
    if (galat != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(galat)));
      return;
    }
    setState(() => _sibuk = true);
    try {
      final hasil = await ref
          .read(pencatatanServiceProvider)
          .simpanAmplop(
            acaraId: widget.acaraId,
            pencatatId: widget.pencatatId,
            bundel: bundel,
            jenis: _jenis,
            nama: _nama.text,
            alamat: _alamat.text,
            dusun: int.tryParse(_dusun.text.trim()),
            keterangan: _keterangan.text,
            nominal: nominal,
          );
      if (!mounted) return;
      final namaTampil = _jenis == JenisAmplop.tanpaNama
          ? '(Tanpa Nama)'
          : _nama.text.trim();
      final nominalTampil = nominalSimpan(_jenis, nominal);
      _nama.clear();
      _alamat.clear();
      _dusun.clear();
      _nominal.clear();
      _keterangan.clear();
      setState(() => _jenis = JenisAmplop.normal);
      _fokusNama.requestFocus();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Tersimpan: $namaTampil — ${formatRupiah(nominalTampil)} '
            '(${hasil.bundelSesudah.jumlahAmplop}/10 di ${hasil.bundelSesudah.kode}).',
          ),
        ),
      );
      if (hasil.menutupBundel && hasil.bundelBaru != null) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Text('Bundel ${hasil.bundelSesudah.kode} penuh'),
            content: Text(
              'Masukkan bundel ${hasil.bundelSesudah.kode} ke kotak.\n'
              'Bundel ${hasil.bundelBaru!.kode} sudah terbuka — '
              'lanjut mencatat.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Lanjut'),
              ),
            ],
          ),
        );
      }
    } on LayananException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.pesan)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(pesanDari(e))));
      }
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ConsumerState.build hanya menerima context; ref adalah properti.
    final layanan = ref.watch(pencatatanServiceProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mencatat Amplop'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt_outlined),
            tooltip: 'Daftar Bundel Saya',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DaftarBundelScreen(
                    acaraId: widget.acaraId,
                    pencatatId: widget.pencatatId,
                    sebagaiPemilik: false,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Bundel>>(
        stream: layanan.bundelPencatatStream(
          widget.acaraId,
          widget.pencatatId,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const TampilMuat();
          }
          if (snapshot.hasError) {
            return TampilGalat(pesan: pesanDari(snapshot.error!));
          }
          final daftar = snapshot.data ?? const <Bundel>[];
          final terbuka = daftar
              .where((b) => b.status == StatusBundel.terbuka)
              .toList();
          // Bundel aktif = yang terbuka bernomor terbesar.
          terbuka.sort((a, b) => b.nomor.compareTo(a.nomor));
          final bundel = terbuka.isEmpty ? null : terbuka.first;
          if (bundel == null) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Belum ada bundel aktif. Ketuk tombol di bawah '
                    'untuk membuka bundel pertama.',
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _sibuk
                        ? null
                        : () async {
                            setState(() => _sibuk = true);
                            _sudahBuka = false;
                            await _bukaBundel();
                            if (mounted) setState(() => _sibuk = false);
                          },
                    icon: const Icon(Icons.inventory_2_outlined),
                    label: const Text('Buka Bundel'),
                  ),
                  if (_galatBuka != null) ...[
                    const SizedBox(height: 12),
                    Text(_galatBuka!, textAlign: TextAlign.center),
                  ],
                ],
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _KartuBundelAktif(bundel: bundel),
              const SizedBox(height: 16),
              _FormAmplop(
                jenis: _jenis,
                onJenis: _gantiJenis,
                nama: _nama,
                alamat: _alamat,
                dusun: _dusun,
                nominal: _nominal,
                keterangan: _keterangan,
                fokusNama: _fokusNama,
                sibuk: _sibuk,
                onSimpan: () => _simpan(bundel),
              ),
              const SizedBox(height: 16),
              Text(
                'Isi bundel ${bundel.kode}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              StreamBuilder<List<AmplopTercatat>>(
                stream: layanan.amplopBundelStream(
                  widget.acaraId,
                  bundel.id,
                ),
                builder: (context, snapshotIsi) {
                  if (snapshotIsi.connectionState ==
                      ConnectionState.waiting) {
                    return const TampilMuat();
                  }
                  if (snapshotIsi.hasError) {
                    return TampilGalat(pesan: pesanDari(snapshotIsi.error!));
                  }
                  final isi = snapshotIsi.data ?? const <AmplopTercatat>[];
                  if (isi.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Belum ada amplop di bundel ini.'),
                    );
                  }
                  return Card(
                    child: Column(
                      children: [
                        for (final tercatat in isi)
                          BarisAmplop(tercatat: tercatat),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              const Row(
                children: [
                  Icon(
                    Icons.cloud_upload_outlined,
                    size: 16,
                    color: Colors.orange,
                  ),
                  SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'oranye = menunggu sinkron (tersimpan di HP, '
                      'terkirim saat ada jaringan)',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _KartuBundelAktif extends StatelessWidget {
  const _KartuBundelAktif({required this.bundel});

  final Bundel bundel;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    bundel.kode,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                Text(
                  '${bundel.jumlahAmplop}/10',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: bundel.jumlahAmplop / 10),
            const SizedBox(height: 8),
            Text('Total bundel: ${formatRupiah(bundel.totalRp)}'),
            if (bundel.jumlahKosong > 0 || bundel.jumlahTanpaNama > 0)
              Text(
                'Kosong: ${bundel.jumlahKosong} • '
                'Tanpa nama: ${bundel.jumlahTanpaNama}',
              ),
          ],
        ),
      ),
    );
  }
}

class _FormAmplop extends StatelessWidget {
  const _FormAmplop({
    required this.jenis,
    required this.onJenis,
    required this.nama,
    required this.alamat,
    required this.dusun,
    required this.nominal,
    required this.keterangan,
    required this.fokusNama,
    required this.sibuk,
    required this.onSimpan,
  });

  final JenisAmplop jenis;
  final ValueChanged<JenisAmplop> onJenis;
  final TextEditingController nama;
  final TextEditingController alamat;
  final TextEditingController dusun;
  final TextEditingController nominal;
  final TextEditingController keterangan;
  final FocusNode fokusNama;
  final bool sibuk;
  final VoidCallback onSimpan;

  @override
  Widget build(BuildContext context) {
    final tanpaNama = jenis == JenisAmplop.tanpaNama;
    final kosong = jenis == JenisAmplop.kosong;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
              selected: {jenis},
              onSelectionChanged: (pilihan) => onJenis(pilihan.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nama,
              focusNode: fokusNama,
              enabled: !tanpaNama,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: tanpaNama ? 'Nama (otomatis "(Tanpa Nama)")' : 'Nama tamu',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (_) => sibuk ? null : onSimpan(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: alamat,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Alamat',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (_) => sibuk ? null : onSimpan(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: dusun,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Dusun (angka, boleh kosong)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (_) => sibuk ? null : onSimpan(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nominal,
              enabled: !kosong,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: kosong ? 'Nominal (amplop kosong = Rp 0)' : 'Nominal (Rp)',
                prefixText: kosong ? null : 'Rp ',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (_) => sibuk ? null : onSimpan(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: keterangan,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Keterangan (boleh kosong)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (_) => sibuk ? null : onSimpan(),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: sibuk ? null : onSimpan,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Simpan Amplop'),
            ),
          ],
        ),
      ),
    );
  }
}
