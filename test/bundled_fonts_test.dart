import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// google_fonts resolves bundled files by filename. If one of these assets is
/// renamed or dropped from the pubspec, release builds fall back to the system
/// font without any visible error, so the bundle is asserted here instead.
void main() {
  const List<String> requiredVariants = <String>[
    'ExtraLight',
    'Light',
    'Regular',
    'Medium',
    'SemiBold',
    'Bold',
    'ExtraBold',
  ];

  testWidgets('every Manrope weight is bundled with the app', (WidgetTester tester) async {
    final AssetManifest manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final List<String> assets = manifest.listAssets();

    for (final String variant in requiredVariants) {
      expect(
        assets.any((String asset) => asset.endsWith('Manrope-$variant.ttf')),
        isTrue,
        reason: 'Manrope-$variant.ttf is missing from the asset bundle',
      );
    }
  });

  testWidgets('the font licence ships with the fonts', (WidgetTester tester) async {
    final String licence = await rootBundle.loadString('assets/fonts/OFL.txt');

    expect(licence, contains('SIL Open Font License'));
  });
}
