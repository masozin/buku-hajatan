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
      final sudahAda =
          await _db.collection('kodeAcara').doc(kode).get();
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
      lokasi: (lokasi == null || lokasi.trim().isEmpty)
          ? null
          : lokasi.trim(),
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
    return _acara
        .where('pemilikId', isEqualTo: pemilikId)
        .snapshots()
        .map((qs) {
          final daftar = qs.docs.map(Acara.fromFirestore).toList();
          daftar.sort((a, b) => a.tanggal.compareTo(b.tanggal));
          return daftar;
        });
  }

  /// Acara yang diikuti pengguna sebagai pencatat (collectionGroup query
  /// ke semua sub-koleksi `pencatat` berdasarkan field userId).
  Stream<List<Keikutsertaan>> acaraDiikutiStream(String uid) {
    return _db
        .collectionGroup('pencatat')
        .where('userId', isEqualTo: uid)
        .snapshots()
        .asyncMap((qs) async {
          final hasil = <Keikutsertaan>[];
          for (final docPencatat in qs.docs) {
            final acaraRef = docPencatat.reference.parent.parent;
            if (acaraRef == null) continue;
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
          }
          hasil.sort(
            (a, b) => a.acara.tanggal.compareTo(b.acara.tanggal),
          );
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
    final doc =
        await _db.collection('kodeAcara').doc(kodeGabung).get();
    if (!doc.exists) return null;
    return doc.data()?['pinGabung'] as String?;
  }

  // ------------------------------------------------------------- pencatat

  Stream<List<Pencatat>> pencatatStream(String acaraId) {
    return _acara
        .doc(acaraId)
        .collection('pencatat')
        .snapshots()
        .map((qs) {
          final daftar = qs.docs
              .map((d) => Pencatat.fromFirestore(d, acaraId: acaraId))
              .toList();
          daftar.sort((a, b) => a.prefix.compareTo(b.prefix));
          return daftar;
        });
  }

  Future<Pencatat?> pencatatDi(String acaraId, String uid) async {
    final doc = await _acara
        .doc(acaraId)
        .collection('pencatat')
        .doc(uid)
        .get();
    if (!doc.exists) return null;
    return Pencatat.fromFirestore(doc, acaraId: acaraId);
  }

  Future<void> setAktifPencatat(
    String acaraId,
    String pencatatId,
    bool aktif,
  ) {
    return _acara
        .doc(acaraId)
        .collection('pencatat')
        .doc(pencatatId)
        .update(<String, dynamic>{'aktif': aktif});
  }

  // ------------------------------------------------------------- undangan

  Stream<List<UndanganPencatat>> undanganStream(String acaraId) {
    return _acara
        .doc(acaraId)
        .collection('undanganPencatat')
        .snapshots()
        .map((qs) {
          final daftar = qs.docs
              .map(
                (d) => UndanganPencatat.fromFirestore(d, acaraId: acaraId),
              )
              .toList();
          daftar.sort((a, b) => a.prefix.compareTo(b.prefix));
          return daftar;
        });
  }

  /// Daftarkan nama pencatat baru; prefix otomatis = huruf berikutnya
  /// setelah jumlah (pencatat terdaftar + undangan yang masih menunggu).
  Future<UndanganPencatat> tambahUndangan(
    String acaraId,
    String nama,
  ) async {
    final namaBersih = nama.trim();
    if (namaBersih.isEmpty) {
      throw const LayananException('Nama pencatat belum diisi.');
    }
    final refAcara = _acara.doc(acaraId);

    final snapPencatat = await refAcara.collection('pencatat').get();
    final snapUndangan =
        await refAcara.collection('undanganPencatat').get();

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
      if (normalisasiNama((data['nama'] as String?) ?? '') ==
          normalBaru) {
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
    );
  }

  Future<void> hapusUndangan(String acaraId, String undanganId) {
    return _acara
        .doc(acaraId)
        .collection('undanganPencatat')
        .doc(undanganId)
        .delete();
  }

  // --------------------------------------------------------------- gabung

  /// Alur gabung pencatat (Opsi A): kode acara -> PIN -> cocokkan nama
  /// dengan undangan dari pemilik -> klaim (buat dokumen pencatat
  /// ber-ID = UID pengguna anonim ini, tandai undangan diklaim).
  Future<Pencatat> gabungAcara({
    required String uid,
    required String kodeInput,
    required String namaInput,
    required String pinInput,
  }) async {
    final kode = kodeInput.trim().toUpperCase();
    if (kode.isEmpty || namaInput.trim().isEmpty || pinInput.isEmpty) {
      throw const LayananException(
        'Kode acara, nama, dan PIN harus diisi semua.',
      );
    }

    final docKode = await _db.collection('kodeAcara').doc(kode).get();
    if (!docKode.exists) {
      throw const LayananException(
        'Kode acara tidak ditemukan. Periksa lagi kode dari pemilik acara.',
      );
    }
    final dataKode = docKode.data()!;
    if ((dataKode['pinGabung'] as String?) != pinInput.trim()) {
      throw const LayananException('PIN acara salah.');
    }
    final acaraId = dataKode['acaraId'] as String;

    // Sudah pernah bergabung di acara ini? Pakai data yang ada.
    final yangAda = await pencatatDi(acaraId, uid);
    if (yangAda != null) return yangAda;

    final refAcara = _acara.doc(acaraId);
    final snapUndangan = await refAcara
        .collection('undanganPencatat')
        .where(
          'namaNormalisasi',
          isEqualTo: normalisasiNama(namaInput),
        )
        .where('status', isEqualTo: 'menunggu')
        .limit(1)
        .get();
    if (snapUndangan.docs.isEmpty) {
      throw LayananException(
        'Nama "${namaInput.trim()}" belum didaftarkan pemilik acara, '
        'atau sudah bergabung dari HP lain. Minta pemilik acara '
        'memeriksa daftar pencatatnya.',
      );
    }

    final docUndangan = snapUndangan.docs.first;
    final dataUndangan = docUndangan.data();
    final pencatat = Pencatat(
      id: uid,
      acaraId: acaraId,
      userId: uid,
      nama: (dataUndangan['nama'] as String?) ?? namaInput.trim(),
      prefix: (dataUndangan['prefix'] as String?) ?? '',
    );

    final batch = _db.batch();
    batch.set(
      refAcara.collection('pencatat').doc(uid),
      pencatat.toMap(),
    );
    batch.update(docUndangan.reference, <String, dynamic>{
      'status': 'diklaim',
      'claimedBy': uid,
      'claimedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    return pencatat;
  }
}
