import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../models/acara.dart';
import '../models/bundel.dart';
import '../models/pencatat.dart';
import '../providers.dart';
import '../services/layanan_exception.dart';
import '../widgets/keadaan.dart';
import 'daftar_bundel.dart';
import 'daftar_pengunjung.dart';
import 'koreksi_amplop.dart';
import 'pencatatan.dart';
import 'rekap.dart';

/// Detail satu acara.
///
/// - Untuk pemilik (Batch 7): dua tab — "Ringkasan" (info acara,
///   jumlah pengunjung & total, kode gabung + PIN, kelola pencatat,
///   tombol tandai selesai) dan "Pengunjung" (daftar semua amplop,
///   bisa dicari & diurutkan).
/// - Untuk pencatat: info acara + kartu prefix miliknya + tombol
///   "Mulai Mencatat" menuju layar pencatatan amplop (Batch 2).
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
          return Scaffold(
            appBar: AppBar(
              title: const Text('Detail Acara'),
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
                          'Data yang sudah tersinkron tetap aman di '
                          'server. Untuk masuk lagi sebagai pencatat, '
                          'kamu perlu kode acara dan PIN dari pemilik '
                          'acara.',
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
                      await ref.read(authServiceProvider).keluar();
                    }
                  },
                ),
              ],
            ),
            floatingActionButton: acara.sudahSelesai
                ? null
                : _FabPencatat(acara: acara),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _InfoAcara(acara: acara),
                const SizedBox(height: 16),
                _TotalAcara(acara: acara),
                const SizedBox(height: 16),
                _KartuPencatatSaya(acara: acara),
              ],
            ),
          );
        }
        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Detail Acara'),
              bottom: const TabBar(
                tabs: [
                  Tab(icon: Icon(Icons.summarize_outlined), text: 'Ringkasan'),
                  Tab(icon: Icon(Icons.people_outline), text: 'Pengunjung'),
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
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => DaftarBundelScreen(
                              acaraId: acara.id,
                              sebagaiPemilik: true,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.inventory_2_outlined),
                      label: const Text('Lihat Semua Bundel'),
                    ),
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
                DaftarPengunjungTab(acaraId: acara.id),
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    acara.namaAcara,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Chip(label: Text(acara.status.label)),
              ],
            ),
            const SizedBox(height: 8),
            Text('Tuan rumah: ${acara.tuanRumah}'),
            Text('Jenis: ${acara.jenis}'),
            Text('Tanggal: ${formatTanggal(acara.tanggal)}'),
            if (acara.lokasi != null) Text('Lokasi: ${acara.lokasi}'),
          ],
        ),
      ),
    );
  }
}

class _TotalAcara extends StatelessWidget {
  const _TotalAcara({required this.acara});

  final Acara acara;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _Angka(label: 'Pengunjung', nilai: '${acara.totalAmplop}'),
            _Angka(label: 'Bundel', nilai: '${acara.totalBundel}'),
            _Angka(label: 'Total', nilai: formatRupiah(acara.totalRp)),
          ],
        ),
      ),
    );
  }
}

class _Angka extends StatelessWidget {
  const _Angka({required this.label, required this.nilai});

  final String label;
  final String nilai;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(nilai, style: Theme.of(context).textTheme.titleMedium),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

/// Kode gabung + PIN untuk dibagikan pemilik ke para pencatat,
/// lengkap dengan tombol salin.
class _KartuKodeGabung extends ConsumerWidget {
  const _KartuKodeGabung({required this.acara});

  final Acara acara;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kode Gabung Pencatat',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Bagikan kode + PIN ini hanya ke pencatat yang sudah '
              'kamu daftarkan namanya di bawah.',
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
            FutureBuilder<String?>(
              future: ref
                  .read(acaraServiceProvider)
                  .ambilPinGabung(acara.kodeGabung),
              builder: (context, snapshot) {
                final pin = snapshot.data;
                return Row(
                  children: [
                    Expanded(
                      child: Text(
                        'PIN: ${pin ?? '...'}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (pin != null)
                      IconButton(
                        icon: const Icon(Icons.copy_outlined),
                        tooltip: 'Salin PIN',
                        onPressed: () => _salin(context, pin),
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
  bool _sibuk = false;

  @override
  void dispose() {
    _namaBaru.dispose();
    super.dispose();
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
            '${undangan.prefix}.',
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pencatat', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
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
                        subtitle: const Text(
                          'Menunggu gabung dengan kode + PIN',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Batalkan pendaftaran',
                          onPressed: () =>
                              layanan.hapusUndangan(widget.acara.id, u.id),
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
                          'Bundel terakhir: ${p.nomorBundelTerakhir}',
                        ),
                        trailing: Switch(
                          value: p.aktif,
                          onChanged: (v) => layanan.setAktifPencatat(
                            widget.acara.id,
                            p.id,
                            v,
                          ),
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
              children: [
                CircleAvatar(
                  radius: 30,
                  child: Text(
                    saya.prefix,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Kamu pencatat ${saya.prefix} — ${saya.nama}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  saya.aktif
                      ? acara.sudahSelesai
                            ? 'Acara sudah selesai — pencatatan ditutup.'
                            : 'Bundel terakhirmu: ${saya.nomorBundelTerakhir}.'
                      : 'Statusmu sedang dinonaktifkan pemilik acara.',
                  textAlign: TextAlign.center,
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
