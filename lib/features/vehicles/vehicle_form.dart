import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models.dart';
import '../../core/store.dart';
import '../../core/widgets.dart';
import '../../core/calculations.dart';

class VehicleForm extends StatefulWidget {
  final Vehicle? vehicle;
  const VehicleForm({super.key, this.vehicle});
  @override
  State<VehicleForm> createState() => _VehicleFormState();
}

class _VehicleFormState extends State<VehicleForm> {
  final form = GlobalKey<FormState>();
  final fields = <String, TextEditingController>{};
  late String type, fuel;
  DateTime? purchase;
  bool saving = false;
  @override
  void initState() {
    super.initState();
    final v = widget.vehicle;
    for (final e in {
      'Nickname': v?.name ?? '',
      'Manufacturer': v?.make ?? '',
      'Model': v?.model ?? '',
      'Registration (optional)': v?.registration ?? '',
      'Odometer (km)': v?.odometer.toString() ?? '0',
      'Notes (optional)': v?.notes ?? '',
    }.entries) {
      fields[e.key] = TextEditingController(text: e.value);
    }
    type = v?.type ?? 'Motorcycle';
    fuel = v?.fuelType ?? 'Petrol';
    purchase = v?.purchased;
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate() || saving) {
      return;
    }
    final odo = double.parse(fields['Odometer (km)']!.text);
    final warning = odometerWarning(odo, widget.vehicle?.odometer ?? 0);
    if (warning != null &&
        !await confirm(
          context,
          'Check odometer',
          warning,
          action: 'Save anyway',
        )) {
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() => saving = true);
    final s = context.read<AppStore>();
    final ok = await perform(
      context,
      () => s.mutate(
        (r) => r.saveVehicle(
          Vehicle(
            id: widget.vehicle?.id,
            name: fields['Nickname']!.text.trim(),
            make: fields['Manufacturer']!.text.trim(),
            model: fields['Model']!.text.trim(),
            registration: fields['Registration (optional)']!.text.trim(),
            odometer: odo,
            type: type,
            fuelType: fuel,
            notes: fields['Notes (optional)']!.text.trim(),
            purchased: purchase,
          ),
        ),
      ),
      success: 'Vehicle saved',
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.vehicle == null ? 'Add vehicle' : 'Edit vehicle'),
    ),
    body: Form(
      key: form,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'MAKE IT YOURS',
            style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          ...fields.entries.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TextFormField(
                controller: e.value,
                decoration: InputDecoration(labelText: e.key),
                maxLength: e.key.contains('Notes') ? 2000 : 100,
                keyboardType: e.key.contains('km')
                    ? const TextInputType.numberWithOptions(decimal: true)
                    : TextInputType.text,
                validator: (v) {
                  if (e.key.contains('optional')) {
                    return null;
                  }
                  if (v == null || v.trim().isEmpty) {
                    return 'Required';
                  }
                  if (e.key.contains('km')) {
                    final n = double.tryParse(v);
                    if (n == null || !n.isFinite || n < 0) {
                      return 'Enter a valid odometer';
                    }
                  }
                  return null;
                },
              ),
            ),
          ),
          DropdownButtonFormField<String>(
            initialValue: type,
            decoration: const InputDecoration(labelText: 'Vehicle type'),
            items: [
              'Motorcycle',
              'Scooter',
              'Car',
              'Other',
            ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: (v) => setState(() => type = v!),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: fuel,
            decoration: const InputDecoration(labelText: 'Fuel type'),
            items: [
              'Petrol',
              'Diesel',
              'Electric',
              'CNG',
              'Other',
            ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: (v) => setState(() => fuel = v!),
          ),
          const SizedBox(height: 16),
          ListTile(
            title: const Text('Purchase date'),
            subtitle: Text(
              purchase == null ? 'Optional' : dateLabel(purchase!),
            ),
            leading: const Icon(Icons.calendar_today),
            trailing: purchase == null
                ? null
                : IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => purchase = null),
                  ),
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: purchase ?? DateTime.now(),
                firstDate: DateTime(1950),
                lastDate: DateTime.now(),
              );
              if (d != null) {
                setState(() => purchase = d);
              }
            },
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: saving ? null : save,
            child: Text(saving ? 'Saving…' : 'Save vehicle'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    ),
  );
}
