import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/pencatatan.dart';
import '../core/rekap.dart';
import '../core/undangan.dart';
import '../models/amplop.dart';
import '../models/bundel.dart';
import '../models/tamu_undangan.dart';
import '../providers.dart';
import '../services/layanan_exception.dart';
import '../widgets/elemen.dart';
import '../widgets/keadaan.dart';
import '../widgets/kolom_form.dart';

/// Mode Buku Tamu (Batch 31, disederhanakan Batch 32 atas
/// keputusan Mark): perangkat pencatat menjadi buku tamu digital
/// di meja penerima tamu — PENGUNJUNG mengisi identitas +
/// ucapannya sendiri, lalu amplopnya langsung dimasukkan ke
/// kotak. Karena itu mode ini:
///
/// - TANPA nominal & TANPA bundel: tamu cukup isi identitas;
///   catatannya mengalir di bundel bebas pencatat ini (bukan
///   bundel per-10) dan lahir BELUM DIHITUNG — nominal diisi
///   belakangan lewat Mode Hitung setelah amplopnya dibuka.
/// - Daftar catatan TIDAK ditampilkan (privasi tamu).
/// - Sesudah simpan tampil layar terima kasih, lalu form kosong
///   lagi untuk tamu berikutnya.
/// - Tombol kembali Android dimatikan (PopScope); keluar hanya
///   lewat ikon kunci dengan PIN pribadi pencatat perangkat ini.
class BukuTamuScreen extends ConsumerStatefulWidget {
  const BukuTamuScreen({
    super.key,
    required this.acaraId,
    required this.pencatatId,
    required this.namaAcara,
  });

  final String acaraId;
  final String pencatatId;
  final String namaAcara;

  @override
  ConsumerState<BukuTamuScreen> createState() => _BukuTamuScreenState();
}

class _BukuTamuScreenState extends ConsumerState<BukuTamuScreen> {
  final _nama = TextEditingController();
  final _alamat = TextEditingController();
  final _dusun = TextEditingController();
  final _rt = TextEditingController();
  final _rw = TextEditingController();
  final _keterangan = TextEditingController();
  final _fokusNama = FocusNode();

  var _sibuk = false;

  /// Bundel bebas pencatat ini — wadah mengalir entri buku tamu
  /// (dibuka/dimuat saat layar tampil).
  Bundel? _bundel;

  /// PIN pribadi pencatat perangkat ini (untuk keluar mode);
  /// null selagi dimuat / bila pencatat belum punya PIN.
  String? _pinPribadi;

  /// Batch 34: fitur Daftar Undangan acara ini menyala + tamu
  /// undangan yang dipilih tamu dari daftar ("Saya diundang").
  var _fiturUndangan = false;
  TamuUndangan? _tamuTerpilih;

  List<String> _saranAlamat = const [];

