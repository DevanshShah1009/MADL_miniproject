import 'models.dart';

double fuelCost(double litres, double price) {
  if (!litres.isFinite ||
      !price.isFinite ||
      litres <= 0 ||
      price <= 0 ||
      litres > 1000000 ||
      price > 1000000) {
    throw const FormatException('Litres and price must be greater than zero.');
  }
  return (litres * price * 100).round() / 100;
}

String? odometerWarning(double value, double current) =>
    !value.isFinite || value < 0
    ? 'Enter a valid non-negative odometer.'
    : value < current
    ? 'This reading is below the current odometer. Save only if this is a historical entry.'
    : null;

class Efficiency {
  final DateTime date;
  final double distance, litres;
  const Efficiency(this.date, this.distance, this.litres);
  double get value => distance / litres;
}

/// The starting fill is excluded; partial fills between full tanks are included.
/// A duplicate or decreasing reading invalidates that entire interval.
List<Efficiency> efficiencies(List<LogEntry> records) {
  final rows = records.where((e) => e.kind == EntryKind.fuel).toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  final result = <Efficiency>[];
  LogEntry? anchor, previous;
  var litres = 0.0;
  var valid = true;
  for (final row in rows) {
    if (previous != null &&
        (row.odometer <= previous.odometer || row.date == previous.date)) {
      valid = false;
    }
    if (anchor != null) {
      litres += row.litres;
    }
    if (row.fullTank) {
      if (anchor != null &&
          valid &&
          litres > 0 &&
          row.odometer > anchor.odometer) {
        result.add(
          Efficiency(row.date, row.odometer - anchor.odometer, litres),
        );
      }
      anchor = row;
      litres = 0;
      valid = true;
    }
    previous = row;
  }
  return result;
}

DateTime day(DateTime d) => DateTime(d.year, d.month, d.day);
String reminderState(LogEntry e, double current, DateTime now) {
  if (e.status != 'active') {
    return e.status;
  }
  final due = e.kind == EntryKind.reminder ? e.date : e.nextDate;
  if ((due != null && day(due).isBefore(day(now))) ||
      (e.nextOdometer != null && current >= e.nextOdometer!)) {
    return 'overdue';
  }
  return 'upcoming';
}

List<LogEntry> inRange(
  List<LogEntry> entries,
  DateTime? start,
  DateTime? end,
) => entries
    .where(
      (e) =>
          (start == null || !e.date.isBefore(day(start))) &&
          (end == null ||
              e.date.isBefore(day(end).add(const Duration(days: 1)))),
    )
    .toList();

double spending(Iterable<LogEntry> rows, [EntryKind? kind]) => rows
    .where(
      (e) => e.kind != EntryKind.reminder && (kind == null || e.kind == kind),
    )
    .fold(0, (sum, e) => sum + e.cost);

Map<String, double> categoryTotals(Iterable<LogEntry> rows) {
  final result = <String, double>{};
  for (final e in rows.where((e) => e.kind != EntryKind.reminder)) {
    final key = e.kind == EntryKind.fuel ? 'Fuel' : e.category;
    result[key] = (result[key] ?? 0) + e.cost;
  }
  return result;
}

/// Only complete full-tank intervals provide a meaningful running-cost sample.
double? costPerKm(List<LogEntry> rows) {
  final fuel = rows.where((e) => e.kind == EntryKind.fuel).toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  if (fuel.length < 2 || !fuel.first.fullTank || !fuel.last.fullTank) {
    return null;
  }
  for (var i = 1; i < fuel.length; i++) {
    if (fuel[i].odometer <= fuel[i - 1].odometer ||
        fuel[i].date == fuel[i - 1].date) {
      return null;
    }
  }
  final distance = fuel.last.odometer - fuel.first.odometer;
  final sample = rows.where(
    (e) => e.date.isAfter(fuel.first.date) && !e.date.isAfter(fuel.last.date),
  );
  return distance > 0 ? spending(sample) / distance : null;
}

void validateVehicle(Vehicle v) {
  if (v.name.trim().isEmpty ||
      v.make.trim().isEmpty ||
      v.model.trim().isEmpty ||
      [v.name, v.make, v.model, v.registration].any((s) => s.length > 120) ||
      v.notes.length > 2000 ||
      !v.odometer.isFinite ||
      v.odometer < 0 ||
      v.odometer > 100000000 ||
      (v.purchased != null &&
          (v.purchased!.year < 1950 ||
              day(v.purchased!).isAfter(day(DateTime.now())))) ||
      !['Motorcycle', 'Scooter', 'Car', 'Other'].contains(v.type) ||
      !['Petrol', 'Diesel', 'Electric', 'CNG', 'Other'].contains(v.fuelType)) {
    throw const FormatException('Vehicle fields are invalid.');
  }
}

void validateEntry(LogEntry e) {
  if (e.title.trim().isEmpty ||
      e.title.length > 120 ||
      e.notes.length > 2000 ||
      e.provider.length > 120 ||
      e.category.length > 120 ||
      (e.kind != EntryKind.fuel && e.category.trim().isEmpty) ||
      e.date.year < 1950 ||
      e.date.year > 2100 ||
      (e.nextDate != null &&
          (e.nextDate!.year < 1950 || e.nextDate!.year > 2100)) ||
      e.vehicleId <= 0 ||
      [
        e.odometer,
        e.cost,
        e.litres,
        e.price,
      ].any((n) => !n.isFinite || n < 0 || n > 100000000) ||
      (e.nextOdometer != null &&
          (!e.nextOdometer!.isFinite ||
              e.nextOdometer! < 0 ||
              e.nextOdometer! > 100000000)) ||
      e.leadDays < 0 ||
      e.leadDays > 365 ||
      !['active', 'completed', 'dismissed'].contains(e.status)) {
    throw const FormatException('Record fields are invalid.');
  }
  if (e.kind == EntryKind.fuel) {
    fuelCost(e.litres, e.price);
    if (e.cost <= 0) {
      throw const FormatException('Fuel total must be positive.');
    }
  }
  if (e.kind != EntryKind.reminder &&
      e.date.isAfter(DateTime.now().add(const Duration(minutes: 1)))) {
    throw const FormatException('History records cannot be in the future.');
  }
  if (e.kind == EntryKind.maintenance &&
      ((e.nextDate != null && day(e.nextDate!).isBefore(day(e.date))) ||
          (e.nextOdometer != null && e.nextOdometer! <= e.odometer))) {
    throw const FormatException(
      'Next service must follow the recorded service.',
    );
  }
}
