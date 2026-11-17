import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../models/acara.dart';
import '../models/bundel.dart';
import '../models/pencatat.dart';
import '../providers.dart';
import '../services/layanan_exception.dart';
import '../theme/tema_aplikasi.dart';
import '../widgets/elemen.dart';
import '../widgets/kartu_total.dart';
import '../widgets/keadaan.dart';
import 'daftar_bundel.dart';
import 'daftar_pengunjung.dart';
import 'koreksi_amplop.dart';
import 'pencatatan.dart';
import 'rekap.dart';
import 'tab_bundel.dart';

/// Detail satu acara.
///
/// - Untuk pemilik (Batch 7, tab ketiga Batch 9): tiga tab —
///   "Ringkasan" (info acara, jumlah pengunjung & total, kode
///   gabung + PIN, kelola pencatat, tombol tandai selesai),
///   "Pengunjung" (daftar semua amplop, bisa dicari & diurutkan),
///   dan "Bundel" (tiap bundel sebagai dropdown berisi daftar
///   pengunjungnya).
/// - Untuk pencatat (Batch 11): tiga tab juga — "Ringkasan"
///   (info acara + kartu prefix miliknya), "Pengunjung" (semua
///   amplop acara; yang bisa ia ubah hanya inputannya sendiri,
///   selama acara aktif), dan "Bundel" (hanya bundel miliknya).
///
/// Tombol catat melayang (FAB) mengikuti aturan main Batch 6/7:
/// selama acara AKTIF hanya pencatat yang melihatnya (menuju layar
/// pencatatan); setelah acara SELESAI hanya pemilik (menuju tambah
/// koreksi). Selain itu FAB disembunyikan.
class DetailAcaraScreen extends ConsumerWidget {
  const DetailAcaraScreen({
    super.key,
    required this.acaraId,
    required this.sebagaiPemilik,
  });

