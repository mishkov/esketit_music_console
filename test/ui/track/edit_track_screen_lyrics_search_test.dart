import 'package:esketit_music_console/domain/album.dart';
import 'package:esketit_music_console/domain/author.dart';
import 'package:esketit_music_console/domain/lyrics_search_candidate.dart';
import 'package:esketit_music_console/domain/track.dart';
import 'package:esketit_music_console/domain/track_lyrics.dart';
import 'package:esketit_music_console/firebase/track/storage_file.dart';
import 'package:esketit_music_console/ui/track/edit_track_screen.dart';
import 'package:esketit_music_console/use_case/lyrics/lyrics_search_repository.dart';
import 'package:esketit_music_console/use_case/track/storage/storage_albums_list.dart';
import 'package:esketit_music_console/use_case/track/storage/tracks_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('searches with current metadata and applies plain lyrics draft', (
    tester,
  ) async {
    final repository = _FakeLyricsSearchRepository(
      candidates: const [
        LyricsSearchCandidate(
          provider: 'lrclib',
          providerId: 10,
          source: 'LRCLIB #10',
          trackName: 'Found track',
          artistName: 'Found artist',
          albumName: 'Found album',
          durationMs: 185000,
          instrumental: false,
          plainText: 'First found line\nSecond found line',
          syncedLines: [],
        ),
      ],
    );
    await _pumpScreen(tester, repository: repository);

    await _tapText(tester, 'Search lyrics');
    await tester.pumpAndSettle();

    expect(repository.lastTrackId, 1);
    expect(repository.lastTrackName, 'Original track');
    expect(repository.lastArtistNames, ['Original artist']);
    expect(repository.lastAlbumName, 'Original album');
    expect(
      find.byKey(const ValueKey('lyrics-search-mini-player')),
      findsOneWidget,
    );
    expect(find.text('track.mp3'), findsOneWidget);
    expect(find.byTooltip('Play'), findsOneWidget);
    expect(find.text('Plain lyrics found'), findsOneWidget);
    expect(find.text('First found line\nSecond found line'), findsOneWidget);

    await _tapText(tester, 'Apply as plain lyrics');
    await tester.pumpAndSettle();

    expect(
      _textFieldValue(tester, 'Lyrics text'),
      'First found line\nSecond found line',
    );
    expect(_textFieldValue(tester, 'Source'), 'LRCLIB #10');
    expect(find.text('Plain lyrics applied to the draft.'), findsOneWidget);
  });

  testWidgets('navigates candidates and previews synced lyrics', (
    tester,
  ) async {
    final repository = _FakeLyricsSearchRepository(
      candidates: const [
        LyricsSearchCandidate(
          provider: 'lrclib',
          providerId: 10,
          source: 'LRCLIB #10',
          trackName: 'Plain candidate',
          artistName: 'Artist',
          albumName: 'Album',
          durationMs: 180000,
          instrumental: false,
          plainText: 'Plain result',
          syncedLines: [],
        ),
        LyricsSearchCandidate(
          provider: 'lrclib',
          providerId: 11,
          source: 'LRCLIB #11',
          trackName: 'Synced candidate',
          artistName: 'Artist',
          albumName: 'Album',
          durationMs: 181000,
          instrumental: false,
          plainText: 'Synced result',
          syncedLines: [
            TrackLyricsLine(startMs: 1200, endMs: 3400, text: 'Timed line'),
            TrackLyricsLine(startMs: 3400, text: 'Last timed line'),
          ],
        ),
      ],
    );
    await _pumpScreen(tester, repository: repository);
    await _tapText(tester, 'Search lyrics');
    await tester.pumpAndSettle();

    expect(find.text('Select the correct lyrics'), findsOneWidget);
    expect(find.text('1 of 2'), findsOneWidget);
    expect(find.text('Plain lyrics found'), findsOneWidget);

    final nextButton = find.byTooltip('Next lyrics');
    await tester.ensureVisible(nextButton);
    await tester.tap(nextButton);
    await tester.pumpAndSettle();

    expect(find.text('2 of 2'), findsOneWidget);
    expect(find.text('Synced lyrics found'), findsOneWidget);
    expect(find.text('00:01.200'), findsOneWidget);
    expect(find.text('Timed line'), findsOneWidget);
    expect(find.text('Apply synced lyrics'), findsOneWidget);
    expect(find.byKey(const ValueKey('current-lyrics-line-0')), findsNothing);

    final forwardButton = find.byTooltip('Forward 5 seconds');
    await tester.ensureVisible(forwardButton);
    await tester.tap(forwardButton);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('current-lyrics-line-1')), findsOneWidget);

    await _tapText(tester, 'Apply synced lyrics');
    await tester.pumpAndSettle();

    expect(find.text('1200'), findsOneWidget);
    expect(find.text('3400'), findsNWidgets(2));
    expect(_textFieldValue(tester, 'Source'), 'LRCLIB #11');
    expect(find.text('Synced lyrics applied to the draft.'), findsOneWidget);
  });

  testWidgets('seeds the manual synchronizer with found plain text', (
    tester,
  ) async {
    final repository = _FakeLyricsSearchRepository(
      candidates: const [
        LyricsSearchCandidate(
          provider: 'lrclib',
          providerId: 12,
          source: 'LRCLIB #12',
          trackName: 'Manual candidate',
          artistName: 'Artist',
          albumName: 'Album',
          durationMs: 180000,
          instrumental: false,
          plainText: 'Line to synchronize\nAnother line',
          syncedLines: [],
        ),
      ],
    );
    await _pumpScreen(tester, repository: repository);
    await _tapText(tester, 'Search lyrics');
    await tester.pumpAndSettle();
    await _tapText(tester, 'Synchronize manually');
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('lyrics-search-mini-player')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('synced-lyrics-creator-mini-player')),
      findsOneWidget,
    );
    expect(
      _textFieldValue(tester, 'Plain text lyrics'),
      'Line to synchronize\nAnother line',
    );
    final delayField = tester.widget<DropdownButtonFormField<int>>(
      find.byType(DropdownButtonFormField<int>),
    );
    expect(delayField.initialValue, 1000);
    expect(_textFieldValue(tester, 'Source'), 'LRCLIB #12');
  });
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required LyricsSearchRepository repository,
}) async {
  final author = const Author(id: 2, currentName: 'Original artist');
  final album = Album(
    id: 3,
    title: 'Original album',
    coverImagePath: '',
    authors: const [Author(id: 2, currentName: 'Original artist')],
    releaseDate: DateTime.utc(2020),
    isPublished: true,
    trackIds: const [1],
    additionalInfo: const [],
  );
  final storage = _FakeTracksStorage(
    track: Track(
      id: 1,
      name: 'Original track',
      authors: [author],
      albumId: 3,
      additionalInfo: const [],
      sourceMetadata: const [],
      file: StorageFile(
        name: 'track.mp3',
        storagePath: '/songs/track.mp3',
        downloadUrl: 'http://localhost:8080/api/songs/track.mp3',
      ),
    ),
    author: author,
    album: album,
  );

  await tester.pumpWidget(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<TracksStorage>.value(value: storage),
        RepositoryProvider<LyricsSearchRepository>.value(value: repository),
      ],
      child: const MaterialApp(home: EditTrackScreen(trackId: 1)),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump();
}

