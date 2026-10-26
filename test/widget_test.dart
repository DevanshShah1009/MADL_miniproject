import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:motolog/app/app.dart';
import 'package:motolog/core/models.dart';
import 'package:motolog/core/repository.dart';
import 'package:motolog/core/store.dart';
import 'package:motolog/features/records/entry_form.dart';

void main() {
  late Repository repository;
  late AppStore store;
  setUpAll(sqfliteFfiInit);
  setUp(() async {
    repository = await Repository.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    store = AppStore(repository);
    await store.refresh();
  });
  tearDown(() async {
    store.dispose();
    await repository.db.close();
  });
  testWidgets('All five navigation destinations work with real empty states', (
    tester,
  ) async {
    await tester.pumpWidget(MotoLogApp(store: store));
    expect(find.text('Welcome to MotoLog'), findsOneWidget);
    for (final label in [
      'Vehicles',
      'Records',
      'Analytics',
      'Settings',
      'Dashboard',
    ]) {
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets('Vehicle form validates required fields and saves', (
    tester,
  ) async {
    await tester.pumpWidget(MotoLogApp(store: store));
    await tester.tap(find.text('Add your first vehicle'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Save vehicle'),
      300,
      scrollable: find
          .byWidgetPredicate(
            (w) =>
                w is Scrollable &&
                w.axisDirection == AxisDirection.down &&
                w.restorationId != 'editable',
          )
          .last,
    );
    await tester.tap(find.text('Save vehicle'));
    await tester.pumpAndSettle();
    expect(store.vehicles, isEmpty);
    await tester.scrollUntilVisible(
      find.widgetWithText(TextFormField, 'Nickname'),
      -400,
      scrollable: find
          .byWidgetPredicate(
            (w) =>
                w is Scrollable &&
                w.axisDirection == AxisDirection.down &&
                w.restorationId != 'editable',
          )
          .last,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nickname'),
      'Daily ride',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Manufacturer'),
      'Honda',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Model'),
      'CB350',
    );
    await tester.scrollUntilVisible(
      find.text('Save vehicle'),
      300,
      scrollable: find
          .byWidgetPredicate(
            (w) =>
                w is Scrollable &&
                w.axisDirection == AxisDirection.down &&
                w.restorationId != 'editable',
          )
          .last,
    );
    await tester.tap(find.text('Save vehicle'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    expect(store.vehicles.single.name, 'Daily ride');
  });
  testWidgets('Fuel form calculates total and rejects zero litres', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(
      () => store.mutate(
        (r) => r.saveVehicle(
          const Vehicle(name: 'Bike', make: 'Honda', model: 'CB'),
        ),
      ),
    );
    await tester.pumpWidget(MotoLogApp(store: store));
    await tester.tap(find.text('Add fuel').first);
    await tester.pumpAndSettle();
    expect(find.byType(EntryForm), findsOneWidget);
    await tester.scrollUntilVisible(
      find.widgetWithText(TextFormField, 'Litres'),
      200,
      scrollable: find
          .byWidgetPredicate(
            (w) =>
                w is Scrollable &&
                w.axisDirection == AxisDirection.down &&
                w.restorationId != 'editable',
          )
          .last,
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Litres'), '5');
    await tester.scrollUntilVisible(
      find.widgetWithText(TextFormField, 'Price / litre'),
      100,
      scrollable: find
          .byWidgetPredicate(
            (w) =>
                w is Scrollable &&
                w.axisDirection == AxisDirection.down &&
                w.restorationId != 'editable',
          )
          .last,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Price / litre'),
      '100',
    );
    await tester.scrollUntilVisible(
      find.widgetWithText(TextFormField, 'Total amount'),
      150,
      scrollable: find
          .byWidgetPredicate(
            (w) =>
                w is Scrollable &&
                w.axisDirection == AxisDirection.down &&
                w.restorationId != 'editable',
          )
          .last,
    );
    expect(find.text('500.00'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.widgetWithText(TextFormField, 'Litres'),
      -200,
      scrollable: find
          .byWidgetPredicate(
            (w) =>
                w is Scrollable &&
                w.axisDirection == AxisDirection.down &&
                w.restorationId != 'editable',
          )
          .last,
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Litres'), '0');
    await tester.scrollUntilVisible(
      find.text('Save record'),
      300,
      scrollable: find
          .byWidgetPredicate(
            (w) =>
                w is Scrollable &&
                w.axisDirection == AxisDirection.down &&
                w.restorationId != 'editable',
          )
          .last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save record'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Enter a valid positive number'),
      -200,
      scrollable: find
          .byWidgetPredicate(
            (w) =>
                w is Scrollable &&
                w.axisDirection == AxisDirection.down &&
                w.restorationId != 'editable',
          )
          .last,
    );
    expect(find.text('Enter a valid positive number'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(store.entries, isEmpty);
    expect(find.byType(EntryForm), findsOneWidget);
  });
  testWidgets('Small-screen navigation has no overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(
      () => store.mutate(
        (r) => r.saveVehicle(
          const Vehicle(
            name: 'My long vehicle nickname',
            make: 'Honda',
            model: 'CB',
          ),
        ),
      ),
    );
    await tester.pumpWidget(MotoLogApp(store: store));
    for (final label in [
      'Dashboard',
      'Vehicles',
      'Records',
      'Analytics',
      'Settings',
    ]) {
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