  final String acaraId;
  final bool sebagaiPemilik;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stream = ref.watch(acaraServiceProvider).acaraStream(acaraId);
    return StreamBuilder<Acara?>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: TampilMuat());
        }
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Detail Acara')),
            body: TampilGalat(pesan: pesanDari(snapshot.error!)),
          );
        }
        final acara = snapshot.data;
        if (acara == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Detail Acara')),
            body: const TampilKosong(
              teks: 'Acara tidak ditemukan (mungkin sudah dihapus).',
            ),
          );
        }
        if (!sebagaiPemilik) {
          return DefaultTabController(
            length: 3,
            child: Scaffold(
              appBar: AppBar(
                title: const Text('Detail Acara'),
                bottom: const TabBar(
                  tabs: [
                    Tab(
                      icon: Icon(Icons.summarize_outlined),
                      text: 'Ringkasan',
                    ),
                    Tab(icon: Icon(Icons.people_outline), text: 'Pengunjung'),
                    Tab(
                      icon: Icon(Icons.inventory_2_outlined),
                      text: 'Bundel',
                    ),
                  ],
                ),
                // Pencatat kini bermuara langsung ke panel ini
                // (Batch 8) — beri jalan keluar sesi di sini.
                actions: [
                IconButton(
                  tooltip: 'Keluar',
                  icon: const Icon(Icons.logout),
                  onPressed: () async {
                    final yakin = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Keluar dari aplikasi?'),
                        content: const Text(
                          'Keluar akan melepas sesi pencatat di HP ini. '
                          'Data yang sudah tersinkron tetap aman. Untuk '
                          'masuk lagi — dari HP ini atau HP lain — kamu '
                          'perlu kode acara, namamu, dan PIN pribadimu.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.of(context).pop(false),
                            child: const Text('Batal'),
                          ),
                          FilledButton(
                            onPressed: () =>
                                Navigator.of(context).pop(true),
                            child: const Text('Keluar'),
                          ),
                        ],
                      ),
                    );
                    if (yakin == true && context.mounted) {
                      // Batch 10: lepas sesi perangkat ini dulu.
                      final uidSaya = ref
                          .read(statusPenggunaProvider)
                          .valueOrNull
                          ?.uid;
                      if (uidSaya != null) {
                        try {
                          await ref
                              .read(acaraServiceProvider)
                              .lepaskanSemuaSesi(uidSaya);
                        } catch (_) {
                          // Abaikan — keluar tetap jalan.
                        }
                      }
                      if (context.mounted) {
                        await ref.read(authServiceProvider).keluar();
                      }
                    }
                  },
                ),
              ],
            ),
              floatingActionButton: acara.sudahSelesai
                  ? null
                  : _FabPencatat(acara: acara),
              body: _TabPencatatDetail(acara: acara),
            ),
          );
        }
        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Detail Acara'),
              bottom: const TabBar(
                tabs: [
                  Tab(icon: Icon(Icons.summarize_outlined), text: 'Ringkasan'),
                  Tab(icon: Icon(Icons.people_outline), text: 'Pengunjung'),
                  Tab(
                    icon: Icon(Icons.inventory_2_outlined),
                    text: 'Bundel',
                  ),
                ],
              ),
            ),
            floatingActionButton: acara.sudahSelesai
                ? FloatingActionButton.extended(
                    onPressed: () => _catatKoreksi(context, ref, acara),
                    icon: const Icon(Icons.add),
                    label: const Text('Catat Koreksi'),
                  )
                : null,
            body: TabBarView(
              children: [
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _InfoAcara(acara: acara),
                    const SizedBox(height: 16),
                    _TotalAcara(acara: acara),
                    const SizedBox(height: 16),
                    _KartuKodeGabung(acara: acara),
                    const SizedBox(height: 16),
                    _KelolaPencatat(acara: acara),
                    const SizedBox(height: 16),
                    _TombolStatus(acara: acara),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => RekapScreen(acaraId: acara.id),
                          ),
                        );
                      },
                      icon: const Icon(Icons.summarize_outlined),
                      label: const Text('Rekap & Ekspor'),
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
                DaftarPengunjungTab(
                  acaraId: acara.id,
                  sudahSelesai: acara.sudahSelesai,
                ),
                DaftarBundelTab(acara: acara),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Pemilik mengetuk FAB "Catat Koreksi": LANGSUNG ke form tambah
  /// amplop (perbaikan 2026-11-17 — sebelumnya pemilik disuruh
  /// memilih bundel dulu, membingungkan). Bundel tujuan dipilih
  /// otomatis: bundel belum penuh yang paling akhir dibuat, alias
  /// biasanya bundel terakhir acara. Di dalam form pemilik masih
  /// bisa mengganti bundel bila ada pilihan lain. Bila semua bundel
  /// penuh, tampilkan penjelasan — amplop tidak bisa dicatat di
  /// luar bundel (satu bundel = 10 amplop, sesuai sistem fisiknya).
  Future<void> _catatKoreksi(
    BuildContext context,
    WidgetRef ref,
    Acara acara,
  ) async {
    final semua = await ref
        .read(pencatatanServiceProvider)
        .semuaBundelStream(acara.id)
        .first;
    final belumPenuh = semua.where((b) => b.jumlahAmplop < 10).toList();
    belumPenuh.sort((a, b) {
      final ta = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final tb = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bandingWaktu = tb.compareTo(ta);
      if (bandingWaktu != 0) return bandingWaktu;
      final bandingPrefix = b.prefix.compareTo(a.prefix);
      return bandingPrefix != 0
          ? bandingPrefix
          : b.nomor.compareTo(a.nomor);
    });
    if (!context.mounted) return;
    if (belumPenuh.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Semua bundel sudah penuh'),
          content: const Text(
            'Setiap amplop harus masuk ke bundel berisi maksimal 10, '
            'dan saat ini semua bundel acara ini sudah penuh (10/10), '
            'jadi belum ada tempat untuk amplop tambahan.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Mengerti'),
            ),
          ],
        ),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => KoreksiAmplopScreen(
          acaraId: acara.id,
          bundel: belumPenuh.first,
          bundelLain: belumPenuh.skip(1).toList(),
        ),
      ),
    );
  }
}

/// Isi tab Detail Acara untuk pencatat (Batch 11): Ringkasan
/// (info acara + total + kartu saya), Pengunjung (semua amplop
/// acara; ubah hanya inputan sendiri selama aktif), dan Bundel
/// (hanya bundel miliknya). Identitas tetap pencatat dicari dari
/// stream pencatat acara ini — yang uidAktif-nya = perangkat ini.
class _TabPencatatDetail extends ConsumerWidget {
  const _TabPencatatDetail({required this.acara});

