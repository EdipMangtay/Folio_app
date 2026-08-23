import 'package:flutter/widgets.dart';

/// Shared Folio V3 motion tokens. Motion communicates continuity and feedback;
/// it is never used as decoration.
abstract final class FolioMotion {
  static const Duration quick = Duration(milliseconds: 150);
  static const Duration standard = Duration(milliseconds: 220);
  static const Duration expressive = Duration(milliseconds: 320);

  static const Duration tab = Duration(milliseconds: 220);
  static const Duration page = Duration(milliseconds: 280);
  static const Duration pageReverse = Duration(milliseconds: 220);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve through = Curves.easeInOutCubic;

  static bool reduce(BuildContext context) => MediaQuery.disableAnimationsOf(context);
}
