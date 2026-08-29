import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../core/utils/formatters.dart';
import '../domain/analytics/weekly_analytics.dart';
import '../domain/models/wallet_snapshot.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    try {
      tz.initializeTimeZones();
      // Use local or default location
      tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
    } catch (e) {
      if (kDebugMode) print('Timezone init fallback: $e');
    }

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    try {
      await _plugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          if (kDebugMode) print('Notification clicked: ${response.payload}');
        },
      );
      _initialized = true;
    } catch (e) {
      if (kDebugMode) print('Notification init error: $e');
    }
  }

  Future<bool> requestPermissions() async {
    if (!_initialized) await init();

    try {
      final bool? iosGranted = await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );

      final bool? macGranted = await _plugin
          .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );

      final bool? androidGranted = await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      return iosGranted ?? macGranted ?? androidGranted ?? true;
    } catch (e) {
      if (kDebugMode) print('Request permissions error: $e');
      return true;
    }
  }

  /// Builds dynamic weekly digest text based on actual wallet transactions.
  String buildWeeklyDigestBody(WalletSnapshot snapshot) {
    final WeeklyAnalytics weekly = WeeklyAnalyticsEngine.compute(snapshot.transactions);
    if (weekly.weekExpense <= 0) {
      return 'Bu hafta harcamanız olmadı. Bütçeniz tamamen korundu! 🌟';
    }

    final String expenseText = Formatters.money(weekly.weekExpense);
    final String topCat = weekly.topCategory;
    final String trend = weekly.changePercent <= 0
        ? 'Önceki haftaya göre %${weekly.changePercent.abs().toStringAsFixed(0)} daha tasarruflu.'
        : 'Önceki haftaya göre %${weekly.changePercent.toStringAsFixed(0)} daha yüksek.';

    return 'Bu hafta $expenseText harcadın. En yüksek pay: $topCat. $trend Detaylar için dokun.';
  }

  /// Shows an instant test notification for the user to experience immediately.
  Future<void> showTestNotification(WalletSnapshot snapshot) async {
    if (!_initialized) await init();
    await requestPermissions();

    final String body = buildWeeklyDigestBody(snapshot);

    const NotificationDetails details = NotificationDetails(
      android: AndroidNotificationDetails(
        'folio_weekly_digest',
        'Haftalık Finansal Özet',
        channelDescription: 'Haftalık harcama ve bütçe performans bildirimleri',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    try {
      await _plugin.show(
        id: 1001,
        title: 'Folio — Haftalık Finansal Özetin Hazır 📊',
        body: body,
        notificationDetails: details,
        payload: '/report/weekly',
      );
    } catch (e) {
      if (kDebugMode) print('Show test notification error: $e');
    }
  }

  /// Schedules the weekly digest for every Sunday at 20:00.
  Future<void> scheduleWeeklyDigest(WalletSnapshot snapshot) async {
    if (!_initialized) await init();
    await requestPermissions();

    const NotificationDetails details = NotificationDetails(
      android: AndroidNotificationDetails(
        'folio_weekly_digest',
        'Haftalık Finansal Özet',
        channelDescription: 'Haftalık harcama ve bütçe performans bildirimleri',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    try {
      final tz.TZDateTime scheduledDate = _nextInstanceOfSundayEvening(20, 0);
      final String body = buildWeeklyDigestBody(snapshot);

      await _plugin.zonedSchedule(
        id: 2001,
        title: 'Folio — Haftalık Finansal Özet 📊',
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: '/report/weekly',
      );
    } catch (e) {
      if (kDebugMode) print('Schedule weekly notification error: $e');
    }
  }

  Future<void> cancelWeeklyDigest() async {
    try {
      await _plugin.cancel(id: 2001);
    } catch (_) {}
  }

  tz.TZDateTime _nextInstanceOfSundayEvening(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    while (scheduledDate.weekday != DateTime.sunday || scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}
