import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'models.dart';
import 'calculations.dart';

const tables = {
  EntryKind.fuel: 'fuel',
  EntryKind.maintenance: 'maintenance',
  EntryKind.reminder: 'reminders',
};

class Repository {
  final Database db;
  Repository(this.db);
  static Future<Repository> open({
    DatabaseFactory? factory,
    String? path,
  }) async {
    final f = factory ?? databaseFactory;
    final db = await f.openDatabase(
      path ?? p.join(await f.getDatabasesPath(), 'motolog.db'),
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) async {
          await db.execute(
            'CREATE TABLE vehicles (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, make TEXT NOT NULL, model TEXT NOT NULL, type TEXT NOT NULL, registration TEXT NOT NULL, fuelType TEXT NOT NULL, notes TEXT NOT NULL, odometer REAL NOT NULL CHECK(odometer >= 0), purchased INTEGER)',
          );
          for (final table in tables.values) {
            await db.execute(
              'CREATE TABLE $table (id INTEGER PRIMARY KEY AUTOINCREMENT, vehicleId INTEGER NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE, title TEXT NOT NULL, category TEXT NOT NULL, provider TEXT NOT NULL, notes TEXT NOT NULL, status TEXT NOT NULL, date INTEGER NOT NULL, odometer REAL NOT NULL CHECK(odometer >= 0), cost REAL NOT NULL CHECK(cost >= 0), litres REAL NOT NULL, price REAL NOT NULL, fullTank INTEGER NOT NULL, nextDate INTEGER, nextOdometer REAL, leadDays INTEGER NOT NULL)',
            );
            await db.execute(
              'CREATE INDEX ${table}_vehicle_date ON $table(vehicleId,date)',
            );
          }
          await db.execute(
            'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
          );
        },
        // No destructive fallback. Future schema upgrades must be additive migrations.
        onUpgrade: (db, oldVersion, newVersion) async {
          throw StateError(
            'Unsupported database upgrade $oldVersion → $newVersion',
          );
        },
      ),
    );
    return Repository(db);
  }

  Future<List<Vehicle>> vehicles() async => (await db.query(
    'vehicles',
    orderBy: 'id DESC',
  )).map(Vehicle.fromMap).toList();
  Future<List<LogEntry>> entries() async {
    final all = <LogEntry>[];
    for (final kind in EntryKind.values) {
      all.addAll(
        (await db.query(tables[kind]!)).map((m) => LogEntry.fromMap(m, kind)),
      );
    }
    return all..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<Map<String, String>> settings() async => {
    for (final m in await db.query('settings'))
      m['key'] as String: m['value'] as String,
  };
  Future<void> setting(String key, String value) => db.insert('settings', {
    'key': key,
    'value': value,
  }, conflictAlgorithm: ConflictAlgorithm.replace);
  Future<void> saveVehicle(Vehicle v) async {
    validateVehicle(v);
    final m = v.toMap()..remove('id');
    if (v.id == null) {
      await db.insert('vehicles', m);
    } else {
      final changed = await db.update(
        'vehicles',
        m,
        where: 'id = ?',
        whereArgs: [v.id],
      );
      if (changed != 1) {
        throw const FormatException('This vehicle no longer exists.');
      }
    }
  }

  Future<void> saveEntry(LogEntry e) async {
    validateEntry(e);
    await db.transaction((tx) async {
      final m = e.toMap()..remove('id');
      if (e.id == null) {
        await tx.insert(tables[e.kind]!, m);
      } else {
        final changed = await tx.update(
          tables[e.kind]!,
          m,
          where: 'id = ?',
          whereArgs: [e.id],
        );
        if (changed != 1) {
          throw const FormatException('This record no longer exists.');
        }
      }
      if (e.kind != EntryKind.reminder) {
        await tx.rawUpdate(
          'UPDATE vehicles SET odometer = MAX(odometer, ?) WHERE id = ?',
          [e.odometer, e.vehicleId],
        );
      }
    });
  }

  Future<void> removeVehicle(int id) => db.transaction((tx) async {
    await tx.delete('vehicles', where: 'id = ?', whereArgs: [id]);
  });
  Future<void> removeEntry(LogEntry e) async {
    await db.delete(tables[e.kind]!, where: 'id = ?', whereArgs: [e.id]);
  }

  Future<void> status(LogEntry e, String status) async {
    await db.update(
      tables[e.kind]!,
      {'status': status},
      where: 'id = ?',
      whereArgs: [e.id],
    );
  }

  Future<void> clear() => db.transaction((tx) async {
    await tx.delete('vehicles');
    await tx.delete('settings');
  });
  Future<String> backup() async => jsonEncode({
    'schemaVersion': 1,
    'createdAt': DateTime.now().toUtc().toIso8601String(),
    'vehicles': (await vehicles()).map((v) => v.toMap()).toList(),
    'entries': (await entries())
        .map((e) => {...e.toMap(), 'kind': e.kind.name})
        .toList(),
    'settings': await settings(),
  });
  Future<void> restore(String json) async {
    final backup = Backup.parse(json);
    await db.transaction((tx) async {
      await tx.delete('vehicles');
      await tx.delete('settings');
      for (final v in backup.vehicles) {
        await tx.insert('vehicles', v.toMap());
      }
      for (final e in backup.entries) {
        await tx.insert(tables[e.kind]!, e.toMap());
      }
      for (final s in backup.settings.entries) {
        await tx.insert('settings', {'key': s.key, 'value': s.value});
      }
    });
  }
}

