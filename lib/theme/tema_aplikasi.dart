import 'package:flutter/material.dart';

/// Sistem desain Buku Hajatan (Batch 12 — rombak tampilan).
///
/// Identitas: **zamrud & emas** — hijau zamrud yang dalam untuk
/// rasa resmi dan terpercaya (urusan uang titipan), aksen emas
/// yang hemat untuk sentuhan hajatan. Tipografi **Plus Jakarta
/// Sans** (dibundel sebagai aset, tetap tampil luring).
///
/// Prinsip tampilan: permukaan bersih berwarna kertas hangat,
/// kartu putih bersudut besar (20) dengan garis tepi sangat tipis
/// sebagai pengganti bayangan keras, tombol utama berbentuk pil
/// setinggi 52, kolom isian terisi (filled) bersudut 14, dan tab
/// berbentuk pil. Tema gelap mengikuti setelan perangkat.
///
/// Semua layar memakai komponen standar Material 3 yang ditata
/// dari sini — perubahan tampilan cukup dilakukan di berkas ini.
class TemaAplikasi {
  const TemaAplikasi._();

  static const String keluargaFont = 'PlusJakartaSans';

  /// Warna merek.
  static const Color zamrud = Color(0xFF0B6E4F);
  static const Color zamrudGelap = Color(0xFF084F39);
  static const Color zamrudTerang = Color(0xFF149A6C);
  static const Color emas = Color(0xFFA67C1A);
  static const Color emasTerang = Color(0xFFDFB84F);

  /// Gradasi untuk kartu sorotan (total acara, bundel aktif).
  static const LinearGradient gradasiPahlawan = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [zamrudTerang, zamrud, zamrudGelap],
    stops: [0, 0.55, 1],
  );

  static ThemeData get terang => _buat(Brightness.light);
  static ThemeData get gelap => _buat(Brightness.dark);

  static ThemeData _buat(Brightness kecerahan) {
    final terangMode = kecerahan == Brightness.light;
    var skema = ColorScheme.fromSeed(
      seedColor: zamrud,
      brightness: kecerahan,
    );
    skema = skema.copyWith(
      // Emas sebagai warna ketiga (aksen hajatan).
      tertiary: terangMode ? emas : emasTerang,
      tertiaryContainer: terangMode
          ? const Color(0xFFF7E7BD)
          : const Color(0xFF57430C),
      onTertiaryContainer: terangMode
          ? const Color(0xFF3D2E04)
          : const Color(0xFFFFE9B0),
      primaryContainer: terangMode
          ? const Color(0xFFD5EFE1)
          : const Color(0xFF0E4630),
      onPrimaryContainer: terangMode
          ? const Color(0xFF04301F)
          : const Color(0xFFB9E8CF),
      outlineVariant: terangMode
          ? const Color(0xFFE4E1D8)
          : const Color(0xFF39413B),
    );

    final latar = terangMode
        ? const Color(0xFFF8F7F3)
        : const Color(0xFF0E120F);
    final warnaKartu = terangMode ? Colors.white : skema.surfaceContainerLow;
    final isiKolom = terangMode
        ? const Color(0xFFF1EFE8)
        : skema.surfaceContainerHigh;

    final teks = _gayaTeks(skema);

    OutlineInputBorder sisiKolom(Color warna, double lebar) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: warna, width: lebar),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: skema,
      fontFamily: keluargaFont,
      scaffoldBackgroundColor: latar,
      textTheme: teks,
      appBarTheme: AppBarThemeData(
        backgroundColor: latar,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: skema.onSurface,
        titleTextStyle: teks.titleLarge,
        iconTheme: IconThemeData(color: skema.onSurface),
      ),
      cardTheme: CardThemeData(
        color: warnaKartu,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: skema.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: const StadiumBorder(),
          side: BorderSide(color: skema.outline),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: isiKolom,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: sisiKolom(Colors.transparent, 1),
        enabledBorder: sisiKolom(Colors.transparent, 1),
        focusedBorder: sisiKolom(skema.primary, 1.6),
        errorBorder: sisiKolom(skema.error, 1),
        focusedErrorBorder: sisiKolom(skema.error, 1.6),
        labelStyle: TextStyle(color: skema.onSurfaceVariant),
        floatingLabelStyle: TextStyle(
          color: skema.primary,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: TextStyle(
          color: skema.onSurfaceVariant.withValues(alpha: 0.75),
        ),
        prefixIconColor: skema.onSurfaceVariant,
        suffixIconColor: skema.onSurfaceVariant,
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide.none,
        backgroundColor: skema.surfaceContainerHighest,
        labelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
      tabBarTheme: TabBarThemeData(
        indicator: BoxDecoration(
          color: skema.primaryContainer,
          borderRadius: BorderRadius.circular(999),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: skema.onPrimaryContainer,
        unselectedLabelColor: skema.onSurfaceVariant,
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        dividerColor: Colors.transparent,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: skema.primary,
        foregroundColor: skema.onPrimary,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          side: WidgetStateProperty.all(
            BorderSide(color: skema.outlineVariant),
          ),
          textStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        titleTextStyle: teks.titleLarge,
        contentTextStyle: teks.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        backgroundColor: skema.surface,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: skema.outlineVariant,
        thickness: 0.8,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: skema.primary,
        linearTrackColor: skema.surfaceContainerHighest,
      ),
      listTileTheme: ListTileThemeData(iconColor: skema.onSurfaceVariant),
      expansionTileTheme: ExpansionTileThemeData(
        shape: const Border(),
        collapsedShape: const Border(),
        iconColor: skema.onSurfaceVariant,
        collapsedIconColor: skema.onSurfaceVariant,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: skema.primary,
        selectionColor: skema.primary.withValues(alpha: 0.25),
        selectionHandleColor: skema.primary,
      ),
    );
  }

  /// Skala tipografi: judul tegas (700/800), isi nyaman dibaca.
  static TextTheme _gayaTeks(ColorScheme skema) {
    return TextTheme(
      displaySmall: const TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        height: 1.15,
      ),
      headlineMedium: const TextStyle(
        fontSize: 27,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
        height: 1.2,
      ),
      headlineSmall: const TextStyle(
        fontSize: 23,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        height: 1.25,
      ),
      titleLarge: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        height: 1.3,
      ),
      titleMedium: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        height: 1.35,
      ),
      titleSmall: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.35,
      ),
      bodyLarge: const TextStyle(fontSize: 16, height: 1.5),
      bodyMedium: const TextStyle(fontSize: 14, height: 1.5),
      bodySmall: const TextStyle(fontSize: 12.5, height: 1.45),
      labelLarge: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ).apply(fontFamily: keluargaFont, bodyColor: skema.onSurface);
  }
}
