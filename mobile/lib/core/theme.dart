import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// SmartEvents brand colours, matching the web app (client/src/index.css).
class AppColors {
  AppColors._();

  static const brand = Color(0xFF4F46E5);
  static const brandDark = Color(0xFF818CF8);
  static const success = Color(0xFF046C4E);
  static const successDark = Color(0xFF34D399);
  static const danger = Color(0xFFE11D48);
  static const warning = Color(0xFFD97706);

  // Light
  static const bg = Color(0xFFF8F9FB);
  static const surface = Color(0xFFFFFFFF);
  static const surface2 = Color(0xFFF4F6F9);
  static const border = Color(0xFFE2E8F0);
  static const fg = Color(0xFF0F172A);
  static const muted = Color(0xFF475569);

  // Dark
  static const bgDark = Color(0xFF0D1018);
  static const surfaceDark = Color(0xFF171B26);
  static const surface2Dark = Color(0xFF1F2432);
  static const borderDark = Color(0xFF2C3344);
  static const fgDark = Color(0xFFF1F5F9);
  static const mutedDark = Color(0xFF94A3B8);

  static const brandGradient = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF4338CA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Extra colours that Material's ColorScheme does not name.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.surface2,
    required this.border,
    required this.muted,
    required this.success,
    required this.warning,
  });

  final Color surface2;
  final Color border;
  final Color muted;
  final Color success;
  final Color warning;

  static AppPalette of(BuildContext context) => Theme.of(context).extension<AppPalette>()!;

  @override
  AppPalette copyWith({Color? surface2, Color? border, Color? muted, Color? success, Color? warning}) => AppPalette(
        surface2: surface2 ?? this.surface2,
        border: border ?? this.border,
        muted: muted ?? this.muted,
        success: success ?? this.success,
        warning: warning ?? this.warning,
      );

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      surface2: Color.lerp(surface2, other.surface2, t)!,
      border: Color.lerp(border, other.border, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
    );
  }
}

class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final dark = b == Brightness.dark;
    final brand = dark ? AppColors.brandDark : AppColors.brand;
    final bg = dark ? AppColors.bgDark : AppColors.bg;
    final surface = dark ? AppColors.surfaceDark : AppColors.surface;
    final surface2 = dark ? AppColors.surface2Dark : AppColors.surface2;
    final border = dark ? AppColors.borderDark : AppColors.border;
    final fg = dark ? AppColors.fgDark : AppColors.fg;
    final muted = dark ? AppColors.mutedDark : AppColors.muted;

    final scheme = ColorScheme.fromSeed(seedColor: AppColors.brand, brightness: b).copyWith(
      primary: brand,
      // Like the website: dark text on the lighter brand colour in dark mode.
      onPrimary: dark ? AppColors.bgDark : Colors.white,
      surface: surface,
      onSurface: fg,
      error: AppColors.danger,
      outline: border,
    );

    final text = ThemeData(brightness: b).textTheme.apply(
      fontFamily: GoogleFonts.instrumentSans().fontFamily,
      bodyColor: fg,
      displayColor: fg,
    );

    OutlineInputBorder field(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c, width: w),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      textTheme: text.copyWith(
        headlineLarge: text.headlineLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.8),
        headlineMedium: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.6),
        headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.4),
        titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.3),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      extensions: [
        AppPalette(
          surface2: surface2,
          border: border,
          muted: muted,
          success: dark ? AppColors.successDark : AppColors.success,
          warning: AppColors.warning,
        ),
      ],
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: fg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: fg),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: border)),
      ),
      dividerTheme: DividerThemeData(color: border, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: field(border),
        enabledBorder: field(border),
        focusedBorder: field(brand, 1.6),
        errorBorder: field(AppColors.danger),
        focusedErrorBorder: field(AppColors.danger, 1.6),
        hintStyle: TextStyle(color: muted),
        labelStyle: TextStyle(color: muted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: brand,
          foregroundColor: dark ? AppColors.bgDark : Colors.white,
          minimumSize: const Size(48, 52),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: fg,
          minimumSize: const Size(48, 52),
          side: BorderSide(color: border),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: brand, textStyle: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface2,
        selectedColor: brand,
        side: BorderSide(color: border),
        labelStyle: TextStyle(color: fg, fontWeight: FontWeight.w600),
        secondaryLabelStyle: TextStyle(color: dark ? AppColors.bgDark : Colors.white, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        showCheckmark: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: brand.withValues(alpha: 0.14),
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => TextStyle(
            fontSize: 11.5,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600,
            color: s.contains(WidgetState.selected) ? brand : muted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(color: s.contains(WidgetState.selected) ? brand : muted),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: brand,
          selectedForegroundColor: dark ? AppColors.bgDark : Colors.white,
          side: BorderSide(color: border),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
