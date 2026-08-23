import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'state/settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
    ),
  );

  final SharedPreferencesWithCache preferences = await SharedPreferencesWithCache.create(
    cacheOptions: const SharedPreferencesWithCacheOptions(
      allowList: <String>{'theme_mode', 'user_name', 'onboarding_seen', 'privacy_lock_enabled'},
    ),
  );
  final bool onboardingSeen = preferences.getBool('onboarding_seen') ?? false;

  runApp(
    ProviderScope(
      overrides: [
        preferencesProvider.overrideWithValue(preferences),
      ],
      child: FolioApp(onboardingSeen: onboardingSeen),
    ),
  );
}
