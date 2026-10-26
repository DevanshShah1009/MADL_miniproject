import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'store.dart';
import '../app/theme.dart';

String money(BuildContext context, num value) => NumberFormat.currency(
  locale: 'en_IN',
  name: context.read<AppStore>().settings['currency'] ?? 'INR',
  symbol: switch (context.read<AppStore>().settings['currency']) {
    'USD' => '\$',
    'EUR' => '€',
    _ => '₹',
  },
  decimalDigits: 2,
).format(value);
String dateLabel(DateTime d) => DateFormat('dd MMM yyyy').format(d);

class Panel extends StatelessWidget {
  final Widget child;
  const Panel({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: const EdgeInsets.all(20), child: child),
  );
}

class Section extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const Section(this.title, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 12),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        ?trailing,
      ],
    ),
  );
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title, description;
  final Widget? action;
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.action,
  });
  @override
  Widget build(BuildContext context) => Panel(
    child: Center(
      child: Column(
        children: [
          const SizedBox(height: 16),
          Icon(icon, size: 48, color: Palette.blue),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          ?action,
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

class Metric extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const Metric(
    this.label,
    this.value,
    this.icon, {
    super.key,
    this.color = Palette.blue,
  });
  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 18),
        Text(value, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}

class MetricGrid extends StatelessWidget {
  final List<Widget> children;
  const MetricGrid({super.key, required this.children});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => Wrap(
      spacing: 12,
      runSpacing: 12,
      children: children
          .map(
            (w) => SizedBox(
              width: c.maxWidth < 330 ? c.maxWidth : (c.maxWidth - 12) / 2,
              child: w,
            ),
          )
          .toList(),
    ),
  );
}

class VehicleSelector extends StatelessWidget {
  const VehicleSelector({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    if (s.vehicles.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<int>(
        key: ValueKey(s.selectedId),
        initialValue: s.selectedId,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Your garage',
          prefixIcon: Icon(Icons.directions_car_outlined),
        ),
        items: s.vehicles
            .map(
              (v) => DropdownMenuItem(
                value: v.id,
                child: Text(v.name, overflow: TextOverflow.ellipsis),
              ),
            )
            .toList(),
        onChanged: s.select,
      ),
    );
  }
}

Future<bool> confirm(
  BuildContext context,
  String title,
  String body, {
  String action = 'Delete',
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;

void message(BuildContext context, String text) {
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

Future<bool> perform(
  BuildContext context,
  Future<void> Function() action, {
  String? success,
}) async {
  try {
    await action();
    if (context.mounted && success != null) {
      message(context, success);
    }
    return true;
  } catch (e) {
    if (context.mounted) {
      message(
        context,
        e is FormatException
            ? e.message
            : 'Could not complete this action. Your saved data is preserved.',
      );
    }
    return false;
  }
}
