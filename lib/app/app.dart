import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/store.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/vehicles/vehicles_screen.dart';
import '../features/records/records_screen.dart';
import '../features/analytics/analytics_screen.dart';
import '../features/settings/settings_screen.dart';
import 'theme.dart';

class MotoLogApp extends StatelessWidget {
  final AppStore store;
  const MotoLogApp({super.key, required this.store});
  @override
  Widget build(BuildContext context) => ChangeNotifierProvider.value(
    value: store,
    child: Consumer<AppStore>(
      builder: (context, s, _) => MaterialApp(
        title: 'MotoLog',
        debugShowCheckedModeBanner: false,
        theme: appTheme(Brightness.light),
        darkTheme: appTheme(Brightness.dark),
        themeMode: switch (s.settings['theme']) {
          'light' => ThemeMode.light,
          'system' => ThemeMode.system,
          _ => ThemeMode.dark,
        },
        home: const AppShell(),
      ),
    ),
  );
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int index = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<AppStore>().refresh().catchError((Object e) {});
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Palette.blue.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.route, color: Palette.blue),
          ),
          const SizedBox(width: 10),
          const Text(
            'MotoLog',
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.8),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 20),
          child: Row(
            children: [
              const Icon(
                Icons.offline_bolt_outlined,
                size: 16,
                color: Palette.teal,
              ),
              const SizedBox(width: 5),
              Text('OFFLINE', style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ),
      ],
    ),
    body: SafeArea(
      child: IndexedStack(
        index: index,
        children: const [
          DashboardScreen(),
          VehiclesScreen(),
          RecordsScreen(),
          AnalyticsScreen(),
          SettingsScreen(),
        ],
      ),
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: index,
      onDestinationSelected: (v) => setState(() => index = v),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.space_dashboard_outlined),
          selectedIcon: Icon(Icons.space_dashboard),
          label: 'Dashboard',
        ),
        NavigationDestination(
          icon: Icon(Icons.directions_car_outlined),
          selectedIcon: Icon(Icons.directions_car),
          label: 'Vehicles',
        ),
        NavigationDestination(
          icon: Icon(Icons.receipt_long_outlined),
          selectedIcon: Icon(Icons.receipt_long),
          label: 'Records',
        ),
        NavigationDestination(
          icon: Icon(Icons.bar_chart_outlined),
          selectedIcon: Icon(Icons.bar_chart),
          label: 'Analytics',
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: 'Settings',
        ),
      ],
    ),
  );
}
