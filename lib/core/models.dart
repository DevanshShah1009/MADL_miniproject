enum EntryKind { fuel, maintenance, reminder }

class Vehicle {
  final int? id;
  final String name, make, model, type, registration, fuelType, notes;
  final double odometer;
  final DateTime? purchased;
  const Vehicle({
    this.id,
    required this.name,
    required this.make,
    required this.model,
    this.type = 'Motorcycle',
    this.registration = '',
    this.fuelType = 'Petrol',
    this.notes = '',
    this.odometer = 0,
    this.purchased,
  });
  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'make': make,
    'model': model,
    'type': type,
    'registration': registration,
    'fuelType': fuelType,
    'notes': notes,
    'odometer': odometer,
    'purchased': purchased?.millisecondsSinceEpoch,
  };
  factory Vehicle.fromMap(Map<String, dynamic> m) => Vehicle(
    id: m['id'] as int?,
    name: m['name'] as String,
    make: m['make'] as String,
    model: m['model'] as String,
    type: m['type'] as String,
    registration: m['registration'] as String,
    fuelType: m['fuelType'] as String,
    notes: m['notes'] as String,
    odometer: (m['odometer'] as num).toDouble(),
    purchased: m['purchased'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(m['purchased'] as int),
  );
}

/// Typed common history envelope. Kind-specific fields are validated before writes.
class LogEntry {
  final int? id;
  final int vehicleId;
  final EntryKind kind;
  final String title, category, provider, notes, status;
  final DateTime date;
  final double odometer, cost, litres, price;
  final bool fullTank;
  final DateTime? nextDate;
  final double? nextOdometer;
  final int leadDays;
  const LogEntry({
    this.id,
    required this.vehicleId,
    required this.kind,
    required this.title,
    required this.date,
    this.category = '',
    this.provider = '',
    this.notes = '',
    this.status = 'active',
    this.odometer = 0,
    this.cost = 0,
    this.litres = 0,
    this.price = 0,
    this.fullTank = false,
    this.nextDate,
    this.nextOdometer,
    this.leadDays = 7,
  });
  Map<String, Object?> toMap() => {
    'id': id,
    'vehicleId': vehicleId,
    'title': title,
    'category': category,
    'provider': provider,
    'notes': notes,
    'status': status,
    'date': date.millisecondsSinceEpoch,
    'odometer': odometer,
    'cost': cost,
    'litres': litres,
    'price': price,
    'fullTank': fullTank ? 1 : 0,
    'nextDate': nextDate?.millisecondsSinceEpoch,
    'nextOdometer': nextOdometer,
    'leadDays': leadDays,
  };
  factory LogEntry.fromMap(Map<String, dynamic> m, EntryKind kind) => LogEntry(
    id: m['id'] as int?,
    vehicleId: m['vehicleId'] as int,
    kind: kind,
    title: m['title'] as String,
    category: m['category'] as String,
    provider: m['provider'] as String,
    notes: m['notes'] as String,
    status: m['status'] as String,
    date: DateTime.fromMillisecondsSinceEpoch(m['date'] as int),
    odometer: (m['odometer'] as num).toDouble(),
    cost: (m['cost'] as num).toDouble(),
    litres: (m['litres'] as num).toDouble(),
    price: (m['price'] as num).toDouble(),
    fullTank: m['fullTank'] == 1,
    nextDate: m['nextDate'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(m['nextDate'] as int),
    nextOdometer: (m['nextOdometer'] as num?)?.toDouble(),
    leadDays: m['leadDays'] as int,
  );
}
