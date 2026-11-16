import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/rekap.dart';
import '../models/amplop.dart';
import '../models/bundel.dart';

/// Pembacaan data untuk rekap & ekspor (Batch 3).
///
/// Rekap realtime di layar TIDAK lewat sini — ia mendengarkan stream
/// bundel (PencatatanService.semuaBundelStream) + stream acara, sesuai
/// rancangan §3. Service ini hanya untuk pembacaan SEKALI jalan yang
/// memang butuh isi amplop: pencarian nama dan ekspor Excel/CSV.
class RekapService {
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _bundelRef(String acaraId) =>
      _db.collection('acara').doc(acaraId).collection('bundel');

  /// Semua bundel acara ini beserta isi amplopnya, sekali baca.
  /// Dipakai pencarian & ekspor — sengaja BUKAN listener, supaya tidak
  /// menahan kuota baca selama layar terbuka.
  Future<List<BundelTerisi>> ambilDataLengkap(String acaraId) async {
    final snapBundel = await _bundelRef(acaraId).get();
    final bundels = snapBundel.docs
        .map((d) => Bundel.fromFirestore(d, acaraId: acaraId))
        .toList();
    bundels.sort((a, b) {
      final bandingPrefix = a.prefix.compareTo(b.prefix);
      return bandingPrefix != 0 ? bandingPrefix : a.nomor.compareTo(b.nomor);
    });

    final hasil = <BundelTerisi>[];
    for (final bundel in bundels) {
      final snapAmplop = await _bundelRef(acaraId)
          .doc(bundel.id)
          .collection('amplop')
          .get();
      final isi = snapAmplop.docs
          .map((d) => Amplop.fromFirestore(d, bundelId: bundel.id))
          .toList();
      isi.sort((a, b) => a.urut.compareTo(b.urut));
      hasil.add(BundelTerisi(bundel: bundel, isi: isi));
    }
    return hasil;
  }

  /// Cari tamu berdasarkan potongan nama/alamat di seluruh acara.
  Future<List<AmplopDitemukan>> cariNama(
    String acaraId,
    String kataKunci,
  ) async {
    final data = await ambilDataLengkap(acaraId);
    return cariDalamData(data, kataKunci);
  }
}
