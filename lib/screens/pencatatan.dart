import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../core/kode.dart';
import '../core/pencatatan.dart';
import '../core/rekap.dart';
import '../core/undangan.dart';
import '../models/amplop.dart';
import '../models/bundel.dart';
import '../models/tamu_undangan.dart';
import '../providers.dart';
import '../services/layanan_exception.dart';
import '../services/pencatatan_service.dart';
import '../theme/tema_aplikasi.dart';
import '../widgets/baris_amplop.dart';
import '../widgets/elemen.dart';
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

  /// Batch 34: fitur Daftar Undangan acara ini menyala.
  /// Ditentukan di _siapkan.
  var _fiturUndangan = false;

  /// Batch 35: pemilik menyembunyikan total dari pencatat —
  /// total di kartu bundel/catatan ditutup. Ditentukan di
  /// _siapkan.
  var _sembunyikanTotal = false;

  /// Batch 35: persiapan awal layar (baca acara + buka bundel)
  /// sudah selesai. Selama false dan belum ada bundel tampil,
  /// layar menunjukkan indikator muat — bukan kartu "belum ada
  /// bundel" sesaat yang membuat layar terasa memuat ulang.
  var _persiapanSelesai = false;

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
          _fiturUndangan = acara.fiturUndangan;
          _sembunyikanTotal = acara.sembunyikanTotal;
          _namaAcara = acara.namaAcara;
        });
      }
    } catch (_) {
      // Gagal membaca acara: anggap Bundel (bawaan) — layanan
      // buka bundel akan menyampaikan galat yang sebenarnya.
    }
    await _bukaBundel();
    if (mounted) setState(() => _persiapanSelesai = true);
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
          if (tampil == null && !_persiapanSelesai) {
            // Batch 35: persiapan awal belum selesai (acara
            // sedang dibaca / bundel sedang dibuka) — tampilkan
            // indikator muat, JANGAN kartu "belum ada bundel"
            // sesaat. Kartu itu yang membuat layar terasa
            // memuat ulang dua kali saat dibuka.
            return const TampilMuat();
          }
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
                _KartuCatatanBebas(
                  bundel: tampil,
                  sembunyikanTotal: _sembunyikanTotal,
                )
              else
                _KartuBundelAktif(
                  bundel: tampil,
                  judul: meninjau ? 'Bundel Penuh' : 'Bundel Aktif',
                  sembunyikanTotal: _sembunyikanTotal,
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
              // Batch 34: Daftar Undangan — cari nama tamu,
              // ketuk untuk menandai hadir (dengan/tanpa amplop)
              // atau tidak hadir. Tamu tak terdaftar tetap
              // dicatat lewat form biasa (jadi walk-in).
              if (_fiturUndangan && !meninjau) ...[
                _DaftarUndanganPencatat(
                  acaraId: widget.acaraId,
                  pencatatId: widget.pencatatId,
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
    this.sembunyikanTotal = false,
  });

  final Bundel bundel;

  /// Batch 35: total bundel ditutup (pengaturan pemilik).
  final bool sembunyikanTotal;

  /// Label kecil di atas kode bundel — "Bundel Penuh" saat mode
  /// tinjau Batch 26.
  final String judul;

  @override
  Widget build(BuildContext context) {
    // Kartu panggung: skala teks dijepit ZonaTeksRapi.
    return ZonaTeksRapi(child: _isi(context));
  }

  Widget _isi(BuildContext context) {
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
                sembunyikanTotal
                    ? 'Rp •••••••'
                    : formatRupiah(bundel.totalRp),
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

/// Daftar Undangan di layar pencatatan (Batch 34, rancangan
/// §6.3): petugas mencari nama tamu lalu menandai hadir
/// (dengan/tanpa amplop) atau tidak hadir. Yang sudah hadir
/// hanya bisa dibatalkan oleh pencatat yang menandainya.
/// Tamu tak terdaftar (walk-in) tidak ada di daftar ini — ia
/// dicatat lewat form biasa di bawah.
class _DaftarUndanganPencatat extends ConsumerStatefulWidget {
  const _DaftarUndanganPencatat({
    required this.acaraId,
    required this.pencatatId,
  });

  final String acaraId;
  final String pencatatId;

  @override
  ConsumerState<_DaftarUndanganPencatat> createState() =>
      _DaftarUndanganPencatatState();
}

class _DaftarUndanganPencatatState
    extends ConsumerState<_DaftarUndanganPencatat> {
  final _kueri = TextEditingController();
  var _cari = '';
  var _tampilkanSemua = false;

  @override
  void dispose() {
    _kueri.dispose();
    super.dispose();
  }

  void _beriTahu(String pesan) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(pesan)));
  }

  Future<void> _tandaiHadir(TamuUndangan tamu) async {
    final hasil = await showDialog<({JenisAmplop jenis, int nominalRibuan})>(
      context: context,
      builder: (_) => _DialogNominalHadir(nama: tamu.nama),
    );
    if (hasil == null || !mounted) return;
    try {
      await ref.read(undanganServiceProvider).tandaiHadirDenganAmplop(
        acaraId: widget.acaraId,
        pencatatId: widget.pencatatId,
        tamu: tamu,
        jenis: hasil.jenis,
        // Sama seperti form biasa: nominal diketik dalam ribuan.
        nominal: hasil.nominalRibuan * 1000,
      );
      _beriTahu(
        '"${tamu.nama}" hadir — ${formatRupiah(hasil.nominalRibuan * 1000)}.',
      );
    } on LayananException catch (e) {
      _beriTahu(e.pesan);
    } catch (e) {
      _beriTahu(pesanDari(e));
    }
  }

  Future<void> _tandaiHadirTanpaAmplop(TamuUndangan tamu) async {
    try {
      await ref.read(undanganServiceProvider).tandaiHadirTanpaAmplop(
        acaraId: widget.acaraId,
        pencatatId: widget.pencatatId,
        tamu: tamu,
      );
      _beriTahu('"${tamu.nama}" hadir (tanpa amplop).');
    } on LayananException catch (e) {
      _beriTahu(e.pesan);
    } catch (e) {
      _beriTahu(pesanDari(e));
    }
  }

  Future<void> _tandaiTidak(TamuUndangan tamu) async {
    try {
      await ref.read(undanganServiceProvider).tandaiTidak(
        acaraId: widget.acaraId,
        tamu: tamu,
        pencatatId: widget.pencatatId,
      );
      _beriTahu('"${tamu.nama}" ditandai tidak hadir.');
    } on LayananException catch (e) {
      _beriTahu(e.pesan);
    } catch (e) {
      _beriTahu(pesanDari(e));
    }
  }

  Future<void> _batalTandai(TamuUndangan tamu) async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Batalkan tanda hadir?'),
        content: Text(
          '"${tamu.nama}" kembali ke belum ada kabar; amplop yang '
          'terlanjur dibuat ikut dihapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Ya, batalkan'),
          ),
        ],
      ),
    );
    if (yakin != true || !mounted) return;
    try {
      await ref.read(undanganServiceProvider).batalTandai(
        acaraId: widget.acaraId,
        pencatatId: widget.pencatatId,
        tamu: tamu,
      );
      _beriTahu('Tanda hadir "${tamu.nama}" dibatalkan.');
    } on LayananException catch (e) {
      _beriTahu(e.pesan);
    } catch (e) {
      _beriTahu(pesanDari(e));
    }
  }

  void _bukaLembar(TamuUndangan tamu) {
    final sayaYangMenandai =
        tamu.statusHadir == StatusHadir.hadir &&
        tamu.dicatatOleh == widget.pencatatId;
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                tamu.nama,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                gabungAlamat(
                  alamat: tamu.alamat,
                  dusun: tamu.dusun,
                  rt: tamu.rt,
                  rw: tamu.rw,
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                'Status: ${tamu.statusHadir.label}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              if (tamu.statusHadir == StatusHadir.belum) ...[
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _tandaiHadir(tamu);
                  },
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Hadir + isi nominal amplop'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _tandaiHadirTanpaAmplop(tamu);
                  },
                  icon: const Icon(Icons.person_outline),
                  label: const Text('Hadir tanpa amplop'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _tandaiTidak(tamu);
                  },
                  icon: const Icon(Icons.person_off_outlined),
                  label: const Text('Tidak hadir'),
                ),
              ] else if (sayaYangMenandai) ...[
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _batalTandai(tamu);
                  },
                  icon: const Icon(Icons.undo_outlined),
                  label: const Text('Batalkan tanda hadir'),
                ),
              ] else ...[
                Text(
                  tamu.statusHadir == StatusHadir.hadir
                      ? 'Sudah ditandai hadir oleh pencatat lain — '
                            'hanya pencatat itu (atau pemilik) yang bisa '
                            'membatalkannya.'
                      : 'Sudah ditandai tidak hadir.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Daftar Undangan', style: tema.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Ketuk nama tamu untuk menandai hadir. Tamu yang tidak '
              'ada di daftar dicatat lewat form di bawah (walk-in).',
              style: tema.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _kueri,
              decoration: const InputDecoration(
                hintText: 'Cari nama tamu…',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _cari = v),
            ),
            const SizedBox(height: 8),
            StreamBuilder<List<TamuUndangan>>(
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
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Tidak ada tamu yang cocok.'),
                  );
                }
                final tampil = _tampilkanSemua
                    ? semua
                    : semua.take(8).toList();
                return Column(
                  children: [
                    for (final tamu in tampil)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(tamu.nama),
                        subtitle: Text(
                          gabungAlamat(
                            alamat: tamu.alamat,
                            dusun: tamu.dusun,
                            rt: tamu.rt,
                            rw: tamu.rw,
                          ),
                        ),
                        trailing: Text(
                          tamu.statusHadir.label,
                          style: TextStyle(
                            fontSize: 12,
                            color: switch (tamu.statusHadir) {
                              StatusHadir.hadir => Colors.green.shade700,
                              StatusHadir.tidak => Colors.red.shade700,
                              StatusHadir.belum =>
                                tema.colorScheme.onSurfaceVariant,
                            },
                          ),
                        ),
                        onTap: () => _bukaLembar(tamu),
                      ),
                    if (!_tampilkanSemua && semua.length > 8)
                      TextButton(
                        onPressed: () =>
                            setState(() => _tampilkanSemua = true),
                        child: Text(
                          'Tampilkan semua (${semua.length} tamu)',
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog nominal untuk "Hadir + isi nominal amplop" (petugas):
/// nominal diketik dalam ribuan seperti form biasa, jenis
/// Normal / Kosong. Mengembalikan null bila dibatalkan.
class _DialogNominalHadir extends StatefulWidget {
  const _DialogNominalHadir({required this.nama});

  final String nama;

  @override
  State<_DialogNominalHadir> createState() => _DialogNominalHadirState();
}

class _DialogNominalHadirState extends State<_DialogNominalHadir> {
  final _nominal = TextEditingController();
  var _jenis = JenisAmplop.normal;

  @override
  void dispose() {
    _nominal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Hadir — ${widget.nama}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<JenisAmplop>(
            value: _jenis,
            decoration: const InputDecoration(labelText: 'Jenis amplop'),
            items: const [
              DropdownMenuItem(
                value: JenisAmplop.normal,
                child: Text('Normal'),
              ),
              DropdownMenuItem(
                value: JenisAmplop.kosong,
                child: Text('Kosong'),
              ),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                _jenis = v;
                if (v == JenisAmplop.kosong) _nominal.clear();
              });
            },
          ),
          TextField(
            controller: _nominal,
            keyboardType: TextInputType.number,
            enabled: _jenis != JenisAmplop.kosong,
            decoration: const InputDecoration(
              labelText: 'Nominal (dalam ribuan, mis. 50 = Rp 50.000)',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop((
            jenis: _jenis,
            nominalRibuan: parseNominal(_nominal.text),
          )),
          child: const Text('Simpan Hadir'),
        ),
      ],
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
  const _KartuCatatanBebas({required this.bundel, this.sembunyikanTotal = false});

  /// Bundel bebas pencatat ini (wadah catatan langsungnya).
  final Bundel bundel;

  /// Batch 35: total saya ditutup (pengaturan pemilik).
  final bool sembunyikanTotal;

  @override
  Widget build(BuildContext context) {
    // Kartu panggung: skala teks dijepit ZonaTeksRapi.
    return ZonaTeksRapi(child: _isi(context));
  }

  Widget _isi(BuildContext context) {
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
                sembunyikanTotal
                    ? 'Rp •••••••'
                    : formatRupiah(bundel.totalRp),
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
