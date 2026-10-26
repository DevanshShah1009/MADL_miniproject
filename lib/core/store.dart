import 'package:flutter/foundation.dart';

import 'models.dart';
import 'repository.dart';
import 'notifications.dart';

class AppStore extends ChangeNotifier {
  final Repository repository;
  final ReminderNotifications? notifications;
  List<Vehicle> vehicles = [];
  List<LogEntry> entries = [];
  Map<String, String> settings = {};
  int? selectedId;
  String? notificationError;
  AppStore(this.repository, {this.notifications});
  Vehicle? get selected =>
      vehicles.where((v) => v.id == selectedId).firstOrNull;
  List<LogEntry> get selectedEntries =>
      entries.where((e) => e.vehicleId == selectedId).toList();
  void select(int? id) {
    selectedId = id;
    notifyListeners();
  }

  Future<void> refresh() async {
    vehicles = await repository.vehicles();
    entries = await repository.entries();
    settings = await repository.settings();
    if (!vehicles.any((v) => v.id == selectedId)) {
      selectedId = vehicles.firstOrNull?.id;
    }
    notifyListeners();
    try {
      await notifications?.sync(
        entries,
        vehicles,
        settings['notifications'] == 'true',
      );
      notificationError = null;
    } catch (_) {
      notificationError = 'Notifications could not be scheduled. Your reminders remain visible in the app.';
    }
    notifyListeners();
  }

  Future<void> mutate(Future<void> Function(Repository) action) async {
    await action(repository);
    await refresh();
  }

  Future<void> setSetting(String key, String value) =>
      mutate((r) => r.setting(key, value));
}
