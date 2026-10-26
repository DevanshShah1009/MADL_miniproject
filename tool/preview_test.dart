// Run with: flutter test tool/preview_test.dart --no-pub
// Synthetic fixtures are confined to this test and never seeded into the app.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:motolog/app/app.dart';
import 'package:motolog/core/models.dart';
import 'package:motolog/core/repository.dart';
import 'package:motolog/core/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Repository repository;
  late AppStore store;
  setUpAll(() async {
    sqfliteFfiInit();
    repository = await Repository.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    final fontRoot = Platform.environment['MOTOLOG_FONT_ROOT'];
    if (fontRoot != null) {
      final loader = FontLoader('Roboto');
      loader.addFont(
        File('$fontRoot/roboto-regular.ttf')
            .readAsBytes()
            .then((b) => ByteData.sublistView(b)),
      );
      await loader.load();
      final icons = FontLoader('MaterialIcons');
      icons.addFont(
        File('$fontRoot/materialicons-regular.otf')
            .readAsBytes()
            .then((b) => ByteData.sublistView(b)),
      );
      await icons.load();
    }
    store = AppStore(repository);
    await repository.saveVehicle(
      const Vehicle(
        name: 'Weekend explorer',
        make: 'Honda',
        model: 'CB350',
        odometer: 12480,
      ),
    );
    for (var i = 0; i < 6; i++) {
      await repository.saveEntry(
        LogEntry(
          vehicleId: 1,
          kind: EntryKind.fuel,
          title: 'Fuel purchase',
          date: DateTime(2026, 5 + i, 3),
          odometer: 10000 + i * 400,
          litres: 12,
          price: 104,
          cost: 1248,
          fullTank: true,
        ),
      );
    }
    await repository.saveEntry(
      LogEntry(
        vehicleId: 1,
        kind: EntryKind.maintenance,
        title: 'Oil & filter change',
        category: 'Engine oil',
        date: DateTime(2026, 10, 12),
        cost: 1450,
        odometer: 12400,
        nextDate: DateTime(2027, 1, 12),
      ),
    );
    await repository.saveEntry(
      LogEntry(
        vehicleId: 1,
        kind: EntryKind.reminder,
        title: 'Insurance renewal',
        category: 'Insurance',
        date: DateTime(2026, 11, 5),
      ),
    );
    await store.refresh();
  });
  tearDownAll(() async {
    store.dispose();
    await repository.db.close();
  });
  testWidgets('Render populated mobile screens without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MotoLogApp(store: store),
      ),
    );
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
      await tester.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('docs/previews').create(recursive: true);
        await File('docs/previews/${label.toLowerCase()}.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}
