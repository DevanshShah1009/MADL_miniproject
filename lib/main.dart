import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/repository.dart';
import 'core/store.dart';
import 'core/notifications.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final repository = await Repository.open();
    final notifications = ReminderNotifications();
    try {
      await notifications.initialize();
    } catch (_) {
      /* Reminders remain available in-app. */
    }
    final store = AppStore(repository, notifications: notifications);
    await store.refresh();
    runApp(MotoLogApp(store: store));
  } catch (_) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.storage_outlined, size: 48),
                    const SizedBox(height: 16),
                    const Text(
                      'MotoLog could not open local storage. Free some device space and retry. Your database has not been erased.',
                    ),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: main, child: const Text('Retry')),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
