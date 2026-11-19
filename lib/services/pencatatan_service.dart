import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/kode.dart';
import '../core/koreksi.dart';
import '../core/pencatatan.dart';
import '../models/acara.dart';
import '../models/amplop.dart';
import '../models/bundel.dart';
import '../models/pencatat.dart';
import '../models/tamu_undangan.dart';
import 'layanan_exception.dart';

/// Satu amplop beserta status sinkronnya (dari metadata dokumen).
class AmplopTercatat {
  const AmplopTercatat({required this.amplop, required this.menungguSinkron});

  final Amplop amplop;

  /// true = masih di antrean lokal HP, belum terkirim ke server.
  final bool menungguSinkron;
}

/// Hasil simpan satu amplop.
class HasilSimpanAmplop {
  const HasilSimpanAmplop({
    required this.bundelSesudah,
    required this.menutupBundel,
    this.bundelBaru,
  });

  /// Bundel lama sesudah amplop ini masuk (jumlah/total terbaru).
  final Bundel bundelSesudah;

  /// true bila amplop ini adalah amplop ke-10 (bundel baru saja penuh).
  final bool menutupBundel;

  /// Bundel berikutnya yang langsung dibuka (hanya bila menutupBundel).
  final Bundel? bundelBaru;
}

/// Operasi Firestore untuk pencatatan hari-H (Batch 2).
///
/// Struktur data mengikuti rancangan teknis §1–§2:
/// `acara/{acaraId}/bundel/{bundelId}/amplop/{amplopId}`.
///
/// Semua tulis memakai WriteBatch + FieldValue.increment, BUKAN
/// transaction — supaya tetap jalan saat offline (tulis masuk antrean
/// lokal HP dan terkirim saat ada jaringan). Keamanan penomorannya
/// bersandar pada asumsi desain: satu pencatat = satu HP, prefix unik
/// per pencatat, jadi nomor bundel hanya dijaga oleh HP itu sendiri.
/// Aturan "maks 10 amplop per bundel" dijaga aplikasi di sini; Rules
/// hanya memvalidasi field (lihat firestore.rules).
class PencatatanService {
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _bundelRef(String acaraId) =>
      _db.collection('acara').doc(acaraId).collection('bundel');

