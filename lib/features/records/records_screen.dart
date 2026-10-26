import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models.dart';
import '../../core/store.dart';
import '../../core/widgets.dart';
import '../../core/calculations.dart';
import '../../app/theme.dart';
import 'entry_form.dart';

class RecordsScreen extends StatefulWidget {
  final bool history;
  const RecordsScreen({super.key, this.history = false});
  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  EntryKind kind = EntryKind.fuel;
  String query = '', state = 'all';
  DateTimeRange? range;
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    final rows = inRange(s.selectedEntries, range?.start, range?.end)
        .where(
          (e) =>
              e.kind == kind &&
              '${e.title} ${e.category} ${e.provider} ${e.notes}'
                  .toLowerCase()
                  .contains(query.toLowerCase()) &&
              (state == 'all' ||
                  reminderState(e, s.selected?.odometer ?? 0, DateTime.now()) ==
                      state),
        )
        .toList();
    final body = ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const VehicleSelector(),
        SegmentedButton<EntryKind>(
          segments: const [
            ButtonSegment(value: EntryKind.fuel, label: Text('Fuel')),
            ButtonSegment(value: EntryKind.maintenance, label: Text('Service')),
            ButtonSegment(value: EntryKind.reminder, label: Text('Reminders')),
          ],
          selected: {kind},
          onSelectionChanged: (v) => setState(() {
            kind = v.first;
            state = 'all';
          }),
        ),
        const SizedBox(height: 16),
        TextField(
          decoration: const InputDecoration(
            hintText: 'Search your history',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (v) => setState(() => query = v),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.date_range),
              label: Text(
                range == null
                    ? 'All dates'
                    : '${dateLabel(range!.start)} – ${dateLabel(range!.end)}',
              ),
              onPressed: () async {
                final r = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(1950),
                  lastDate: DateTime(2100),
                  initialDateRange: range,
                );
                if (r != null) {
                  setState(() => range = r);
                }
              },
            ),
            if (range != null)
              IconButton(
                tooltip: 'Clear dates',
                onPressed: () => setState(() => range = null),
                icon: const Icon(Icons.close),
              ),
            FilledButton.icon(
              onPressed: () => openEntry(context, kind),
              icon: const Icon(Icons.add),
              label: Text(
                kind == EntryKind.fuel
                    ? 'Add fuel'
                    : kind == EntryKind.maintenance
                    ? 'Log service'
                    : 'Add reminder',
              ),
            ),
          ],
        ),
        if (kind == EntryKind.reminder)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Wrap(
              spacing: 6,
              children: ['all', 'upcoming', 'overdue', 'completed', 'dismissed']
                  .map(
                    (v) => ChoiceChip(
                      label: Text(v),
                      selected: state == v,
                      onSelected: (_) => setState(() => state = v),
                    ),
                  )
                  .toList(),
            ),
          ),
        Section(
          '${rows.length} ${kind == EntryKind.reminder ? 'reminders' : 'records'}',
        ),
        if (kind == EntryKind.fuel && rows.isNotEmpty)
          Panel(
            child: Text(
              '${rows.fold<double>(0, (a, e) => a + e.litres).toStringAsFixed(2)} L purchased  •  ${money(context, spending(rows))}\nWeighted average: ${money(context, spending(rows) / rows.fold<double>(0, (a, e) => a + e.litres))}/L',
            ),
          ),
        if (rows.isEmpty)
          const EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'A clear road ahead',
            description:
                'Add a record or adjust your filters to see your history.',
          ),
        ...rows.map(
          (e) => Padding(
            padding: const EdgeInsets.only(top: 10),
            child: EntryTile(entry: e),
          ),
        ),
        const SizedBox(height: 28),
      ],
    );
    return widget.history
        ? Scaffold(
            appBar: AppBar(title: const Text('Vehicle history')),
            body: body,
          )
        : body;
  }
}

