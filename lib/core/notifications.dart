import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'models.dart';
import 'calculations.dart';

class ReminderNotifications {
  final plugin = FlutterLocalNotificationsPlugin();
  Future<void> initialize() async {
    tzdata.initializeTimeZones();
    await plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
      ),
    );
  }

  Future<bool> request() async =>
      await plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission() ??
      false;
  Future<void> sync(
    List<LogEntry> entries,
    List<Vehicle> vehicles,
    bool enabled,
  ) async {
    await plugin.cancelAll();
    if (!enabled) {
      return;
    }
    final now = DateTime.now();
    var count = 0;
    final pending =
        entries
            .where(
              (e) =>
                  e.status == 'active' &&
                  (e.kind == EntryKind.reminder ||
                      e.nextDate != null ||
                      e.nextOdometer != null),
            )
            .toList()
          ..sort(
            (a, b) => (a.nextDate ?? a.date).compareTo(b.nextDate ?? b.date),
          );
    for (final e in pending) {
      final v = vehicles.where((v) => v.id == e.vehicleId).firstOrNull;
      if (v == null) {
        continue;
      }
      final date = e.kind == EntryKind.reminder ? e.date : e.nextDate;
      final overdue = reminderState(e, v.odometer, now) == 'overdue';
      if (date == null && !overdue) {
        continue;
      }
      if (count++ >= 60) {
        break;
      }
      final local = date == null
          ? now.add(const Duration(days: 1))
          : DateTime(
              date.year,
              date.month,
              date.day,
              9,
            ).subtract(Duration(days: e.leadDays));
      final scheduled = local.isAfter(now)
          ? local
          : DateTime(now.year, now.month, now.day + 1, 9);
      // UTC instanxt preserves the chosen device-local time without a timezone plugin.
      // Reconciled when the app resumes; boot receiver restores pending alarms.
      await plugin.zonedSchedule(
        e.id! * 3 + e.kind.index,
        '${v.name} • ${e.title}',
        overdue
            ? 'Overdue — review your schedule in MotoLog.'
            : 'Your vehicle reminder is coming up.',
        tz.TZDateTime.from(scheduled, tz.UTC),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'motolog_reminders',
            'Vehicle reminders',
            channelDescription: 'Optional service and document reminders',
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }
}