  /// Keadaan layar terima kasih sesudah simpan.
  var _terimaKasih = false;
  var _namaSapa = '';
  Timer? _timerReset;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _muatPelengkap();
    });
  }

  Future<void> _muatPelengkap() async {
    try {
      final acara = await ref
          .read(acaraServiceProvider)
          .acaraStream(widget.acaraId)
          .first;
      if (mounted && acara != null) {
        setState(() => _fiturUndangan = acara.fiturUndangan);
      }
    } catch (_) {
      // Gagal membaca acara: anggap fitur mati.
    }
    try {
      final daftar = await ref
          .read(acaraServiceProvider)
          .pencatatStream(widget.acaraId)
          .first;
      for (final p in daftar) {
        if (p.id == widget.pencatatId) {
          if (mounted) setState(() => _pinPribadi = p.pinPribadi);
          break;
        }
      }
    } catch (_) {
      // PIN gagal dimuat: dialog keluar memakai jalur konfirmasi
      // sederhana (lihat _keluarMode).
    }
    try {
      final bebas = await ref
          .read(pencatatanServiceProvider)
          .bukaBundelBebas(
            acaraId: widget.acaraId,
            pencatatId: widget.pencatatId,
          );
      if (mounted) setState(() => _bundel = bebas);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(pesanDari(e))));
      }
    }
    try {
      final data = await ref
          .read(rekapServiceProvider)
          .ambilDataLengkap(widget.acaraId);
      if (mounted) {
        setState(() => _saranAlamat = daftarAlamatUnik(data));
      }
    } catch (_) {
      // Sugesti hanya pelengkap.
    }
  }

  @override
  void dispose() {
    _timerReset?.cancel();
    _nama.dispose();
    _alamat.dispose();
    _dusun.dispose();
    _rt.dispose();
    _rw.dispose();
    _keterangan.dispose();
    _fokusNama.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    final bundel = _bundel;
    if (bundel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Buku tamu sedang disiapkan…')),
      );
      return;
    }
    if (_nama.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama tamu belum diisi.')),
      );
      return;
    }
    setState(() => _sibuk = true);
    try {
      // Batch 34: tamu yang memilih namanya dari Daftar
      // Undangan — catatannya tertaut ke tamu itu (lahir belum
      // dihitung seperti entri Buku Tamu biasa; nominal menyusul
      // lewat Mode Hitung).
      final tamuTerpilih = _tamuTerpilih;
      if (tamuTerpilih != null) {
        await ref.read(undanganServiceProvider).tandaiHadirBukuTamu(
          acaraId: widget.acaraId,
          pencatatId: widget.pencatatId,
          bundel: bundel,
          tamu: tamuTerpilih,
          nama: _nama.text,
          alamat: _alamat.text,
          dusun: dusunSimpan(_dusun.text),
          rt: int.tryParse(_rt.text.trim()),
          rw: int.tryParse(_rw.text.trim()),
          keterangan: _keterangan.text,
        );
        // Muat ulang bundel bebas (jumlahnya bertambah satu).
        final bebas = await ref
            .read(pencatatanServiceProvider)
            .bukaBundelBebas(
              acaraId: widget.acaraId,
              pencatatId: widget.pencatatId,
            );
        if (!mounted) return;
        setState(() {
          _bundel = bebas;
          _namaSapa = _nama.text.trim();
          _terimaKasih = true;
        });
        _timerReset?.cancel();
        _timerReset = Timer(const Duration(seconds: 5), () {
          if (mounted) _resetForm();
        });
        return;
      }
      final hasil = await ref
          .read(pencatatanServiceProvider)
          .simpanAmplop(
            acaraId: widget.acaraId,
            pencatatId: widget.pencatatId,
            bundel: bundel,
            jenis: JenisAmplop.normal,
            nama: _nama.text,
            alamat: _alamat.text,
            dusun: dusunSimpan(_dusun.text),
            rt: int.tryParse(_rt.text.trim()),
            rw: int.tryParse(_rw.text.trim()),
            keterangan: _keterangan.text,
            // Buku Tamu tanpa nominal: nominal diisi lewat
            // Mode Hitung setelah amplopnya dibuka.
            nominal: 0,
            dihitung: false,
          );
      if (!mounted) return;
      setState(() {
        _bundel = hasil.bundelSesudah;
        _namaSapa = _nama.text.trim();
        _terimaKasih = true;
      });
      _timerReset?.cancel();
      _timerReset = Timer(const Duration(seconds: 5), () {
        if (mounted) _resetForm();
      });
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

  void _resetForm() {
    _timerReset?.cancel();
    _nama.clear();
    _alamat.clear();
    _dusun.clear();
    _rt.clear();
    _rw.clear();
    _keterangan.clear();
    setState(() {
      _terimaKasih = false;
      _tamuTerpilih = null;
    });
    _fokusNama.requestFocus();
  }

  /// Batch 34: tamu mencari namanya sendiri di Daftar Undangan
  /// ("Saya diundang") — form terisi dari data undangannya,
  /// simpan nanti menautkan catatan ke tamu itu.
  Future<void> _pilihTamuUndangan() async {
    final tamu = await showModalBottomSheet<TamuUndangan>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _LembarCariUndangan(acaraId: widget.acaraId),
    );
    if (tamu == null || !mounted) return;
    setState(() {
      _tamuTerpilih = tamu;
      _nama.text = tamu.nama;
      _alamat.text = tamu.alamat ?? '';
      _dusun.text = tamu.dusun?.toString() ?? '';
      _rt.text = tamu.rt?.toString() ?? '';
      _rw.text = tamu.rw?.toString() ?? '';
    });
  }

  /// Keluar dari Mode Buku Tamu: wajib PIN pribadi pencatat
  /// perangkat ini. Bila PIN belum ada (pencatat lama), cukup
  /// konfirmasi — perangkat tetap tidak bisa ditinggal tamu
  /// tanpa dialog apa pun.
  Future<void> _keluarMode() async {
    final pin = _pinPribadi;
    bool boleh = false;
    if (pin == null || pin.isEmpty) {
      boleh =
          await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Keluar Mode Buku Tamu?'),
              content: const Text(
                'Khusus petugas: keluar mengembalikan perangkat ke '
                'layar pencatatan biasa.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Keluar'),
                ),
              ],
            ),
          ) ??
          false;
    } else {
      boleh =
          await showDialog<bool>(
            context: context,
            builder: (_) => _DialogPinKeluar(pinBenar: pin),
          ) ??
          false;
    }
    if (boleh && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Tamu tidak boleh keluar mode ini dengan tombol kembali.
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Buku Tamu'),
          actions: [
            IconButton(
              tooltip: 'Keluar Mode Buku Tamu (khusus petugas)',
              icon: const Icon(Icons.lock_outline),
              onPressed: _keluarMode,
            ),
          ],
        ),
        body: _terimaKasih ? _bangunTerimaKasih(context) : _bangunForm(context),
      ),
    );
  }

  Widget _bangunTerimaKasih(BuildContext context) {
    final tema = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LogoAplikasi(ukuran: 96),
            const SizedBox(height: 24),
            Text(
              _namaSapa.isEmpty
                  ? 'Terima kasih atas kehadiran & doanya.'
                  : 'Terima kasih, Bapak/Ibu $_namaSapa.',
              textAlign: TextAlign.center,
              style: tema.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Kehadiran dan doa restu Anda sangat berarti bagi '
              'keluarga besar ${widget.namaAcara}. Amplop Anda '
              'silakan dimasukkan ke kotak yang tersedia.',
              textAlign: TextAlign.center,
              style: tema.textTheme.bodyLarge,
            ),
            const SizedBox(height: 28),
            Text(
              'Menyiapkan untuk tamu berikutnya…',
              style: tema.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _resetForm,
              child: const Text('Tamu Berikutnya'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bangunForm(BuildContext context) {
    final tema = Theme.of(context);
    final bundel = _bundel;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Selamat Datang',
          style: tema.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${widget.namaAcara} — silakan isi buku tamu digital '
          'kami, lalu masukkan amplop Anda ke kotak yang tersedia.',
          style: tema.textTheme.bodyLarge,
        ),
        const SizedBox(height: 6),
        Text(
          bundel == null
              ? 'Menyiapkan buku tamu…'
              : 'Sudah tercatat ${bundel.jumlahAmplop} pengunjung '
                    'di buku tamu ini.',
          style: tema.textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        // Batch 34: tamu yang diundang bisa memilih namanya
        // dari daftar — datanya terisi otomatis dan kehadirannya
        // tercatat di Daftar Undangan.
        if (_fiturUndangan && !_terimaKasih) ...[
          OutlinedButton.icon(
            onPressed: _sibuk ? null : _pilihTamuUndangan,
            icon: const Icon(Icons.mail_outline_rounded),
            label: const Text('Saya diundang — cari namaku'),
          ),
          const SizedBox(height: 8),
        ],
        if (_tamuTerpilih != null)
          Card(
            child: ListTile(
              leading: const Icon(Icons.mail_outline_rounded),
              title: Text('Undangan: ${_tamuTerpilih!.nama}'),
              subtitle: const Text(
                'Kehadiranmu akan ditandai di Daftar Undangan.',
              ),
              trailing: IconButton(
                tooltip: 'Batalkan pilihan undangan',
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _tamuTerpilih = null),
              ),
            ),
          ),
        if (_tamuTerpilih != null) const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _nama,
                  focusNode: _fokusNama,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(fontSize: 18),
                  decoration: const InputDecoration(
                    labelText: 'Nama Bapak/Ibu',
                  ),
                  onSubmitted: (_) => _sibuk ? null : _simpan(),
                ),
                const SizedBox(height: 14),
                KolomAlamat(
                  controller: _alamat,
                  saran: _saranAlamat,
                  onSubmitted: () => _sibuk ? null : _simpan(),
                ),
                const SizedBox(height: 14),
                KolomDusun(
                  controller: _dusun,
                  teksBebas: true,
                  onSubmitted: () => _sibuk ? null : _simpan(),
                ),
                // Batch 37: input RT/RW DISEMBUNYIKAN sementara
                // (permintaan Mark 2026-11-20) — controller &
                // data tetap ada; kembalikan baris Row RT/RW di
                // sini untuk menampilkannya lagi.
                const SizedBox(height: 14),
                TextField(
                  controller: _keterangan,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Ucapan / doa (boleh kosong)',
                  ),
                  onSubmitted: (_) => _sibuk ? null : _simpan(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _sibuk ? null : _simpan,
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('Simpan & Selesai'),
        ),
      ],
    );
  }
}