class Backup {
  final List<Vehicle> vehicles;
  final List<LogEntry> entries;
  final Map<String, String> settings;
  Backup(this.vehicles, this.entries, this.settings);
  factory Backup.parse(String source) {
    try {
      if (source.length > 20 * 1024 * 1024) {
        throw const FormatException('Backup exceeds 20 MB.');
      }
      final m = jsonDecode(source) as Map<String, dynamic>;
      if (m['schemaVersion'] != 1) {
        throw const FormatException('Unsupported backup schema.');
      }
      final vehicles = (m['vehicles'] as List)
          .map((v) => Vehicle.fromMap(Map<String, dynamic>.from(v as Map)))
          .toList();
      final entries = (m['entries'] as List).map((v) {
        final row = Map<String, dynamic>.from(v as Map);
        if (row['fullTank'] != 0 && row['fullTank'] != 1) {
          throw const FormatException('Invalid full-tank value.');
        }
        return LogEntry.fromMap(
          row,
          EntryKind.values.byName(row['kind'] as String),
        );
      }).toList();
      final ids = <int>{};
      for (final v in vehicles) {
        validateVehicle(v);
        if (v.id == null || v.id! <= 0 || !ids.add(v.id!)) {
          throw const FormatException('Invalid or duplicate vehicle ID.');
        }
      }
      final entryIds = <String>{};
      for (final e in entries) {
        validateEntry(e);
        if (!ids.contains(e.vehicleId) ||
            e.id == null ||
            e.id! <= 0 ||
            !entryIds.add('${e.kind.name}:${e.id}')) {
          throw const FormatException(
            'Invalid record relationship or duplicate ID.',
          );
        }
      }
      final settings = Map<String, String>.from(m['settings'] as Map);
      const allowed = {
        'theme': ['dark', 'light', 'system'],
        'currency': ['INR', 'USD', 'EUR'],
        'notifications': ['true', 'false'],
        'leadDays': ['0', '1', '3', '7', '14', '30'],
      };
      for (final s in settings.entries) {
        if (!allowed.containsKey(s.key) || !allowed[s.key]!.contains(s.value)) {
          throw const FormatException('Invalid backup settings.');
        }
      }
      return Backup(vehicles, entries, settings);
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException(
        'Malformed backup. No data has been changed.',
      );
    }
  }
}

String csv(List<LogEntry> rows, EntryKind kind, {String currency = 'INR'}) {
  String cell(Object? value) {
    var s = value?.toString() ?? '';
    // PrevcsCent spreadsheet formula execution in user-entered fields.
    if (RegExp(r'^[=+@\-\t\r]').hasMatch(s)) {
      s = "'$s";
    }
    return '"${s.replaceAll('"', '""')}"';
  }

  final data = <List<Object?>>[
    [
      'Vehicle ID',
      'Title',
      'Category',
      'Date (ISO 8601)',
      'Odometer (km)',
      'Cost ($currency)',
      'Litres',
      'Price/litre ($currency)',
      'Full tank',
      'Provider',
      'Notes',
    ],
    ...rows
        .where((e) => e.kind == kind)
        .map(
          (e) => [
            e.vehicleId,
            e.title,
            e.category,
            e.date.toIso8601String(),
            e.odometer,
            e.cost,
            e.litres,
            e.price,
            e.fullTank,
            e.provider,
            e.notes,
          ],
        ),
  ];
  return data.map((r) => r.map(cell).join(',')).join('\r\n');
}
