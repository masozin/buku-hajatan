import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/kode.dart';
import '../core/pencatatan.dart';
import '../core/undangan.dart';
import '../models/acara.dart';
import '../models/amplop.dart';
import '../models/bundel.dart';
import '../models/pencatat.dart';
import '../models/tamu_undangan.dart';
import 'layanan_exception.dart';
import 'pencatatan_service.dart';

/// Operasi Firestore untuk Daftar Undangan (Batch 34, rancangan
/// multi-metode v2 §6): sub-koleksi `acara/{id}/tamuUndangan`.
///
/// Peran:
/// - Pemilik menyiapkan daftar sebelum acara (manual / tempel /
///   CSV) dan mengelolanya selama tamu belum berstatus hadir.
/// - Pencatat menandai hadir/tidak di hari-H; hadir dengan
///   amplop membuat amplop ke wadah metode acara milik pencatat
///   itu dan menautkannya (`amplopId`), hadir tanpa amplop hanya
///   menandai status (D4), salah tandai bisa dibatalkan selama
///   acara aktif oleh pencatat yang menandai.
/// - Tamu tak terdaftar (walk-in) TIDAK dibuat di sini — ia
///   lahir otomatis dari PencatatanService.simpanAmplop (§6.3).
///
/// Semua tulis memakai WriteBatch + FieldValue.increment (pola
/// yang sama dengan pencatatan), supaya tetap jalan offline.
/// Agregat kehadiran di dokumen acara diperbarui dalam batch
/// yang sama dengan perubahan statusnya.
class UndanganService {
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  final PencatatanService _pencatatan = PencatatanService();

  CollectionReference<Map<String, dynamic>> _tamuRef(String acaraId) =>
      _db.collection('acara').doc(acaraId).collection('tamuUndangan');

  DocumentReference<Map<String, dynamic>> _refAcara(String acaraId) =>
      _db.collection('acara').doc(acaraId);

  String get _uidSaya {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw const LayananException('Kamu belum masuk.');
    return uid;
  }

  Future<Acara> _bacaAcara(String acaraId) async {
    final doc = await _refAcara(acaraId).get();
    if (!doc.exists) throw const LayananException('Acara tidak ditemukan.');
    return Acara.fromFirestore(doc);
  }

  /// Pemilik acara ini (untuk pengelolaan daftar & tandai-tidak
  /// pasca-selesai).
  Future<Acara> _pastikanPemilik(String acaraId) async {
    final acara = await _bacaAcara(acaraId);
    if (acara.pemilikId != _uidSaya) {
      throw const LayananException(
        'Hanya pemilik acara yang boleh melakukan ini.',
      );
    }
    return acara;
  }

  /// Pengelolaan daftar (tambah/ubah/hapus) hanya selama acara
  /// masih aktif — setelah selesai daftar dibekukan, yang tersisa
  /// tandai-tidak / reset-tidak oleh pemilik.
  Future<Acara> _pastikanBisaKelola(String acaraId) async {
    final acara = await _pastikanPemilik(acaraId);
    if (acara.sudahSelesai) {
      throw const LayananException(
        'Acara sudah selesai — daftar undangan tidak bisa diubah lagi.',
      );
    }
    return acara;
  }

  /// Pencatat bersesi di acara ini (kunci sesi Batch 10).
  Future<Pencatat> _periksaSesiPencatat(
    String acaraId,
    String pencatatId,
  ) async {
    final doc = await _refAcara(
      acaraId,
    ).collection('pencatat').doc(pencatatId).get();
    if (!doc.exists) {
      throw const LayananException('Kamu belum terdaftar di acara ini.');
    }
    final pencatat = Pencatat.fromFirestore(doc, acaraId: acaraId);
    if (!pencatat.aktif) {
      throw const LayananException(
        'Statusmu sedang dinonaktifkan pemilik acara.',
      );
    }
    if (pencatat.uidAktif != _uidSaya) {
      throw const LayananException(
        'Sesi pencatat ini tidak sedang dipegang perangkat ini. '
        'Masuk lagi sebagai pencatat untuk mengambil sesi.',
      );
    }
    return pencatat;
  }