/// Lembar cari nama di Daftar Undangan untuk perangkat Buku
/// Tamu (Batch 34): tamu mengetuk namanya sendiri (hanya yang
/// berstatus 'belum' yang tampil — yang sudah hadir tidak bisa
/// ditandai dua kali dari sini).
class _LembarCariUndangan extends ConsumerStatefulWidget {
  const _LembarCariUndangan({required this.acaraId});

  final String acaraId;

  @override
  ConsumerState<_LembarCariUndangan> createState() =>
      _LembarCariUndanganState();
}

class _LembarCariUndanganState extends ConsumerState<_LembarCariUndangan> {
  final _kueri = TextEditingController();
  var _cari = '';

  @override
  void dispose() {
    _kueri.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cari Namamu di Daftar Undangan', style: tema.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Ketuk namamu — form di bawah akan terisi otomatis.',
              style: tema.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _kueri,
              decoration: const InputDecoration(
                hintText: 'Ketik namamu…',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _cari = v),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 320,
              child: StreamBuilder<List<TamuUndangan>>(
                stream: ref
                    .watch(undanganServiceProvider)
                    .daftarUndanganStream(widget.acaraId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const TampilMuat();
                  }
                  if (snapshot.hasError) {
                    return TampilGalat(pesan: pesanDari(snapshot.error!));
                  }
                  final semua = (snapshot.data ?? const <TamuUndangan>[])
                      .where((t) => t.statusHadir == StatusHadir.belum)
                      .where(
                        (t) => cocokUndangan(
                          nama: t.nama,
                          alamat: t.alamat,
                          kueri: _cari,
                        ),
                      )
                      .toList();
                  if (semua.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'Namamu tidak ada di daftar — isi form seperti '
                        'biasa, nanti tercatat sebagai tamu biasa.',
                      ),
                    );
                  }
                  return ListView(
                    shrinkWrap: true,
                    children: [
                      for (final tamu in semua.take(30))
                        ListTile(
                          title: Text(tamu.nama),
                          subtitle: Text(
                            gabungAlamat(
                              alamat: tamu.alamat,
                              dusun: tamu.dusun,
                              rt: tamu.rt,
                              rw: tamu.rw,
                            ),
                          ),
                          onTap: () => Navigator.of(context).pop(tamu),
                        ),
                      if (semua.length > 30)
                        const Padding(
                          padding: EdgeInsets.all(8),
                          child: Text('Persempit pencarian dengan nama lengkap.'),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog PIN keluar Mode Buku Tamu: controller dimiliki State
/// dialog dan dibuang di dispose — pola aman Batch 23
/// (controller yang dibuat di fungsi pemanggil lalu dibuang
/// sesudah showDialog memicu crash kerangka kerja).
class _DialogPinKeluar extends StatefulWidget {
  const _DialogPinKeluar({required this.pinBenar});

  final String pinBenar;

  @override
  State<_DialogPinKeluar> createState() => _DialogPinKeluarState();
}

class _DialogPinKeluarState extends State<_DialogPinKeluar> {
  final _pin = TextEditingController();
  String? _galat;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  void _periksa() {
    if (_pin.text.trim() == widget.pinBenar) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _galat = 'PIN salah — coba lagi.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Keluar Mode Buku Tamu'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Khusus petugas: masukkan PIN pribadimu untuk '
            'mengembalikan perangkat ke layar pencatatan biasa.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pin,
            obscureText: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'PIN Pribadimu',
              errorText: _galat,
            ),
            onSubmitted: (_) => _periksa(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _periksa,
          child: const Text('Keluar'),
        ),
      ],
    );
  }
}
