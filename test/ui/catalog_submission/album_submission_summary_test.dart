import 'package:esketit_music_console/domain/catalog_submission.dart';
import 'package:esketit_music_console/ui/catalog_submission/album_cover_preview.dart';
import 'package:esketit_music_console/ui/catalog_submission/album_submission_summary.dart';
import 'package:esketit_music_console/ui/catalog_submission/submission_status_badge.dart';
import 'package:esketit_music_console/use_case/track/storage/tracks_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('aligns album details beside artwork and opens it full screen', (
    tester,
  ) async {
    await tester.pumpWidget(_screen(_submission()));
    final artwork = find.byType(AlbumCoverPreview);
    final title = find.text('Comedic (Film Scoring Moods)');
    final status = find.byType(SubmissionStatusBadge);
    final date = find.text('Sep 27, 2026');
    expect(
      tester.getTopRight(artwork).dx,
      lessThan(tester.getTopLeft(title).dx),
    );
    expect(tester.getCenter(title).dy, tester.getCenter(status).dy);
    expect(
      tester.getTopLeft(date).dx,
      greaterThan(tester.getTopRight(artwork).dx),
    );
    expect(
      tester.getTopLeft(date).dy,
      greaterThan(tester.getBottomLeft(title).dy),
    );
    expect(find.text('Release date'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('open-album-image')));
    await tester.pumpAndSettle();
    final dialog = find.byKey(const ValueKey('full-screen-album-image'));
    expect(dialog, findsOneWidget);
    expect(tester.getSize(dialog), tester.getSize(find.byType(Scaffold)));
    final image = tester.widget<Image>(
      find.descendant(of: dialog, matching: find.byType(Image)),
    );
    expect((image.image as NetworkImage).url, 'https://example.com/cover.png');
    expect(image.fit, BoxFit.contain);

    await tester.tap(find.byKey(const ValueKey('close-album-image')));
    await tester.pumpAndSettle();
    expect(dialog, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps artwork on the left at mobile width with a long title', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final title = 'Comedic (Film Scoring Moods) with an extended album title';
    await tester.pumpWidget(_screen(_submission(title: title)));
    final artwork = find.byType(AlbumCoverPreview);
    expect(
      tester.getTopRight(artwork).dx,
      lessThan(tester.getTopLeft(find.text(title)).dx),
    );
    expect(
      tester.getTopLeft(find.byType(SubmissionStatusBadge)).dx,
      greaterThan(tester.getTopRight(artwork).dx),
    );
    expect(find.text('Sep 27, 2026'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses retained snapshot and handles missing artwork and date', (
    tester,
  ) async {
    await tester.pumpWidget(_screen(_submission(snapshotOnly: true)));
    expect(find.text('Sep 27, 2026'), findsOneWidget);
    expect(find.byKey(const ValueKey('open-album-image')), findsOneWidget);

    await tester.pumpWidget(_screen(_submission(sparse: true)));
    expect(find.text('Not provided'), findsOneWidget);
    expect(find.byIcon(Icons.album_outlined), findsOneWidget);
    expect(find.byKey(const ValueKey('open-album-image')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Widget _screen(CatalogSubmission submission) =>
    RepositoryProvider<TracksStorage>.value(
      value: _FakeStorage(),
      child: MaterialApp(
        home: Scaffold(
          body: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: AlbumSubmissionSummary(submission: submission),
            ),
          ),
        ),
      ),
    );

CatalogSubmission _submission({
  String title = 'Comedic (Film Scoring Moods)',
  bool snapshotOnly = false,
  bool sparse = false,
}) {
  final data = {
    'title': title,
    if (!sparse) 'coverImagePath': 'cover.png',
    if (!sparse) 'releaseDate': '2026-09-27T00:00:00Z',
  };
  return CatalogSubmission(
    id: 1,
    entityType: CatalogSubmissionEntityType.album,
    entityId: 9,
    requesterUserId: 7,
    status: CatalogSubmissionStatus.pendingReview,
    snapshot: data,
    entity: snapshotOnly ? const {} : data,
    feedback: const [],
    createdAt: DateTime.utc(2026, 9, 26),
    submittedAt: DateTime.utc(2026, 9, 26),
    updatedAt: DateTime.utc(2026, 9, 26),
  );
}

class _FakeStorage extends Fake implements TracksStorage {
  @override
  String resolveAlbumCoverUrl(String coverImagePath) =>
      'https://example.com/$coverImagePath';
}
