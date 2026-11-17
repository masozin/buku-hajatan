import 'package:intl/intl.dart';

/// Format tampilan Rupiah & tanggal (locale Indonesia).
///
/// [formatTanggal] membutuhkan `initializeDateFormatting('id_ID')`
/// yang sudah dipanggil di main.dart sebelum aplikasi berjalan.

final NumberFormat _formatRp = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
);

/// 1500000 -> "Rp 1.500.000"
String formatRupiah(int nilai) => _formatRp.format(nilai);

final DateFormat _formatTgl = DateFormat('EEEE, d MMMM y', 'id_ID');
final DateFormat _formatTglSingkat = DateFormat('d MMM y', 'id_ID');

/// "Senin, 16 November 2026"
String formatTanggal(DateTime tanggal) => _formatTgl.format(tanggal);

/// "16 Nov 2026"
String formatTanggalSingkat(DateTime tanggal) =>
    _formatTglSingkat.format(tanggal);

final DateFormat _formatJam = DateFormat('HH:mm');

/// "14:35" — jam dari timestamp pencatatan amplop (Batch 7).
String formatJam(DateTime waktu) => _formatJam.format(waktu);

final DateFormat _formatTglJam = DateFormat('d MMM y HH:mm', 'id_ID');

/// "16 Nov 2026 14:35"
String formatTanggalJam(DateTime waktu) => _formatTglJam.format(waktu);

/// Cap waktu ringkas untuk baris daftar (Batch 13): bila [waktu]
/// jatuh pada hari kalender yang sama dengan [sekarang], cukup
/// jamnya ("14:35"); bila sudah beda tanggal, tanggal + jam
/// ("16 Nov 2026 14:35").
String formatWaktuKonteks(DateTime waktu, {DateTime? sekarang}) {
  final acuan = sekarang ?? DateTime.now();
  final hariSama =
      waktu.year == acuan.year &&
      waktu.month == acuan.month &&
      waktu.day == acuan.day;
  return hariSama ? formatJam(waktu) : formatTanggalJam(waktu);
}
