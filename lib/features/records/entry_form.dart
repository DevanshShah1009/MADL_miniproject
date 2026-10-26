import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models.dart';
import '../../core/store.dart';
import '../../core/widgets.dart';
import '../../core/calculations.dart';

const maintenanceCategories = [
  'Routine service',
  'Engine oil',
  'Air filter',
  'Brakes',
  'Tyres',
  'Battery',
  'Repairs',
  'Insurance / documents',
  'Custom',
];
const reminderCategories = [
  'Scheduled service',
  'Insurance',
  'PUC',
  'Registration',
  'Driving licence',
  'Custom',
];

class EntryForm extends StatefulWidget {
  final EntryKind kind;
  final LogEntry? entry;
  const EntryForm({super.key, required this.kind, this.entry});
  @override
  State<EntryForm> createState() => _EntryFormState();
}

class _EntryFormState extends State<EntryForm> {
  final form = GlobalKey<FormState>();
  final fields = <String, TextEditingController>{};
  late int vehicleId, lead;
  late DateTime date;
  DateTime? nextDate;
  late String category, status;
  bool full = false, overrideTotal = false, saving = false;
  bool get fuel => widget.kind == EntryKind.fuel;
  bool get reminder => widget.kind == EntryKind.reminder;
  @override
  void initState() {
    super.initState();
    final s = context.read<AppStore>();
    final e = widget.entry;
    vehicleId = e?.vehicleId ?? s.selectedId!;
    date = e?.date ?? DateTime.now();
    nextDate = e?.nextDate;
    lead = e?.leadDays ?? int.parse(s.settings['leadDays'] ?? '7');
    category =
        e?.category ?? (reminder ? 'Scheduled service' : 'Routine service');
    status = e?.status ?? 'active';
    full = e?.fullTank ?? false;
    overrideTotal =
        e != null && fuel && (e.cost - e.litres * e.price).abs() > 0.02;
    for (final item in {
      'Title': e?.title ?? (fuel ? 'Fuel purchase' : ''),
      'Odometer (km)': (e?.odometer ?? s.selected?.odometer ?? 0).toString(),
      'Litres': e?.litres.toString() ?? '',
      'Price / litre': e?.price.toString() ?? '',
      'Total amount': e?.cost.toStringAsFixed(2) ?? '',
      'Provider / station': e?.provider ?? '',
      'Notes': e?.notes ?? '',
      'Next odometer (km)': e?.nextOdometer?.toString() ?? '',
      'Custom category': e?.category ?? '',
    }.entries) {
      fields[item.key] = TextEditingController(text: item.value);
    }
    if (!fuel &&
        !(reminder ? reminderCategories : maintenanceCategories).contains(
          category,
        )) {
      category = 'Custom';
    }
    fields['Litres']!.addListener(recalculate);
    fields['Price / litre']!.addListener(recalculate);
  }

