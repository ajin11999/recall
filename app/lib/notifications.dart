import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'api.dart';

class Notifications {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  /// Serializes concurrent [sync] calls. Without this, two overlapping syncs
  /// (e.g. one from app start, one from the maintenance screen that is built
  /// eagerly inside the IndexedStack) interleave their cancelAll/schedule
  /// loops and can leave duplicate alarms behind on some devices.
  static Future<void> _syncChain = Future.value();

  /// ID reserved for the manual test notification. Kept far outside the range
  /// of autoincremented maintenance-schedule IDs so it can never collide with
  /// (and duplicate) a real reminder.
  static const _testId = 1 << 30;

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
  ///
  /// Calls are serialized: concurrent invocations queue behind each other
  /// instead of interleaving their cancelAll/schedule loops.
  static Future<void> sync(Api api) {
    final next = _syncChain.then((_) => _syncInner(api));
    // Keep the chain alive even if something unexpected throws.
    _syncChain = next.catchError((_) {});
    return next;
  }

  static Future<void> _syncInner(Api api) async {
    if (!_ready) return;
    try {
      final upcoming = await api.upcomingMaintenance(days: 60);
      await _plugin.cancelAll();
      final now = tz.TZDateTime.now(tz.local);
      final seen = <int>{};
      for (final m in upcoming) {
        // Defensive: never schedule the same schedule twice, even if the
        // backend ever returns a row more than once.
        if (!seen.add(m.id)) continue;
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
      id: _testId,
      title: 'Recall test notification',
      body: 'Notifications are working.',
      notificationDetails: _details,
    );
  }
}