  Future<TamuUndangan> _bacaTamu(String acaraId, String tamuId) async {
    final doc = await _tamuRef(acaraId).doc(tamuId).get();
    if (!doc.exists) {
      throw const LayananException('Tamu tidak ditemukan. Muat ulang.');
    }
    return TamuUndangan.fromFirestore(doc);
  }

  /// Kode tamu yang belum dipakai di acara ini (tabrakan sangat
  /// jarang, tapi diperiksa — kodenya isi QR Batch 35).
  Future<String> _kodeTamuUnik(
    String acaraId,
    Set<String> dipakaiLokal,
  ) async {
    final sudahAda = <String>{
      ...dipakaiLokal,
      for (final t in await daftarUndanganSekali(acaraId)) t.kodeTamu,
    };
    for (var i = 0; i < 5; i++) {
      final kode = buatKodeTamu();
      if (!sudahAda.contains(kode)) return kode;
    }
    throw const LayananException(
      'Gagal membuat kode tamu — coba lagi sebentar.',
    );
  }

  static List<TamuUndangan> _urutkan(List<TamuUndangan> daftar) {
    daftar.sort((a, b) {
      final bandingNama = a.nama.toLowerCase().compareTo(
        b.nama.toLowerCase(),
      );
      if (bandingNama != 0) return bandingNama;
      return (a.alamat ?? '').compareTo(b.alamat ?? '');
    });
    return daftar;
  }

  // -------------------------------------------------------------- baca

  Stream<List<TamuUndangan>> daftarUndanganStream(String acaraId) {
    return _tamuRef(acaraId).snapshots().map((qs) {
      return _urutkan(qs.docs.map(TamuUndangan.fromFirestore).toList());
    });
  }

  Future<List<TamuUndangan>> daftarUndanganSekali(String acaraId) async {
    final qs = await _tamuRef(acaraId).get();
    return _urutkan(qs.docs.map(TamuUndangan.fromFirestore).toList());
  }

  // ------------------------------------------------------ kelola (pemilik)

