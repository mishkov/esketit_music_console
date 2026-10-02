import 'package:esketit_music_console/ui/catalog_submission/source_metadata_link.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher/link.dart';

void main() {
  for (final url in [
    null,
    '',
    '   ',
    'invalid',
    '/relative',
    'javascript:alert(1)',
  ]) {
    testWidgets('keeps missing or unsupported URL "$url" as plain text', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SourceMetadataLink(url: url)),
        ),
      );

      expect(find.byType(Link), findsNothing);
      expect(find.byType(TextButton), findsNothing);
      expect(
        find.text(url == null || url.trim().isEmpty ? '—' : url.trim()),
        findsOneWidget,
      );
    });
  }

  testWidgets('trims and wraps a long URL within the available width', (
    tester,
  ) async {
    final url = 'https://music.apple.com/us/song/${'1234567890' * 15}';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 200, child: SourceMetadataLink(url: ' $url ')),
        ),
      ),
    );

    expect(tester.widget<Link>(find.byType(Link)).uri, Uri.parse(url));
    expect(tester.getSize(find.text(url)).height, greaterThan(24));
    expect(tester.getSize(find.text(url)).width, lessThanOrEqualTo(200));
    expect(tester.takeException(), isNull);
  });
}
