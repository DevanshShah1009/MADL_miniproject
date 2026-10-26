import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:motolog/core/models.dart';
import 'package:motolog/core/calculations.dart';
import 'package:motolog/core/repository.dart';

LogEntry fuel(
  int day,
  double odo,
  double litres, {
  bool full = true,
  int? id,
  double? cost,
}) => LogEntry(
  id: id,
  vehicleId: 1,
  kind: EntryKind.fuel,
  title: 'Fuel',
  date: DateTime(2025, 1, day),
  odometer: odo,
  litres: litres,
  price: 100,
  cost: cost ?? litres * 100,
  fullTank: full,
);
const vehicle = Vehicle(
  id: 1,
  name: 'Commuter',
  make: 'Honda',
  model: 'City',
  type: 'Car',
  odometer: 100,
);

void main() {
  test('Fuel cost rounds to paise and rejects invalid input', () {
    expect(fuelCost(4.23, 103.21), 436.58);
    expect(() => fuelCost(0, 10), throwsFormatException);
    expect(() => fuelCost(double.nan, 10), throwsFormatException);
    expect(() => fuelCost(3, -1), throwsFormatException);
  });
  test('Full tank calculation includes intermediate partial fills, excludes anchor', () {
    final values = efficiencies([
      fuel(1, 100, 10),
      fuel(2, 200, 3, full: false),
      fuel(3, 400, 7),
    ]);
    expect(values.single.value, 30);
    expect(values.single.litres, 10);
    expect(
      efficiencies([fuel(1, 100, 10, full: false), fuel(2, 200, 5)]),
      isEmpty,
    );
  });
  test('Duplicate and decreasing readings invalidate intervals and recover at next full tank', () {
    expect(
      efficiencies([fuel(1, 100, 10), fuel(2, 100, 3), fuel(3, 200, 5)])
          .single
          .value,
      20,
    );
    expect(
      efficiencies([
        fuel(1, 100, 10),
        fuel(2, 90, 3, full: false),
        fuel(3, 200, 5),
      ]),
      isEmpty,
    );
    expect(efficiencies([fuel(1, 100, 10), fuel(1, 200, 5)]), isEmpty);
  });
  test(
    'Odometer validation flags historical readings and rejects invalid numbers',
    () {
      expect(odometerWarning(50, 100), isNotNull);
      expect(odometerWarning(-1, 100), isNotNull);
      expect(odometerWarning(double.infinity, 100), isNotNull);
      expect(odometerWarning(150, 100), isNull);
    },
  );
  test(
    'Reminder dates compare calendar days and distance can trigger earlier',
    () {
      final e = LogEntry(
        vehicleId: 1,
        kind: EntryKind.reminder,
        category: 'Custom',
        title: 'PUC',
        date: DateTime(2025, 1, 10),
        nextOdometer: 500,
      );
      expect(reminderState(e, 100, DateTime(2025, 1, 10, 23)), 'upcoming');
      expect(reminderState(e, 500, DateTime(2025, 1, 9)), 'overdue');
      expect(reminderState(e, 100, DateTime(2025, 1, 11)), 'overdue');
      final completed = LogEntry.fromMap({
        ...e.toMap(),
        'status': 'completed',
      }, EntryKind.reminder);
      expect(reminderState(completed, 1000, DateTime(2026)), 'completed');
    },
  );
  test('Service next date and mileage must follow service', () {
    final e = LogEntry(
      vehicleId: 1,
      kind: EntryKind.maintenance,
      category: 'Custom',
      title: 'Service',
      date: DateTime(2025),
      odometer: 100,
      nextOdometer: 100,
    );
    expect(() => validateEntry(e), throwsFormatException);
    final next = LogEntry.fromMap({
      ...e.toMap(),
      'nextOdometer': 200,
      'nextDate': DateTime(2025, 2).millisecondsSinceEpoch,
    }, EntryKind.maintenance);
    expect(() => validateEntry(next), returnsNormally);
    expect(reminderState(next, 150, DateTime(2025, 3)), 'overdue');
  });
  test(
    'Aggregation and date filters include end day and exclude reminders',
    () {
      final rows = [
        fuel(1, 100, 10),
        fuel(2, 200, 5),
        LogEntry(
          vehicleId: 1,
          kind: EntryKind.reminder,
          category: 'Custom',
          title: 'Due',
          date: DateTime(2025),
          cost: 99,
        ),
      ];
      expect(spending(rows), 1500);
      expect(categoryTotals(rows), {'Fuel': 1500});
      expect(
        inRange(rows, DateTime(2025, 1, 2), DateTime(2025, 1, 2)).length,
        1,
      );
      expect(costPerKm(rows), 5);
      expect(costPerKm([fuel(1, 100, 10), fuel(2, 100, 5)]), isNull);
    },
  );
  test('Backup validation rejects wrong schema, broken relationships and invalid IDs', () {
    final data = {
      'schemaVersion': 1,
      'vehicles': [vehicle.toMap()],
      'entries': [
        {...fuel(1, 100, 10, id: 1).toMap(), 'kind': 'fuel'},
      ],
      'settings': {'theme': 'dark'},
    };
    expect(Backup.parse(jsonEncode(data)).entries.single.litres, 10);
    expect(() => Backup.parse('{broken'), throwsFormatException);
    expect(
      () => Backup.parse(jsonEncode({...data, 'schemaVersion': 99})),
      throwsFormatException,
    );
    expect(
      () => Backup.parse(jsonEncode({...data, 'vehicles': []})),
      throwsFormatException,
    );
    expect(
      () => Backup.parse(
        jsonEncode({
          ...data,
          'vehicles': [vehicle.toMap(), vehicle.toMap()],
        }),
      ),
      throwsFormatException,
    );
    expect(
      () => Backup.parse(
        jsonEncode({
          ...data,
          'settings': {'theme': 'invalid'},
        }),
      ),
      throwsFormatException,
    );
  });
  test('CSV escapes quotes, commas and spreadsheet formulas', () {
    final e = LogEntry.fromMap({
      ...fuel(1, 100, 10).toMap(),
      'title': '=SUM(1,2)',
      'notes': 'A "quote"',
    }, EntryKind.fuel);
    final output = csv([e], EntryKind.fuel);
    expect(output, contains("'=SUM(1,2)"));
    expect(output, contains('A ""quote""'));
  });
  group('SQLite repository', () {
    late Repository repo;
    setUpAll(sqfliteFfiInit);
    setUp(() async {
      repo = await Repository.open(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
    });
    tearDown(() async {
      await repo.db.close();
    });
    test(
      'CRUD, odometer updates, status changes, cascade and round-trip restore',
      () async {
        await repo.saveVehicle(
          const Vehicle(
            name: 'Commuter',
            make: 'Honda',
            model: 'City',
            type: 'Car',
            odometer: 100,
          ),
        );
        expect((await repo.vehicles()).length, 1);
        await repo.saveEntry(fuel(1, 300, 5));
        final e = (await repo.entries()).single;
        expect((await repo.vehicles()).single.odometer, 300);
        await repo.saveEntry(
          LogEntry.fromMap({...e.toMap(), 'cost': 450}, EntryKind.fuel),
        );
        expect((await repo.entries()).single.cost, 450);
        await repo.status(e, 'completed');
        expect((await repo.entries()).single.status, 'completed');
        await repo.setting('theme', 'light');
        final backup = await repo.backup();
        await repo.removeVehicle(1);
        expect(await repo.entries(), isEmpty);
        await repo.restore(backup);
        expect((await repo.entries()).single.cost, 450);
        expect((await repo.settings())['theme'], 'light');
        await repo.removeEntry((await repo.entries()).single);
        expect(await repo.entries(), isEmpty);
      },
    );
    test(
      'Malformed restore preserves existing data; foreign keys reject orphans',
      () async {
        await repo.saveVehicle(
          const Vehicle(name: 'Bike', make: 'Honda', model: 'CB'),
        );
        await expectLater(
          repo.restore('{"schemaVersion":4}'),
          throwsFormatException,
        );
        expect((await repo.vehicles()).length, 1);
        final orphan = LogEntry.fromMap({
          ...fuel(1, 100, 2).toMap(),
          'vehicleId': 999,
        }, EntryKind.fuel);
        await expectLater(
          repo.saveEntry(orphan),
          throwsA(isA<DatabaseException>()),
        );
        expect(await repo.entries(), isEmpty);
      },
    );
    test(
      'Editing a future service schedule preserves history cost and date',
      () async {
        await repo.saveVehicle(
          const Vehicle(name: 'Bike', make: 'Honda', model: 'CB'),
        );
        await repo.saveEntry(
          LogEntry(
            vehicleId: 1,
            kind: EntryKind.maintenance,
            category: 'Custom',
            title: 'Oil',
            date: DateTime(2025),
            cost: 700,
            nextOdometer: 500,
          ),
        );
        final original = (await repo.entries()).single;
        await repo.saveEntry(
          LogEntry.fromMap({
            ...original.toMap(),
            'nextOdometer': 1000,
          }, EntryKind.maintenance),
        );
        final changed = (await repo.entries()).single;
        expect(changed.cost, original.cost);
        expect(changed.date, original.date);
        expect(changed.nextOdometer, 1000);
      },
    );
  });
}
