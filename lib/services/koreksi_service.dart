import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/kode.dart';
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

  /// Bundel khusus PEMILIK untuk koreksi (Batch 20): cari bundel
  /// ber-prefix PM yang belum penuh; bila belum ada atau yang
  /// terakhir sudah penuh, buat bundel PM baru (nomor berikutnya)
  /// dan naikkan totalBundel acara — dalam satu batch tulis.
  /// Koreksi pemilik tidak lagi bercampur ke bundel pencatat.
  Future<Bundel> bundelPemilikAcara(String acaraId, String pemilikId) async {
    final docAcara = await _refAcara(acaraId).get();
    if (!docAcara.exists) {
      throw const LayananException('Acara tidak ditemukan.');
    }
    final acara = Acara.fromFirestore(docAcara);
    if (!acara.sudahSelesai) {
      throw const LayananException(
        'Bundel pemilik hanya untuk koreksi setelah acara selesai.',
      );
    }
    final snap = await _refAcara(acaraId)
        .collection('bundel')
        .where('prefix', isEqualTo: prefixBundelPemilik)
        .get();
    final daftar = snap.docs
        .map((d) => Bundel.fromFirestore(d, acaraId: acaraId))
        .toList();
    var nomorTerbesar = 0;
    Bundel? terpilih;
    for (final b in daftar) {
      if (b.nomor > nomorTerbesar) nomorTerbesar = b.nomor;
      if (!bundelPenuh(b.jumlahAmplop) &&
          (terpilih == null || b.nomor > terpilih.nomor)) {
        terpilih = b;
      }
    }
    if (terpilih != null) return terpilih;

    final refBaru = _refAcara(acaraId).collection('bundel').doc();
    final baru = Bundel(
      id: refBaru.id,
      acaraId: acaraId,
      pencatatId: pemilikId,
      prefix: prefixBundelPemilik,
      nomor: nomorTerbesar + 1,
    );
    final batch = _db.batch();
    batch.set(refBaru, baru.toMap());
    batch.update(_refAcara(acaraId), <String, dynamic>{
      'totalBundel': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    return baru;
  }

  /// Tambah satu amplop ke bundel yang belum penuh.
  Future<void> tambahAmplop({
    required String acaraId,
    required String bundelId,
    required String pemilikId,
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
    final bundel = (await _pastikanBolehKoreksi(acaraId, bundelId)).bundel;
    // Bundel bebas (Batch 30) tidak pernah penuh.
    if (!bundel.bebas && bundelPenuh(bundel.jumlahAmplop)) {
      throw const LayananException(
        'Bundel ini sudah penuh (10 pengunjung) — tambah tidak tersedia. '
        'Pilih bundel lain yang belum penuh.',
      );
    }
    final namaEfektif = namaSimpan(jenis, nama);
    final nominalEfektif = nominalSimpan(jenis, nominal);
    final menutup =
        !bundel.bebas && amplopIniMenutupBundel(bundel.jumlahAmplop);

    // Nomor urut dari slot kosong, bukan jumlah + 1: setelah hapus di
    // tengah bundel, nomor lama tetap terpakai (lihat slotUrutKosong).
    // Bundel bebas: urut berjalan terus — nomor terbesar + 1.
    final refBundel = _refBundel(acaraId, bundelId);
    final snapAmplop = await refBundel.collection('amplop').get();
    final urutTerpakai = snapAmplop.docs
        .map((d) => Amplop.fromFirestore(d, bundelId: bundelId).urut)
        .toList();
    final int? urut = bundel.bebas
        ? (urutTerpakai.isEmpty
              ? 1
              : urutTerpakai.reduce((a, b) => a > b ? a : b) + 1)
        : slotUrutKosong(urutTerpakai);
    if (urut == null) {
      throw const LayananException('Bundel ini sudah penuh (10 pengunjung).');
    }

    final amplop = Amplop(
      id: '',
      bundelId: bundelId,
      urut: urut,
      nama: namaEfektif,
      alamat: (alamat == null || alamat.trim().isEmpty)
          ? null
          : alamat.trim(),
      dusun: dusun,
      rt: rt,
      rw: rw,
      keterangan: (keterangan == null || keterangan.trim().isEmpty)
          ? null
          : keterangan.trim(),
      nominal: nominalEfektif,
      jenis: jenis,
      createdBy: pemilikId,
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
    int? dusun,
    int? rt,
    int? rw,
    String? keterangan,
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
        'dusun': dusun,
        'rt': rt,
        'rw': rw,
        'keterangan': (keterangan == null || keterangan.trim().isEmpty)
            ? null
            : keterangan.trim(),
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
    final tadinyaPenuh =
        !bundel.bebas && bundelPenuh(bundel.jumlahAmplop);

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
