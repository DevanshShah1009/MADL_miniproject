import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models.dart';
import '../../core/store.dart';
import '../../core/widgets.dart';
import '../../core/calculations.dart';
import '../../app/theme.dart';
import '../vehicles/vehicle_form.dart';
import '../records/entry_form.dart';
import '../records/records_screen.dart';
import '../analytics/analytics_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    final v = s.selected;
    if (v == null) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'A little care.\nA longer journey.',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 16),
          const Text(
            'Your personal vehicle companion. Private, organised and always ready — even offline.',
          ),
          const SizedBox(height: 32),
          EmptyState(
            icon: Icons.two_wheeler,
            title: 'Welcome to MotoLog',
            description: 'Start with your vehicle. We’ll help you keep the rest in view.',
            action: FilledButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => const VehicleForm()),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Add your first vehicle'),
            ),
          ),
        ],
      );
    }
    final now = DateTime.now();
    final rows = s.selectedEntries;
    final month = rows
        .where((e) => e.date.year == now.year && e.date.month == now.month)
        .toList();
    final efficiency = efficiencies(rows);
    final reminders =
        rows
            .where(
              (e) =>
                  e.status == 'active' &&
                  (e.kind == EntryKind.reminder ||
                      e.nextDate != null ||
                      e.nextOdometer != null),
            )
            .toList()
          ..sort((a, b) {
            final ao = reminderState(a, v.odometer, now) == 'overdue',
                bo = reminderState(b, v.odometer, now) == 'overdue';
            if (ao != bo) {
              return ao ? -1 : 1;
            }
            return (a.kind == EntryKind.reminder
                    ? a.date
                    : a.nextDate ?? DateTime(2100))
                .compareTo(
                  b.kind == EntryKind.reminder
                      ? b.date
                      : b.nextDate ?? DateTime(2100),
                );
          });
    final activity = rows
        .where((e) => e.kind != EntryKind.reminder)
        .take(5)
        .toList();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const VehicleSelector(),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF254C87), Color(0xFF172940)],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'READY FOR THE ROAD',
                style: TextStyle(
                  color: Color(0xFFB8D0F7),
                  letterSpacing: 2,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      v.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Icon(
                    v.type == 'Car' ? Icons.directions_car : Icons.two_wheeler,
                    size: 48,
                    color: const Color(0xFF91B9FF),
                  ),
                ],
              ),
              Text(
                '${v.make} ${v.model} • ${v.fuelType}',
                style: const TextStyle(color: Color(0xFFB8D0F7)),
              ),
              const SizedBox(height: 28),
              Text(
                '${v.odometer.toStringAsFixed(0)} km',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const Text(
                'CURRENT ODOMETER',
                style: TextStyle(
                  color: Color(0xFFB8D0F7),
                  letterSpacing: 1.6,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: () => openEntry(context, EntryKind.fuel),
              icon: const Icon(Icons.local_gas_station_outlined),
              label: const Text('Add fuel'),
            ),
            FilledButton.tonalIcon(
              onPressed: () => openEntry(context, EntryKind.maintenance),
              icon: const Icon(Icons.build_outlined),
              label: const Text('Log service'),
            ),
            OutlinedButton.icon(
              onPressed: () => openEntry(context, EntryKind.reminder),
              icon: const Icon(Icons.add_alert_outlined),
              label: const Text('Add reminder'),
            ),
          ],
        ),
        const Section('This month'),
        MetricGrid(
          children: [
            Metric(
              'Total expenses',
              money(context, spending(month)),
              Icons.payments_outlined,
            ),
            Metric(
              'Latest full-tank efficiency',
              efficiency.isEmpty
                  ? '— km/L'
                  : '${efficiency.last.value.toStringAsFixed(1)} km/L',
              Icons.speed,
              color: Palette.teal,
            ),
            Metric(
              'Fuel',
              money(context, spending(month, EntryKind.fuel)),
              Icons.local_gas_station_outlined,
            ),
            Metric(
              'Maintenance',
              money(context, spending(month, EntryKind.maintenance)),
              Icons.build_outlined,
              color: Palette.amber,
            ),
          ],
        ),
        const Section('On your radar'),
        if (reminders.isEmpty)
          const Panel(
            child: Text(
              'No upcoming deadlines. Add a reminder for insurance, PUC or your next service.',
            ),
          ),
        ...reminders
            .take(4)
            .map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: ListTile(
                    leading: Icon(
                      Icons.notifications_active_outlined,
                      color: reminderState(e, v.odometer, now) == 'overdue'
                          ? Palette.red
                          : Palette.amber,
                    ),
                    title: Text(e.title),
                    subtitle: Text(
                      '${reminderState(e, v.odometer, now).toUpperCase()} • ${e.kind == EntryKind.reminder
                          ? dateLabel(e.date)
                          : e.nextDate != null
                          ? dateLabel(e.nextDate!)
                          : 'Distance based'}${e.nextOdometer == null ? '' : ' • ${e.nextOdometer} km'}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => EntryDetail(kind: e.kind, id: e.id!),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        const Section('Spending overview'),
        MonthlyChart(entries: rows),
        const Section('Latest service'),
        if (rows.any((e) => e.kind == EntryKind.maintenance))
          EntryTile(
            entry: rows.firstWhere((e) => e.kind == EntryKind.maintenance),
          )
        else
          const Panel(
            child: Text(
              'No service history yet. Log your next service to start a maintenance timeline.',
            ),
          ),
        const Section('Recent activity'),
        if (activity.isEmpty)
          const Panel(
            child: Text('Your fuel and service history will appear here.'),
          ),
        ...activity.map(
          (e) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: EntryTile(entry: e),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