  /// Tambah satu tamu manual (pemilik, selama acara aktif).
  Future<TamuUndangan> tambahTamu({
    required String acaraId,
    required String nama,
    String? alamat,
    String? dusun,
    int? rt,
    int? rw,
    String? kategori,
  }) async {
    final acara = await _pastikanBisaKelola(acaraId);
    if (!acara.fiturUndangan) {
      throw const LayananException(
        'Fitur Daftar Undangan tidak aktif di acara ini.',
      );
    }
    final namaBersih = nama.trim();
    if (namaBersih.isEmpty) {
      throw const LayananException('Nama tamu belum diisi.');
    }
    final kode = await _kodeTamuUnik(acaraId, const {});
    final ref = _tamuRef(acaraId).doc();
    final tamu = TamuUndangan(
      id: ref.id,
      nama: namaBersih,
      alamat: (alamat == null || alamat.trim().isEmpty)
          ? null
          : alamat.trim(),
      dusun: dusun,
      rt: rt,
      rw: rw,
      kategori: (kategori == null || kategori.trim().isEmpty)
          ? null
          : kategori.trim(),
      kodeTamu: kode,
    );
    final batch = _db.batch();
    batch.set(ref, tamu.toMap());
    batch.update(_refAcara(acaraId), <String, dynamic>{
      'totalUndangan': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    return tamu;
  }

  /// Tambah banyak tamu sekaligus (tempel teks / impor CSV —
  /// hasil parse dari core/undangan.dart). Mengembalikan jumlah
  /// yang tersimpan. Dibatasi 200 baris per panggilan (batas
  /// batch tulis Firestore) — bagi daftarnya bila lebih.
  Future<int> tambahBanyak({
    required String acaraId,
    required List<BarisTamu> daftar,
  }) async {
    final acara = await _pastikanBisaKelola(acaraId);
    if (!acara.fiturUndangan) {
      throw const LayananException(
        'Fitur Daftar Undangan tidak aktif di acara ini.',
      );
    }
    if (daftar.isEmpty) {
      throw const LayananException('Tidak ada baris tamu yang valid.');
    }
    if (daftar.length > 200) {
      throw const LayananException(
        'Maksimal 200 tamu sekali simpan — bagi daftarnya menjadi '
        'dua bagian.',
      );
    }
    // Kode tamu dicek sekali di awal (bukan per baris) supaya
    // impor 200 baris tidak membaca daftar 200 kali.
    final dipakai = <String>{
      for (final t in await daftarUndanganSekali(acaraId)) t.kodeTamu,
    };
    final batch = _db.batch();
    for (final baris in daftar) {
      var kode = buatKodeTamu();
      var percobaan = 0;
      while (dipakai.contains(kode) && percobaan < 5) {
        kode = buatKodeTamu();
        percobaan++;
      }
      if (dipakai.contains(kode)) {
        throw const LayananException(
          'Gagal membuat kode tamu — coba lagi sebentar.',
        );
      }
      dipakai.add(kode);
      final ref = _tamuRef(acaraId).doc();
      batch.set(
        ref,
        TamuUndangan(
          id: ref.id,
          nama: baris.nama,
          alamat: baris.alamat,
          dusun: baris.dusun,
          rt: baris.rt,
          rw: baris.rw,
          kategori: baris.kategori,
          kodeTamu: kode,
        ).toMap(),
      );
    }
    batch.update(_refAcara(acaraId), <String, dynamic>{
      'totalUndangan': FieldValue.increment(daftar.length),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    return daftar.length;
  }

  /// Ubah data tamu — hanya selama statusnya masih 'belum'.
  /// Setelah ditandai hadir/tidak, identitasnya dibekukan (yang
  /// boleh berubah hanya statusnya).
  Future<void> ubahTamu({
    required String acaraId,
    required TamuUndangan tamu,
    required String nama,
    String? alamat,
    String? dusun,
    int? rt,
    int? rw,
    String? kategori,
  }) async {
    await _pastikanBisaKelola(acaraId);
    final kini = await _bacaTamu(acaraId, tamu.id);
    if (kini.statusHadir != StatusHadir.belum) {
      throw const LayananException(
        'Tamu yang sudah ditandai hadir/tidak tidak bisa diubah '
        'lagi — batalkan dulu tandanya.',
      );
    }
    final namaBersih = nama.trim();
    if (namaBersih.isEmpty) {
      throw const LayananException('Nama tamu belum diisi.');
    }
    await _tamuRef(acaraId).doc(tamu.id).update(<String, dynamic>{
      'nama': namaBersih,
      'alamat': (alamat == null || alamat.trim().isEmpty) ? null : alamat.trim(),
      'dusun': dusun,
      'rt': rt,
      'rw': rw,
      'kategori': (kategori == null || kategori.trim().isEmpty)
          ? null
          : kategori.trim(),
    });
  }

  /// Hapus tamu — hanya selama statusnya masih 'belum'.
  Future<void> hapusTamu({
    required String acaraId,
    required TamuUndangan tamu,
  }) async {
    await _pastikanBisaKelola(acaraId);
    final kini = await _bacaTamu(acaraId, tamu.id);
    if (kini.statusHadir != StatusHadir.belum) {
      throw const LayananException(
        'Tamu yang sudah ditandai hadir/tidak tidak bisa dihapus.',
      );
    }
    final batch = _db.batch();
    batch.delete(_tamuRef(acaraId).doc(tamu.id));
    batch.update(_refAcara(acaraId), <String, dynamic>{
      'totalUndangan': FieldValue.increment(-1),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  // ------------------------------------------------- tandai hadir / tidak

  /// Tandai hadir DENGAN amplop (pencatat, selama acara aktif):
  /// membuat amplop ke wadah metode acara milik pencatat ini
  /// (bundel aktif / bundel bebas), menautkan amplopId-nya,
  /// dan menaikkan agregat kehadiran + uang dalam satu batch.
  Future<void> tandaiHadirDenganAmplop({
    required String acaraId,
    required String pencatatId,
    required TamuUndangan tamu,
    required JenisAmplop jenis,
    required int nominal,
  }) async {
    final acara = await _bacaAcara(acaraId);
    if (acara.sudahSelesai) {
      throw const LayananException(
        'Acara sudah selesai — penandaan hadir ditutup.',
      );
    }
    if (!acara.fiturUndangan) {
      throw const LayananException(
        'Fitur Daftar Undangan tidak aktif di acara ini.',
      );
    }
    final pencatat = await _periksaSesiPencatat(acaraId, pencatatId);
    final kini = await _bacaTamu(acaraId, tamu.id);
    if (kini.statusHadir != StatusHadir.belum) {
      throw LayananException(
        'Tamu ini sudah ditandai ${kini.statusHadir.label.toLowerCase()}.',
      );
    }
    final galat = validasiAmplop(
      jenis: jenis,
      nama: kini.nama,
      nominal: nominal,
    );
    if (galat != null) throw LayananException(galat);

    final bundel = acara.metodeLangsung
        ? await _pencatatan.bukaBundelBebas(
            acaraId: acaraId,
            pencatatId: pencatatId,
          )
        : await _pencatatan.bukaBundelAktif(
            acaraId: acaraId,
            pencatatId: pencatatId,
          );
    final refBundel = _db
        .collection('acara')
        .doc(acaraId)
        .collection('bundel')
        .doc(bundel.id);
    final docBundel = await refBundel.get();
    if (!docBundel.exists) {
      throw const LayananException('Bundel tidak ditemukan. Buka lagi.');
    }
    final bundelKini = Bundel.fromFirestore(docBundel, acaraId: acaraId);
    if (bundelKini.pencatatId != pencatatId) {
      throw const LayananException('Bundel ini milik pencatat lain.');
    }
    if (!bundelKini.bebas && bundelPenuh(bundelKini.jumlahAmplop)) {
      throw LayananException(
        'Bundel ${bundelKini.kode} sudah penuh — buka bundel baru.',
      );
    }

    final urut = urutBerikutnya(bundelKini.jumlahAmplop);
    final menutup =
        !bundelKini.bebas &&
        amplopIniMenutupBundel(bundelKini.jumlahAmplop);
    final nominalEfektif = nominalSimpan(jenis, nominal);
    final refAmplop = refBundel.collection('amplop').doc();
    final amplop = Amplop(
      id: refAmplop.id,
      bundelId: bundelKini.id,
      urut: urut,
      nama: namaSimpan(jenis, kini.nama),
      alamat: kini.alamat,
      dusun: kini.dusun,
      rt: kini.rt,
      rw: kini.rw,
      keterangan: null,
      nominal: nominalEfektif,
      jenis: jenis,
      createdBy: pencatatId,
      tamuId: kini.id,
    );

    final batch = _db.batch();
    batch.set(refAmplop, amplop.toMap());
    batch.update(refBundel, <String, dynamic>{
      'jumlahAmplop': FieldValue.increment(1),
      'totalRp': FieldValue.increment(nominalEfektif),
      if (jenis == JenisAmplop.kosong)
        'jumlahKosong': FieldValue.increment(1),
      if (jenis == JenisAmplop.tanpaNama)
        'jumlahTanpaNama': FieldValue.increment(1),
      if (menutup) 'status': StatusBundel.penuh.name,
      if (menutup) 'ditutupAt': FieldValue.serverTimestamp(),
    });
    batch.update(_refAcara(acaraId), <String, dynamic>{
      'totalAmplop': FieldValue.increment(1),
      'totalRp': FieldValue.increment(nominalEfektif),
      'totalHadir': FieldValue.increment(1),
      'totalRpHadir': FieldValue.increment(nominalEfektif),
      'updatedAt': FieldValue.serverTimestamp(),
      if (menutup) 'totalBundel': FieldValue.increment(1),
    });
    batch.update(_tamuRef(acaraId).doc(kini.id), <String, dynamic>{
      'statusHadir': StatusHadir.hadir.nilaiSimpan,
      'hadirAt': FieldValue.serverTimestamp(),
      'amplopId': refAmplop.id,
      'dicatatOleh': pencatatId,
    });
    if (menutup) {
      final refBaru = _db
          .collection('acara')
          .doc(acaraId)
          .collection('bundel')
          .doc();
      batch.set(
        refBaru,
        Bundel(
          id: refBaru.id,
          acaraId: acaraId,
          pencatatId: pencatatId,
          prefix: pencatat.prefix,
          nomor: bundelKini.nomor + 1,
        ).toMap(),
      );
      batch.update(
        _refAcara(acaraId).collection('pencatat').doc(pencatatId),
        <String, dynamic>{'nomorBundelTerakhir': bundelKini.nomor + 1},
      );
    }
    await batch.commit();
  }

  /// Tandai hadir TANPA amplop (D4 — pencatat, selama acara
  /// aktif): hanya status; uang tidak terpengaruh, tidak ada
  /// amplop yang dibuat.
  Future<void> tandaiHadirTanpaAmplop({
    required String acaraId,
    required String pencatatId,
    required TamuUndangan tamu,
  }) async {
    final acara = await _bacaAcara(acaraId);
    if (acara.sudahSelesai) {
      throw const LayananException(
        'Acara sudah selesai — penandaan hadir ditutup.',
      );
    }
    if (!acara.fiturUndangan) {
      throw const LayananException(
        'Fitur Daftar Undangan tidak aktif di acara ini.',
      );
    }
    await _periksaSesiPencatat(acaraId, pencatatId);
    final kini = await _bacaTamu(acaraId, tamu.id);
    if (kini.statusHadir != StatusHadir.belum) {
      throw LayananException(
        'Tamu ini sudah ditandai ${kini.statusHadir.label.toLowerCase()}.',
      );
    }
    final batch = _db.batch();
    batch.update(_tamuRef(acaraId).doc(kini.id), <String, dynamic>{
      'statusHadir': StatusHadir.hadir.nilaiSimpan,
      'hadirAt': FieldValue.serverTimestamp(),
      'dicatatOleh': pencatatId,
    });
    batch.update(_refAcara(acaraId), <String, dynamic>{
      'totalHadir': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  /// Tandai TIDAK hadir. Boleh oleh pencatat selama acara aktif,
  /// atau oleh pemilik kapan pun — termasuk setelah acara selesai
  /// (rancangan §6.3). [pencatatId] null = panggilan pemilik.
  Future<void> tandaiTidak({
    required String acaraId,
    required TamuUndangan tamu,
    String? pencatatId,
  }) async {
    final acara = await _bacaAcara(acaraId);
    if (!acara.fiturUndangan) {
      throw const LayananException(
        'Fitur Daftar Undangan tidak aktif di acara ini.',
      );
    }
    String penanda;
    if (pencatatId != null) {
      if (acara.sudahSelesai) {
        throw const LayananException(
          'Acara sudah selesai — penandaan oleh pencatat ditutup.',
        );
      }
      await _periksaSesiPencatat(acaraId, pencatatId);
      penanda = pencatatId;
    } else {
      await _pastikanPemilik(acaraId);
      penanda = _uidSaya;
    }
    final kini = await _bacaTamu(acaraId, tamu.id);
    if (kini.statusHadir != StatusHadir.belum) {
      throw LayananException(
        'Tamu ini sudah ditandai ${kini.statusHadir.label.toLowerCase()}.',
      );
    }
    final batch = _db.batch();
    batch.update(_tamuRef(acaraId).doc(kini.id), <String, dynamic>{
      'statusHadir': StatusHadir.tidak.nilaiSimpan,
      'dicatatOleh': penanda,
    });
    batch.update(_refAcara(acaraId), <String, dynamic>{
      'totalTidakHadir': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  /// Kembalikan tamu 'tidak hadir' menjadi 'belum' (pemilik,
  /// kapan pun) — mis. salah tandai setelah acara selesai.
  Future<void> resetTidak({
    required String acaraId,
    required TamuUndangan tamu,
  }) async {
    await _pastikanPemilik(acaraId);
    final kini = await _bacaTamu(acaraId, tamu.id);
    if (kini.statusHadir != StatusHadir.tidak) {
      throw const LayananException(
        'Hanya tamu berstatus tidak hadir yang bisa dikembalikan.',
      );
    }
    final batch = _db.batch();
    batch.update(_tamuRef(acaraId).doc(kini.id), <String, dynamic>{
      'statusHadir': StatusHadir.belum.nilaiSimpan,
      'dicatatOleh': FieldValue.delete(),
    });
    batch.update(_refAcara(acaraId), <String, dynamic>{
      'totalTidakHadir': FieldValue.increment(-1),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  /// Batalkan tanda hadir (pencatat yang menandai, selama acara
  /// aktif): status kembali 'belum'; amplop yang terlanjur dibuat
  /// DIHAPUS dalam batch yang sama dan agregatnya mundur. Bila
  /// hadir tanpa amplop, hanya status + agregat yang mundur.
  Future<void> batalTandai({
    required String acaraId,
    required String pencatatId,
    required TamuUndangan tamu,
  }) async {
    final acara = await _bacaAcara(acaraId);
    if (acara.sudahSelesai) {
      throw const LayananException(
        'Acara sudah selesai — pembatalan lewat pemilik acara.',
      );
    }
    await _periksaSesiPencatat(acaraId, pencatatId);
    final kini = await _bacaTamu(acaraId, tamu.id);
    if (kini.statusHadir != StatusHadir.hadir) {
      throw const LayananException('Tamu ini tidak sedang ditandai hadir.');
    }
    if (kini.dicatatOleh != pencatatId) {
      throw const LayananException(
        'Hanya pencatat yang menandai tamu ini yang boleh '
        'membatalkannya.',
      );
    }

    final batch = _db.batch();
    final updateAcara = <String, dynamic>{
      'totalHadir': FieldValue.increment(-1),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (kini.amplopId != null) {
      // Cari amplop + bundelnya: amplop selalu berada di bundel
      // milik pencatat yang menandai.
      final snapBundel = await _db
          .collection('acara')
          .doc(acaraId)
          .collection('bundel')
          .where('pencatatId', isEqualTo: pencatatId)
          .get();
      DocumentSnapshot<Map<String, dynamic>>? docAmplop;
      Bundel? bundelAmplop;
      for (final docB in snapBundel.docs) {
        final coba = await docB.reference
            .collection('amplop')
            .doc(kini.amplopId!)
            .get();
        if (coba.exists) {
          docAmplop = coba;
          bundelAmplop = Bundel.fromFirestore(docB, acaraId: acaraId);
          break;
        }
      }
      if (docAmplop == null || bundelAmplop == null) {
        throw const LayananException(
          'Amplop tertaut tidak ditemukan. Muat ulang.',
        );
      }
      final amplop = Amplop.fromFirestore(
        docAmplop,
        bundelId: bundelAmplop.id,
      );
      final refBundel = _db
          .collection('acara')
          .doc(acaraId)
          .collection('bundel')
          .doc(bundelAmplop.id);
      final tadinyaPenuh =
          !bundelAmplop.bebas && bundelPenuh(bundelAmplop.jumlahAmplop);
      batch.delete(docAmplop.reference);
      batch.update(refBundel, <String, dynamic>{
        'jumlahAmplop': FieldValue.increment(-1),
        'totalRp': FieldValue.increment(-amplop.nominal),
        if (amplop.jenis == JenisAmplop.kosong)
          'jumlahKosong': FieldValue.increment(-1),
        if (amplop.jenis == JenisAmplop.tanpaNama)
          'jumlahTanpaNama': FieldValue.increment(-1),
        if (tadinyaPenuh) 'status': StatusBundel.terbuka.name,
        if (tadinyaPenuh) 'ditutupAt': FieldValue.delete(),
      });
      updateAcara['totalAmplop'] = FieldValue.increment(-1);
      updateAcara['totalRp'] = FieldValue.increment(-amplop.nominal);
      updateAcara['totalRpHadir'] = FieldValue.increment(-amplop.nominal);
    }
    batch.update(_refAcara(acaraId), updateAcara);
    batch.update(_tamuRef(acaraId).doc(kini.id), <String, dynamic>{
      'statusHadir': StatusHadir.belum.nilaiSimpan,
      'hadirAt': FieldValue.delete(),
      'amplopId': FieldValue.delete(),
      'dicatatOleh': FieldValue.delete(),
    });
    await batch.commit();
  }

  /// Hadir dari perangkat Buku Tamu (Batch 34, §6.3): tamu
  /// menemukan namanya sendiri di daftar, lalu mengisi identitas
  /// di form buku tamu. Amplopnya lahir BELUM DIHITUNG seperti
  /// entri Buku Tamu biasa (Batch 32) — nominal menyusul lewat
  /// Mode Hitung; tautan tamuId menjaga totalRpHadir ikut naik
  /// saat dihitung. [bundel] adalah bundel bebas perangkat ini
  /// (sudah dibuka layar Buku Tamu).
  Future<void> tandaiHadirBukuTamu({
    required String acaraId,
    required String pencatatId,
    required Bundel bundel,
    required TamuUndangan tamu,
    required String nama,
    String? alamat,
    String? dusun,
    int? rt,
    int? rw,
    String? keterangan,
  }) async {
    final acara = await _bacaAcara(acaraId);
    if (acara.sudahSelesai) {
      throw const LayananException(
        'Acara sudah selesai — penandaan hadir ditutup.',
      );
    }
    if (!acara.fiturUndangan) {
      throw const LayananException(
        'Fitur Daftar Undangan tidak aktif di acara ini.',
      );
    }
    await _periksaSesiPencatat(acaraId, pencatatId);
    final kini = await _bacaTamu(acaraId, tamu.id);
    if (kini.statusHadir != StatusHadir.belum) {
      throw LayananException(
        'Tamu ini sudah ditandai ${kini.statusHadir.label.toLowerCase()}.',
      );
    }
    if (!bundel.bebas) {
      throw const LayananException(
        'Buku Tamu memakai bundel bebas — muat ulang layar ini.',
      );
    }
    final refBundel = _db
        .collection('acara')
        .doc(acaraId)
        .collection('bundel')
        .doc(bundel.id);
    final docBundel = await refBundel.get();
    if (!docBundel.exists) {
      throw const LayananException('Bundel tidak ditemukan. Buka lagi.');
    }
    final bundelKini = Bundel.fromFirestore(docBundel, acaraId: acaraId);
    if (bundelKini.pencatatId != pencatatId) {
      throw const LayananException('Bundel ini milik pencatat lain.');
    }
    final namaBersih = nama.trim();
    if (namaBersih.isEmpty) {
      throw const LayananException('Nama tamu belum diisi.');
    }

    final refAmplop = refBundel.collection('amplop').doc();
    final amplop = Amplop(
      id: refAmplop.id,
      bundelId: bundelKini.id,
      urut: urutBerikutnya(bundelKini.jumlahAmplop),
      nama: namaBersih,
      alamat: (alamat == null || alamat.trim().isEmpty)
          ? null
          : alamat.trim(),
      dusun: dusun,
      rt: rt,
      rw: rw,
      keterangan: (keterangan == null || keterangan.trim().isEmpty)
          ? null
          : keterangan.trim(),
      nominal: 0,
      jenis: JenisAmplop.normal,
      createdBy: pencatatId,
      dihitung: false,
      tamuId: kini.id,
    );

    final batch = _db.batch();
    batch.set(refAmplop, amplop.toMap());
    batch.update(refBundel, <String, dynamic>{
      'jumlahAmplop': FieldValue.increment(1),
    });
    batch.update(_refAcara(acaraId), <String, dynamic>{
      'totalAmplop': FieldValue.increment(1),
      'totalHadir': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.update(_tamuRef(acaraId).doc(kini.id), <String, dynamic>{
      'statusHadir': StatusHadir.hadir.nilaiSimpan,
      'hadirAt': FieldValue.serverTimestamp(),
      'amplopId': refAmplop.id,
      'dicatatOleh': pencatatId,
    });
    await batch.commit();
  }
}
