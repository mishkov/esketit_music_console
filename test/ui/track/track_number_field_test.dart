import 'package:esketit_music_console/domain/album.dart';
import 'package:esketit_music_console/firebase/track/storage_file.dart';
import 'package:esketit_music_console/domain/track.dart';
import 'package:esketit_music_console/ui/track/track_number_field.dart';
import 'package:esketit_music_console/use_case/track/storage/tracks_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'prefills maximum plus one and rejects occupied or missing numbers',
    (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      final form = GlobalKey<FormState>();
      final album = Album(
        id: 1,
        title: 'Gaps',
        coverImagePath: '',
        authors: const [],
        releaseDate: DateTime.utc(2026),
        isPublished: true,
        trackIds: const [1, 2],
        additionalInfo: const [],
      );
      await tester.pumpWidget(
        RepositoryProvider<TracksStorage>.value(
          value: _Storage(),
          child: MaterialApp(
            home: Scaffold(
              body: Form(
                key: form,
                child: TrackNumberField(controller: controller, album: album),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(controller.text, '11');
      await tester.enterText(find.byType(TextFormField), '4');
      expect(form.currentState!.validate(), isTrue);
      await tester.enterText(find.byType(TextFormField), '10');
      expect(form.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.textContaining('already occupied'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '');
      expect(form.currentState!.validate(), isFalse);
    },
  );
}

class _Storage extends Fake implements TracksStorage {
  @override
  Future<List<Track>> getAlbumTracks(int albumId) async => [
    Track(
      id: 1,
      name: 'First',
      albumId: 1,
      trackNumber: 1,
      authors: [],
      additionalInfo: const [],
      sourceMetadata: const [],
      file: StorageFile(
        name: "test.mp3",
        storagePath: "test.mp3",
        downloadUrl: "http://music.test/test.mp3",
      ),
    ),
    Track(
      id: 2,
      name: 'Tenth',
      albumId: 1,
      trackNumber: 10,
      authors: [],
      additionalInfo: const [],
      sourceMetadata: const [],
      file: StorageFile(
        name: "test.mp3",
        storagePath: "test.mp3",
        downloadUrl: "http://music.test/test.mp3",
      ),
    ),
  ];
}
