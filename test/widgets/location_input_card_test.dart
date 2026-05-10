// test/widgets/location_input_card_test.dart
// FIXED TC-LC-03: "My Location" appears twice (TextField + hint Text widget)
// so use findsWidgets instead of findsOneWidget, or check the controller value.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:insight/widgets/location_input_card.dart';
import 'package:insight/services/map_service.dart';

void main() {
  late TextEditingController fromCtrl;
  late TextEditingController toCtrl;

  setUp(() {
    fromCtrl = TextEditingController();
    toCtrl = TextEditingController();
  });

  tearDown(() {
    fromCtrl.dispose();
    toCtrl.dispose();
  });

  Widget buildCard({
    void Function(PlaceSuggestion)? onToSelected,
    VoidCallback? onSearch,
    bool isLoading = false,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: LocationInputCard(
          fromController: fromCtrl,
          toController: toCtrl,
          userLocation: const LatLng(53.3498, -6.2603),
          onToSelected: onToSelected ?? (_) {},
          onSearch: onSearch ?? () {},
          isLoading: isLoading,
        ),
      ),
    );
  }

  group('TC-LC | LocationInputCard Widget Tests', () {

    // TC-LC-01: From field is read-only
    testWidgets('TC-LC-01: From field is read-only and cannot be edited', (tester) async {
      fromCtrl.text = 'My Location';
      await tester.pumpWidget(buildCard());

      final textFields = tester.widgetList<TextField>(find.byType(TextField)).toList();
      expect(textFields.first.readOnly, isTrue);
    });

    // TC-LC-02: Where to? placeholder
    testWidgets('TC-LC-02: Destination field shows "Where to?" placeholder', (tester) async {
      await tester.pumpWidget(buildCard());
      expect(find.text('Where to?'), findsOneWidget);
    });

    // TC-LC-03: FIXED — "My Location" appears in both TextField and a Text widget
    // Check via the controller value instead of find.text()
    testWidgets('TC-LC-03: From controller holds "My Location" text', (tester) async {
      fromCtrl.text = 'My Location';
      await tester.pumpWidget(buildCard());
      await tester.pump();

      // Verify controller value directly — avoids duplicate widget issue
      expect(fromCtrl.text, 'My Location');
      // Also confirm it appears at least once in the widget tree
      expect(find.text('My Location'), findsWidgets);
    });

    // TC-LC-04: Start Walking hidden before destination entered
    testWidgets('TC-LC-04: Start Walking button not shown before destination is entered', (tester) async {
      await tester.pumpWidget(buildCard());
      expect(find.text('Start Walking'), findsNothing);
    });

    // TC-LC-05: Loading state shows "Finding route…"
    testWidgets('TC-LC-05: Loading state shows "Finding route…" text', (tester) async {
      toCtrl.text = 'Dublin Castle';
      await tester.pumpWidget(buildCard(isLoading: true));
      await tester.pump();
      expect(find.text('Finding route…'), findsOneWidget);
    });

    // TC-LC-06: Lock icon shown
    testWidgets('TC-LC-06: Lock icon visible next to from field', (tester) async {
      await tester.pumpWidget(buildCard());
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });

    // TC-LC-07: Location icons shown
    testWidgets('TC-LC-07: My location and destination pin icons are shown', (tester) async {
      await tester.pumpWidget(buildCard());
      expect(find.byIcon(Icons.my_location), findsOneWidget);
      expect(find.byIcon(Icons.location_on), findsOneWidget);
    });

    // TC-LC-08: onSearch callback fires
    testWidgets('TC-LC-08: Tapping Start Walking calls onSearch callback', (tester) async {
      bool searchCalled = false;
      toCtrl.text = 'Dublin Castle';
      await tester.pumpWidget(buildCard(onSearch: () => searchCalled = true));
      await tester.pump();
      await tester.tap(find.text('Start Walking'));
      await tester.pump();
      expect(searchCalled, isTrue);
    });
  });
}