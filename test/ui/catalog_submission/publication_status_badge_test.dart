import 'package:esketit_music_console/domain/catalog_publication_status.dart';
import 'package:esketit_music_console/ui/catalog_submission/publication_status_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders every centralized publication status label', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              PublicationStatusBadge(
                status: CatalogPublicationStatus.published,
              ),
              PublicationStatusBadge(
                status: CatalogPublicationStatus.pendingReview,
              ),
              PublicationStatusBadge(
                status: CatalogPublicationStatus.changesRequested,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Published'), findsOneWidget);
    expect(find.text('Pending review'), findsOneWidget);
    expect(find.text('Changes requested'), findsOneWidget);
  });
}
