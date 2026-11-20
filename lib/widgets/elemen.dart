import 'package:flutter/material.dart';

import '../models/acara.dart';
import '../theme/tema_aplikasi.dart';

/// Elemen merek & potongan tampilan bersama (Batch 12).

/// Tanda merek aplikasi: logo Buku Hajatan — dua tamu di belakang
/// buku terbuka dengan pena emas (Batch 16). Versi terang dipakai
/// di tema terang, versi zamrud di tema gelap — dipakai di layar
/// Masuk dan tempat lain yang membutuhkan identitas aplikasi.
class LogoAplikasi extends StatelessWidget {
  const LogoAplikasi({super.key, this.ukuran = 64});

  final double ukuran;

  @override
  Widget build(BuildContext context) {
    final gelap = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: ukuran,
      height: ukuran,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ukuran * 0.3),
        boxShadow: [
          BoxShadow(
            color: TemaAplikasi.zamrud.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ukuran * 0.3),
        child: Image.asset(
          gelap
              ? 'assets/icon/logo_zamrud.png'
              : 'assets/icon/logo_terang.png',
          width: ukuran,
          height: ukuran,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

/// Lencana status acara: Aktif = hijau zamrud muda,
/// Selesai = abu hangat.
class ChipStatusAcara extends StatelessWidget {
  const ChipStatusAcara({super.key, required this.status});

  final StatusAcara status;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final aktif = status == StatusAcara.aktif;
    return Chip(
      avatar: Icon(
        aktif ? Icons.circle : Icons.check_circle,
        size: 10,
        color: aktif ? skema.primary : skema.onSurfaceVariant,
      ),
      label: Text(status.label),
      backgroundColor: aktif
          ? skema.primaryContainer
          : skema.surfaceContainerHighest,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: aktif ? skema.onPrimaryContainer : skema.onSurfaceVariant,
      ),
      visualDensity: VisualDensity.compact,
    );
  }
}

/// Zona teks rapi (fix skala font 2026-11-20): di dalam zona
/// ini skala font perangkat dijepit lebih ketat (maks 1,15x)
/// daripada plafon konten aplikasi (1,45x di main.dart).
/// Dipakai untuk bagian struktural yang komposisinya rapat —
/// kartu total, kartu bundel aktif, panel ringkasan — supaya
/// font besar tidak membuatnya meluber, sementara teks isi
/// (nama, alamat, nominal) di luar zona tetap boleh membesar
/// mengikuti setelan pengguna.
class ZonaTeksRapi extends StatelessWidget {
  const ZonaTeksRapi({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(
        textScaler: media.textScaler.clamp(
          minScaleFactor: 0.85,
          maxScaleFactor: 1.15,
        ),
      ),
      child: child,
    );
  }
}

/// TabBar di zona rapi (Batch 35): teks tab (Ringkasan /
/// Pengunjung / Bundel) ikut plafon konten 1,45x dan tampak
/// terlalu besar di font besar — bungkus ini menjepitnya ke
/// 1,15x seperti kartu panggung. Mengimplementasikan
/// PreferredSizeWidget karena AppBar.bottom menuntutnya;
/// tinggi 72 mengikuti tab ikon + teks Material.
class ZonaTeksRapiTab extends StatelessWidget
    implements PreferredSizeWidget {
  const ZonaTeksRapiTab({super.key, required this.child});

  final TabBar child;

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    return ZonaTeksRapi(child: child);
  }
}

/// Judul bagian di dalam halaman (mis. "Acara Saya"), dengan
/// ruang aksi opsional di sisi kanan.
class JudulBagian extends StatelessWidget {
  const JudulBagian({super.key, required this.teks, this.aksi});

  final String teks;
  final Widget? aksi;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            teks,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        ?aksi,
      ],
    );
  }
}
