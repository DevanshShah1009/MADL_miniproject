import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/models.dart';
import '../../core/store.dart';
import '../../core/widgets.dart';
import '../../core/calculations.dart';
import '../../app/theme.dart';
import '../records/records_screen.dart';

class MonthlyChart extends StatelessWidget {
  final List<LogEntry> entries;
  final DateTime? ending;
  const MonthlyChart({super.key, required this.entries, this.ending});
  @override
  Widget build(BuildContext context) {
    final now = ending ?? DateTime.now();
    final months = List.generate(
      6,
      (i) => DateTime(now.year, now.month - 5 + i),
    );
    final values = months
        .map(
          (m) => spending(
            entries.where(
              (e) => e.date.year == m.year && e.date.month == m.month,
            ),
          ),
        )
        .toList();
    final maxValue = values.fold<double>(0, math.max);
    if (maxValue == 0) {
      return const Panel(
        child: Text(
          'Your monthly spending chart will appear after your first fuel or service entry.',
        ),
      );
    }
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '6 MONTHS • ${context.read<AppStore>().settings['currency'] ?? 'INR'}',
            style: const TextStyle(letterSpacing: 1.5, fontSize: 11),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(
                6,
                (i) => Expanded(
                  child: Semantics(
                    label:
                        '${DateFormat.yMMMM().format(months[i])}: ${money(context, values[i])}',
                    button: true,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => showExpenseDetails(
                        context,
                        DateFormat.yMMMM().format(months[i]),
                        entries
                            .where(
                              (e) =>
                                  e.kind != EntryKind.reminder &&
                                  e.date.year == months[i].year &&
                                  e.date.month == months[i].month,
                            )
                            .toList(),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Tooltip(
                            message: money(context, values[i]),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 350),
                              height: math.max(4, 115 * values[i] / maxValue),
                              width: 24,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(7),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    i == 5 ? Palette.teal : Palette.blue,
                                    (i == 5 ? Palette.teal : Palette.blue)
                                        .withValues(alpha: 0.35),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            DateFormat.MMM().format(months[i]),
                            style: const TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Tap a bar to explore its records.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

void showExpenseDetails(
  BuildContext context,
  String title,
  List<LogEntry> rows,
) {
  Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              money(context, spending(rows)),
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 20),
            if (rows.isEmpty) const Text('No expenses in this period.'),
            ...rows.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: EntryTile(entry: e),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  DateTimeRange? range;
  String trend = 'All';
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    final rows = inRange(s.selectedEntries, range?.start, range?.end);
    final total = spending(rows),
        fuel = spending(rows, EntryKind.fuel),
        service = spending(rows, EntryKind.maintenance);
    final efficiency = efficiencies(rows);
    final perKm = costPerKm(rows);
    final categories = categoryTotals(rows);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const VehicleSelector(),
        Row(
          children: [
            Expanded(
              child: Text(
                'The bigger picture',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            IconButton(
              tooltip: 'Select date range',
              icon: const Icon(Icons.date_range),
              onPressed: () async {
                final r = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(1950),
                  lastDate: DateTime.now(),
                  initialDateRange: range,
                );
                if (r != null) {
                  setState(() => range = r);
                }
              },
            ),
          ],
        ),
        if (range != null)
          InputChip(
            label: Text(
              '${dateLabel(range!.start)} – ${dateLabel(range!.end)}',
            ),
            onDeleted: () => setState(() => range = null),
          )
        else
          const Text('All-time insights • selected vehicle'),
        const SizedBox(height: 24),
        MetricGrid(
          children: [
            Metric(
              'Total running expenses',
              money(context, total),
              Icons.account_balance_wallet_outlined,
            ),
            Metric(
              'Fuel spending',
              money(context, fuel),
              Icons.local_gas_station_outlined,
            ),
            Metric(
              'Maintenance',
              money(context, service),
              Icons.build_outlined,
              color: Palette.teal,
            ),
            Metric(
              'Sample cost / km',
              perKm == null ? 'Not enough data' : money(context, perKm),
              Icons.route_outlined,
              color: Palette.amber,
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'Cost/km covers the interval between the first and last full tanks in the filter, excludes the starting fill, and requires increasing readings. It is a sample, not lifetime ownership cost.',
          style: TextStyle(fontSize: 12),
        ),
        const Section('Monthly spending'),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'All', label: Text('All')),
            ButtonSegment(value: 'Fuel', label: Text('Fuel')),
            ButtonSegment(value: 'Service', label: Text('Service')),
          ],
          selected: {trend},
          onSelectionChanged: (v) => setState(() => trend = v.first),
        ),
        const SizedBox(height: 12),
        MonthlyChart(
          entries: rows
              .where(
                (e) =>
                    trend == 'All' ||
                    e.kind ==
                        (trend == 'Fuel'
                            ? EntryKind.fuel
                            : EntryKind.maintenance),
              )
              .toList(),
          ending: range?.end,
        ),
        const Section('Where it goes'),
        if (categories.isEmpty)
          const EmptyState(
            icon: Icons.donut_large,
            title: 'Insights start with a record',
            description: 'Fuel and maintenance costs will be grouped here.',
          ),
        ...categories.entries.map(
          (c) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Panel(
              child: InkWell(
                onTap: () => showExpenseDetails(
                  context,
                  c.key,
                  rows
                      .where(
                        (e) =>
                            e.kind != EntryKind.reminder &&
                            (e.kind == EntryKind.fuel ? 'Fuel' : e.category) ==
                                c.key,
                      )
                      .toList(),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(c.key)),
                        Text(money(context, c.value)),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: total == 0 ? 0 : c.value / total,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(5),
                      color: c.key == 'Fuel' ? Palette.blue : Palette.teal,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const Section('Fuel efficiency'),
        const Text(
          'Full tank to full tank • km/L\nPartial fills are included. Results assume comparable fill levels; invalid intervals are excluded.',
        ),
        const SizedBox(height: 14),
        if (efficiency.isEmpty)
          const Panel(
            child: Text(
              'Record at least two full tanks with increasing odometer readings to see measured fuel efficiency.',
            ),
          ),
        ...efficiency.reversed.map(
          (e) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(dateLabel(e.date))),
                      Text(
                        '${e.value.toStringAsFixed(1)} km/L',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${e.distance.toStringAsFixed(0)} km / ${e.litres.toStringAsFixed(2)} L',
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value:
                        e.value /
                        efficiency.map((v) => v.value).reduce(math.max),
                    color: Palette.teal,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
