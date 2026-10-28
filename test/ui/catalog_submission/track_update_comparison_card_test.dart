import 'package:esketit_music_console/domain/catalog_submission.dart';
import 'package:esketit_music_console/ui/catalog_submission/track_update_comparison_card.dart';
import 'package:esketit_music_console/ui/catalog_submission/staged_audio_player.dart';
import 'package:esketit_music_console/use_case/catalog_submission/catalog_submission_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repository extends Fake implements CatalogSubmissionRepository {}

CatalogSubmission proposal({bool outdated = false}) =>
    CatalogSubmission.fromJson({
      'id': 12,
      'entityType': 'track_update',
      'entityId': 2981,
      'requesterUserId': 2,
      'status': 'pending_review',
      'createdAt': '2026-10-28T10:00:00Z',
      'submittedAt': '2026-10-28T10:00:00Z',
      'updatedAt': '2026-10-28T10:00:00Z',
      'snapshot': {},
      'feedback': [],
      'entity': {
        'trackId': 2981,
        'isOutdated': outdated,
        'targetAvailable': true,
        'reason': 'Replace the compressed recording with the studio version.',
        'changedFields': ['name', 'audioFilePath'],
        'beforeAuthorNames': ['Сплин'],
        'afterAuthorNames': ['Сплин'],
        'beforeAlbumTitle': '25-й кадр',
        'afterAlbumTitle': '25-й кадр',
        'before': {
          'name': 'Old title',
          'authorIds': [354],
          'albumId': 626,
          'trackNumber': 3,
          'audioFilePath': '/api/songs/old.mp3',
        },
        'after': {
          'name': 'Corrected title',
          'authorIds': [354],
          'albumId': 626,
          'trackNumber': 3,
          'audioFilePath': '/api/catalog-submissions/track-updates/12/audio',
        },
        'current': {
          'name': 'A newer catalog correction',
          'authorIds': [354],
          'albumId': 626,
          'trackNumber': 3,
        },
      },
    });

void main() {
  for (final width in [390.0, 1280.0]) {
    testWidgets(
      'compares versions and filters unchanged fields at width $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          RepositoryProvider<CatalogSubmissionRepository>.value(
            value: _Repository(),
            child: MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: TrackUpdateComparisonCard(
                    submission: proposal(),
                    leaseToken: 'review-lease',
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Compare track changes'), findsOneWidget);
        expect(find.text('Old title'), findsOneWidget);
        expect(find.text('Corrected title'), findsOneWidget);
        final players = tester
            .widgetList<StagedAudioPlayer>(find.byType(StagedAudioPlayer))
            .toList();
        expect(players[0].publishedAudioPath, '/api/songs/old.mp3');
        expect(players[1].trackUpdateSubmissionId, 12);
        expect(players[1].leaseToken, 'review-lease');
        await tester.ensureVisible(find.text('Show changed fields only'));
        await tester.tap(find.text('Show changed fields only'));
        await tester.pumpAndSettle();
        expect(find.text('Artists'), findsNothing);
        expect(find.text('Old title'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'explains stale proposals and reveals the latest published version',
    (tester) async {
      await tester.pumpWidget(
        RepositoryProvider<CatalogSubmissionRepository>.value(
          value: _Repository(),
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: TrackUpdateComparisonCard(
                  submission: proposal(outdated: true),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Published track changed'), findsOneWidget);
      await tester.tap(find.text('View latest published data'));
      await tester.pumpAndSettle();
      expect(find.text('A newer catalog correction'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
