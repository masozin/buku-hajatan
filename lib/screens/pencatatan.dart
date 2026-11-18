import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../core/kode.dart';
import '../core/pencatatan.dart';
import '../core/rekap.dart';
import '../models/amplop.dart';
import '../models/bundel.dart';
import '../providers.dart';
import '../services/layanan_exception.dart';
import '../services/pencatatan_service.dart';
import '../theme/tema_aplikasi.dart';
import '../widgets/baris_amplop.dart';
import '../widgets/keadaan.dart';
import '../widgets/kolom_form.dart';
import 'buku_tamu.dart';
import 'koreksi_amplop.dart';
import 'mode_hitung.dart';

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
  final _rt = TextEditingController();
  final _rw = TextEditingController();
  final _nominal = TextEditingController();
  final _keterangan = TextEditingController();
  final _fokusNama = FocusNode();
  var _jenis = JenisAmplop.normal;
  var _sibuk = false;
  var _sudahBuka = false;
  String? _galatBuka;

  /// Batch 30: true bila acara ini Metode Langsung (wadahnya
  /// bundel bebas, bukan bundel 10). Ditentukan di _siapkan.
  var _langsung = false;

  /// Batch 31: fitur Buku Tamu acara ini menyala + nama acara
  /// untuk kepala Mode Buku Tamu. Ditentukan di _siapkan.
  var _fiturBukuTamu = false;
  var _namaAcara = '';

  /// Sugesti alamat untuk kolom Alamat (Batch 14): alamat unik
  /// yang pernah dipakai di acara ini.
  List<String> _saranAlamat = const [];

  /// Id bundel yang sedang DITINJAU setelah penuh (Batch 26):
  /// selama terisi, layar menampilkan bundel itu untuk diperiksa
  /// dan form disembunyikan; null = mode mencatat biasa.
  String? _idBundelTinjau;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _siapkan();
    });
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
    _fokusNama.dispose();
    super.dispose();
  }

  /// Batch 30: tentukan dulu metode acara ini, baru buka
  /// wadahnya — bundel aktif untuk Metode Bundel, bundel bebas
  /// untuk Metode Langsung.
  Future<void> _siapkan() async {
    try {
      final acara = await ref
          .read(acaraServiceProvider)
          .acaraStream(widget.acaraId)
          .first;
      if (mounted && acara != null) {
        setState(() {
          _langsung = acara.metodeLangsung;
          _fiturBukuTamu = acara.fiturBukuTamu;
          _namaAcara = acara.namaAcara;
        });
      }
    } catch (_) {
      // Gagal membaca acara: anggap Bundel (bawaan) — layanan
      // buka bundel akan menyampaikan galat yang sebenarnya.
    }
    await _bukaBundel();
    _muatSaranAlamat();
  }

  Future<void> _bukaBundel() async {
    if (_sudahBuka) return;
    _sudahBuka = true;
    try {
      final layanan = ref.read(pencatatanServiceProvider);
      if (_langsung) {
        await layanan.bukaBundelBebas(
          acaraId: widget.acaraId,
          pencatatId: widget.pencatatId,
        );
      } else {
        await layanan.bukaBundelAktif(
          acaraId: widget.acaraId,
          pencatatId: widget.pencatatId,
        );
      }
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
    // Batch 14: nominal diketik DALAM RIBU saat input (50 berarti
    // Rp 50.000) — dikalikan 1000 di sini. (Form ubah/koreksi
    // tidak memakai perkalian ini.)
    final nominal = parseNominal(_nominal.text) * 1000;
    final alamatDipakai = _alamat.text.trim();
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
            rt: int.tryParse(_rt.text.trim()),
            rw: int.tryParse(_rw.text.trim()),
            keterangan: _keterangan.text,
            nominal: nominal,
          );
      if (!mounted) return;
      // Alamat yang baru dipakai ikut menjadi sugesti berikutnya.
      if (alamatDipakai.isNotEmpty &&
          !_saranAlamat.any(
            (a) => normalisasiNama(a) == normalisasiNama(alamatDipakai),
          )) {
        _saranAlamat = [..._saranAlamat, alamatDipakai]..sort(
          (x, y) => normalisasiNama(x).compareTo(normalisasiNama(y)),
        );
      }
      final namaTampil = _jenis == JenisAmplop.tanpaNama
          ? '(Tanpa Nama)'
          : _nama.text.trim();
      final nominalTampil = nominalSimpan(_jenis, nominal);
      _nama.clear();
      _alamat.clear();
      _dusun.clear();
      _rt.clear();
      _rw.clear();
      _nominal.clear();
      _keterangan.clear();
      setState(() => _jenis = JenisAmplop.normal);
      _fokusNama.requestFocus();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _langsung
                ? 'Tersimpan: $namaTampil — '
                      '${formatRupiah(nominalTampil)} '
                      '(pengunjung ke-${hasil.bundelSesudah.jumlahAmplop} '
                      'yang kamu catat).'
                : 'Tersimpan: $namaTampil — '
                      '${formatRupiah(nominalTampil)} '
                      '(${hasil.bundelSesudah.jumlahAmplop}/10 di '
                      '${hasil.bundelSesudah.kode}).',
          ),
        ),
      );
      if (hasil.menutupBundel) {
        // Batch 26 (permintaan Mark): TIDAK ada popup lagi.
        // Masuk mode tinjau — bundel yang baru penuh ditampilkan
        // untuk diperiksa dulu, form disembunyikan, dan pengguna
        // melanjutkan sendiri lewat tombol Lanjut di bawah daftar.
        setState(() => _idBundelTinjau = hasil.bundelSesudah.id);
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
      // Batch 13: tombol "Daftar Bundel Saya" di sini dihapus —
      // fungsinya digantikan tab Bundel di Detail Acara.
      appBar: AppBar(title: const Text('Mencatat Pengunjung')),
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
          Bundel? bundel;
          Bundel? bundelTinjau;
          if (_langsung) {
            // Metode Langsung: wadahnya bundel bebas pencatat ini
            // (satu-satunya); tidak ada mode tinjau bundel penuh.
            for (final b in daftar) {
              if (b.bebas) bundel = b;
            }
          } else {
            final terbuka = daftar
                .where((b) => b.status == StatusBundel.terbuka)
                .toList();
            // Bundel aktif = yang terbuka bernomor terbesar.
            terbuka.sort((a, b) => b.nomor.compareTo(a.nomor));
            bundel = terbuka.isEmpty ? null : terbuka.first;
            // Batch 26: mode tinjau — bundel yang baru penuh
            // ditampilkan menggantikan bundel aktif sampai
            // pengguna mengetuk Lanjut.
            if (_idBundelTinjau != null) {
              for (final b in daftar) {
                if (b.id == _idBundelTinjau) bundelTinjau = b;
              }
            }
          }
          final tampil = bundelTinjau ?? bundel;
          final meninjau = bundelTinjau != null;
          if (tampil == null) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _langsung
                        ? 'Catatan belum dibuka. Ketuk tombol di '
                              'bawah untuk mulai mencatat.'
                        : 'Belum ada bundel aktif. Ketuk tombol di '
                              'bawah untuk membuka bundel pertama.',
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
                    label: Text(_langsung ? 'Buka Catatan' : 'Buka Bundel'),
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
              if (_langsung)
                _KartuCatatanBebas(bundel: tampil)
              else
                _KartuBundelAktif(
                  bundel: tampil,
                  judul: meninjau ? 'Bundel Penuh' : 'Bundel Aktif',
                ),
              const SizedBox(height: 16),
              // Batch 31/32: jalan masuk Mode Buku Tamu & Mode
              // Hitung — hanya bila fitur Buku Tamu acara ini
              // menyala. Buku Tamu memakai bundel bebasnya
              // sendiri, jadi tidak tergantung bundel aktif.
              if (_fiturBukuTamu && !meninjau) ...[
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => BukuTamuScreen(
                          acaraId: widget.acaraId,
                          pencatatId: widget.pencatatId,
                          namaAcara: _namaAcara,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.menu_book_outlined),
                  label: const Text(
                    'Mode Buku Tamu — tamu mengisi sendiri',
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ModeHitungScreen(
                          acaraId: widget.acaraId,
                          pencatatId: widget.pencatatId,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.calculate_outlined),
                  label: const Text(
                    'Mode Hitung — isi nominal buku tamu',
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (!meninjau)
                _FormAmplop(
                  jenis: _jenis,
                  onJenis: _gantiJenis,
                  nama: _nama,
                  alamat: _alamat,
                  dusun: _dusun,
                  rt: _rt,
                  rw: _rw,
                  nominal: _nominal,
                  keterangan: _keterangan,
                  fokusNama: _fokusNama,
                  sibuk: _sibuk,
                  saranAlamat: _saranAlamat,
                  onSimpan: () => _simpan(tampil),
                )
              else
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.fact_check_outlined,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Bundel ${tampil.kode} sudah penuh — '
                            'masukkan ke kotak. Periksa daftar '
                            'pengunjung di bawah; ketuk pensil bila '
                            'ada yang perlu dibetulkan. Kalau sudah, '
                            'ketuk tombol Lanjut di bawah daftar.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                _langsung
                    ? 'Pengunjung yang saya catat'
                    : 'Isi bundel ${tampil.kode}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              StreamBuilder<List<AmplopTercatat>>(
                stream: layanan.amplopBundelStream(
                  widget.acaraId,
                  tampil.id,
                ),
                builder: (context, snapshotIsi) {
                  if (snapshotIsi.connectionState ==
                      ConnectionState.waiting) {
                    return const TampilMuat();
                  }
                  if (snapshotIsi.hasError) {
                    return TampilGalat(pesan: pesanDari(snapshotIsi.error!));
                  }
                  // Batch 15: isi bundel ditampilkan dari yang
                  // TERBARU (urut terbesar di atas, nomor 1 paling
                  // bawah) — yang baru diinput langsung terlihat.
                  final isi = [...(snapshotIsi.data ?? const <AmplopTercatat>[])]
                    ..sort(
                      (a, b) => b.amplop.urut.compareTo(a.amplop.urut),
                    );
                  if (isi.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        _langsung
                            ? 'Belum ada pengunjung tercatat.'
                            : 'Belum ada pengunjung di bundel ini.',
                      ),
                    );
                  }
                  // Batch 30: bundel bebas bisa berisi ratusan —
                  // layar ini menampilkan 50 catatan terakhir saja
                  // (daftar lengkap ada di tab Pengunjung).
                  final terpotong = _langsung && isi.length > 50;
                  final isiTampil = terpotong
                      ? isi.sublist(0, 50)
                      : isi;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (terpotong)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text(
                            'Menampilkan 50 catatan terakhir — daftar '
                            'lengkapnya ada di tab Pengunjung.',
                          ),
                        ),
                      Card(
                        child: Column(
                          children: [
                            for (final tercatat in isiTampil)
                              BarisAmplop(
                            tercatat: tercatat,
                            // Pencatat boleh mengubah amplop yang ia
                            // input sendiri (Batch 8) — tombol pensil
                            // di tiap baris.
                            onUbah: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => KoreksiAmplopScreen(
                                    acaraId: widget.acaraId,
                                    bundel: tampil,
                                    amplopLama: tercatat.amplop,
                                    pencatatId: widget.pencatatId,
                                  ),
                                ),
                              );
                                },
                              ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
              // Batch 26: tombol melanjutkan dari mode tinjau —
              // kembali ke form bundel berikutnya yang sudah
              // terbuka otomatis.
              if (meninjau) ...[
                FilledButton.icon(
                  onPressed: () =>
                      setState(() => _idBundelTinjau = null),
                  icon: const Icon(Icons.arrow_forward),
                  label: Text(
                    bundel == null
                        ? 'Lanjut'
                        : 'Lanjut ke Bundel ${bundel.kode}',
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Icon(
                    Icons.cloud_upload_outlined,
                    size: 16,
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'emas = menunggu sinkron (tersimpan di HP, '
                      'terkirim saat ada jaringan)',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
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

/// Kartu bundel aktif (Batch 12): panel gradasi zamrud — kode
/// bundel besar, lencana kemajuan n/10, batang kemajuan putih,
/// dan total bundel. Titik fokus layar pencatatan.
class _KartuBundelAktif extends StatelessWidget {
  const _KartuBundelAktif({
    required this.bundel,
    this.judul = 'Bundel Aktif',
  });

  final Bundel bundel;

  /// Label kecil di atas kode bundel — "Bundel Penuh" saat mode
  /// tinjau Batch 26.
  final String judul;

  @override
  Widget build(BuildContext context) {
    final putihRedup = Colors.white.withValues(alpha: 0.78);
    return Container(
      decoration: BoxDecoration(
        gradient: TemaAplikasi.gradasiPahlawan,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: TemaAplikasi.zamrud.withValues(alpha: 0.28),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      judul,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: putihRedup,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      bundel.kode,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${bundel.jumlahAmplop}/10 pengunjung',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LinearProgressIndicator(
            value: bundel.jumlahAmplop / 10,
            minHeight: 7,
            borderRadius: BorderRadius.circular(999),
            backgroundColor: Colors.white.withValues(alpha: 0.25),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('Total bundel', style: TextStyle(color: putihRedup)),
              const Spacer(),
              Text(
                formatRupiah(bundel.totalRp),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          if (bundel.jumlahKosong > 0 || bundel.jumlahTanpaNama > 0) ...[
            const SizedBox(height: 4),
            Text(
              'Kosong: ${bundel.jumlahKosong} • '
              'Tanpa nama: ${bundel.jumlahTanpaNama}',
              style: TextStyle(fontSize: 12.5, color: putihRedup),
            ),
          ],
        ],
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
    required this.rt,
    required this.rw,
    required this.nominal,
    required this.keterangan,
    required this.fokusNama,
    required this.sibuk,
    required this.saranAlamat,
    required this.onSimpan,
  });

  final JenisAmplop jenis;
  final ValueChanged<JenisAmplop> onJenis;
  final TextEditingController nama;
  final TextEditingController alamat;
  final TextEditingController dusun;
  final TextEditingController rt;
  final TextEditingController rw;
  final TextEditingController nominal;
  final TextEditingController keterangan;
  final FocusNode fokusNama;
  final bool sibuk;

  /// Sugesti alamat acara ini (Batch 14).
  final List<String> saranAlamat;
  final VoidCallback onSimpan;

  @override
  Widget build(BuildContext context) {
    final tanpaNama = jenis == JenisAmplop.tanpaNama;
    final kosong = jenis == JenisAmplop.kosong;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
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
              ),
              onSubmitted: (_) => sibuk ? null : onSimpan(),
            ),
            const SizedBox(height: 12),
            KolomAlamat(
              controller: alamat,
              saran: saranAlamat,
              onSubmitted: () => sibuk ? null : onSimpan(),
            ),
            const SizedBox(height: 12),
            KolomDusun(
              controller: dusun,
              onSubmitted: () => sibuk ? null : onSimpan(),
            ),
            const SizedBox(height: 12),
            // Batch 25: RT & RW berdampingan, stepper − / + sama
            // seperti dusun.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: KolomDusun(
                    controller: rt,
                    label: 'RT (angka, boleh kosong)',
                    onSubmitted: () => sibuk ? null : onSimpan(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: KolomDusun(
                    controller: rw,
                    label: 'RW (angka, boleh kosong)',
                    onSubmitted: () => sibuk ? null : onSimpan(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Batch 14: nominal diketik dalam ribu — tampilkan
            // pratinjau hasil kalinya agar tidak salah tafsir.
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: nominal,
              builder: (context, nilaiTeks, _) {
                final n = parseNominal(nilaiTeks.text);
                return TextField(
                  controller: nominal,
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
                  onSubmitted: (_) => sibuk ? null : onSimpan(),
                );
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: keterangan,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Keterangan (boleh kosong)',
              ),
              onSubmitted: (_) => sibuk ? null : onSimpan(),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: sibuk ? null : onSimpan,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Simpan Pengunjung'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kartu ringkasan Metode Langsung (Batch 30): panel gradasi
/// sekeluarga dengan kartu bundel aktif, tetapi isinya hitungan
/// berjalan pencatat ini — tidak ada kode bundel, tidak ada
/// batas 10.
class _KartuCatatanBebas extends StatelessWidget {
  const _KartuCatatanBebas({required this.bundel});

  /// Bundel bebas pencatat ini (wadah catatan langsungnya).
  final Bundel bundel;

  @override
  Widget build(BuildContext context) {
    final putihRedup = Colors.white.withValues(alpha: 0.78);
    return Container(
      decoration: BoxDecoration(
        gradient: TemaAplikasi.gradasiPahlawan,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: TemaAplikasi.zamrud.withValues(alpha: 0.28),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Catatan Langsung (tanpa bundel)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: putihRedup,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${bundel.jumlahAmplop} pengunjung',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('Total saya', style: TextStyle(color: putihRedup)),
              const Spacer(),
              Text(
                formatRupiah(bundel.totalRp),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          if (bundel.jumlahKosong > 0 || bundel.jumlahTanpaNama > 0) ...[
            const SizedBox(height: 4),
            Text(
              'Kosong: ${bundel.jumlahKosong} • '
              'Tanpa nama: ${bundel.jumlahTanpaNama}',
              style: TextStyle(fontSize: 12.5, color: putihRedup),
            ),
          ],
        ],
      ),
    );
  }
}
