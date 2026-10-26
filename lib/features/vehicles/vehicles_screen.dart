import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/store.dart';
import '../../core/widgets.dart';
import '../../app/theme.dart';
import '../records/records_screen.dart';
import 'vehicle_form.dart';

class VehiclesScreen extends StatelessWidget {
  const VehiclesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Your garage',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => const VehicleForm()),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text('Every ride. Every detail. In one place.'),
        const SizedBox(height: 24),
        if (s.vehicles.isEmpty)
          const EmptyState(
            icon: Icons.two_wheeler,
            title: 'Your journey starts here',
            description: 'Add your first vehicle to track fuel, servicing and upcoming deadlines.',
          ),
        ...s.vehicles.map(
          (v) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Palette.blue.withValues(alpha: 0.16),
                        child: Icon(
                          v.type == 'Car'
                              ? Icons.directions_car
                              : Icons.two_wheeler,
                          color: Palette.blue,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              v.name,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            Text('${v.make} ${v.model}'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Text(
                    '${v.odometer.toStringAsFixed(0)} km',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${v.type} • ${v.fuelType}${v.registration.isEmpty ? '' : ' • ${v.registration}'}',
                  ),
                  if (v.purchased != null)
                    Text('Purchased ${dateLabel(v.purchased!)}'),
                  if (v.notes.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(v.notes),
                    ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonal(
                        onPressed: () {
                          s.select(v.id);
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  const RecordsScreen(history: true),
                            ),
                          );
                        },
                        child: const Text('View history'),
                      ),
                      OutlinedButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => VehicleForm(vehicle: v),
                          ),
                        ),
                        child: const Text('Edit'),
                      ),
                      IconButton(
                        tooltip: 'Delete vehicle',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          if (await confirm(
                                context,
                                'Delete ${v.name}?',
                                'All fuel, service and reminder records for this vehicle will be permanently deleted. Export a backup first if needed.',
                              ) &&
                              context.mounted) {
                            await perform(
                              context,
                              () => s.mutate((r) => r.removeVehicle(v.id!)),
                              success: 'Vehicle deleted',
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
