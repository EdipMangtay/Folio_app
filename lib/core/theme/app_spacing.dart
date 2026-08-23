import 'package:flutter/widgets.dart';

/// Folio V7 geometry: calmer, more classical and less pill-heavy.
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double xxxl = 64;
  static const double huge = 84;

  static const double page = 22;
  static const double section = 48;
  static const double compactSection = 34;
  static const double maxContent = 760;

  static const double radiusXs = 8;
  static const double radiusSm = 12;
  static const double radiusMd = 16;
  static const double radiusLg = 22;
  static const double radiusXl = 28;
  static const double radiusSheet = 30;
  static const double radiusPill = 999;

  static const EdgeInsets pageInsets = EdgeInsets.fromLTRB(page, 18, page, 44);
  static const EdgeInsets pageInsetsTop = EdgeInsets.fromLTRB(page, 26, page, 44);
}
