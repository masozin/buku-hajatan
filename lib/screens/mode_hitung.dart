import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../core/kode.dart';
import '../core/pencatatan.dart';
import '../core/pengunjung.dart';
import '../core/rekap.dart';
import '../models/amplop.dart';
import '../providers.dart';
import '../services/layanan_exception.dart';
import '../widgets/keadaan.dart';

/// Mode Hitung (Batch 32, keputusan Mark 2026-11-19): layar
/// mengisi nominal entri Buku Tamu yang BELUM dihitung, sesudah
/// amplopnya dibuka dari kotak. Pencocokan lewat NAMA yang
/// tertulis di amplop (amplop di kotak acak — urutan tidak bisa
/// diandalkan), jadi daftar ini dilengkapi pencarian nama.
///
/// Dua mode:
/// - Pencatat ([pencatatId] terisi): SEMUA entri acara ini,
///   selama acara aktif — petugas bisa membantu menghitung di
///   sela acara walau acara belum ditandai selesai. Batch 33:
///   ruang lingkupnya acara (bukan per perangkat) karena kotak
///   amplop di lapangan biasanya cuma satu untuk banyak tablet
///   buku tamu — petugas yang membuka amplop tidak tahu entri
///   tamu itu ditulis dari tablet mana.
/// - Pemilik ([pencatatId] null): SEMUA entri, mengikuti gerbang
///   koreksi — mengisi nominal dari sisi pemilik terbuka setelah
///   acara ditandai selesai; sebelum itu daftar tampil baca-saja
///   untuk memantau progres.
class ModeHitungScreen extends ConsumerStatefulWidget {
  const ModeHitungScreen({
    super.key,
    required this.acaraId,
    this.pencatatId,
  });

  final String acaraId;
  final String? pencatatId;

  bool get modePencatat => pencatatId != null;

  @override
  ConsumerState<ModeHitungScreen> createState() => _ModeHitungScreenState();
}

class _ModeHitungScreenState extends ConsumerState<ModeHitungScreen> {
  final _cari = TextEditingController();
  List<BundelTerisi>? _data;
  var _sudahSelesai = false;
  String? _galatMuat;
  var _sibuk = false;