  /// Kunci sesi (Batch 10): pencatat hanya boleh mencatat dari
  /// perangkat yang sedang memegang sesinya (uidAktif == UID
  /// perangkat ini). Penegakan utama ada di rules; pemeriksaan ini
  /// memberi pesan yang jelas di aplikasi.
  void _periksaSesi(Pencatat pencatat) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (pencatat.uidAktif != uid) {
      throw const LayananException(
        'Sesi pencatat ini tidak sedang dipegang perangkat ini. '
        'Masuk lagi sebagai pencatat untuk mengambil sesi.',
      );
    }
  }

  // -------------------------------------------------------------- bundel

  /// Bundel milik satu pencatat di acara ini, urut nomor menaik.
  Stream<List<Bundel>> bundelPencatatStream(
    String acaraId,
    String pencatatId,
  ) {
    return _bundelRef(acaraId)
        .where('pencatatId', isEqualTo: pencatatId)
        .snapshots()
        .map((qs) {
          final daftar = qs.docs
              .map((d) => Bundel.fromFirestore(d, acaraId: acaraId))
              .toList();
          daftar.sort((a, b) => a.nomor.compareTo(b.nomor));
          return daftar;
        });
  }

  /// Semua bundel di acara ini (untuk pemilik), urut prefix lalu nomor.
  Stream<List<Bundel>> semuaBundelStream(String acaraId) {
    return _bundelRef(acaraId).snapshots().map((qs) {
      final daftar = qs.docs
          .map((d) => Bundel.fromFirestore(d, acaraId: acaraId))
          .toList();
      daftar.sort((a, b) {
        final bandingPrefix = a.prefix.compareTo(b.prefix);
        return bandingPrefix != 0
            ? bandingPrefix
            : a.nomor.compareTo(b.nomor);
      });
      return daftar;
    });
  }

  /// Buka (atau buat bila belum ada) bundel aktif pencatat ini.
  ///
  /// - Bila bundel bernomor terakhir masih terbuka, kembalikan itu.
  /// - Bila belum ada bundel sama sekali, buat bundel nomor 1.
  /// - Bila bundel terakhir sudah penuh, buat bundel berikutnya.
  /// Pembuatan bundel menaikkan `pencatat.nomorBundelTerakhir` dan
  /// agregat `acara.totalBundel` dalam batch yang sama.
  Future<Bundel> bukaBundelAktif({
    required String acaraId,
    required String pencatatId,
  }) async {
    final refAcara = _db.collection('acara').doc(acaraId);
    final refPencatat = refAcara.collection('pencatat').doc(pencatatId);

    final docAcara = await refAcara.get();
    if (!docAcara.exists) {
      throw const LayananException('Acara tidak ditemukan.');
    }
    final acara = Acara.fromFirestore(docAcara);
    if (acara.sudahSelesai) {
      throw const LayananException(
        'Acara sudah selesai — pencatatan ditutup.',
      );
    }

    final docPencatat = await refPencatat.get();
    if (!docPencatat.exists) {
      throw const LayananException('Kamu belum terdaftar di acara ini.');
    }
    final pencatat = Pencatat.fromFirestore(docPencatat, acaraId: acaraId);
    if (!pencatat.aktif) {
      throw const LayananException(
        'Statusmu sedang dinonaktifkan pemilik acara.',
      );
    }
    _periksaSesi(pencatat);

    final snap = await _bundelRef(
      acaraId,
    ).where('pencatatId', isEqualTo: pencatatId).get();
    // Bundel aktif selalu bernomor terbesar (bundel baru hanya dibuat
    // saat bundel sebelumnya penuh), jadi cukup periksa yang terbesar.
    Bundel? terakhir;
    var nomorTerbesar = pencatat.nomorBundelTerakhir;
    for (final doc in snap.docs) {
      final bundel = Bundel.fromFirestore(doc, acaraId: acaraId);
      if (terakhir == null || bundel.nomor > terakhir.nomor) {
        terakhir = bundel;
      }
      if (bundel.nomor > nomorTerbesar) nomorTerbesar = bundel.nomor;
    }
    if (terakhir != null && terakhir.status == StatusBundel.terbuka) {
      return terakhir;
    }

    final nomorBaru = nomorTerbesar + 1;
    final refBundelBaru = _bundelRef(acaraId).doc();
    final bundelBaru = Bundel(
      id: refBundelBaru.id,
      acaraId: acaraId,
      pencatatId: pencatatId,
      prefix: pencatat.prefix,
      nomor: nomorBaru,
    );

    final batch = _db.batch();
    batch.set(refBundelBaru, bundelBaru.toMap());
    batch.update(refPencatat, <String, dynamic>{
      'nomorBundelTerakhir': nomorBaru,
    });
    batch.update(refAcara, <String, dynamic>{
      'totalBundel': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    return bundelBaru;
  }

  /// Buka (atau buat bila belum ada) BUNDEL BEBAS pencatat ini
  /// (Batch 30, Metode Langsung): satu wadah per pencatat yang
  /// tidak pernah penuh. Berbeda dengan bundel fisik: pembuatan-
  /// nya TIDAK menaikkan totalBundel acara maupun
  /// nomorBundelTerakhir pencatat, dan penulisannya cukup satu
  /// set (tidak ada agregat lain yang berubah).
  Future<Bundel> bukaBundelBebas({
    required String acaraId,
    required String pencatatId,
  }) async {
    final refAcara = _db.collection('acara').doc(acaraId);
    final refPencatat = refAcara.collection('pencatat').doc(pencatatId);

    final docAcara = await refAcara.get();
    if (!docAcara.exists) {
      throw const LayananException('Acara tidak ditemukan.');
    }
    if (Acara.fromFirestore(docAcara).sudahSelesai) {
      throw const LayananException(
        'Acara sudah selesai — pencatatan ditutup.',
      );
    }
    final docPencatat = await refPencatat.get();
    if (!docPencatat.exists) {
      throw const LayananException('Kamu belum terdaftar di acara ini.');
    }
    final pencatat = Pencatat.fromFirestore(docPencatat, acaraId: acaraId);
    if (!pencatat.aktif) {
      throw const LayananException(
        'Statusmu sedang dinonaktifkan pemilik acara.',
      );
    }
    _periksaSesi(pencatat);

    final snap = await _bundelRef(
      acaraId,
    ).where('pencatatId', isEqualTo: pencatatId).get();
    for (final doc in snap.docs) {
      final bundel = Bundel.fromFirestore(doc, acaraId: acaraId);
      if (bundel.bebas) return bundel;
    }

    final refBaru = _bundelRef(acaraId).doc();
    final baru = Bundel(
      id: refBaru.id,
      acaraId: acaraId,
      pencatatId: pencatatId,
      prefix: pencatat.prefix,
      nomor: 0,
      bebas: true,
    );
    await refBaru.set(baru.toMap());
    return baru;
  }

  // -------------------------------------------------------------- amplop

  /// Isi satu bundel, urut 1..10, lengkap dengan status sinkron
  /// tiap baris (hasPendingWrites dari metadata dokumen).
  Stream<List<AmplopTercatat>> amplopBundelStream(
    String acaraId,
    String bundelId,
  ) {
    return _bundelRef(
      acaraId,
    ).doc(bundelId).collection('amplop').snapshots(
      includeMetadataChanges: true,
    ).map((qs) {
      final daftar = qs.docs
          .map(
            (d) => AmplopTercatat(
              amplop: Amplop.fromFirestore(d, bundelId: bundelId),
              menungguSinkron: d.metadata.hasPendingWrites,
            ),
          )
          .toList();
      daftar.sort((a, b) => a.amplop.urut.compareTo(b.amplop.urut));
      return daftar;
    });
  }

  /// Simpan satu amplop ke bundel aktif pencatat.
  ///
  /// Satu batch tulis: dokumen amplop + agregat bundel + agregat acara.
  /// Bila ini amplop ke-10, bundel ditutup (status penuh + ditutupAt),
  /// bundel berikutnya langsung dibuat, dan nomorBundelTerakhir naik.
  Future<HasilSimpanAmplop> simpanAmplop({
    required String acaraId,
    required String pencatatId,
    required Bundel bundel,
    required JenisAmplop jenis,
    required String nama,
    String? alamat,
    int? dusun,
    int? rt,
    int? rw,
    String? keterangan,
    required int nominal,
    bool dihitung = true,
  }) async {
    // Batch 32: entri Buku Tamu lahir BELUM dihitung (dihitung
    // false) — tamu hanya mengisi identitas, nominal menyusul
    // lewat Mode Hitung; validasinya cukup nama terisi.
    final galat = dihitung
        ? validasiAmplop(jenis: jenis, nama: nama, nominal: nominal)
        : (nama.trim().isEmpty ? 'Nama tamu belum diisi.' : null);
    if (galat != null) throw LayananException(galat);

    final namaEfektif = namaSimpan(jenis, nama);
    final nominalEfektif = nominalSimpan(jenis, nominal);
    final alamatEfektif = (alamat == null || alamat.trim().isEmpty)
        ? null
        : alamat.trim();

    final refAcara = _db.collection('acara').doc(acaraId);
    final refPencatat = refAcara.collection('pencatat').doc(pencatatId);
    final refBundel = _bundelRef(acaraId).doc(bundel.id);

    // Baca ulang keadaan terbaru (dari cache bila offline) supaya
    // urut & hitung penuh tidak memakai data basi dari layar.
    final docAcara = await refAcara.get();
    if (!docAcara.exists) {
      throw const LayananException('Acara tidak ditemukan.');
    }
    final acara = Acara.fromFirestore(docAcara);
    if (acara.sudahSelesai) {
      throw const LayananException(
        'Acara sudah selesai — pencatatan ditutup.',
      );
    }
    final docPencatat = await refPencatat.get();
    if (!docPencatat.exists) {
      throw const LayananException('Kamu belum terdaftar di acara ini.');
    }
    final pencatat = Pencatat.fromFirestore(docPencatat, acaraId: acaraId);
    if (!pencatat.aktif) {
      throw const LayananException(
        'Statusmu sedang dinonaktifkan pemilik acara.',
      );
    }
    _periksaSesi(pencatat);
    final docBundel = await refBundel.get();
    if (!docBundel.exists) {
      throw const LayananException('Bundel tidak ditemukan. Buka lagi.');
    }
    final bundelKini = Bundel.fromFirestore(docBundel, acaraId: acaraId);
    if (bundelKini.pencatatId != pencatatId) {
      throw const LayananException('Bundel ini milik pencatat lain.');
    }
    // Bundel bebas (Batch 30) tidak pernah penuh dan tidak
    // pernah menutup — urutnya berjalan terus.
    if (!bundelKini.bebas && bundelPenuh(bundelKini.jumlahAmplop)) {
      throw LayananException(
        'Bundel ${bundelKini.kode} sudah penuh — buka bundel baru.',
      );
    }

    final urut = urutBerikutnya(bundelKini.jumlahAmplop);
    final menutup =
        !bundelKini.bebas &&
        amplopIniMenutupBundel(bundelKini.jumlahAmplop);

    // Batch 34: tamu tak terdaftar (walk-in) — bila fitur Daftar
    // Undangan menyala, catatan manual ini otomatis membuat baris
    // tamu asal 'langsung' berstatus hadir + menautkannya, supaya
    // daftar kehadiran tetap lengkap (§6.3). Tanpa Nama tidak
    // dibuatkan baris (tidak ada nama untuk dicari). Catatan LEWAT
    // Daftar Undangan tidak lewat sini (UndanganService membuat
    // amplopnya sendiri), jadi tidak ada ganda. Konsekuensi yang
    // perlu diketahui petugas: mengetik manual nama tamu yang
    // sebenarnya sudah ada di daftar akan tercatat sebagai
    // walk-in kedua — pakai Daftar Undangan untuk tamu terdaftar.
    // Kode tamu dibuat acak tanpa cek tabrakan di sini (ruang
    // 62^8 — tabrakan praktis mustahil; daftar yang diimpor
    // pemilik tetap dicek di UndanganService).
    final walkIn =
        acara.fiturUndangan &&
        jenis != JenisAmplop.tanpaNama &&
        namaEfektif.trim().isNotEmpty;
    final refAmplop = refBundel.collection('amplop').doc();
    final refTamuWalkIn = walkIn
        ? _db.collection('acara').doc(acaraId).collection('tamuUndangan').doc()
        : null;

    final amplop = Amplop(
      id: refAmplop.id,
      bundelId: bundelKini.id,
      urut: urut,
      nama: namaEfektif,
      alamat: alamatEfektif,
      dusun: dusun,
      rt: rt,
      rw: rw,
      keterangan: (keterangan == null || keterangan.trim().isEmpty)
          ? null
          : keterangan.trim(),
      nominal: nominalEfektif,
      jenis: jenis,
      createdBy: pencatatId,
      dihitung: dihitung,
      tamuId: refTamuWalkIn?.id,
    );

    final batch = _db.batch();
    batch.set(refAmplop, amplop.toMap());
    if (walkIn && refTamuWalkIn != null) {
      batch.set(
        refTamuWalkIn,
        TamuUndangan(
          id: refTamuWalkIn.id,
          nama: namaEfektif,
          alamat: alamatEfektif,
          dusun: dusun,
          rt: rt,
          rw: rw,
          kodeTamu: buatKodeTamu(),
          statusHadir: StatusHadir.hadir,
          hadirAt: DateTime.now(),
          amplopId: refAmplop.id,
          dicatatOleh: pencatatId,
          asal: 'langsung',
        ).toMap(),
      );
    }
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
    batch.update(refAcara, <String, dynamic>{
      'totalAmplop': FieldValue.increment(1),
      'totalRp': FieldValue.increment(nominalEfektif),
      'updatedAt': FieldValue.serverTimestamp(),
      if (menutup) 'totalBundel': FieldValue.increment(1),
      // Batch 34: walk-in ikut menghitung kehadiran — diundang
      // dan hadir naik bersama (totalRpHadir naik sebesar
      // nominalnya; untuk entri Buku Tamu yang belum dihitung
      // nominalnya 0, uangnya menyusul lewat Mode Hitung).
      if (walkIn) 'totalUndangan': FieldValue.increment(1),
      if (walkIn) 'totalHadir': FieldValue.increment(1),
      if (walkIn) 'totalRpHadir': FieldValue.increment(nominalEfektif),
    });

    Bundel? bundelBaru;
    if (menutup) {
      final refBaru = _bundelRef(acaraId).doc();
      bundelBaru = Bundel(
        id: refBaru.id,
        acaraId: acaraId,
        pencatatId: pencatatId,
        prefix: pencatat.prefix,
        nomor: bundelKini.nomor + 1,
      );
      batch.set(refBaru, bundelBaru.toMap());
      batch.update(refPencatat, <String, dynamic>{
        'nomorBundelTerakhir': bundelKini.nomor + 1,
      });
    }
    await batch.commit();

    return HasilSimpanAmplop(
      bundelSesudah: Bundel(
        id: bundelKini.id,
        acaraId: acaraId,
        pencatatId: bundelKini.pencatatId,
        prefix: bundelKini.prefix,
        nomor: bundelKini.nomor,
        status: menutup ? StatusBundel.penuh : bundelKini.status,
        jumlahAmplop: bundelKini.jumlahAmplop + 1,
        totalRp: bundelKini.totalRp + nominalEfektif,
        jumlahKosong:
            bundelKini.jumlahKosong +
            (jenis == JenisAmplop.kosong ? 1 : 0),
        jumlahTanpaNama:
            bundelKini.jumlahTanpaNama +
            (jenis == JenisAmplop.tanpaNama ? 1 : 0),
        bebas: bundelKini.bebas,
        createdAt: bundelKini.createdAt,
        ditutupAt: menutup ? DateTime.now() : bundelKini.ditutupAt,
      ),
      menutupBundel: menutup,
      bundelBaru: bundelBaru,
    );
  }

  /// Ubah satu amplop oleh pencatat yang MENGINPUTNYA (Batch 8),
  /// selama acara masih aktif — untuk membetulkan salah ketik di
  /// tempat. Setelah acara selesai, hak ubah berpindah ke pemilik
  /// (mode koreksi Batch 6). Agregat digeser sebesar delta saja
  /// (deltaUbahAmplop), jumlah amplop tidak berubah. Hapus TIDAK
  /// dibuka untuk pencatat.
  Future<void> ubahAmplop({
    required String acaraId,
    required String pencatatId,
    required String bundelId,
    required Amplop amplopLama,
    required String nama,
    String? alamat,
    int? dusun,
    int? rt,
    int? rw,
    String? keterangan,
    required JenisAmplop jenis,
    required int nominal,
  }) async {
    final galat = validasiAmplop(jenis: jenis, nama: nama, nominal: nominal);
    if (galat != null) throw LayananException(galat);

    final refAcara = _db.collection('acara').doc(acaraId);
    final docAcara = await refAcara.get();
    if (!docAcara.exists) {
      throw const LayananException('Acara tidak ditemukan.');
    }
    if (Acara.fromFirestore(docAcara).sudahSelesai) {
      throw const LayananException(
        'Acara sudah selesai — perubahan sekarang lewat pemilik acara.',
      );
    }
    final docPencatat = await refAcara
        .collection('pencatat')
        .doc(pencatatId)
        .get();
    if (!docPencatat.exists) {
      throw const LayananException('Kamu belum terdaftar di acara ini.');
    }
    final pencatat = Pencatat.fromFirestore(docPencatat, acaraId: acaraId);
    if (!pencatat.aktif) {
      throw const LayananException(
        'Statusmu sedang dinonaktifkan pemilik acara.',
      );
    }
    _periksaSesi(pencatat);

    final refBundel = _bundelRef(acaraId).doc(bundelId);
    final docBundel = await refBundel.get();
    if (!docBundel.exists) {
      throw const LayananException('Bundel tidak ditemukan. Buka lagi.');
    }
    final bundelKini = Bundel.fromFirestore(docBundel, acaraId: acaraId);
    if (bundelKini.pencatatId != pencatatId) {
      throw const LayananException('Bundel ini milik pencatat lain.');
    }

    // Baca ulang amplopnya: delta dihitung dari nilai tersimpan,
    // dan hanya penginput asli yang boleh mengubah.
    final refAmplop = refBundel.collection('amplop').doc(amplopLama.id);
    final docAmplop = await refAmplop.get();
    if (!docAmplop.exists) {
      throw const LayananException('Pengunjung tidak ditemukan. Muat ulang.');
    }
    final tersimpan = Amplop.fromFirestore(docAmplop, bundelId: bundelId);
    if (tersimpan.createdBy != pencatatId) {
      throw const LayananException(
        'Hanya pencatat yang menginput pengunjung ini yang boleh mengubahnya.',
      );
    }

    final nominalEfektif = nominalSimpan(jenis, nominal);
    final delta = deltaUbahAmplop(
      jenisLama: tersimpan.jenis,
      nominalLama: tersimpan.nominal,
      jenisBaru: jenis,
      nominalBaru: nominalEfektif,
    );

    final batch = _db.batch();
    batch.update(refAmplop, <String, dynamic>{
      'nama': namaSimpan(jenis, nama),
      'alamat': (alamat == null || alamat.trim().isEmpty)
          ? null
          : alamat.trim(),
      'dusun': dusun,
      'rt': rt,
      'rw': rw,
      'keterangan': (keterangan == null || keterangan.trim().isEmpty)
          ? null
          : keterangan.trim(),
      'nominal': nominalEfektif,
      'jenis': jenis.nilaiSimpan,
      // Batch 32: ubah manual menetapkan nominal & jenis final —
      // entri Buku Tamu yang diubah di sini dianggap terhitung.
      'dihitung': true,
      'dihitungOleh': pencatatId,
    });
    batch.update(refBundel, <String, dynamic>{
      'totalRp': FieldValue.increment(delta.deltaRp),
      if (delta.deltaKosong != 0)
        'jumlahKosong': FieldValue.increment(delta.deltaKosong),
      if (delta.deltaTanpaNama != 0)
        'jumlahTanpaNama': FieldValue.increment(delta.deltaTanpaNama),
    });
    batch.update(refAcara, <String, dynamic>{
      'totalRp': FieldValue.increment(delta.deltaRp),
      'updatedAt': FieldValue.serverTimestamp(),
      // Batch 34: amplop tertaut ke tamu undangan — perubahan
      // nominalnya ikut menggeser uang kehadiran.
      if (tersimpan.tamuId != null)
        'totalRpHadir': FieldValue.increment(delta.deltaRp),
    });
    await batch.commit();
  }

  /// Mode Hitung sisi pencatat (Batch 32, dilonggarkan Batch
  /// 33): mengisi nominal satu entri Buku Tamu yang BELUM
  /// dihitung (dihitung == false) — hasil membuka amplop
  /// fisiknya dan mencocokkan nama yang tertulis di amplop.
  /// Batch 33: boleh entri dari perangkat MANA PUN — di lapangan
  /// bisa ada 2 tablet buku tamu tetapi hanya 1 kotak amplop,
  /// jadi petugas yang membuka amplop tidak tahu entri tamu itu
  /// ditulis dari tablet mana. Yang tetap dijaga: sesi aktif
  /// petugas ini, acara belum selesai, dan entri dibaca ulang
  /// (menolak bila ternyata sudah dihitung petugas lain).
  /// Penghitungnya dicatat di field dihitungOleh. [jenisBaru]
  /// normal/kosong/hadir; nominal efektif mengikuti jenisnya.
  Future<void> hitungAmplop({
    required String acaraId,
    required String pencatatId,
    required String bundelId,
    required Amplop amplopLama,
    required JenisAmplop jenisBaru,
    required int nominalBaru,
  }) async {
    final refAcara = _db.collection('acara').doc(acaraId);
    final docAcara = await refAcara.get();
    if (!docAcara.exists) {
      throw const LayananException('Acara tidak ditemukan.');
    }
    if (Acara.fromFirestore(docAcara).sudahSelesai) {
      throw const LayananException(
        'Acara sudah selesai — penghitungan dilanjutkan pemilik acara.',
      );
    }
    final docPencatat = await refAcara
        .collection('pencatat')
        .doc(pencatatId)
        .get();
    if (!docPencatat.exists) {
      throw const LayananException('Kamu belum terdaftar di acara ini.');
    }
    final pencatat = Pencatat.fromFirestore(docPencatat, acaraId: acaraId);
    if (!pencatat.aktif) {
      throw const LayananException(
        'Statusmu sedang dinonaktifkan pemilik acara.',
      );
    }
    _periksaSesi(pencatat);

    final refBundel = _bundelRef(acaraId).doc(bundelId);
    final docBundel = await refBundel.get();
    if (!docBundel.exists) {
      throw const LayananException('Bundel tidak ditemukan. Buka lagi.');
    }
    // Batch 33: bundel tujuan boleh milik pencatat lain (entri
    // buku tamu dari tablet sebelah) — agregatnya tetap diupdate
    // di bundel asal entri itu.

    final refAmplop = refBundel.collection('amplop').doc(amplopLama.id);
    final docAmplop = await refAmplop.get();
    if (!docAmplop.exists) {
      throw const LayananException('Pengunjung tidak ditemukan. Muat ulang.');
    }
    final tersimpan = Amplop.fromFirestore(docAmplop, bundelId: bundelId);
    if (tersimpan.dihitung) {
      throw const LayananException(
        'Pengunjung ini sudah dihitung petugas lain.',
      );
    }

    final galat = validasiAmplop(
      jenis: jenisBaru,
      nama: tersimpan.nama,
      nominal: nominalBaru,
    );
    if (galat != null) throw LayananException(galat);

    final nominalEfektif = nominalSimpan(jenisBaru, nominalBaru);
    final delta = deltaUbahAmplop(
      jenisLama: tersimpan.jenis,
      nominalLama: tersimpan.nominal,
      jenisBaru: jenisBaru,
      nominalBaru: nominalEfektif,
    );

    final batch = _db.batch();
    batch.update(refAmplop, <String, dynamic>{
      'nominal': nominalEfektif,
      'jenis': jenisBaru.nilaiSimpan,
      'dihitung': true,
      'dihitungOleh': pencatatId,
    });
    batch.update(refBundel, <String, dynamic>{
      'totalRp': FieldValue.increment(delta.deltaRp),
      if (delta.deltaKosong != 0)
        'jumlahKosong': FieldValue.increment(delta.deltaKosong),
      if (delta.deltaTanpaNama != 0)
        'jumlahTanpaNama': FieldValue.increment(delta.deltaTanpaNama),
    });
    batch.update(refAcara, <String, dynamic>{
      'totalRp': FieldValue.increment(delta.deltaRp),
      'updatedAt': FieldValue.serverTimestamp(),
      // Batch 34: entri Buku Tamu yang tertaut ke tamu undangan
      // (hadir lewat Buku Tamu) — saat dihitung, nominalnya
      // masuk uang kehadiran.
      if (tersimpan.tamuId != null)
        'totalRpHadir': FieldValue.increment(delta.deltaRp),
    });
    await batch.commit();
  }
}
