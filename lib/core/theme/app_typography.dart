import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

abstract final class AppTypography {
  static const List<FontFeature> tabular = <FontFeature>[FontFeature.tabularFigures()];

  static TextTheme textTheme(Brightness brightness) {
    final Color primary = AppColors.ink(brightness);
    final Color secondary = AppColors.muted(brightness);
    final TextTheme base = GoogleFonts.manropeTextTheme();

    TextStyle money(
      double size, {
      double height = 0.96,
      double tracking = -2.0,
      FontWeight weight = FontWeight.w600,
    }) {
      return base.displayLarge!.copyWith(
        fontSize: size,
        height: height,
        fontWeight: weight,
        letterSpacing: tracking,
        color: primary,
        fontFeatures: tabular,
      );
    }

    return TextTheme(
      displayLarge: money(56, height: 0.96, tracking: -2.10, weight: FontWeight.w600),
      displayMedium: money(40, height: 1.0, tracking: -1.45, weight: FontWeight.w600),
      displaySmall: money(30, height: 1.02, tracking: -0.95, weight: FontWeight.w600),
      headlineLarge: base.headlineLarge!.copyWith(
        fontSize: 31,
        height: 1.10,
        fontWeight: FontWeight.w600,
        letterSpacing: -1.05,
        color: primary,
      ),
      headlineMedium: base.headlineMedium!.copyWith(
        fontSize: 23,
        height: 1.16,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.58,
        color: primary,
      ),
      headlineSmall: base.headlineSmall!.copyWith(
        fontSize: 18,
        height: 1.22,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.32,
        color: primary,
      ),
      titleLarge: base.titleLarge!.copyWith(
        fontSize: 17,
        height: 1.28,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.28,
        color: primary,
      ),
      titleMedium: base.titleMedium!.copyWith(
        fontSize: 15,
        height: 1.32,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.15,
        color: primary,
      ),
      titleSmall: base.titleSmall!.copyWith(
        fontSize: 14,
        height: 1.30,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.10,
        color: primary,
      ),
      bodyLarge: base.bodyLarge!.copyWith(
        fontSize: 16,
        height: 1.52,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.18,
        color: primary,
      ),
      bodyMedium: base.bodyMedium!.copyWith(
        fontSize: 14.5,
        height: 1.50,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.10,
        color: primary,
      ),
      bodySmall: base.bodySmall!.copyWith(
        fontSize: 12.5,
        height: 1.42,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.03,
        color: secondary,
      ),
      labelLarge: base.labelLarge!.copyWith(
        fontSize: 13.5,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.08,
        color: primary,
      ),
      labelMedium: base.labelMedium!.copyWith(
        fontSize: 10.5,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.45,
        color: secondary,
      ),
      labelSmall: base.labelSmall!.copyWith(
        fontSize: 10.5,
        height: 1.2,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.12,
        color: secondary,
      ),
    );
  }

  static TextStyle eyebrow(BuildContext context, {Color? color}) {
    return Theme.of(context).textTheme.labelMedium!.copyWith(color: color);
  }

  static TextStyle moneyHero(BuildContext context) => Theme.of(context).textTheme.displayLarge!;
  static TextStyle moneyLarge(BuildContext context) => Theme.of(context).textTheme.displayMedium!;
  static TextStyle moneyMedium(BuildContext context) => Theme.of(context).textTheme.displaySmall!;
}
