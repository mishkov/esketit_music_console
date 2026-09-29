import 'dart:typed_data';

import 'package:esketit_music_console/domain/catalog_submission.dart';
import 'package:esketit_music_console/ui/catalog_submission/audio_object_url.dart';
import 'package:esketit_music_console/ui/catalog_submission/staged_audio_player.dart';
import 'package:esketit_music_console/use_case/catalog_submission/catalog_submission_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'loads authenticated bytes and revokes its object URL on cleanup',
    (tester) async {
      final repository = _AudioRepository();
      final urls = _ObjectUrls();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StagedAudioPlayer(
              trackId: 42,
              leaseToken: 'lease',
              repository: repository,
              objectUrlFactory: urls,
            ),
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey('staged-audio-progress-42')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('staged-audio-position-42')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('staged-audio-duration-42')),
        findsOneWidget,
      );
      expect(find.text('0:00'), findsNWidgets(2));
      expect(
        tester.getSize(find.byTooltip('Play staged audio')),
        const Size(56, 56),
      );
      expect(find.byIcon(Icons.more_vert), findsNothing);
      expect(
        find.byKey(const ValueKey('staged-audio-volume-42')),
        findsOneWidget,
      );
      expect(find.byTooltip('Mute staged audio'), findsOneWidget);
      await tester.tap(find.byTooltip('Mute staged audio'));
      await tester.pump();
      expect(
        tester
            .widget<Slider>(
              find.byKey(const ValueKey('staged-audio-volume-42')),
            )
            .value,
        0,
      );
      await tester.tap(find.byTooltip('Unmute staged audio'));
      await tester.pump();
      expect(
        tester
            .widget<Slider>(
              find.byKey(const ValueKey('staged-audio-volume-42')),
            )
            .value,
        0.7,
      );
      await tester.tap(find.byTooltip('Play staged audio'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(repository.requestedTrackId, 42);
      expect(repository.requestedLease, 'lease');
      expect(urls.created, 1);

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pump();
      expect(urls.revoked, ['blob:test-audio']);
    },
  );
}

class _AudioRepository extends Fake implements CatalogSubmissionRepository {
  int? requestedTrackId;
  String? requestedLease;

  @override
  Future<CatalogAudioData> getStagedAudio(
    int trackId, {
    String? leaseToken,
  }) async {
    requestedTrackId = trackId;
    requestedLease = leaseToken;
    return CatalogAudioData(
      bytes: Uint8List.fromList(const [1, 2, 3]),
      contentType: 'audio/mpeg',
    );
  }
}

class _ObjectUrls implements AudioObjectUrlFactory {
  int created = 0;
  final List<String> revoked = [];

  @override
  String create(List<int> bytes, {String? contentType}) {
    created += 1;
    return 'blob:test-audio';
  }

  @override
  void revoke(String url) => revoked.add(url);
}
