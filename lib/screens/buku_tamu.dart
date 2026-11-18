import 'dart:async';

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
import '../widgets/elemen.dart';
import '../widgets/keadaan.dart';
import '../widgets/kolom_form.dart';

/// Mode Buku Tamu (Batch 31, rancangan multi-metode v2 §5):
/// perangkat pencatat berubah menjadi buku tamu digital di meja
/// penerima tamu — PENGUNJUNG mengisi identitasnya sendiri,
/// petugas pendamping mengisi nominal di zona petugas pada layar
/// yang sama. Datanya identik dengan pencatatan biasa (satu
/// amplop lewat PencatatanService ke bundel aktif / bundel bebas
/// pencatat ini); yang berbeda hanya tampilan & privasi:
///
/// - Daftar catatan TIDAK ditampilkan — tamu tidak melihat nama
///   maupun nominal tamu lain.
/// - Sesudah simpan tampil layar terima kasih, lalu form kosong
///   lagi untuk tamu berikutnya.
/// - Tombol kembali Android dimatikan (PopScope); keluar dari
///   mode ini hanya lewat ikon kunci dengan PIN pribadi pencatat
///   yang sedang masuk di perangkat ini (keputusan D5).
class BukuTamuScreen extends ConsumerStatefulWidget {
  const BukuTamuScreen({
    super.key,
    required this.acaraId,
    required this.pencatatId,
    required this.bundelAwal,
    required this.langsung,
    required this.namaAcara,
  });

  final String acaraId;
  final String pencatatId;

  /// Bundel tujuan saat mode dibuka (bundel aktif pencatat, atau
  /// bundel bebasnya pada Metode Langsung). Berganti mengikuti
  /// hasil simpan bila bundel penuh dan berikutnya terbuka.
  final Bundel bundelAwal;

  /// true = Metode Langsung (wadah bundel bebas).
  final bool langsung;
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
  final _nominal = TextEditingController();
  final _keterangan = TextEditingController();
  final _fokusNama = FocusNode();

  var _jenis = JenisAmplop.normal;
  var _sibuk = false;
  late Bundel _bundel = widget.bundelAwal;

  /// PIN pribadi pencatat perangkat ini (untuk keluar mode);
  /// null selagi dimuat / bila pencatat belum punya PIN.
  String? _pinPribadi;

  List<String> _saranAlamat = const [];

  /// Keadaan layar terima kasih sesudah simpan.
  var _terimaKasih = false;
  var _namaSapa = '';
  String? _catatanPetugas;
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
      // PIN gagal dimuat: dialog keluar akan memakai jalur
      // konfirmasi sederhana (lihat _keluarMode).
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
    _nominal.dispose();
    _keterangan.dispose();
    _fokusNama.dispose();
    super.dispose();
  }

  void _gantiJenis(JenisAmplop jenis) {
    setState(() {
      _jenis = jenis;
      if (jenis == JenisAmplop.kosong) _nominal.clear();
      if (jenis == JenisAmplop.tanpaNama) _nama.clear();
    });
  }

  Future<void> _simpan() async {
    // Sama seperti form pencatatan: nominal diketik DALAM RIBU.
    final nominal = parseNominal(_nominal.text) * 1000;
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
            bundel: _bundel,
            jenis: _jenis,
            nama: _nama.text,
            alamat: _alamat.text,
            dusun: int.tryParse(_dusun.text.trim()),
            rt: int.tryParse(_rt.text.trim()),
            rw: int.tryParse(_rw.text.trim()),
            keterangan: _keterangan.text,
            nominal: nominal,
          );
      if (!mounted) return;
      final namaSapa = _jenis == JenisAmplop.tanpaNama
          ? ''
          : _nama.text.trim();
      setState(() {
        // Bundel penuh -> berikutnya sudah dibuka layanan;
        // tamu tidak perlu tahu, petugas diberi catatan kecil.
        _bundel = hasil.bundelBaru ?? hasil.bundelSesudah;
        _namaSapa = namaSapa;
        _catatanPetugas = hasil.menutupBundel
            ? 'Bundel ${hasil.bundelSesudah.kode} sudah penuh — '
                  'silakan dimasukkan ke kotak.'
            : null;
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
    _nominal.clear();
    _keterangan.clear();
    setState(() {
      _jenis = JenisAmplop.normal;
      _terimaKasih = false;
      _catatanPetugas = null;
    });
    _fokusNama.requestFocus();
  }

  /// Keluar dari Mode Buku Tamu (D5): wajib PIN pribadi pencatat
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
              'keluarga besar ${widget.namaAcara}.',
              textAlign: TextAlign.center,
              style: tema.textTheme.bodyLarge,
            ),
            if (_catatanPetugas != null) ...[
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 18,
                        color: tema.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Flexible(child: Text(_catatanPetugas!)),
                    ],
                  ),
                ),
              ),
            ],
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
    final tanpaNama = _jenis == JenisAmplop.tanpaNama;
    final kosong = _jenis == JenisAmplop.kosong;
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
          'kami, lalu serahkan amplop Anda kepada petugas.',
          style: tema.textTheme.bodyLarge,
        ),
        const SizedBox(height: 6),
        Text(
          widget.langsung
              ? 'Sudah tercatat ${_bundel.jumlahAmplop} pengunjung.'
              : 'Bundel ${_bundel.kode} • ${_bundel.jumlahAmplop}/10 '
                    'pengunjung.',
          style: tema.textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _nama,
                  focusNode: _fokusNama,
                  enabled: !tanpaNama,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(fontSize: 18),
                  decoration: InputDecoration(
                    labelText: tanpaNama
                        ? 'Nama (otomatis "(Tanpa Nama)")'
                        : 'Nama Bapak/Ibu',
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
                  onSubmitted: () => _sibuk ? null : _simpan(),
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: KolomDusun(
                        controller: _rt,
                        label: 'RT (angka, boleh kosong)',
                        onSubmitted: () => _sibuk ? null : _simpan(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: KolomDusun(
                        controller: _rw,
                        label: 'RW (angka, boleh kosong)',
                        onSubmitted: () => _sibuk ? null : _simpan(),
                      ),
                    ),
                  ],
                ),
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
        const SizedBox(height: 16),
        // Zona petugas: jenis + nominal amplop yang diserahkan.
        Card(
          color: tema.colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.badge_outlined,
                      size: 18,
                      color: tema.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Diisi petugas pendamping',
                      style: tema.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
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
                      _gantiJenis(pilihan.first),
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
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: InputDecoration(
                        labelText: kosong
                            ? 'Nominal (kosong = Rp 0)'
                            : 'Nominal (ribu Rp)',
                        prefixText: kosong ? null : 'Rp ',
                        helperText: kosong
                            ? null
                            : n > 0
                            ? '= ${formatRupiah(n * 1000)}'
                            : 'Ketik dalam ribu: 50 = Rp 50.000',
                      ),
                      onSubmitted: (_) => _sibuk ? null : _simpan(),
                    );
                  },
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

/// Dialog PIN keluar Mode Buku Tamu (Batch 31): controller
/// dimiliki State dialog dan dibuang di dispose — pola aman
/// Batch 23 (controller yang dibuat di fungsi pemanggil lalu
/// dibuang sesudah showDialog memicu crash kerangka kerja).
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
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
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
