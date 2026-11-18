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
                    if (yakin != true) return;
                    // Perbaikan Batch 13 (keluar harus dua kali):
                    // tangkap layanan & uid SEBELUM menunggu lagi.
                    // Begitu sesi lepas, gerbang menukar layar ini
                    // dengan halaman gabung dan widget terlepas —
                    // pemeriksaan mounted di tengah jalan dulu
                    // membatalkan keluar() diam-diam, sehingga
                    // pengguna terdampar di halaman gabung dan
                    // harus keluar sekali lagi. Kini keluar()
                    // dipanggil tanpa syarat lewat rujukan yang
                    // sudah ditangkap.
                    final auth = ref.read(authServiceProvider);
                    final layananAcara = ref.read(acaraServiceProvider);
                    final uidSaya = ref
                        .read(statusPenggunaProvider)
                        .valueOrNull
                        ?.uid;
                    if (uidSaya != null) {
                      try {
                        await layananAcara.lepaskanSemuaSesi(uidSaya);
                      } catch (_) {
                        // Abaikan — keluar tetap jalan.
                      }
                    }
                    await auth.keluar();
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
                ? FloatingActionButton(
                    onPressed: () => _catatKoreksi(context, ref, acara),
                    tooltip: 'Catat Koreksi',
                    child: const Icon(Icons.edit_note_rounded),
                  )
                : null,
            body: TabBarView(
              children: [
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _InfoAcara(acara: acara, tampilkanKode: true),
                    const SizedBox(height: 16),
                    _TotalAcara(acara: acara),
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
  /// pengunjung (perbaikan 2026-11-17 — sebelumnya pemilik disuruh
  /// memilih bundel dulu, membingungkan).
  ///
  /// Batch 20: tujuan utama kini BUNDEL KHUSUS PEMILIK (prefix PM,
  /// kode PM001, PM002, …) — dicari yang belum penuh, dibuat baru
  /// bila belum ada atau yang terakhir sudah penuh, jadi koreksi
  /// selalu punya tempat dan tidak bercampur ke bundel pencatat.
  /// Di dalam form pemilik tetap bisa mengganti ke bundel lain
  /// yang belum penuh.
  Future<void> _catatKoreksi(
    BuildContext context,
    WidgetRef ref,
    Acara acara,
  ) async {
    final pengguna = ref.read(statusPenggunaProvider).valueOrNull;
    if (pengguna == null) return;
    try {
      final bundelPemilik = await ref
          .read(koreksiServiceProvider)
          .bundelPemilikAcara(acara.id, pengguna.uid);
      final semua = await ref
          .read(pencatatanServiceProvider)
          .semuaBundelStream(acara.id)
          .first;
      final lain = semua
          .where((b) => b.id != bundelPemilik.id && b.jumlahAmplop < 10)
          .toList();
      lain.sort((a, b) {
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
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => KoreksiAmplopScreen(
            acaraId: acara.id,
            bundel: bundelPemilik,
            bundelLain: lain,
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(pesanDari(e))));
    }
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
        // Batch 13: tombol melayang pencatat cukup ikon saja.
        return FloatingActionButton(
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
          tooltip: 'Catat Pengunjung',
          child: const Icon(Icons.edit_note_rounded),
        );
      },
    );
  }
}

class _InfoAcara extends StatelessWidget {
  const _InfoAcara({required this.acara, this.tampilkanKode = false});

  final Acara acara;

  /// true hanya di halaman pemilik (Batch 13): kode gabung +
  /// tombol salin tampil langsung di bawah tanggal acara, tanpa
  /// dropdown dan tanpa keterangan tambahan.
  final bool tampilkanKode;