  final Acara acara;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uidSaya = ref.watch(statusPenggunaProvider).valueOrNull?.uid;
    return StreamBuilder<List<Pencatat>>(
      stream: ref.watch(acaraServiceProvider).pencatatStream(acara.id),
      builder: (context, snapPencatat) {
        Pencatat? saya;
        for (final p in snapPencatat.data ?? const <Pencatat>[]) {
          if (p.uidAktif == uidSaya) {
            saya = p;
            break;
          }
        }
        return TabBarView(
          children: [
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _InfoAcara(acara: acara),
                const SizedBox(height: 16),
                _TotalAcara(acara: acara),
                const SizedBox(height: 16),
                _KartuPencatatSaya(acara: acara),
              ],
            ),
            DaftarPengunjungTab(
              acaraId: acara.id,
              sudahSelesai: acara.sudahSelesai,
              modePencatat: true,
              pencatatIdSaya: saya?.id,
            ),
            saya == null
                ? const TampilKosong(
                    teks: 'Kamu belum terdaftar sebagai pencatat di '
                        'acara ini.',
                    ikon: Icons.inventory_2_outlined,
                  )
                : DaftarBundelTab(acara: acara, pencatatIdSaya: saya.id),
          ],
        );
      },
    );
  }
}

/// FAB "Catat Amplop" untuk pencatat pada acara yang masih aktif —
/// tampil hanya bila pengguna memang pencatat aktif di acara ini.
class _FabPencatat extends ConsumerWidget {
  const _FabPencatat({required this.acara});

  final Acara acara;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pengguna = ref.watch(statusPenggunaProvider).valueOrNull;
    if (pengguna == null) return const SizedBox.shrink();
    return FutureBuilder<Pencatat?>(
      future: ref.read(acaraServiceProvider).pencatatDi(acara.id, pengguna.uid),
      builder: (context, snapshot) {
        final saya = snapshot.data;
        if (saya == null || !saya.aktif) return const SizedBox.shrink();
        return FloatingActionButton.extended(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PencatatanScreen(
                  acaraId: acara.id,
                  pencatatId: saya.id,
                ),
              ),
            );
          },
          icon: const Icon(Icons.edit_note_outlined),
          label: const Text('Catat Amplop'),
        );
      },
    );
  }
}

class _InfoAcara extends StatelessWidget {
  const _InfoAcara({required this.acara});

  final Acara acara;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    acara.namaAcara,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const SizedBox(width: 8),
                ChipStatusAcara(status: acara.status),
              ],
            ),
            const SizedBox(height: 12),
            _BarisInfo(
              ikon: Icons.celebration_rounded,
              label: 'Jenis',
              nilai: acara.jenis,
            ),
            _BarisInfo(
              ikon: Icons.home_rounded,
              label: 'Tuan rumah',
              nilai: acara.tuanRumah,
            ),
            _BarisInfo(
              ikon: Icons.calendar_month_rounded,
              label: 'Tanggal',
              nilai: formatTanggal(acara.tanggal),
            ),
            if (acara.lokasi != null)
              _BarisInfo(
                ikon: Icons.place_rounded,
                label: 'Lokasi',
                nilai: acara.lokasi!,
              ),
          ],
        ),
      ),
    );
  }
}

/// Satu baris label–nilai berikon di kartu info acara.
class _BarisInfo extends StatelessWidget {
  const _BarisInfo({
    required this.ikon,
    required this.label,
    required this.nilai,
  });

  final IconData ikon;
  final String label;
  final String nilai;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ikon, size: 20, color: skema.primary),
          const SizedBox(width: 12),
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: skema.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              nilai,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Total acara kini memakai kartu sorotan bersama (Batch 12).
class _TotalAcara extends StatelessWidget {
  const _TotalAcara({required this.acara});

  final Acara acara;

  @override
  Widget build(BuildContext context) {
    return KartuTotalAcara(acara: acara);
  }
}

/// Kode gabung + PIN untuk dibagikan pemilik ke para pencatat,
/// lengkap dengan tombol salin.
class _KartuKodeGabung extends ConsumerWidget {
  const _KartuKodeGabung({required this.acara});

  final Acara acara;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Bisa dilipat (Batch 8): halaman Ringkasan lebih bersih —
    // kode & PIN baru tampil saat pemilik mengetuk bagiannya.
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.key_outlined),
        title: const Text('Kode Gabung & PIN Pencatat'),
        subtitle: const Text('Ketuk untuk menampilkan'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Bagikan kode ini hanya ke pencatat yang sudah kamu '
                'daftarkan namanya di bagian Pencatat.',
              ),
              const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Kode: ${acara.kodeGabung}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_outlined),
                  tooltip: 'Salin kode',
                  onPressed: () => _salin(context, acara.kodeGabung),
                ),
              ],
            ),
            // Sejak Batch 10 pencatat masuk dengan PIN PRIBADI
            // masing-masing (ada di bagian Pencatat), bukan lagi
            // satu PIN acara bersama.
            const Text(
              'Pencatat masuk dengan kode ini + namanya + PIN '
              'pribadinya masing-masing — PIN pribadi tiap pencatat '
              'ada di bagian Pencatat di bawah.',
            ),
            ],
          ),
        ],
      ),
    );
  }

  void _salin(BuildContext context, String teks) {
    Clipboard.setData(ClipboardData(text: teks));
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Tersalin: $teks')));
  }
}