  void recalculate() {
    if (!fuel || overrideTotal) {
      return;
    }
    final l = double.tryParse(fields['Litres']!.text),
        p = double.tryParse(fields['Price / litre']!.text);
    if (l != null && p != null && l.isFinite && p.isFinite && l > 0 && p > 0) {
      fields['Total amount']!.text = fuelCost(l, p).toStringAsFixed(2);
    } else {
      fields['Total amount']!.clear();
    }
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Widget field(
    String name, {
    bool numeric = false,
    bool optional = false,
    bool readOnly = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: fields[name],
      readOnly: readOnly,
      decoration: InputDecoration(
        labelText: '$name${optional ? ' (optional)' : ''}',
      ),
      maxLines: name == 'Notes' ? 3 : 1,
      maxLength: numeric ? null : (name == 'Notes' ? 2000 : 120),
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      validator: (s) {
        if (optional && (s == null || s.trim().isEmpty)) {
          return null;
        }
        if (s == null || s.trim().isEmpty) {
          return 'Required';
        }
        if (numeric) {
          final n = double.tryParse(s);
          if (n == null ||
              !n.isFinite ||
              n < 0 ||
              (fuel &&
                  ['Litres', 'Price / litre', 'Total amount'].contains(name) &&
                  n == 0)) {
            return 'Enter a valid ${fuel && !name.contains('km') ? 'positive' : 'non-negative'} number';
          }
        }
        return null;
      },
    ),
  );
  Future<void> pickDate(bool next) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: next ? (nextDate ?? date) : (date),
      firstDate: DateTime(1950),
      lastDate: next || reminder ? DateTime(2100) : now,
    );
    if (picked == null || !mounted) {
      return;
    }
    if (!next && fuel) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(date),
      );
      if (!mounted) {
        return;
      }
      setState(
        () => date = DateTime(
          picked.year,
          picked.month,
          picked.day,
          time?.hour ?? date.hour,
          time?.minute ?? date.minute,
        ),
      );
    } else {
      setState(() {
        if (next) {
          nextDate = picked;
        } else {
          date = picked;
        }
      });
    }
  }

  Future<void> save() async {
    if (!form.currentState!.validate() || saving) {
      return;
    }
    final s = context.read<AppStore>();
    final odo = reminder ? 0.0 : double.parse(fields['Odometer (km)']!.text);
    final vehicle = s.vehicles.firstWhere((v) => v.id == vehicleId);
    final warning = reminder ? null : odometerWarning(odo, vehicle.odometer);
    final duplicate =
        !reminder &&
        s.entries.any(
          (e) =>
              e.vehicleId == vehicleId &&
              e.kind == widget.kind &&
              e.id != widget.entry?.id &&
              e.odometer == odo,
        );
    if ((warning != null || duplicate) &&
        !await confirm(
          context,
          'Check this reading',
          '${warning ?? ''}${duplicate ? '\nAnother record has this odometer reading. Fuel efficiency may be unavailable.' : ''}',
          action: 'Save anyway',
        )) {
      return;
    }
    if (!mounted) {
      return;
    }
    final entry = LogEntry(
      id: widget.entry?.id,
      vehicleId: vehicleId,
      kind: widget.kind,
      title: fields['Title']!.text.trim(),
      date: date,
      odometer: odo,
      cost: reminder ? 0 : double.parse(fields['Total amount']!.text),
      litres: fuel ? double.parse(fields['Litres']!.text) : 0,
      price: fuel ? double.parse(fields['Price / litre']!.text) : 0,
      fullTank: full,
      category: fuel
          ? 'Fuel'
          : category == 'Custom'
          ? fields['Custom category']!.text.trim()
          : category,
      provider: fields['Provider / station']!.text.trim(),
      notes: fields['Notes']!.text.trim(),
      nextDate: reminder ? null : nextDate,
      nextOdometer: double.tryParse(fields['Next odometer (km)']!.text),
      leadDays: lead,
      status: status,
    );
    try {
      validateEntry(entry);
    } on FormatException catch (e) {
      message(context, e.message);
      return;
    }
    setState(() => saving = true);
    final ok = await perform(
      context,
      () => s.mutate((r) => r.saveEntry(entry)),
      success: 'Record saved',
    );
    if (!mounted) {
      return;
    }
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.entry == null ? 'Add' : 'Edit'} ${fuel
              ? 'fuel'
              : reminder
              ? 'reminder'
              : 'service'}',
        ),
      ),
      body: Form(
        key: form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            DropdownButtonFormField<int>(
              initialValue: vehicleId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Vehicle'),
              items: s.vehicles
                  .map(
                    (v) => DropdownMenuItem(value: v.id, child: Text(v.name)),
                  )
                  .toList(),
              onChanged: (v) => setState(() => vehicleId = v!),
            ),
            const SizedBox(height: 16),
            field('Title'),
            if (!fuel) ...[
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: (reminder ? reminderCategories : maintenanceCategories)
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) => setState(() => category = v!),
              ),
              const SizedBox(height: 16),
              if (category == 'Custom') field('Custom category'),
            ],
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: Text(
                reminder ? 'Due date' : 'Date${fuel ? ' & time' : ''}',
              ),
              subtitle: Text(
                '${dateLabel(date)}${fuel ? ' • ${TimeOfDay.fromDateTime(date).format(context)}' : ''}',
              ),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: () => pickDate(false),
            ),
            const SizedBox(height: 16),
            if (!reminder) field('Odometer (km)', numeric: true),
            if (fuel) ...[
              field('Litres', numeric: true),
              field('Price / litre', numeric: true),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Override calculated total'),
                subtitle: const Text('Use the amount printed on your receipt.'),
                value: overrideTotal,
                onChanged: (v) => setState(() {
                  overrideTotal = v;
                  recalculate();
                }),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Filled to a full tank'),
                subtitle: const Text(
                  'Used for full-tank efficiency calculations.',
                ),
                value: full,
                onChanged: (v) => setState(() => full = v),
              ),
            ],
            if (!reminder)
              field(
                'Total amount',
                numeric: true,
                readOnly: fuel && !overrideTotal,
              ),
            if (!reminder) field('Provider / station', optional: true),
            if (!fuel) ...[
              if (!reminder)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Next service date'),
                  subtitle: Text(
                    nextDate == null ? 'Optional' : dateLabel(nextDate!),
                  ),
                  trailing: nextDate == null
                      ? const Icon(Icons.event)
                      : IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() => nextDate = null),
                        ),
                  onTap: () => pickDate(true),
                ),
              field('Next odometer (km)', numeric: true, optional: true),
              DropdownButtonFormField<int>(
                initialValue: lead,
                decoration: const InputDecoration(
                  labelText: 'Remind before (days)',
                ),
                items:
                    ({
                          ...{0, 1, 3, 7, 14, 30},
                          lead,
                        }.toList()..sort())
                        .map(
                          (d) => DropdownMenuItem(
                            value: d,
                            child: Text('$d days'),
                          ),
                        )
                        .toList(),
                onChanged: (v) => setState(() => lead = v!),
              ),
              const SizedBox(height: 16),
              const Text(
                'Schedules are based on your entries. Odometer reminders update when you record mileage. Either date or distance can make a service overdue.',
              ),
              const SizedBox(height: 16),
            ],
            field('Notes', optional: true),
            FilledButton(
              onPressed: saving ? null : save,
              child: Text(saving ? 'Saving…' : 'Save record'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

void openEntry(BuildContext context, EntryKind kind, {LogEntry? entry}) {
  if (context.read<AppStore>().vehicles.isEmpty) {
    message(context, 'Add a vehicle to your garage first.');
    return;
  }
  Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => EntryForm(kind: kind, entry: entry),
    ),
  );
}
