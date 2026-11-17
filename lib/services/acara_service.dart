import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/kode.dart';
import '../models/acara.dart';
import '../models/pencatat.dart';
import 'layanan_exception.dart';

/// Pasangan acara + data kepencatatan pengguna di acara itu,
/// untuk daftar "Acara yang Saya Ikuti".
class Keikutsertaan {
  const Keikutsertaan({required this.acara, required this.pencatat});

  final Acara acara;
  final Pencatat pencatat;
}

/// Semua operasi Firestore untuk acara, pencatat, dan undangan.
/// Struktur data mengikuti rancangan teknis §1:
///
/// pemilik/{uid}
/// acara/{acaraId} (+ sub: pencatat, undanganPencatat, bundel)
/// kodeAcara/{kodeGabung} -> { acaraId, pinGabung, pemilikId }
class AcaraService {
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _acara =>
      _db.collection('acara');

  // ---------------------------------------------------------------- acara

  /// Buat acara baru + dokumen kode gabungnya dalam satu batch.
  /// Mengembalikan acara yang tersimpan (dengan ID & kode gabung final).
  Future<Acara> buatAcara({
    required String pemilikId,
    required String namaAcara,
    required String tuanRumah,
    required String jenis,
    required DateTime tanggal,
    String? lokasi,
    required String pinGabung,
  }) async {
    // Cari kode gabung yang belum dipakai (tabrakan sangat jarang,
    // tapi tetap diperiksa karena kode ini kunci pencarian acara).
    String kode = buatKodeGabung();
    for (var i = 0; i < 5; i++) {
      final sudahAda = await _db.collection('kodeAcara').doc(kode).get();
      if (!sudahAda.exists) break;
      kode = buatKodeGabung();
    }

    final refAcara = _acara.doc();
    final acara = Acara(
      id: refAcara.id,
      pemilikId: pemilikId,
      namaAcara: namaAcara.trim(),
      tuanRumah: tuanRumah.trim(),
      jenis: jenis,
      tanggal: tanggal,
      lokasi: (lokasi == null || lokasi.trim().isEmpty) ? null : lokasi.trim(),
      kodeGabung: kode,
    );

    final batch = _db.batch();
    batch.set(refAcara, acara.toMap());
    batch.set(_db.collection('kodeAcara').doc(kode), <String, dynamic>{
      'acaraId': refAcara.id,
      'pinGabung': pinGabung,
      'pemilikId': pemilikId,
    });
    await batch.commit();
    return acara;
  }

  Stream<Acara?> acaraStream(String acaraId) {
    return _acara.doc(acaraId).snapshots().map((doc) {
      return doc.exists ? Acara.fromFirestore(doc) : null;
    });
  }

  /// Acara milik pemilik ini, urut tanggal terdekat dulu.
  Stream<List<Acara>> acaraMilikSayaStream(String pemilikId) {
    return _acara.where('pemilikId', isEqualTo: pemilikId).snapshots().map((
      qs,
    ) {
      final daftar = qs.docs.map(Acara.fromFirestore).toList();
      daftar.sort((a, b) => a.tanggal.compareTo(b.tanggal));
      return daftar;
    });
  }

  /// Acara yang diikuti pengguna sebagai pencatat (collectionGroup
  /// query ke semua sub-koleksi `pencatat` berdasarkan sesi aktif:
  /// field uidAktif == UID perangkat ini, Batch 10).
  Stream<List<Keikutsertaan>> acaraDiikutiStream(String uid) {
    return _db
        .collectionGroup('pencatat')
        .where('uidAktif', isEqualTo: uid)
        .snapshots()
        .asyncMap((qs) async {
          final hasil = <Keikutsertaan>[];
          for (final docPencatat in qs.docs) {
            final acaraRef = docPencatat.reference.parent.parent;
            if (acaraRef == null) continue;
            // Satu acara yang gagal dibaca (mis. rules sesaat
            // belum mengakui sesi) tidak boleh mematikan seluruh
            // daftar — lewati; snapshot berikutnya memperbaikinya.
            try {
              final docAcara = await acaraRef.get();
              if (!docAcara.exists) continue;
              hasil.add(
                Keikutsertaan(
                  acara: Acara.fromFirestore(docAcara),
                  pencatat: Pencatat.fromFirestore(
                    docPencatat,
                    acaraId: acaraRef.id,
                  ),
                ),
              );
            } catch (_) {
              continue;
            }
          }
          hasil.sort((a, b) => a.acara.tanggal.compareTo(b.acara.tanggal));
          return hasil;
        });
  }