/// Kelola pencatat (pemilik): tambah nama (prefix otomatis),
/// daftar undangan yang belum bergabung, daftar pencatat aktif.
class _KelolaPencatat extends ConsumerStatefulWidget {
  const _KelolaPencatat({required this.acara});

  final Acara acara;

  @override
  ConsumerState<_KelolaPencatat> createState() => _KelolaPencatatState();
}

class _KelolaPencatatState extends ConsumerState<_KelolaPencatat> {
  final _namaBaru = TextEditingController();
  final _pinBaru = TextEditingController();
  bool _sibuk = false;

  @override
  void dispose() {
    _namaBaru.dispose();
    _pinBaru.dispose();
    super.dispose();
  }

  /// Reset sesi pencatat [p] (Batch 10): lepaskan kunci sesi dari
  /// perangkat yang sedang memegangnya, supaya ia bisa masuk dari
  /// perangkat lain dengan nama + PIN pribadinya. Identitas dan
  /// semua data catatannya tetap menempel ke namanya.
  Future<void> _resetSesi(Pencatat p) async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reset sesi ${p.nama}?'),
        content: Text(
          'Sesi ${p.nama} di perangkat yang sekarang memegangnya '
          'akan dilepas. Setelah itu ia bisa masuk dari perangkat '
          'mana pun dengan namanya + PIN pribadinya.\n\n'
          'Bundel & amplop yang sudah ${p.nama} catat TIDAK berubah '
          '— semua tetap atas namanya.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset Sesi'),
          ),
        ],
      ),
    );
    if (yakin != true || !mounted) return;
    try {
      await ref
          .read(acaraServiceProvider)
          .resetSesiPencatat(widget.acara.id, p);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sesi ${p.nama} sudah direset — silakan masuk lagi dari '
            'perangkat mana pun.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(pesanDari(e))));
    }
  }

  /// Dialog atur/ganti PIN pribadi untuk satu undangan (Batch 10).
  Future<void> _aturPin({
    required String undanganId,
    required String nama,
    String? pinSaatIni,
  }) async {
    final kontrol = TextEditingController(text: pinSaatIni ?? '');
    final pinBaru = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('PIN pribadi $nama'),
        content: TextField(
          controller: kontrol,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'PIN pribadi (4–6 digit angka)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(kontrol.text),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    kontrol.dispose();
    if (pinBaru == null || !mounted) return;
    try {
      await ref
          .read(acaraServiceProvider)
          .aturPinPribadi(widget.acara.id, undanganId, pinBaru);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PIN pribadi $nama diperbarui.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(pesanDari(e))));
    }
  }

  Future<void> _tambah() async {
    setState(() => _sibuk = true);
    try {
      final undangan = await ref
          .read(acaraServiceProvider)
          .tambahUndangan(
            widget.acara.id,
            _namaBaru.text,
            pinPribadi: _pinBaru.text,
          );
      if (!mounted) return;
      _namaBaru.clear();
      _pinBaru.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${undangan.nama} didaftarkan sebagai pencatat '
            '${undangan.prefix} — PIN pribadinya: '
            '${undangan.pinPribadi}. Bagikan ke orangnya.',
          ),
        ),
      );
    } on LayananException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.pesan)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(pesanDari(e))));
      }
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final layanan = ref.watch(acaraServiceProvider);
    // Bisa dilipat (Batch 8): form tambah + daftar pencatat baru
    // tampil saat pemilik mengetuk bagiannya — Ringkasan bersih.
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.badge_outlined),
        title: const Text('Pencatat'),
        subtitle: const Text('Ketuk untuk mengelola'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _namaBaru,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nama pencatat baru',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _sibuk ? null : _tambah(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _sibuk ? null : _tambah,
                  child: const Text('Tambah'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _pinBaru,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'PIN pribadi pencatat baru '
                    '(kosongkan = dibuatkan otomatis)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            StreamBuilder<List<UndanganPencatat>>(
              stream: layanan.undanganStream(widget.acara.id),
              builder: (context, snapshot) {
                final menunggu = (snapshot.data ?? const [])
                    .where((u) => !u.sudahDiklaim)
                    .toList();
                if (menunggu.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Belum bergabung:',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    for (final u in menunggu)
                      ListTile(
                        dense: true,
                        leading: CircleAvatar(child: Text(u.prefix)),
                        title: Text(u.nama),
                        subtitle: Text(
                          'PIN pribadi: ${u.pinPribadi ?? 'belum diatur'}'
                          ' • menunggu gabung',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.key_outlined),
                              tooltip: 'Atur PIN pribadi',
                              onPressed: () => _aturPin(
                                undanganId: u.id,
                                nama: u.nama,
                                pinSaatIni: u.pinPribadi,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Batalkan pendaftaran',
                              onPressed: () => layanan.hapusUndangan(
                                widget.acara.id,
                                u.id,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
            StreamBuilder<List<Pencatat>>(
              stream: layanan.pencatatStream(widget.acara.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const TampilMuat();
                }
                final daftar = snapshot.data ?? const <Pencatat>[];
                if (daftar.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Belum ada pencatat yang bergabung.'),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sudah bergabung:',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    for (final p in daftar)
                      ListTile(
                        dense: true,
                        leading: CircleAvatar(child: Text(p.prefix)),
                        title: Text(p.nama),
                        subtitle: Text(
                          'Bundel terakhir: ${p.nomorBundelTerakhir}'
                          ' • PIN pribadi: ${p.pinPribadi ?? 'belum diatur'}'
                          '${p.uidAktif != null ? ' • sesi aktif di 1 perangkat' : ' • tidak sedang masuk'}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (p.undanganId != null)
                              IconButton(
                                icon: const Icon(Icons.key_outlined),
                                tooltip: 'Atur PIN pribadi',
                                onPressed: () => _aturPin(
                                  undanganId: p.undanganId!,
                                  nama: p.nama,
                                  pinSaatIni: p.pinPribadi,
                                ),
                              ),
                            IconButton(
                              icon: const Icon(Icons.phonelink_erase_outlined),
                              tooltip: 'Reset sesi (lepas perangkat)',
                              onPressed: () => _resetSesi(p),
                            ),
                            Switch(
                              value: p.aktif,
                              onChanged: (v) => layanan.setAktifPencatat(
                                widget.acara.id,
                                p.id,
                                v,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TombolStatus extends ConsumerWidget {
  const _TombolStatus({required this.acara});

  final Acara acara;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selesai = acara.sudahSelesai;
    return OutlinedButton.icon(
      onPressed: () {
        ref
            .read(acaraServiceProvider)
            .ubahStatusAcara(
              acara.id,
              selesai ? StatusAcara.aktif : StatusAcara.selesai,
            );
      },
      icon: Icon(selesai ? Icons.replay_outlined : Icons.done_all),
      label: Text(selesai ? 'Aktifkan Kembali' : 'Tandai Acara Selesai'),
    );
  }
}

/// Kartu untuk pencatat yang membuka detail acara yang diikutinya.
class _KartuPencatatSaya extends ConsumerWidget {
  const _KartuPencatatSaya({required this.acara});

  final Acara acara;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pengguna = ref.watch(statusPenggunaProvider).valueOrNull;
    if (pengguna == null) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<Pencatat?>(
          future: ref
              .read(acaraServiceProvider)
              .pencatatDi(acara.id, pengguna.uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const TampilMuat();
            }
            final saya = snapshot.data;
            if (saya == null) {
              return const Text(
                'Kamu belum terdaftar sebagai pencatat di acara ini.',
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      gradient: TemaAplikasi.gradasiPahlawan,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      saya.prefix,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Kamu pencatat ${saya.prefix} — ${saya.nama}',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  saya.aktif
                      ? acara.sudahSelesai
                            ? 'Acara sudah selesai — pencatatan ditutup.'
                            : 'Bundel terakhirmu: ${saya.nomorBundelTerakhir}.'
                      : 'Statusmu sedang dinonaktifkan pemilik acara.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (saya.aktif && !acara.sudahSelesai) ...[
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PencatatanScreen(
                            acaraId: acara.id,
                            pencatatId: saya.id,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit_note_outlined),
                    label: const Text('Mulai Mencatat'),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => DaftarBundelScreen(
                            acaraId: acara.id,
                            pencatatId: saya.id,
                            sebagaiPemilik: false,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.list_alt_outlined),
                    label: const Text('Daftar Bundel Saya'),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
