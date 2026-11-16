import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/pencatatan.dart';
import '../models/acara.dart';
import '../models/amplop.dart';
import '../models/bundel.dart';
import '../models/pencatat.dart';
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
    required int nominal,
  }) async {
    final galat = validasiAmplop(jenis: jenis, nama: nama, nominal: nominal);
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
    final docBundel = await refBundel.get();
    if (!docBundel.exists) {
      throw const LayananException('Bundel tidak ditemukan. Buka lagi.');
    }
    final bundelKini = Bundel.fromFirestore(docBundel, acaraId: acaraId);
    if (bundelKini.pencatatId != pencatatId) {
      throw const LayananException('Bundel ini milik pencatat lain.');
    }
    if (bundelPenuh(bundelKini.jumlahAmplop)) {
      throw const LayananException(
        'Bundel ${bundelKini.kode} sudah penuh — buka bundel baru.',
      );
    }

    final urut = urutBerikutnya(bundelKini.jumlahAmplop);
    final menutup = amplopIniMenutupBundel(bundelKini.jumlahAmplop);

    final amplop = Amplop(
      id: '',
      bundelId: bundelKini.id,
      urut: urut,
      nama: namaEfektif,
      alamat: alamatEfektif,
      nominal: nominalEfektif,
      jenis: jenis,
      createdBy: pencatatId,
    );

    final batch = _db.batch();
    batch.set(refBundel.collection('amplop').doc(), amplop.toMap());
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
        createdAt: bundelKini.createdAt,
        ditutupAt: menutup ? DateTime.now() : bundelKini.ditutupAt,
      ),
      menutupBundel: menutup,
      bundelBaru: bundelBaru,
    );
  }
}