class EntryTile extends StatelessWidget {
  final LogEntry entry;
  const EntryTile({super.key, required this.entry});
  @override
  Widget build(BuildContext context) {
    final e = entry;
    final s = context.watch<AppStore>();
    final v = s.vehicles.where((v) => v.id == e.vehicleId).firstOrNull;
    final state = reminderState(e, v?.odometer ?? 0, DateTime.now());
    final icon = switch (e.kind) {
      EntryKind.fuel => Icons.local_gas_station_outlined,
      EntryKind.maintenance => Icons.build_outlined,
      EntryKind.reminder => Icons.notifications_none,
    };
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        leading: CircleAvatar(
          backgroundColor: Palette.blue.withValues(alpha: 0.12),
          child: Icon(icon, color: Palette.blue),
        ),
        title: Text(e.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${dateLabel(e.date)} • ${e.kind == EntryKind.reminder ? state : '${e.odometer.toStringAsFixed(0)} km'}',
          style: TextStyle(
            color: e.kind == EntryKind.reminder && state == 'overdue'
                ? Palette.red
                : null,
          ),
        ),
        trailing: e.kind == EntryKind.reminder
            ? const Icon(Icons.chevron_right)
            : Text(money(context, e.cost)),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => EntryDetail(kind: e.kind, id: e.id!),
          ),
        ),
      ),
    );
  }
}

class EntryDetail extends StatelessWidget {
  final EntryKind kind;
  final int id;
  const EntryDetail({super.key, required this.kind, required this.id});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    final e = s.entries.where((e) => e.kind == kind && e.id == id).firstOrNull;
    if (e == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('This record is no longer available.')),
      );
    }
    final vehicle = s.vehicles.firstWhere((v) => v.id == e.vehicleId);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Record details'),
        actions: [
          IconButton(
            tooltip: 'Edit',
            onPressed: () => openEntry(context, kind, entry: e),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.title,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                Text('${vehicle.name} • ${e.category}'),
                const SizedBox(height: 24),
                Text(
                  kind == EntryKind.reminder
                      ? reminderState(
                          e,
                          vehicle.odometer,
                          DateTime.now(),
                        ).toUpperCase()
                      : money(context, e.cost),
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 16),
                Text('Date: ${dateLabel(e.date)}'),
                if (kind != EntryKind.reminder)
                  Text('Odometer: ${e.odometer} km'),
                if (kind == EntryKind.fuel) ...[
                  Text('${e.litres} L × ${money(context, e.price)}/L'),
                  Text(e.fullTank ? 'Full tank' : 'Partial fill'),
                  if ((e.cost - e.litres * e.price).abs() > 0.02)
                    const Text('Receipt total was overridden.'),
                ],
                if (e.provider.isNotEmpty) Text('Provider: ${e.provider}'),
                if (e.nextDate != null)
                  Text('Next service: ${dateLabel(e.nextDate!)}'),
                if (e.nextOdometer != null)
                  Text('Due at: ${e.nextOdometer} km'),
                if (kind != EntryKind.fuel)
                  Text('Lead time: ${e.leadDays} days'),
                if (e.notes.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(e.notes),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (kind == EntryKind.reminder ||
              e.nextDate != null ||
              e.nextOdometer != null) ...[
            Text('Schedule status: ${e.status}'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                for (final state in ['active', 'completed', 'dismissed'])
                  if (state != e.status)
                    OutlinedButton(
                      onPressed: () => perform(
                        context,
                        () => s.mutate((r) => r.status(e, state)),
                        success: 'Schedule updated',
                      ),
                      child: Text(
                        state == 'active'
                            ? 'Reopen'
                            : state == 'completed'
                            ? 'Complete'
                            : 'Dismiss',
                      ),
                    ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: () async {
              if (!await confirm(
                context,
                'Delete record?',
                'This permanently removes this record. The vehicle odometer is retained.',
              )) {
                return;
              }
              if (!context.mounted) {
                return;
              }
              if (await perform(
                    context,
                    () => s.mutate((r) => r.removeEntry(e)),
                  ) &&
                  context.mounted) {
                Navigator.pop(context);
              }
            },
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete record'),
          ),
        ],
      ),
    );
  }
}
