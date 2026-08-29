import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final Provider<SharedPreferencesWithCache> preferencesProvider = Provider<SharedPreferencesWithCache>(
  (Ref ref) => throw UnimplementedError('preferencesProvider must be overridden in main.dart'),
);

class SettingsState {
  const SettingsState({
    required this.themeMode,
    required this.userName,
    required this.hasSeenOnboarding,
    required this.privacyLockEnabled,
    this.hideBalances = false,
    this.weeklyNotificationsEnabled = true,
  });

  final ThemeMode themeMode;
  final String userName;
  final bool hasSeenOnboarding;
  final bool privacyLockEnabled;
  final bool hideBalances;
  final bool weeklyNotificationsEnabled;

  SettingsState copyWith({
    ThemeMode? themeMode,
    String? userName,
    bool? hasSeenOnboarding,
    bool? privacyLockEnabled,
    bool? hideBalances,
    bool? weeklyNotificationsEnabled,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      userName: userName ?? this.userName,
      hasSeenOnboarding: hasSeenOnboarding ?? this.hasSeenOnboarding,
      privacyLockEnabled: privacyLockEnabled ?? this.privacyLockEnabled,
      hideBalances: hideBalances ?? this.hideBalances,
      weeklyNotificationsEnabled:
          weeklyNotificationsEnabled ?? this.weeklyNotificationsEnabled,
    );
  }
}

final NotifierProvider<SettingsController, SettingsState> settingsProvider =
    NotifierProvider<SettingsController, SettingsState>(SettingsController.new);

class SettingsController extends Notifier<SettingsState> {
  static const String _themeKey = 'theme_mode';
  static const String _userKey = 'user_name';
  static const String _onboardingKey = 'onboarding_seen';
  static const String _privacyLockKey = 'privacy_lock_enabled';
  static const String _hideBalancesKey = 'hide_balances';
  static const String _weeklyNotificationsKey = 'weekly_notifications_enabled';

  SharedPreferencesWithCache get _prefs => ref.read(preferencesProvider);

  @override
  SettingsState build() {
    final String rawTheme = _prefs.getString(_themeKey) ?? 'system';
    final ThemeMode mode = switch (rawTheme) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    return SettingsState(
      themeMode: mode,
      userName: _prefs.getString(_userKey) ?? 'Edip',
      hasSeenOnboarding: _prefs.getBool(_onboardingKey) ?? false,
      privacyLockEnabled: _prefs.getBool(_privacyLockKey) ?? false,
      hideBalances: _prefs.getBool(_hideBalancesKey) ?? false,
      weeklyNotificationsEnabled:
          _prefs.getBool(_weeklyNotificationsKey) ?? true,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _prefs.setString(_themeKey, mode.name);
  }

  Future<void> setUserName(String value) async {
    final String clean = value.trim().isEmpty ? 'Edip' : value.trim();
    state = state.copyWith(userName: clean);
    await _prefs.setString(_userKey, clean);
  }

  Future<void> completeOnboarding() async {
    state = state.copyWith(hasSeenOnboarding: true);
    await _prefs.setBool(_onboardingKey, true);
  }

  Future<void> setPrivacyLockEnabled(bool enabled) async {
    state = state.copyWith(privacyLockEnabled: enabled);
    await _prefs.setBool(_privacyLockKey, enabled);
  }

  Future<void> toggleHideBalances() async {
    final bool next = !state.hideBalances;
    state = state.copyWith(hideBalances: next);
    await _prefs.setBool(_hideBalancesKey, next);
  }

  Future<void> setHideBalances(bool value) async {
    state = state.copyWith(hideBalances: value);
    await _prefs.setBool(_hideBalancesKey, value);
  }

  Future<void> toggleWeeklyNotifications() async {
    final bool next = !state.weeklyNotificationsEnabled;
    state = state.copyWith(weeklyNotificationsEnabled: next);
    await _prefs.setBool(_weeklyNotificationsKey, next);
  }

  Future<void> setWeeklyNotifications(bool value) async {
    state = state.copyWith(weeklyNotificationsEnabled: value);
    await _prefs.setBool(_weeklyNotificationsKey, value);
  }
}
