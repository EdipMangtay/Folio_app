import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../motion/folio_page_transitions.dart';
import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final bool dark = brightness == Brightness.dark;
    final Color canvas = AppColors.canvas(brightness);
    final Color surface = AppColors.surface(brightness);
    final Color elevated = AppColors.elevated(brightness);
    final Color ink = AppColors.ink(brightness);
    final Color muted = AppColors.muted(brightness);
    final Color line = AppColors.line(brightness);
    final Color accent = AppColors.accent(brightness);

    final ColorScheme scheme = ColorScheme(
      brightness: brightness,
      primary: accent,
      onPrimary: dark ? AppColors.inkLight : Colors.white,
      secondary: AppColors.sage,
      onSecondary: Colors.white,
      error: AppColors.terracotta,
      onError: Colors.white,
      surface: surface,
      onSurface: ink,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      canvasColor: canvas,
      cardColor: surface,
      dividerColor: line,
      textTheme: AppTypography.textTheme(brightness),
      splashFactory: InkRipple.splashFactory,
      splashColor: accent.withValues(alpha: 0.045),
      highlightColor: accent.withValues(alpha: 0.022),
      hoverColor: ink.withValues(alpha: 0.018),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: AppTypography.textTheme(brightness).titleLarge,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: elevated,
        contentPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: line.withValues(alpha: 0.95), width: 0.8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: accent.withValues(alpha: 0.48), width: 1),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: AppColors.terracotta.withValues(alpha: 0.55)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: AppColors.terracotta.withValues(alpha: 0.72), width: 1),
        ),
        hintStyle: TextStyle(color: muted.withValues(alpha: 0.78), fontWeight: FontWeight.w400),
        labelStyle: TextStyle(color: muted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          backgroundColor: ink,
          foregroundColor: canvas,
          disabledBackgroundColor: ink.withValues(alpha: 0.12),
          disabledForegroundColor: muted,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
          textStyle: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: -0.1),
          elevation: 0,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          textStyle: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: -0.08),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: ink,
          minimumSize: const Size(44, 44),
          shape: const CircleBorder(),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: elevated,
        selectedColor: AppColors.accentSoft(brightness),
        disabledColor: elevated,
        side: BorderSide(color: line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        labelStyle: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w500, color: ink),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        showDragHandle: false,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusSheet)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusLg)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ink,
        contentTextStyle: AppTypography.textTheme(brightness).bodyMedium?.copyWith(color: canvas),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: accent),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          return states.contains(WidgetState.selected) ? elevated : muted;
        }),
        trackColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          return states.contains(WidgetState.selected)
              ? AppColors.sage.withValues(alpha: dark ? 0.84 : 0.78)
              : AppColors.soft(brightness);
        }),
        trackOutlineColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: surface,
        headerHeadlineStyle: AppTypography.textTheme(brightness).headlineMedium,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          side: WidgetStatePropertyAll<BorderSide>(BorderSide(color: line)),
          backgroundColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
            if (states.contains(WidgetState.selected)) return AppColors.accentSoft(brightness);
            return Colors.transparent;
          }),
          foregroundColor: WidgetStatePropertyAll<Color>(ink),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.iOS: FolioPageTransitionsBuilder(),
          TargetPlatform.macOS: FolioPageTransitionsBuilder(),
          TargetPlatform.android: FolioPageTransitionsBuilder(),
          TargetPlatform.windows: FolioPageTransitionsBuilder(),
          TargetPlatform.linux: FolioPageTransitionsBuilder(),
          TargetPlatform.fuchsia: FolioPageTransitionsBuilder(),
        },
      ),
    );
  }
}
