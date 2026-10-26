import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:motolog/core/models.dart';
import 'package:motolog/core/repository.dart';

void main() {
  test(
    'Database retains records and preferences across close/reopen',
    () async {
      sqfliteFfiInit();
      final directory = await Directory.systemTemp.createTemp('motolog-test-');
      final path = '${directory.path}/persist.db';
      final first = await Repository.open(
        factory: databaseFactoryFfi,
        path: path,
      );
      await first.saveVehicle(
        const Vehicle(name: 'Persistent bike', make: 'Honda', model: 'CB'),
      );
      await first.setting('theme', 'light');
      await first.saveEntry(
        LogEntry(
          vehicleId: 1,
          kind: EntryKind.reminder,
          title: 'Insurance',
          category: 'Insurance',
          date: DateTime(2027),
        ),
      );
      await first.db.close();
      final second = await Repository.open(
        factory: databaseFactoryFfi,
        path: path,
      );
      expect((await second.vehicles()).single.name, 'Persistent bike');
      expect((await second.entries()).single.title, 'Insurance');
      expect((await second.settings())['theme'], 'light');
      await second.clear();
      expect(await second.vehicles(), isEmpty);
      expect(await second.entries(), isEmpty);
      expect(await second.settings(), isEmpty);
      await second.db.close();
      await directory.delete(recursive: true);
    },
  );
}
