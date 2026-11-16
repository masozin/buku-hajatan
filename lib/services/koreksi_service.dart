import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/koreksi.dart';
import '../core/pencatatan.dart';
import '../models/acara.dart';
import '../models/amplop.dart';
import '../models/bundel.dart';
import 'layanan_exception.dart';

/// Koreksi data oleh PEMILIK setelah acara selesai (Batch 6):
/// tambah / ubah / hapus amplop, dengan agregat bundel & acara
/// disesuaikan dalam batch tulis yang sama (pola yang sama dengan
/// PencatatanService.simpanAmplop).
///
/// Penjagaan berlapis: service ini menolak bila acara belum selesai,
/// dan rules hanya mengizinkan tulis koreksi pemilik pada acara
/// berstatus selesai. Selama acara aktif pemilik hanya memantau —
/// pencatatan adalah pekerjaan pencatat.
class KoreksiService {
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _refAcara(String acaraId) =>
      _db.collection('acara').doc(acaraId);

  DocumentReference<Map<String, dynamic>> _refBundel(
    String acaraId,
    String bundelId,
  ) => _refAcara(acaraId).collection('bundel').doc(bundelId);

  /// Ambil acara + bundel segar dan pastikan koreksi memang boleh:
  /// acara ada, sudah selesai, bundel ada.
  Future<({Acara acara, Bundel bundel})> _pastikanBolehKoreksi(
    String acaraId,
    String bundelId,
  ) async {
    final docAcara = await _refAcara(acaraId).get();
    if (!docAcara.exists) {
      throw const LayananException('Acara tidak ditemukan.');
    }
    final acara = Acara.fromFirestore(docAcara);
    if (!acara.sudahSelesai) {
      throw const LayananException(
        'Koreksi hanya dibuka setelah acara selesai. Selama acara '
        'berlangsung, pemilik hanya memantau.',
      );
    }
    final docBundel = await _refBundel(acaraId, bundelId).get();
    if (!docBundel.exists) {
      throw const LayananException('Bundel tidak ditemukan. Muat ulang.');
    }
    return (
      acara: acara,
      bundel: Bundel.fromFirestore(docBundel, acaraId: acaraId),
    );
  }

  /// Tambah satu amplop ke bundel yang belum penuh.
  Future<void> tambahAmplop({
    required String acaraId,
    required String bundelId,
    required String pemilikId,
    required String nama,
    String? alamat,
    required JenisAmplop jenis,
    required int nominal,
  }) async {
    final galat = validasiAmplop(jenis: jenis, nama: nama, nominal: nominal);
    if (galat != null) throw LayananException(galat);
    final bundel = (await _pastikanBolehKoreksi(acaraId, bundelId)).bundel;
    if (bundelPenuh(bundel.jumlahAmplop)) {
      throw const LayananException(
        'Bundel ini sudah penuh (10 amplop) — tambah tidak tersedia. '
        'Pilih bundel lain yang belum penuh.',
      );
    }
    final namaEfektif = namaSimpan(jenis, nama);
    final nominalEfektif = nominalSimpan(jenis, nominal);
    final menutup = amplopIniMenutupBundel(bundel.jumlahAmplop);

    final amplop = Amplop(
      id: '',
      bundelId: bundelId,
      urut: urutBerikutnya(bundel.jumlahAmplop),
      nama: namaEfektif,
      alamat: (alamat == null || alamat.trim().isEmpty)
          ? null
          : alamat.trim(),
      nominal: nominalEfektif,
      jenis: jenis,
      createdBy: pemilikId,
    );

    final refBundel = _refBundel(acaraId, bundelId);
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
    batch.update(_refAcara(acaraId), <String, dynamic>{
      'totalAmplop': FieldValue.increment(1),
      'totalRp': FieldValue.increment(nominalEfektif),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  /// Ubah satu amplop; agregat digeser sebesar selisihnya saja.
  Future<void> ubahAmplop({
    required String acaraId,
    required String bundelId,
    required Amplop amplopLama,
    required String nama,
    String? alamat,
    required JenisAmplop jenis,
    required int nominal,
  }) async {
    final galat = validasiAmplop(jenis: jenis, nama: nama, nominal: nominal);
    if (galat != null) throw LayananException(galat);
    await _pastikanBolehKoreksi(acaraId, bundelId);

    final nominalEfektif = nominalSimpan(jenis, nominal);
    final delta = deltaUbahAmplop(
      jenisLama: amplopLama.jenis,
      nominalLama: amplopLama.nominal,
      jenisBaru: jenis,
      nominalBaru: nominalEfektif,
    );

    final refBundel = _refBundel(acaraId, bundelId);
    final batch = _db.batch();
    batch.update(
      refBundel.collection('amplop').doc(amplopLama.id),
      <String, dynamic>{
        'nama': namaSimpan(jenis, nama),
        'alamat': (alamat == null || alamat.trim().isEmpty)
            ? null
            : alamat.trim(),
        'nominal': nominalEfektif,
        'jenis': jenis.nilaiSimpan,
      },
    );
    batch.update(refBundel, <String, dynamic>{
      'totalRp': FieldValue.increment(delta.deltaRp),
      if (delta.deltaKosong != 0)
        'jumlahKosong': FieldValue.increment(delta.deltaKosong),
      if (delta.deltaTanpaNama != 0)
        'jumlahTanpaNama': FieldValue.increment(delta.deltaTanpaNama),
    });
    batch.update(_refAcara(acaraId), <String, dynamic>{
      'totalRp': FieldValue.increment(delta.deltaRp),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  /// Hapus satu amplop; agregat dikurangi, bundel yang tadinya
  /// penuh terbuka lagi.
  Future<void> hapusAmplop({
    required String acaraId,
    required String bundelId,
    required Amplop amplop,
  }) async {
    final bundel = (await _pastikanBolehKoreksi(acaraId, bundelId)).bundel;
    final tadinyaPenuh = bundelPenuh(bundel.jumlahAmplop);

    final refBundel = _refBundel(acaraId, bundelId);
    final batch = _db.batch();
    batch.delete(refBundel.collection('amplop').doc(amplop.id));
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
    batch.update(_refAcara(acaraId), <String, dynamic>{
      'totalAmplop': FieldValue.increment(-1),
      'totalRp': FieldValue.increment(-amplop.nominal),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }
}