  @override
  void initState() {
    super.initState();
    _cari.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _muat());
  }

  @override
  void dispose() {
    _cari.dispose();
    super.dispose();
  }

  Future<void> _muat() async {
    try {
      final acara = await ref
          .read(acaraServiceProvider)
          .acaraStream(widget.acaraId)
          .first;
      final data = await ref
          .read(rekapServiceProvider)
          .ambilDataLengkap(widget.acaraId);
      if (!mounted) return;
      setState(() {
        _data = data;
        _sudahSelesai = acara?.sudahSelesai ?? false;
        _galatMuat = null;
      });
    } catch (e) {
      if (mounted) setState(() => _galatMuat = pesanDari(e));
    }
  }

  /// Semua entri acara ini (kedua mode melihat daftar yang
  /// sama — satu kotak, satu daftar; Batch 33).
  List<AmplopDitemukan> get _semua {
    final data = _data;
    if (data == null) return const [];
    return semuaPengunjung(data);
  }

  bool get _bisaHitung =>
      widget.modePencatat ? !_sudahSelesai : _sudahSelesai;

  Future<void> _hitung(AmplopDitemukan ditemukan) async {
    final hasil = await showModalBottomSheet<({JenisAmplop jenis, int nominal})>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _LembarHitung(amplop: ditemukan.amplop),
    );
    if (hasil == null || !mounted) return;
    setState(() => _sibuk = true);
    try {
      if (widget.modePencatat) {
        await ref
            .read(pencatatanServiceProvider)
            .hitungAmplop(
              acaraId: widget.acaraId,
              pencatatId: widget.pencatatId!,
              bundelId: ditemukan.amplop.bundelId,
              amplopLama: ditemukan.amplop,
              jenisBaru: hasil.jenis,
              nominalBaru: hasil.nominal,
            );
      } else {
        await ref
            .read(koreksiServiceProvider)
            .hitungAmplop(
              acaraId: widget.acaraId,
              bundelId: ditemukan.amplop.bundelId,
              amplopLama: ditemukan.amplop,
              jenisBaru: hasil.jenis,
              nominalBaru: hasil.nominal,
              pemilikId: ref.read(statusPenggunaProvider).valueOrNull?.uid,
            );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Terhitung: ${ditemukan.amplop.tampilNama} — '
            '${hasil.jenis.label}'
            '${hasil.jenis == JenisAmplop.normal ? ' ${formatRupiah(hasil.nominal)}' : ''}.',
          ),
        ),
      );
      await _muat();
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

  /// Amplop polos tanpa nama yang ditemukan di kotak: tidak
  /// dicocokkan ke siapa-siapa, langsung dicatat sebagai entri
  /// Tanpa Nama yang sudah terhitung.
  Future<void> _tambahTanpaNama() async {
    final nominal = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _LembarTanpaNama(),
    );
    if (nominal == null || !mounted) return;
    setState(() => _sibuk = true);
    try {
      if (widget.modePencatat) {
        final bebas = await ref
            .read(pencatatanServiceProvider)
            .bukaBundelBebas(
              acaraId: widget.acaraId,
              pencatatId: widget.pencatatId!,
            );
        await ref
            .read(pencatatanServiceProvider)
            .simpanAmplop(
              acaraId: widget.acaraId,
              pencatatId: widget.pencatatId!,
              bundel: bebas,
              jenis: JenisAmplop.tanpaNama,
              nama: '',
              nominal: nominal,
            );
      } else {
        final uid = ref.read(statusPenggunaProvider).valueOrNull?.uid;
        if (uid == null) {
          throw const LayananException('Sesi pemilik tidak ditemukan.');
        }
        final koreksi = ref.read(koreksiServiceProvider);
        final bundel = await koreksi.bundelPemilikAcara(widget.acaraId, uid);
        await koreksi.tambahAmplop(
          acaraId: widget.acaraId,
          bundelId: bundel.id,
          pemilikId: uid,
          nama: '',
          jenis: JenisAmplop.tanpaNama,
          nominal: nominal,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Amplop tanpa nama tercatat: ${formatRupiah(nominal)}.',
          ),
        ),
      );
      await _muat();
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
    final tema = Theme.of(context);
    final data = _data;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mode Hitung'),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            icon: const Icon(Icons.refresh),
            onPressed: _sibuk ? null : _muat,
          ),
        ],
      ),
      body: data == null
          ? (_galatMuat != null
                ? TampilGalat(pesan: _galatMuat!)
                : const TampilMuat())
          : _bangunIsi(context, tema),
    );
  }

  Widget _bangunIsi(BuildContext context, ThemeData tema) {
    final semua = _semua;
    final belum = semua.where((d) => !d.amplop.dihitung).toList()
      ..sort((a, b) {
        final wa = a.amplop.createdAt;
        final wb = b.amplop.createdAt;
        if (wa == null && wb == null) {
          return a.amplop.urut.compareTo(b.amplop.urut);
        }
        if (wa == null) return 1;
        if (wb == null) return -1;
        return wa.compareTo(wb);
      });
    final sudah = semua.length - belum.length;
    final kunci = normalisasiNama(_cari.text);
    final tampil = kunci.isEmpty
        ? belum
        : belum
              .where(
                (d) => normalisasiNama(d.amplop.nama).contains(kunci),
              )
              .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Sudah dihitung $sudah dari ${semua.length} '
                    'pengunjung',
                    style: tema.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: semua.isEmpty ? 1 : sudah / semua.length,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.modePencatat
                        ? 'Satu kotak untuk semua tablet — daftar '
                              'ini berisi entri Buku Tamu dari semua '
                              'perangkat. Cocokkan nama yang tertulis '
                              'di amplop, lalu isi nominalnya.'
                        : 'Cocokkan nama yang tertulis di amplop, '
                              'lalu isi nominalnya.',
                    style: tema.textTheme.bodySmall,
                  ),
                  if (!_bisaHitung) ...[
                    const SizedBox(height: 8),
                    Text(
                      widget.modePencatat
                          ? 'Acara sudah selesai — penghitungan '
                                'sekarang dilanjutkan pemilik acara.'
                          : 'Acara belum ditandai selesai — dari sisi '
                                'pemilik, mengisi nominal terbuka '
                                'setelah acara selesai. Petugas bisa '
                                'membantu dari perangkatnya sekarang.',
                      style: tema.textTheme.bodySmall?.copyWith(
                        color: tema.colorScheme.tertiary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            controller: _cari,
            decoration: const InputDecoration(
              labelText: 'Cari nama pada amplop',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: OutlinedButton.icon(
            onPressed: (_bisaHitung && !_sibuk) ? _tambahTanpaNama : null,
            icon: const Icon(Icons.mail_outline),
            label: const Text('Amplop Tanpa Nama dari Kotak'),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: belum.isEmpty
              ? const TampilKosong(
                  teks: 'Semua pengunjung sudah dihitung.',
                )
              : tampil.isEmpty
              ? const TampilKosong(teks: 'Tidak ada nama yang cocok.')
              : ListView.builder(
                  itemCount: tampil.length,
                  itemBuilder: (context, i) {
                    final d = tampil[i];
                    final a = d.amplop;
                    final alamat = gabungAlamat(
                      alamat: a.alamat,
                      dusun: a.dusun,
                      rt: a.rt,
                      rw: a.rw,
                    );
                    return ListTile(
                      title: Text(a.tampilNama),
                      subtitle: Text(
                        [
                          if (alamat.isNotEmpty) alamat,
                          if (a.createdAt != null)
                            formatWaktuKonteks(a.createdAt!),
                        ].join(' • '),
                      ),
                      trailing: Icon(
                        _bisaHitung
                            ? Icons.chevron_right
                            : Icons.lock_outline,
                        size: 20,
                      ),
                      onTap: (_bisaHitung && !_sibuk)
                          ? () => _hitung(d)
                          : null,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// Lembar isi nominal untuk satu entri belum dihitung: pilih
/// hasil pembukaan amplopnya — Normal (isi nominal), Kosong
/// (amplopnya kosong), atau Hadir Saja (ternyata tidak ada
/// amplopnya). Mengembalikan (jenis, nominal rupiah penuh).
class _LembarHitung extends StatefulWidget {
  const _LembarHitung({required this.amplop});

  final Amplop amplop;

  @override
  State<_LembarHitung> createState() => _LembarHitungState();
}

class _LembarHitungState extends State<_LembarHitung> {
  final _nominal = TextEditingController();
  var _jenis = JenisAmplop.normal;

  @override
  void dispose() {
    _nominal.dispose();
    super.dispose();
  }

  void _simpan() {
    final nominal = parseNominal(_nominal.text) * 1000;
    if (_jenis == JenisAmplop.normal && nominal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nominal belum diisi untuk jenis Normal.'),
        ),
      );
      return;
    }
    Navigator.of(context).pop((jenis: _jenis, nominal: nominal));
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final a = widget.amplop;
    final alamat = gabungAlamat(
      alamat: a.alamat,
      dusun: a.dusun,
      rt: a.rt,
      rw: a.rw,
    );
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            a.tampilNama,
            style: tema.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          if (alamat.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(alamat, style: tema.textTheme.bodyMedium),
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
                value: JenisAmplop.hadir,
                label: Text('Hadir Saja'),
              ),
            ],
            selected: {_jenis},
            onSelectionChanged: (pilihan) =>
                setState(() => _jenis = pilihan.first),
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _nominal,
            builder: (context, nilaiTeks, _) {
              final n = parseNominal(nilaiTeks.text);
              return TextField(
                controller: _nominal,
                enabled: _jenis == JenisAmplop.normal,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  labelText: _jenis == JenisAmplop.normal
                      ? 'Nominal (ribu Rp)'
                      : 'Nominal (otomatis Rp 0)',
                  prefixText: _jenis == JenisAmplop.normal ? 'Rp ' : null,
                  helperText: _jenis == JenisAmplop.normal
                      ? (n > 0
                            ? '= ${formatRupiah(n * 1000)}'
                            : 'Ketik dalam ribu: 50 = Rp 50.000')
                      : null,
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _simpan,
            icon: const Icon(Icons.check),
            label: const Text('Simpan Hasil Hitung'),
          ),
        ],
      ),
    );
  }
}

/// Lembar cepat mencatat amplop polos tanpa nama dari kotak.
class _LembarTanpaNama extends StatefulWidget {
  const _LembarTanpaNama();

  @override
  State<_LembarTanpaNama> createState() => _LembarTanpaNamaState();
}

class _LembarTanpaNamaState extends State<_LembarTanpaNama> {
  final _nominal = TextEditingController();

  @override
  void dispose() {
    _nominal.dispose();
    super.dispose();
  }

  void _simpan() {
    final nominal = parseNominal(_nominal.text) * 1000;
    if (nominal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nominal belum diisi.')),
      );
      return;
    }
    Navigator.of(context).pop(nominal);
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Amplop Tanpa Nama',
            style: tema.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Amplop polos dari kotak yang tidak bertuliskan nama — '
            'dicatat apa adanya dengan nominalnya.',
          ),
          const SizedBox(height: 16),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _nominal,
            builder: (context, nilaiTeks, _) {
              final n = parseNominal(nilaiTeks.text);
              return TextField(
                controller: _nominal,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  labelText: 'Nominal (ribu Rp)',
                  prefixText: 'Rp ',
                  helperText: n > 0
                      ? '= ${formatRupiah(n * 1000)}'
                      : 'Ketik dalam ribu: 50 = Rp 50.000',
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _simpan,
            icon: const Icon(Icons.check),
            label: const Text('Catat Amplop'),
          ),
        ],
      ),
    );
  }
}