  void _salinKode(BuildContext context) {
    Clipboard.setData(ClipboardData(text: acara.kodeGabung));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Kode gabung tersalin: ${acara.kodeGabung}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final skema = tema.colorScheme;
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
            if (tampilkanKode) ...[
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.key_rounded, size: 20, color: skema.primary),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 92,
                    child: Text(
                      'Kode Gabung',
                      style: tema.textTheme.bodySmall?.copyWith(
                        color: skema.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      acara.kodeGabung,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_outlined),
                    tooltip: 'Salin kode',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _salinKode(context),
                  ),
                ],
              ),
            ],
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
  bool _sibuk = false;

  @override
  void dispose() {
    _namaBaru.dispose();
    super.dispose();
  }

  /// Reset sesi pencatat [p] (Batch 10): lepaskan kunci sesi dari
  /// perangkat yang sedang memegangnya, supaya ia bisa masuk dari
  /// perangkat lain dengan nama + PIN-nya. Identitas dan
  /// semua data catatannya tetap menempel ke namanya.
  Future<void> _resetSesi(Pencatat p) async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reset sesi ${p.nama}?'),
        content: Text(
          'Sesi ${p.nama} di perangkat yang sekarang memegangnya '
          'akan dilepas. Setelah itu ia bisa masuk dari perangkat '
          'mana pun dengan namanya + PIN-nya.\n\n'
          'Bundel & pengunjung yang sudah ${p.nama} catat TIDAK berubah '
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

  /// Dialog atur/ganti PIN untuk satu undangan (Batch 10).
  /// Batch 23: isi dialog dipindah ke widget ber-State sendiri
  /// ([_DialogAturPin]) yang MEMILIKI controller-nya. Pola lama —
  /// controller dibuat di sini lalu di-dispose tepat setelah
  /// showDialog selesai — memunculkan layar merah
  /// "_dependents.isEmpty" saat Batal/Simpan ditekan, karena
  /// controller dibuang selagi pohon widget dialog belum selesai
  /// dilepas dari framework.
  Future<void> _aturPin({
    required String undanganId,
    required String nama,
    String? pinSaatIni,
  }) async {
    final pinBaru = await showDialog<String>(
      context: context,
      builder: (context) => _DialogAturPin(
        nama: nama,
        pinSaatIni: pinSaatIni,
      ),
    );
    if (pinBaru == null || !mounted) return;
    try {
      await ref
          .read(acaraServiceProvider)
          .aturPinPribadi(widget.acara.id, undanganId, pinBaru);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PIN $nama diperbarui.')),
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
          .tambahUndangan(widget.acara.id, _namaBaru.text);
      if (!mounted) return;
      _namaBaru.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${undangan.nama} didaftarkan sebagai pencatat '
            '${undangan.prefix} — PIN: '
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
        // Batch 23: padding atas 12 — form tambah pencatat tidak
        // lagi menempel ke judul bagian.
        childrenPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
                        title: Text(u.nama),
                        subtitle: Text(
                          'PIN: ${u.pinPribadi ?? 'belum diatur'}'
                          ' • menunggu gabung',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.key_outlined),
                              tooltip: 'Atur PIN',
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
                    // Batch 23 (permintaan Mark): detail pencatat
                    // disusun KE BAWAH — nama, lalu rincian per
                    // baris, lalu semua tombol aksi dalam SATU
                    // baris di bawahnya. Pola lama (ListTile dengan
                    // tiga aksi menumpuk di trailing) sempit dan
                    // teksnya terpotong di layar HP.
                    for (final p in daftar)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.nama,
                              style:
                                  Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Bundel terakhir: ${p.nomorBundelTerakhir}\n'
                              'PIN: ${p.pinPribadi ?? 'belum diatur'}\n'
                              '${p.uidAktif != null ? 'Sesi aktif di 1 perangkat' : 'Tidak sedang masuk'}',
                              style:
                                  Theme.of(context).textTheme.bodySmall,
                            ),
                            Row(
                              children: [
                                if (p.undanganId != null)
                                  IconButton(
                                    icon: const Icon(Icons.key_outlined),
                                    tooltip: 'Atur PIN',
                                    onPressed: () => _aturPin(
                                      undanganId: p.undanganId!,
                                      nama: p.nama,
                                      pinSaatIni: p.pinPribadi,
                                    ),
                                  ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.phonelink_erase_outlined,
                                  ),
                                  tooltip: 'Reset sesi (lepas perangkat)',
                                  onPressed: () => _resetSesi(p),
                                ),
                                const Spacer(),
                                Text(
                                  'Aktif',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall,
                                ),
                                Switch(
                                  value: p.aktif,
                                  onChanged: (v) =>
                                      layanan.setAktifPencatat(
                                    widget.acara.id,
                                    p.id,
                                    v,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 1),
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

/// Isi dialog atur PIN (Batch 23): StatefulWidget yang memiliki
/// controller teksnya sendiri — controller dibuang di dispose()
/// State ini, yaitu SETELAH rute dialog benar-benar dilepas dari
/// pohon widget. Mengembalikan PIN baru lewat Navigator.pop, atau
/// null bila dibatalkan.
class _DialogAturPin extends StatefulWidget {
  const _DialogAturPin({required this.nama, this.pinSaatIni});

  final String nama;
  final String? pinSaatIni;

  @override
  State<_DialogAturPin> createState() => _DialogAturPinState();
}

class _DialogAturPinState extends State<_DialogAturPin> {
  late final TextEditingController _kontrol;

  @override
  void initState() {
    super.initState();
    _kontrol = TextEditingController(text: widget.pinSaatIni ?? '');
  }

  @override
  void dispose() {
    _kontrol.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('PIN ${widget.nama}'),
      content: TextField(
        controller: _kontrol,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'PIN (4–6 digit angka)',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_kontrol.text),
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}

class _TombolStatus extends ConsumerWidget {
  const _TombolStatus({required this.acara});

  final Acara acara;

  /// Batch 20: ganti status selalu lewat dialog penjelasan dulu —
  /// pemilik tahu persis apa yang berubah sebelum menekan tombol.
  Future<void> _konfirmasi(BuildContext context, WidgetRef ref) async {
    final selesai = acara.sudahSelesai;
    final yakin = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          selesai ? 'Aktifkan kembali acara?' : 'Tandai acara selesai?',
        ),
        content: Text(
          selesai
              ? 'Setelah acara aktif lagi:\n\n'
                    '• Pencatat bisa kembali mencatat dan mengubah '
                    'inputannya sendiri.\n'
                    '• Koreksi oleh pemilik DITUTUP — tambah, ubah, '
                    'dan hapus pengunjung tidak bisa sampai acara '
                    'ditandai selesai lagi.\n\n'
                    'Data yang sudah ada tidak berubah.'
              : 'Setelah acara ditandai selesai:\n\n'
                    '• Pencatat TIDAK bisa lagi mencatat atau '
                    'mengubah catatannya.\n'
                    '• Kamu bisa mengoreksi data: menambah, '
                    'mengubah, dan menghapus pengunjung.\n'
                    '• Pengunjung tambahan yang kamu catat masuk '
                    'ke bundel khusus pemilik (kode PM001, PM002, '
                    '…).\n'
                    '• Rekap dan ekspor tetap bisa dibuka.\n\n'
                    'Acara bisa diaktifkan kembali kapan pun.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(selesai ? 'Aktifkan' : 'Tandai Selesai'),
          ),
        ],
      ),
    );
    if (yakin != true) return;
    await ref
        .read(acaraServiceProvider)
        .ubahStatusAcara(
          acara.id,
          selesai ? StatusAcara.aktif : StatusAcara.selesai,
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selesai = acara.sudahSelesai;
    return OutlinedButton.icon(
      onPressed: () => _konfirmasi(context, ref),
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
                  // Batch 13: tombol "Daftar Bundel Saya" dihapus —
                  // bundel milik pencatat kini ada di tab Bundel.
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
