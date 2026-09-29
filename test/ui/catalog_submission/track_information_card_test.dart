import 'package:esketit_music_console/domain/album.dart';
import 'package:esketit_music_console/domain/author.dart';
import 'package:esketit_music_console/domain/catalog_submission.dart';
import 'package:esketit_music_console/ui/catalog_submission/track_information_card.dart';
import 'package:esketit_music_console/use_case/track/storage/tracks_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('uses related submissions for supported track details', (
    tester,
  ) async {
    final storage = _FakeTracksStorage();
    final track = _submission(
      id: 1,
      entityType: CatalogSubmissionEntityType.track,
      entityId: 42,
      entity: const {
        'name': 'Night Drive',
        'authorIds': [7],
        'albumId': 9,
      },
    );
    final album = _submission(
      id: 2,
      entityType: CatalogSubmissionEntityType.album,
      entityId: 9,
      entity: const {
        'title': 'After Dark',
        'coverImagePath': 'cover.png',
        'releaseDate': '2026-09-27T00:00:00Z',
      },
    );
    final author = _submission(
      id: 3,
      entityType: CatalogSubmissionEntityType.author,
      entityId: 7,
      entity: const {
        'currentName': 'Филки',
        'photos': ['author.png'],
      },
    );

    await tester.pumpWidget(
      RepositoryProvider<TracksStorage>.value(
        value: storage,
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 900,
              child: TrackInformationCard(
                submission: track,
                relatedSubmissions: [track, album, author],
                requesterEmail: 'artist@example.com',
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Track information'), findsOneWidget);
    expect(find.text('Night Drive'), findsOneWidget);
    expect(find.text('Pending review'), findsOneWidget);
    expect(find.text('Филки'), findsOneWidget);
    expect(find.text('After Dark'), findsOneWidget);
    expect(find.text('Sep 27, 2026'), findsOneWidget);
    expect(find.text('artist@example.com'), findsOneWidget);
    expect(storage.resolvedCoverPath, 'cover.png');
    expect(storage.resolvedAuthorPhotoPath, 'author.png');
    expect(storage.authorId, isNull);
    expect(storage.albumId, isNull);
    expect(find.text('Genre'), findsNothing);
    expect(find.text('Duration'), findsNothing);
    expect(find.text('Explicit'), findsNothing);
  });

  testWidgets('shows only known fields for a sparse track submission', (
    tester,
  ) async {
    final track = _submission(
      id: 1,
      entityType: CatalogSubmissionEntityType.track,
      entityId: 42,
      entity: const {'name': 'Night Drive'},
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: TrackInformationCard(
              submission: track,
              relatedSubmissions: [track],
              requesterEmail: '',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Night Drive'), findsOneWidget);
    expect(find.text('Submitted at'), findsOneWidget);
    expect(find.text('Artist'), findsNothing);
    expect(find.text('Album'), findsNothing);
    expect(find.text('Release date'), findsNothing);
  });

  testWidgets('loads names and photos when related submissions are absent', (
    tester,
  ) async {
    final storage = _FakeTracksStorage(
      author: const Author(
        id: 7,
        currentName: 'Full artist name',
        photos: ['artist.jpg'],
      ),
      album: Album(
        id: 9,
        title: 'Full album name',
        coverImagePath: 'album.jpg',
        authors: const [],
        releaseDate: DateTime.utc(2026, 9, 27),
        isPublished: false,
        trackIds: const [],
        additionalInfo: const [],
      ),
    );
    final track = _submission(
      id: 1,
      entityType: CatalogSubmissionEntityType.track,
      entityId: 42,
      entity: const {
        'name': 'Night Drive',
        'authorIds': [7],
        'albumId': 9,
      },
    );

    await tester.pumpWidget(
      RepositoryProvider<TracksStorage>.value(
        value: storage,
        child: MaterialApp(
          home: Scaffold(
            body: TrackInformationCard(
              submission: track,
              relatedSubmissions: [track],
              requesterEmail: 'artist@example.com',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Full artist name'), findsOneWidget);
    expect(find.text('Full album name'), findsOneWidget);
    expect(find.text('Author #7'), findsNothing);
    expect(find.text('Album #9'), findsNothing);
    expect(storage.authorId, 7);
    expect(storage.albumId, 9);
    expect(storage.resolvedAuthorPhotoPath, 'artist.jpg');
    expect(storage.resolvedCoverPath, 'album.jpg');
    final imageUrls = tester
        .widgetList<Image>(find.byType(Image))
        .map((image) => (image.image as NetworkImage).url);
    expect(
      imageUrls,
      containsAll([
        'https://example.com/artist.jpg',
        'https://example.com/album.jpg',
      ]),
    );
  });
}

CatalogSubmission _submission({
  required int id,
  required CatalogSubmissionEntityType entityType,
  required int entityId,
  required Map<String, dynamic> entity,
}) => CatalogSubmission(
  id: id,
  entityType: entityType,
  entityId: entityId,
  requesterUserId: 5,
  status: CatalogSubmissionStatus.pendingReview,
  snapshot: entity,
  entity: entity,
  feedback: const [],
  createdAt: DateTime.utc(2026, 9, 27, 12),
  submittedAt: DateTime.utc(2026, 9, 27, 15, 54),
  updatedAt: DateTime.utc(2026, 9, 27, 15, 54),
);

class _FakeTracksStorage extends Fake implements TracksStorage {
  _FakeTracksStorage({this.author, this.album});

  final Author? author;
  final Album? album;
  int? authorId;
  int? albumId;
  String? resolvedCoverPath;
  String? resolvedAuthorPhotoPath;

  @override
  Future<Author> getAuthor(int id) async {
    authorId = id;
    if (author == null) throw StateError('Author unavailable');
    return author!;
  }

  @override
  Future<Album> getAlbum(int id) async {
    albumId = id;
    if (album == null) throw StateError('Album unavailable');
    return album!;
  }

  @override
  String resolveAlbumCoverUrl(String coverImagePath) {
    resolvedCoverPath = coverImagePath;
    return 'https://example.com/$coverImagePath';
  }

  @override
  String resolveAuthorPhotoUrl(String photoPath) {
    resolvedAuthorPhotoPath = photoPath;
    return 'https://example.com/$photoPath';
  }
}
