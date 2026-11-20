import 'package:cloud_firestore/cloud_firestore.dart';

/// Status kehadiran satu tamu undangan (Batch 34, rancangan
/// multi-metode v2 §6): daftar disiapkan sebelum acara, petugas
/// menandai hadir/tidak di hari-H.
enum StatusHadir {
  belum,
  hadir,
  tidak;

  static StatusHadir dariString(String? nilai) {
    switch (nilai) {
      case 'hadir':
        return StatusHadir.hadir;
      case 'tidak':
        return StatusHadir.tidak;
      default:
        return StatusHadir.belum;
    }
  }

  /// Nilai yang disimpan di Firestore.
  String get nilaiSimpan => name;

  String get label {
    switch (this) {
      case StatusHadir.belum:
        return 'Belum ada kabar';
      case StatusHadir.hadir:
        return 'Hadir';
      case StatusHadir.tidak:
        return 'Tidak hadir';
    }
  }
}

/// Satu tamu dalam Daftar Undangan. Dokumen:
/// `acara/{acaraId}/tamuUndangan/{tamuId}`.
///
/// Nama boleh kembar — alamat selalu tampil sebagai pembeda
/// (rancangan §6.2). [kodeTamu] adalah kode acak 8 karakter per
/// tamu, unik dalam acara — isi QR undangan (Batch 35).
class TamuUndangan {
  const TamuUndangan({
    required this.id,
    required this.nama,
    this.alamat,
    this.dusun,
    this.rt,
    this.rw,
    this.kategori,
    required this.kodeTamu,
    this.statusHadir = StatusHadir.belum,
    this.hadirAt,
    this.amplopId,
    this.dicatatOleh,
    this.asal = 'daftar',
  });

  final String id;
  final String nama;
  final String? alamat;

  /// Dusun/kampung teks bebas (Batch 36, sama seperti Amplop;
  /// dokumen lama berangka terbaca sebagai teks angka).
  final String? dusun;
  final int? rt;
  final int? rw;

  /// Kategori bebas, mis. "Keluarga", "Rekan kerja", "Tetangga".
  final String? kategori;

  final String kodeTamu;
  final StatusHadir statusHadir;

  /// Waktu ditandai hadir (server).
  final DateTime? hadirAt;

  /// ID dokumen amplop bila hadir dengan amplop — tautan ke
  /// catatan uangnya (null bila hadir tanpa amplop / belum hadir).
  final String? amplopId;

  /// ID pencatat yang menandai (jejak siapa menandai hadir).
  final String? dicatatOleh;

  /// `'daftar'` (disiapkan sebelum acara) atau `'langsung'`
  /// (walk-in: tamu tak terdaftar yang dicatat manual — dibuat
  /// otomatis oleh pencatatan, §6.3).
  final String asal;

  bool get dariDaftar => asal == 'daftar';

  factory TamuUndangan.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return TamuUndangan(
      id: doc.id,
      nama: (data['nama'] as String?) ?? '',
      alamat: data['alamat'] as String?,
      dusun: data['dusun']?.toString(),
      rt: (data['rt'] as num?)?.toInt(),
      rw: (data['rw'] as num?)?.toInt(),
      kategori: data['kategori'] as String?,
      kodeTamu: (data['kodeTamu'] as String?) ?? '',
      statusHadir: StatusHadir.dariString(data['statusHadir'] as String?),
      hadirAt: (data['hadirAt'] as Timestamp?)?.toDate(),
      amplopId: data['amplopId'] as String?,
      dicatatOleh: data['dicatatOleh'] as String?,
      asal: (data['asal'] as String?) ?? 'daftar',
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'nama': nama,
      'alamat': alamat,
      'dusun': dusun,
      'rt': rt,
      'rw': rw,
      'kategori': kategori,
      'kodeTamu': kodeTamu,
      'statusHadir': statusHadir.nilaiSimpan,
      // hadirAt hanya terisi saat ditandai hadir — tamu baru
      // (status belum) tidak boleh membawa stempel waktu.
      'hadirAt': hadirAt == null ? null : Timestamp.fromDate(hadirAt!),
      'amplopId': amplopId,
      'dicatatOleh': dicatatOleh,
      'asal': asal,
    };
  }
}
