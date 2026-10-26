import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models.dart';
import '../../core/repository.dart';
import '../../core/store.dart';
import '../../core/widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool busy = false;
  int currencyRevision = 0;
  Future<void> export(String type) async {
    setState(() => busy = true);
    final s = context.read<AppStore>();
    await perform(context, () async {
      final content = type == 'json'
          ? await s.repository.backup()
          : csv(
              s.entries,
              type == 'fuel' ? EntryKind.fuel : EntryKind.maintenance,
              currency: s.settings['currency'] ?? 'INR',
            );
      final extension = type == 'json' ? 'json' : 'csv';
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Save MotoLog export',
        fileName:
            'motolog_${type}_${DateTime.now().millisecondsSinceEpoch}.$extension',
        type: FileType.custom,
        allowedExtensions: [extension],
        bytes: Uint8List.fromList(utf8.encode(content)),
      );
      if (mounted) {
        message(
          context,
          result == null ? 'Export cancelled.' : 'Export saved successfully.',
        );
      }
    });
    if (mounted) {
      setState(() => busy = false);
    }
  }

  Future<void> restore() async {
    setState(() => busy = true);
    final s = context.read<AppStore>();
    await perform(context, () async {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );
      if (result == null) {
        return;
      }
      final file = result.files.single;
      if (file.size > 20 * 1024 * 1024) {
        throw const FormatException('Backup exceeds the 20 MB limit.');
      }
      final text = utf8.decode(
        file.bytes ?? await File(file.path!).readAsBytes(),
      );
      final parsed = Backup.parse(text);
      if (!mounted) {
        return;
      }
      if (!await confirm(
        context,
        'Replace all local data?',
        'This backup contains ${parsed.vehicles.length} vehicles and ${parsed.entries.length} records. It will replace all current data and preferences. Export a backup first if you need to keep them.',
        action: 'Replace data',
      )) {
        return;
      }
      await s.mutate((r) => r.restore(text));
      if (mounted) {
        message(context, 'Backup restored successfully.');
      }
    });
    if (mounted) {
      setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Make it yours',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        const Text('Your garage stays on your device.'),
        const Section('Preferences'),
        Panel(
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                key: ValueKey('theme-${s.settings['theme']}'),
                initialValue: s.settings['theme'] ?? 'dark',
                decoration: const InputDecoration(labelText: 'Appearance'),
                items: ['dark', 'light', 'system']
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) =>
                    perform(context, () => s.setSetting('theme', v!)),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: ValueKey(
                  'currency-${s.settings['currency']}-$currencyRevision',
                ),
                initialValue: s.settings['currency'] ?? 'INR',
                decoration: const InputDecoration(labelText: 'Currency'),
                items: const [
                  DropdownMenuItem(value: 'INR', child: Text('INR • ₹')),
                  DropdownMenuItem(value: 'USD', child: Text('USD • \$')),
                  DropdownMenuItem(value: 'EUR', child: Text('EUR • €')),
                ],
                onChanged: (v) async {
                  if (await confirm(
                        context,
                        'Change currency label?',
                        'Existing amounts are not converted. Use one currency consistently across your records.',
                        action: 'Change',
                      ) &&
                      context.mounted) {
                    await perform(context, () => s.setSetting('currency', v!));
                  }
                  if (mounted) {
                    setState(() {
                      currencyRevision++;
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              const Text(
                'Distance: kilometres (km) • Fuel: litres (L)\nAll calculations use metric units.',
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                key: ValueKey('lead-${s.settings['leadDays']}'),
                initialValue: s.settings['leadDays'] ?? '7',
                decoration: const InputDecoration(
                  labelText: 'Default reminder lead time',
                ),
                items: ['0', '1', '3', '7', '14', '30']
                    .map(
                      (v) => DropdownMenuItem(value: v, child: Text('$v days')),
                    )
                    .toList(),
                onChanged: (v) =>
                    perform(context, () => s.setSetting('leadDays', v!)),
              ),
            ],
          ),
        ),
        const Section('Reminders'),
        Panel(
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Local notifications'),
                subtitle: const Text('Optional reminders around 9 AM'),
                value: s.settings['notifications'] == 'true',
                onChanged: (v) async {
                  await perform(context, () async {
                    if (v && !(await s.notifications?.request() ?? false)) {
                      if (context.mounted) {
                        message(
                          context,
                          'Permission not granted. Reminders are still visible inside MotoLog.',
                        );
                      }
                      return;
                    }
                    await s.setSetting('notifications', v.toString());
                  });
                },
              ),
              const Text(
                'Android may delay delivery to save battery. Pending alerts survive device restarts. Open MotoLog after a timezone change to refresh local times. Mileage reminders require updated readings.',
              ),
              if (s.notificationError != null) Text(s.notificationError!),
            ],
          ),
        ),
        const Section('Your data'),
        Panel(
          child: Column(
            children: [
              const Text(
                'Exports contain your vehicle identifiers and notes. Store backups somewhere you trust.',
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.backup_outlined),
                title: const Text('Save JSON backup'),
                subtitle: const Text('All vehicles, records and preferences'),
                onTap: busy ? null : () => export('json'),
              ),
              ListTile(
                leading: const Icon(Icons.restore_outlined),
                title: const Text('Restore JSON backup'),
                subtitle: const Text('Validate, then confirm replacement'),
                onTap: busy ? null : restore,
              ),
              ListTile(
                leading: const Icon(Icons.local_gas_station_outlined),
                title: const Text('Export fuel CSV'),
                onTap: busy ? null : () => export('fuel'),
              ),
              ListTile(
                leading: const Icon(Icons.build_outlined),
                title: const Text('Export service CSV'),
                onTap: busy ? null : () => export('maintenance'),
              ),
              if (busy) const LinearProgressIndicator(),
              ListTile(
                leading: Icon(
                  Icons.delete_forever_outlined,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: const Text('Clear all data'),
                onTap: busy
                    ? null
                    : () async {
                        if (await confirm(
                              context,
                              'Clear all MotoLog data?',
                              'All vehicles, records, reminders and preferences will be permanently removed. This cannot be undone.',
                            ) &&
                            context.mounted) {
                          await perform(
                            context,
                            () => s.mutate((r) => r.clear()),
                            success: 'All data cleared',
                          );
                        }
                      },
              ),
            ],
          ),
        ),
        const Section('About MotoLog'),
        const Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MotoLog 1.0.0',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Smart Vehicle Maintenance Companion\nMobile Application Development mini-project',
              ),
              SizedBox(height: 16),
              Text(
                'Offline by design. No account, advertising or remote vehicle-data collection. Service schedules are user-entered reminders, not mechanical diagnoses.',
              ),
              SizedBox(height: 12),
              Text('Optional attachments are not supported in this version.'),
            ],
          ),
        ),
        TextButton(
          onPressed: () => showLicensePage(
            context: context,
            applicationName: 'MotoLog',
            applicationVersion: '1.0.0',
          ),
          child: const Text('Open-source licences'),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
