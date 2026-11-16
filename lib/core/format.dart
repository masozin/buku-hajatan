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
