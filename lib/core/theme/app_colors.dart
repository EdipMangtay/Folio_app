import 'package:flutter/material.dart';

/// Folio V8 — premium warm palette with stronger contrast and cleaner accents.
abstract final class AppColors {
  // Light layers.
  static const Color canvasLight = Color(0xFFF8F4ED);
  static const Color surfaceLight = Color(0xFFFFFCF7);
  static const Color elevatedLight = Color(0xFFFFFEFB);
  static const Color softLight = Color(0xFFF0E5D8);
  static const Color inkLight = Color(0xFF241A12);
  static const Color mutedLight = Color(0xFF776553);
  static const Color tertiaryLight = Color(0xFFA48F7A);
  static const Color lineLight = Color(0x2136261B);

  // Dark layers.
  static const Color canvasDark = Color(0xFF14100D);
  static const Color surfaceDark = Color(0xFF1D1713);
  static const Color elevatedDark = Color(0xFF261E19);
  static const Color softDark = Color(0xFF322822);
  static const Color inkDark = Color(0xFFF7F0E8);
  static const Color mutedDark = Color(0xFFC9B9AB);
  static const Color tertiaryDark = Color(0xFF9C8A7C);
  static const Color lineDark = Color(0x26FFFFFF);

  // Brand accent — richer espresso bronze.
  static const Color coffee = Color(0xFF8E6646);
  static const Color coffeeBright = Color(0xFFD0B08C);
  static const Color coffeeSoft = Color(0xFFF1E4D5);
  static const Color coffeeDarkSoft = Color(0xFF392D24);

  // Supporting semantic/category tones.
  static const Color sage = Color(0xFF64866A);
  static const Color terracotta = Color(0xFFB97659);
  static const Color blueGray = Color(0xFF7C92A0);
  static const Color sand = Color(0xFFB39371);
  static const Color olive = Color(0xFF81906D);
  static const Color dustyRose = Color(0xFFA77E83);
  static const Color amber = Color(0xFFB2834F);
  static const Color slate = Color(0xFF8B817A);

  static const Color coral = terracotta;
  static const Color sky = blueGray;
  static const Color mint = olive;
  static const Color rose = dustyRose;

  static Color ink(Brightness brightness) => brightness == Brightness.dark ? inkDark : inkLight;
  static Color muted(Brightness brightness) => brightness == Brightness.dark ? mutedDark : mutedLight;
  static Color tertiary(Brightness brightness) => brightness == Brightness.dark ? tertiaryDark : tertiaryLight;
  static Color canvas(Brightness brightness) => brightness == Brightness.dark ? canvasDark : canvasLight;
  static Color surface(Brightness brightness) => brightness == Brightness.dark ? surfaceDark : surfaceLight;
  static Color elevated(Brightness brightness) => brightness == Brightness.dark ? elevatedDark : elevatedLight;
  static Color soft(Brightness brightness) => brightness == Brightness.dark ? softDark : softLight;
  static Color line(Brightness brightness) => brightness == Brightness.dark ? lineDark : lineLight;
  static Color accent(Brightness brightness) => brightness == Brightness.dark ? coffeeBright : coffee;
  static Color accentSoft(Brightness brightness) => brightness == Brightness.dark ? coffeeDarkSoft : coffeeSoft;

  static Color category(String category) {
    switch (category) {
      case 'Yeme & İçme':
        return terracotta;
      case 'Market':
        return sage;
      case 'Ulaşım':
        return blueGray;
      case 'Alışveriş':
        return dustyRose;
      case 'Ev':
      case 'Faturalar':
        return sand;
      case 'Sağlık':
      case 'Spor':
        return olive;
      case 'Kahve':
        return amber;
      case 'Abonelik':
      case 'Teknoloji':
        return coffeeBright;
      case 'Maaş':
      case 'Freelance':
      case 'Nakit Girişi':
      case 'Yatırım Getirisi':
      case 'Satış':
      case 'İade':
      case 'Hediye':
      case 'Diğer Gelir':
      case 'Finans':
        return sage;
      default:
        return slate;
    }
  }

  static Color pulseForScore(int score) {
    if (score >= 80) return sage;
    if (score >= 65) return coffee;
    return terracotta;
  }
}