String _textFieldValue(WidgetTester tester, String label) {
  final field = tester.widget<TextField>(
    find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == label,
    ),
  );
  return field.controller?.text ?? '';
}

class _FakeTracksStorage extends Fake implements TracksStorage {
  _FakeTracksStorage({
    required this.track,
    required this.author,
    required this.album,
  });

  final Track track;
  final Author author;
  final Album album;

  @override
  Future<Track> getTrack(int id) async => track;

  @override
  Future<List<Author>> getAuthors() async => [author];

  @override
  Future<StorageAlbumsList> getAlbumsList({
    int page = 1,
    int pageSize = 100,
    int? authorId,
    String? query,
    bool? isPublished,
  }) async => StorageAlbumsList(
    albums: [album],
    page: 1,
    pageSize: pageSize,
    totalItems: 1,
    totalPages: 1,
  );

  @override
  Future<Album> getAlbum(int id) async => album;

  @override
  Future<TrackLyrics?> getTrackLyrics(int trackId) async => null;
}

class _FakeLyricsSearchRepository extends Fake
    implements LyricsSearchRepository {
  _FakeLyricsSearchRepository({required this.candidates});

  final List<LyricsSearchCandidate> candidates;
  int? lastTrackId;
  String? lastTrackName;
  List<String>? lastArtistNames;
  String? lastAlbumName;

  @override
  Future<List<LyricsSearchCandidate>> search({
    required int trackId,
    required String trackName,
    required List<String> artistNames,
    required String albumName,
    int? durationMs,
  }) async {
    lastTrackId = trackId;
    lastTrackName = trackName;
    lastArtistNames = List<String>.from(artistNames);
    lastAlbumName = albumName;
    return candidates;
  }
}
