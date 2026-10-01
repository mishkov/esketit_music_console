import 'package:esketit_music_console/ui/catalog_submission/external_links_information_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [800.0, 400.0, 320.0]) {
    testWidgets('wraps external link table cells at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final provider = 'provider_${'long' * 12}';
      final title = 'A long descriptive streaming link title ' * 5;
      final url = 'https://example.com/${'abcdefghij' * 15}';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    ExternalLinksInformationCard(
                      additionalInfo: [
                        {
                          'type': 'external_link',
                          'provider': provider,
                          'title': title,
                          'url': url,
                        },
                        {
                          'type': 'external_link',
                          'provider': 'music',
                          'url': 'https://example.com/other',
                        },
                        {
                          'type': 'text',
                          'title': 'Credits',
                          'text': 'Recorded live',
                        },
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final card = find.byType(ExternalLinksInformationCard);
      final table = find.byType(DataTable);
      expect(tester.widget<DataTable>(table).rows, hasLength(2));
      expect(find.text('—'), findsOneWidget);
      expect(find.text('Credits'), findsNothing);
      expect(find.text('Recorded live'), findsNothing);
      expect(
        find.descendant(
          of: card,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                (widget.axisDirection == AxisDirection.left ||
                    widget.axisDirection == AxisDirection.right),
          ),
        ),
        findsNothing,
      );
      for (final value in [provider, title.trim(), url]) {
        final cell = find.text(value);
        expect(tester.getSize(cell).height, greaterThan(24));
        expect(
          tester.getTopRight(cell).dx,
          lessThan(tester.getTopRight(card).dx),
        );
        expect(
          tester.getTopLeft(cell).dx,
          greaterThan(tester.getTopLeft(card).dx),
        );
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('shows an empty state for missing external links', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ExternalLinksInformationCard(additionalInfo: null),
        ),
      ),
    );

    expect(find.text('External links'), findsOneWidget);
    expect(find.text('No external links.'), findsOneWidget);
    expect(find.byType(DataTable), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