  Future<void> ubahStatusAcara(String acaraId, StatusAcara status) {
    return _acara.doc(acaraId).update(<String, dynamic>{
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// PIN gabung acara (hanya untuk ditampilkan ke pemiliknya).
  Future<String?> ambilPinGabung(String kodeGabung) async {
    final doc = await _db.collection('kodeAcara').doc(kodeGabung).get();
    if (!doc.exists) return null;
    return doc.data()?['pinGabung'] as String?;
  }

  // ------------------------------------------------------------- pencatat

  Stream<List<Pencatat>> pencatatStream(String acaraId) {
    return _acara.doc(acaraId).collection('pencatat').snapshots().map((qs) {
      final daftar = qs.docs
          .map((d) => Pencatat.fromFirestore(d, acaraId: acaraId))
          .toList();
      daftar.sort((a, b) => a.prefix.compareTo(b.prefix));
      return daftar;
    });
  }

  /// Dokumen sesi perangkat: acara/{id}/pencatatSesi/{uid}.
  DocumentReference<Map<String, dynamic>> _refSesi(
    String acaraId,
    String uid,
  ) => _acara.doc(acaraId).collection('pencatatSesi').doc(uid);

  /// Pencatat yang sesinya sedang dipegang perangkat [uid] di acara
  /// ini (Batch 10): cari lewat uidAktif; cadangan data lama —
  /// dokumen ber-ID = UID dengan field userId (Batch 1–9).
  Future<Pencatat?> pencatatDi(String acaraId, String uid) async {
    final koleksi = _acara.doc(acaraId).collection('pencatat');
    final bySesi = await koleksi
        .where('uidAktif', isEqualTo: uid)
        .limit(1)
        .get();
    if (bySesi.docs.isNotEmpty) {
      return Pencatat.fromFirestore(bySesi.docs.first, acaraId: acaraId);
    }
    final legacy = await koleksi.doc(uid).get();
    if (legacy.exists) {
      final p = Pencatat.fromFirestore(legacy, acaraId: acaraId);
      if (p.uidAktif == uid) return p;
    }
    return null;
  }

  /// Aktif/nonaktifkan pencatat. Menonaktifkan sekaligus MEMUTUS
  /// sesi perangkat yang sedang memegangnya (Batch 10).
  Future<void> setAktifPencatat(
    String acaraId,
    String pencatatId,
    bool aktif,
  ) async {
    final refPencatat = _acara
        .doc(acaraId)
        .collection('pencatat')
        .doc(pencatatId);
    if (aktif) {
      await refPencatat.update(<String, dynamic>{'aktif': true});
      return;
    }
    final doc = await refPencatat.get();
    final uidAktif = doc.data()?['uidAktif'] as String?;
    final batch = _db.batch();
    batch.update(refPencatat, <String, dynamic>{
      'aktif': false,
      if (uidAktif != null) 'uidAktif': FieldValue.delete(),
      if (uidAktif != null) 'userId': FieldValue.delete(),
    });
    if (uidAktif != null) batch.delete(_refSesi(acaraId, uidAktif));
    await batch.commit();
  }

  // ------------------------------------------------------------- undangan

  Stream<List<UndanganPencatat>> undanganStream(String acaraId) {
    return _acara.doc(acaraId).collection('undanganPencatat').snapshots().map((
      qs,
    ) {
      final daftar = qs.docs
          .map((d) => UndanganPencatat.fromFirestore(d, acaraId: acaraId))
          .toList();
      daftar.sort((a, b) => a.prefix.compareTo(b.prefix));
      return daftar;
    });
  }

  /// PIN pribadi sah: 4–6 digit angka.
  static String? validasiPinPribadi(String pin) {
    if (!RegExp(r'^\d{4,6}$').hasMatch(pin)) {
      return 'PIN pribadi harus 4–6 digit angka.';
    }
    return null;
  }

  /// Daftarkan nama pencatat baru; prefix otomatis = huruf berikutnya
  /// setelah jumlah (pencatat terdaftar + undangan yang masih menunggu).
  /// [pinPribadi] (Batch 10): PIN pribadinya untuk masuk dari
  /// perangkat mana pun; kosong → dibuatkan acak 4 digit.
  Future<UndanganPencatat> tambahUndangan(
    String acaraId,
    String nama, {
    String? pinPribadi,
  }) async {
    final namaBersih = nama.trim();
    if (namaBersih.isEmpty) {
      throw const LayananException('Nama pencatat belum diisi.');
    }
    var pin = pinPribadi?.trim() ?? '';
    if (pin.isEmpty) {
      pin = (1000 + Random().nextInt(9000)).toString();
    } else {
      final galatPin = validasiPinPribadi(pin);
      if (galatPin != null) throw LayananException(galatPin);
    }
    final refAcara = _acara.doc(acaraId);

    final snapPencatat = await refAcara.collection('pencatat').get();
    final snapUndangan = await refAcara.collection('undanganPencatat').get();

    final normalBaru = normalisasiNama(namaBersih);
    var jumlahTerpakai = snapPencatat.docs.length;
    for (final doc in snapUndangan.docs) {
      final data = doc.data();
      if ((data['namaNormalisasi'] as String?) == normalBaru &&
          (data['status'] as String?) == 'menunggu') {
        throw LayananException(
          'Nama "$namaBersih" sudah didaftarkan dan belum bergabung.',
        );
      }
      if ((data['status'] as String?) == 'menunggu') jumlahTerpakai++;
    }
    for (final doc in snapPencatat.docs) {
      final data = doc.data();
      if (normalisasiNama((data['nama'] as String?) ?? '') == normalBaru) {
        throw LayananException(
          'Nama "$namaBersih" sudah bergabung sebagai pencatat.',
        );
      }
    }

    final undangan = UndanganPencatat(
      id: '',
      acaraId: acaraId,
      nama: namaBersih,
      namaNormalisasi: normalBaru,
      prefix: hurufPrefix(jumlahTerpakai),
      pinPribadi: pin,
    );
    final ref = await refAcara
        .collection('undanganPencatat')
        .add(undangan.toMap());
    return UndanganPencatat(
      id: ref.id,
      acaraId: acaraId,
      nama: undangan.nama,
      namaNormalisasi: undangan.namaNormalisasi,
      prefix: undangan.prefix,
      pinPribadi: undangan.pinPribadi,
    );
  }

  /// Atur/ganti PIN pribadi sebuah undangan (Batch 10). Salinan di
  /// dokumen pencatatnya (bila sudah bergabung) ikut diperbarui.
  Future<void> aturPinPribadi(
    String acaraId,
    String undanganId,
    String pinBaru,
  ) async {
    final pin = pinBaru.trim();
    final galatPin = validasiPinPribadi(pin);
    if (galatPin != null) throw LayananException(galatPin);
    final refAcara = _acara.doc(acaraId);
    final batch = _db.batch();
    batch.update(
      refAcara.collection('undanganPencatat').doc(undanganId),
      <String, dynamic>{'pinPribadi': pin},
    );
    final snapPencatat = await refAcara
        .collection('pencatat')
        .where('undanganId', isEqualTo: undanganId)
        .limit(1)
        .get();
    if (snapPencatat.docs.isNotEmpty) {
      batch.update(snapPencatat.docs.first.reference, <String, dynamic>{
        'pinPribadi': pin,
      });
    }
    await batch.commit();
  }

  Future<void> hapusUndangan(String acaraId, String undanganId) {
    return _acara
        .doc(acaraId)
        .collection('undanganPencatat')
        .doc(undanganId)
        .delete();
  }

  // --------------------------------------------------------------- gabung

  /// Masukkan penulisan dokumen sesi perangkat ini ke dalam [batch]
  /// yang sama dengan penulisan dokumen pencatatnya (perbaikan
  /// Batch 10). WAJIB satu batch: keanggotaan pencatat — dokumen
  /// pencatat + dokumen sesi — harus tampak oleh rules & stream
  /// secara atomik. Bila sesi ditulis terpisah sesudahnya, ada
  /// sesaat ketika dokumen pencatat sudah terbaca stream tetapi
  /// rules belum mengakui sesi → baca acara ditolak
  /// (permission-denied) tepat setelah gabung.
  void _tambahSesiKeBatch(
    WriteBatch batch,
    String acaraId,
    String uid,
    String pencatatId,
  ) {
    batch.set(_refSesi(acaraId, uid), <String, dynamic>{
      'pencatatId': pencatatId,
      'uid': uid,
    });
  }

  /// Alur gabung / masuk pencatat (Batch 10 — identitas tetap +
  /// kunci sesi):
  ///
  /// 1. Perangkat ini sudah memegang sesi di acara ini → pakai.
  ///    (Termasuk migrasi sesi data lama Batch 1–9.)
  /// 2. Selain itu cocokkan nama ke undangan pemilik dan periksa
  ///    PIN PRIBADI pencatat itu (bukan lagi PIN acara).
  /// 3. Klaim pertama: buat dokumen pencatat ber-ID tetap (= ID
  ///    undangan). Masuk ulang: ambil sesi — DITOLAK bila sesi
  ///    sedang dipegang perangkat lain (kebijakan Mark: sampai
  ///    perangkat itu keluar, atau pemilik mereset sesinya).
  Future<Pencatat> gabungAcara({
    required String uid,
    required String kodeInput,
    required String namaInput,
    required String pinInput,
  }) async {
    final kode = kodeInput.trim().toUpperCase();
    if (kode.isEmpty || namaInput.trim().isEmpty || pinInput.isEmpty) {
      throw const LayananException(
        'Kode acara, nama, dan PIN pribadi harus diisi semua.',
      );
    }

    final docKode = await _db.collection('kodeAcara').doc(kode).get();
    if (!docKode.exists) {
      throw const LayananException(
        'Kode acara tidak ditemukan. Periksa lagi kode dari pemilik acara.',
      );
    }
    final acaraId = docKode.data()!['acaraId'] as String;
    final refAcara = _acara.doc(acaraId);

    // (1) Sesi perangkat ini.
    final yangAda = await pencatatDi(acaraId, uid);
    if (yangAda != null) {
      // Satu batch: lengkapi migrasi data lama (bila dokumennya
      // masih format Batch 1–9) + pastikan dokumen sesi ada —
      // atomik, lihat _tambahSesiKeBatch.
      final docRef = refAcara.collection('pencatat').doc(yangAda.id);
      final mentah = (await docRef.get()).data() ?? const {};
      final batch = _db.batch();
      if (mentah['uidAktif'] == null) {
        var undanganId = yangAda.undanganId;
        if (undanganId == null) {
          final snapU = await refAcara
              .collection('undanganPencatat')
              .where('claimedBy', isEqualTo: uid)
              .limit(1)
              .get();
          if (snapU.docs.isNotEmpty) undanganId = snapU.docs.first.id;
        }
        batch.update(docRef, <String, dynamic>{
          'uidAktif': uid,
          'userId': uid,
          if (undanganId != null) 'undanganId': undanganId,
        });
      }
      _tambahSesiKeBatch(batch, acaraId, uid, yangAda.id);
      await batch.commit();
      return yangAda;
    }

    // (2) Undangan atas nama ini (status apa pun).
    final snapUndangan = await refAcara
        .collection('undanganPencatat')
        .where('namaNormalisasi', isEqualTo: normalisasiNama(namaInput))
        .limit(1)
        .get();
    if (snapUndangan.docs.isEmpty) {
      throw LayananException(
        'Nama "${namaInput.trim()}" belum didaftarkan pemilik acara. '
        'Minta pemilik acara memeriksa daftar pencatatnya.',
      );
    }
    final docUndangan = snapUndangan.docs.first;
    final undangan = UndanganPencatat.fromFirestore(
      docUndangan,
      acaraId: acaraId,
    );
    if (undangan.pinPribadi == null) {
      throw const LayananException(
        'PIN pribadi untuk nama ini belum diatur pemilik acara. '
        'Minta pemilik mengaturnya dulu di bagian Pencatat.',
      );
    }
    if (undangan.pinPribadi != pinInput.trim()) {
      throw const LayananException('PIN pribadi salah.');
    }

    // (3) Dokumen pencatatnya: ID tetap = ID undangan; data lama
    // bisa ber-ID = UID pengklaim pertama (tautan claimedBy).
    DocumentSnapshot<Map<String, dynamic>>? docPencatat = await refAcara
        .collection('pencatat')
        .doc(undangan.id)
        .get();
    if (!docPencatat.exists && undangan.claimedBy != null) {
      final legacy = await refAcara
          .collection('pencatat')
          .doc(undangan.claimedBy!)
          .get();
      if (legacy.exists) docPencatat = legacy;
    }

    if (docPencatat == null || !docPencatat.exists) {
      // Klaim pertama.
      if (undangan.sudahDiklaim) {
        throw const LayananException(
          'Nama ini sudah terdaftar tetapi data pencatatnya tidak '
          'ditemukan. Minta pemilik acara memeriksa daftar pencatatnya.',
        );
      }
      final pencatat = Pencatat(
        id: undangan.id,
        acaraId: acaraId,
        nama: undangan.nama,
        prefix: undangan.prefix,
        undanganId: undangan.id,
        uidAktif: uid,
        pinPribadi: undangan.pinPribadi,
      );
      final batch = _db.batch();
      batch.set(
        refAcara.collection('pencatat').doc(pencatat.id),
        pencatat.toMap(),
      );
      batch.update(docUndangan.reference, <String, dynamic>{
        'status': 'diklaim',
        'claimedBy': uid,
        'claimedAt': FieldValue.serverTimestamp(),
      });
      _tambahSesiKeBatch(batch, acaraId, uid, pencatat.id);
      await batch.commit();
      return pencatat;
    }

    // Masuk ulang / ambil sesi.
    final pencatat = Pencatat.fromFirestore(docPencatat, acaraId: acaraId);
    if (!pencatat.aktif) {
      throw const LayananException(
        'Statusmu sedang dinonaktifkan pemilik acara.',
      );
    }
    if (pencatat.uidAktif != null && pencatat.uidAktif != uid) {
      throw const LayananException(
        'Pencatat ini sedang aktif di perangkat lain. Keluar dulu '
        'dari perangkat itu, atau minta pemilik acara mereset '
        'sesinya.',
      );
    }
    final batch = _db.batch();
    batch.update(docPencatat.reference, <String, dynamic>{
      'uidAktif': uid,
      'userId': uid,
      'undanganId': undangan.id,
      'pinPribadi': undangan.pinPribadi,
      'sesiMasukPada': FieldValue.serverTimestamp(),
    });
    _tambahSesiKeBatch(batch, acaraId, uid, pencatat.id);
    await batch.commit();
    return Pencatat(
      id: pencatat.id,
      acaraId: pencatat.acaraId,
      nama: pencatat.nama,
      prefix: pencatat.prefix,
      undanganId: undangan.id,
      uidAktif: uid,
      pinPribadi: undangan.pinPribadi,
      nomorBundelTerakhir: pencatat.nomorBundelTerakhir,
      aktif: pencatat.aktif,
      createdAt: pencatat.createdAt,
    );
  }

  /// Reset sesi seorang pencatat oleh pemilik (Batch 10, tombol
  /// "Reset Sesi" di kelola pencatat): lepaskan kunci sesi dari
  /// perangkat yang sedang memegangnya, supaya pencatat bisa masuk
  /// dari perangkat lain dengan nama + PIN pribadinya. Identitas,
  /// bundel, dan amplopnya TIDAK berubah — semua tetap menempel
  /// ke namanya.
  Future<void> resetSesiPencatat(String acaraId, Pencatat pencatat) async {
    final batch = _db.batch();
    batch.update(
      _acara.doc(acaraId).collection('pencatat').doc(pencatat.id),
      <String, dynamic>{
        'uidAktif': FieldValue.delete(),
        'userId': FieldValue.delete(),
        'sesiMasukPada': FieldValue.delete(),
      },
    );
    if (pencatat.uidAktif != null) {
      batch.delete(_refSesi(acaraId, pencatat.uidAktif!));
    }
    await batch.commit();
  }

  /// Lepaskan SEMUA sesi pencatat milik perangkat [uid] di semua
  /// acara (Batch 10) — dipanggil sebelum keluar (sign out), supaya
  /// nama-namanya bebas dipakai perangkat lain. Kegagalan di sini
  /// tidak boleh menghalangi keluar; pemanggil membungkusnya
  /// try/catch (sesi yang tertinggal bisa direset pemilik).
  Future<void> lepaskanSemuaSesi(String uid) async {
    final snap = await _db
        .collectionGroup('pencatat')
        .where('uidAktif', isEqualTo: uid)
        .get();
    if (snap.docs.isEmpty) return;
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, <String, dynamic>{
        'uidAktif': FieldValue.delete(),
        'userId': FieldValue.delete(),
        'sesiMasukPada': FieldValue.delete(),
      });
      final acaraRef = doc.reference.parent.parent;
      if (acaraRef != null) {
        batch.delete(acaraRef.collection('pencatatSesi').doc(uid));
      }
    }
    await batch.commit();
  }
}
