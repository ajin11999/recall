import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'api.dart';

class Notifications {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'maintenance',
      'Maintenance reminders',
      channelDescription: 'Upcoming asset maintenance',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  static Future<void> init() async {
    if (kIsWeb) return;
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // keep UTC fallback
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/launcher_icon'),
      ),
    );
    _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    _ready = true;
  }

  static Future<void> cancelAll() async {
    if (!_ready) return;
    await _plugin.cancelAll();
  }

  /// Re-schedules one local notification per upcoming maintenance task,
  /// at 09:00 local time on its due date (overdue ones fire in ~2 minutes).
  static Future<void> sync(Api api) async {
    if (!_ready) return;
    try {
      final upcoming = await api.upcomingMaintenance(days: 60);
      await _plugin.cancelAll();
      final now = tz.TZDateTime.now(tz.local);
      for (final m in upcoming) {
        final due = DateTime.tryParse(m.nextDueDate);
        if (due == null) continue;
        var when = tz.TZDateTime(tz.local, due.year, due.month, due.day, 9);
        if (!when.isAfter(now)) when = now.add(const Duration(minutes: 2));
        await _plugin.zonedSchedule(
          id: m.id,
          title: 'Maintenance due: ${m.name}',
          body: '${m.itemName ?? 'Item'} — due ${m.nextDueDate}',
          scheduledDate: when,
          notificationDetails: _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } catch (_) {
      // Best-effort: notification sync must never break the UI.
    }
  }

  static Future<void> showTest() async {
    if (!_ready) return;
    await _plugin.show(
      id: 1000000,
      title: 'Recall test notification',
      body: 'Notifications are working.',
      notificationDetails: _details,
    );
  }
}
