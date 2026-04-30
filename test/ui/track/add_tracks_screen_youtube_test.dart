import 'package:esketit_music_console/domain/album.dart';
import 'package:esketit_music_console/domain/author.dart';
import 'package:esketit_music_console/domain/auth/app_user.dart';
import 'package:esketit_music_console/domain/auth/auth_session.dart';
import 'package:esketit_music_console/domain/track.dart';
import 'package:esketit_music_console/esketit_rest_api/youtube/youtube_import_models.dart';
import 'package:esketit_music_console/firebase/track/storage_file.dart';
import 'package:esketit_music_console/ui/track/add_tracks_screen.dart';
import 'package:esketit_music_console/use_case/auth/bloc/auth_bloc.dart';
import 'package:esketit_music_console/use_case/auth/auth_repository.dart';
import 'package:esketit_music_console/use_case/telegram/telegram_import_repository.dart';
import 'package:esketit_music_console/use_case/track/storage/storage_albums_list.dart';
import 'package:esketit_music_console/use_case/track/storage/storage_tracks_list.dart';
import 'package:esketit_music_console/use_case/track/storage/tracks_storage.dart';
import 'package:esketit_music_console/use_case/track/tracks_list/bloc/track_list_bloc.dart';
import 'package:esketit_music_console/use_case/youtube/youtube_import_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the YouTube import tab for admins and starts a session', (
    tester,
  ) async {
    final tracksStorage = _FakeTracksStorage();
    final youtubeRepository = _FakeYouTubeImportRepository(
      startSessionResponse: _buildSession(),
    );

    await _pumpScreen(
      tester,
      tracksStorage: tracksStorage,
      youtubeRepository: youtubeRepository,
    );

    expect(find.text('Import from YouTube'), findsOneWidget);

    await _openYouTubeTab(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'YouTube URL'),
      'https://music.youtube.com/playlist?list=abc',
    );
    await _tapVisible(tester, find.text('Replace active session'));
    await tester.pumpAndSettle();
    await _tapVisible(
      tester,
      find.widgetWithText(FilledButton, 'Start import'),
    );

    expect(
      youtubeRepository.lastStartUrl,
      'https://music.youtube.com/playlist?list=abc',
    );
    expect(youtubeRepository.lastStartReplaceExisting, isTrue);
  });

  testWidgets('renders the current YouTube item and suggestions', (
    tester,
  ) async {
    final tracksStorage = _FakeTracksStorage(
      tracksById: {
        55: _buildTrack(
          id: 55,
          name: 'Matched Local Track',
          authorNames: const ['Known Author'],
          albumId: 3,
        ),
      },
    );
    final youtubeRepository = _FakeYouTubeImportRepository(
      currentSession: _buildSession(
        currentItem: _buildCurrentItem(
          suggestions: const [
            YouTubeImportSuggestion(
              type: 'exact_source_match',
              trackId: 55,
              confidence: 0.99,
              metadata: {'videoId': 'yt-123'},
            ),
          ],
        ),
      ),
    );

    await _pumpScreen(
      tester,
      tracksStorage: tracksStorage,
      youtubeRepository: youtubeRepository,
    );

    await _openYouTubeTab(tester);

    expect(find.text('Current YouTube item'), findsOneWidget);
    expect(find.text('Parsed Song Title'), findsNWidgets(2));
    expect(find.textContaining('Known Author, Guest Artist'), findsOneWidget);
    expect(find.textContaining('Parsed Album'), findsWidgets);
    expect(find.text('Exact source match found'), findsOneWidget);
    expect(find.text('Use suggestion'), findsOneWidget);
    expect(find.textContaining('Matched Local Track'), findsWidgets);
  });

  testWidgets('submits add-as-new with prefilled parsed data', (tester) async {
    final tracksStorage = _FakeTracksStorage(
      authors: const [Author(id: 7, currentName: 'Known Author')],
      albums: [
        Album(
          id: 3,
          title: 'Parsed Album',
          coverImagePath: '',
          authors: const [],
          releaseDate: DateTime.utc(2023, 1, 1),
          isPublished: true,
          trackIds: const [10, 11],
          additionalInfo: const [],
        ),
      ],
    );
    final youtubeRepository = _FakeYouTubeImportRepository(
      currentSession: _buildSession(
        currentItem: _buildCurrentItem(
          suggestions: const [],
          parsedAuthorNames: const ['Known Author'],
        ),
      ),
      addCurrentResponse: _buildAddResponse(),
    );

    await _pumpScreen(
      tester,
      tracksStorage: tracksStorage,
      youtubeRepository: youtubeRepository,
    );

    await _openYouTubeTab(tester);
    await _tapVisible(tester, find.widgetWithText(FilledButton, 'Add as new'));

    expect(youtubeRepository.lastCreateName, 'Parsed Song Title');
    expect(youtubeRepository.lastCreateAuthorIds, [7]);
    expect(youtubeRepository.lastCreateAlbumId, 3);
    expect(youtubeRepository.lastCreateAlbumOrder, 2);
  });

  testWidgets('submits attach payload from an exact-match suggestion', (
    tester,
  ) async {
    final tracksStorage = _FakeTracksStorage(
      tracksById: {
        88: _buildTrack(
          id: 88,
          name: 'Already Imported Track',
          authorNames: const ['Known Author'],
          albumId: 9,
        ),
      },
    );
    final youtubeRepository = _FakeYouTubeImportRepository(
      currentSession: _buildSession(
        currentItem: _buildCurrentItem(
          suggestions: const [
            YouTubeImportSuggestion(
              type: 'exact_source_match',
              trackId: 88,
              confidence: 1,
              metadata: {},
            ),
          ],
        ),
      ),
      attachCurrentResponse: _buildAddResponse(trackId: 88),
    );

    await _pumpScreen(
      tester,
      tracksStorage: tracksStorage,
      youtubeRepository: youtubeRepository,
    );

    await _openYouTubeTab(tester);
    await _tapVisible(
      tester,
      find.widgetWithText(FilledButton, 'Attach exact source match'),
    );

    expect(youtubeRepository.lastAttachTrackId, 88);
  });

  testWidgets('skip and cancel actions call the repository', (tester) async {
    final tracksStorage = _FakeTracksStorage();
    final youtubeRepository = _FakeYouTubeImportRepository(
      currentSession: _buildSession(currentItem: _buildCurrentItem()),
      skipCurrentResponse: _buildSession(
        currentItem: _buildCurrentItem(videoId: 'yt-456'),
      ),
    );

    await _pumpScreen(
      tester,
      tracksStorage: tracksStorage,
      youtubeRepository: youtubeRepository,
    );

    await _openYouTubeTab(tester);

    await _tapVisible(tester, find.widgetWithText(FilledButton, 'Skip'));
    expect(youtubeRepository.skipCount, 1);

    await _tapVisible(
      tester,
      find.widgetWithText(TextButton, 'Cancel session'),
    );
    await _tapVisible(
      tester,
      find.widgetWithText(FilledButton, 'Cancel session'),
    );
    expect(youtubeRepository.cancelCount, 1);
  });
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required _FakeTracksStorage tracksStorage,
  required _FakeYouTubeImportRepository youtubeRepository,
}) async {
  final authBloc = AuthBloc(
    authRepository: _FakeAuthRepository(
      session: AuthSession(
        user: AppUser(
          id: 1,
          email: 'admin@example.com',
          role: AppUserRole.admin,
          createdAt: DateTime.utc(2026, 1, 1),
        ),
        accessToken: 'token',
        accessTokenExpiresAt: DateTime.utc(2099, 1, 1),
        refreshToken: 'refresh',
        refreshTokenExpiresAt: DateTime.utc(2099, 1, 2),
      ),
    ),
  )..add(const AuthSessionRestoreRequested());

  await tester.pumpWidget(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<TracksStorage>.value(value: tracksStorage),
        RepositoryProvider<TelegramImportRepository>(
          create: (_) => _FakeTelegramImportRepository(),
        ),
        RepositoryProvider<YouTubeImportRepository>.value(
          value: youtubeRepository,
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: authBloc),
          BlocProvider(
            create: (_) => TrackListBloc(
              const TrackListState(tracks: []),
              storage: tracksStorage,
            ),
          ),
        ],
        child: const MaterialApp(home: AddTracksScreen()),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

Future<void> _openYouTubeTab(WidgetTester tester) async {
  final tabFinder = find.text('Import from YouTube');
  await tester.ensureVisible(tabFinder);
  await tester.pumpAndSettle();
  await tester.tap(tabFinder);
  await tester.pumpAndSettle();
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

YouTubeImportSession _buildSession({YouTubeCurrentImportItem? currentItem}) {
  return YouTubeImportSession(
    sessionId: 'session-1',
    status: 'active',
    sourceType: 'playlist',
    sourceUrl: 'https://music.youtube.com/playlist?list=abc',
    progress: const YouTubeImportProgress(
      total: 2,
      processed: 0,
      remaining: 2,
      skipped: 0,
      saved: 0,
    ),
    createdAt: DateTime.utc(2026, 4, 29, 12),
    updatedAt: DateTime.utc(2026, 4, 29, 12),
    currentItem: currentItem,
  );
}

YouTubeCurrentImportItem _buildCurrentItem({
  String videoId = 'yt-123',
  List<String> parsedAuthorNames = const ['Known Author', 'Guest Artist'],
  List<YouTubeImportSuggestion> suggestions = const [],
}) {
  return YouTubeCurrentImportItem(
    sourceType: 'track',
    sourceUrl: 'https://music.youtube.com/watch?v=$videoId',
    originalSourceUrl: 'https://www.youtube.com/watch?v=$videoId',
    videoId: videoId,
    parsedTitle: 'Parsed Song Title',
    parsedAuthorNames: parsedAuthorNames,
    parsedAlbumTitle: 'Parsed Album',
    parsedReleaseDate: DateTime.utc(2024, 5, 1),
    coverImageUrl: null,
    durationSeconds: 213,
    suggestions: suggestions,
  );
}

YouTubeImportAddResponse _buildAddResponse({int trackId = 77}) {
  return YouTubeImportAddResponse(
    session: _buildSession(
      currentItem: _buildCurrentItem(videoId: 'next-item'),
    ),
    track: _buildTrack(
      id: trackId,
      name: 'Created Track',
      authorNames: const ['Known Author'],
      albumId: 3,
    ),
  );
}

Track _buildTrack({
  required int id,
  required String name,
  required List<String> authorNames,
  required int albumId,
}) {
  return Track(
    id: id,
    name: name,
    authors: authorNames
        .asMap()
        .entries
        .map((entry) => Author(id: entry.key + 1, currentName: entry.value))
        .toList(),
    albumId: albumId,
    albumOrder: 0,
    additionalInfo: const [],
    sourceMetadata: const [],
    file: StorageFile(
      name: '$id.mp3',
      storagePath: '/songs/$id.mp3',
      downloadUrl: 'http://localhost:8080/songs/$id.mp3',
    ),
  );
}

class _FakeAuthRepository implements AuthRepository {
  const _FakeAuthRepository({required this.session});

  final AuthSession session;

  @override
  Future<AuthSession?> restoreSession() async => session;

  @override
  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async => session;

  @override
  Future<void> signOut() async {}

  @override
  Future<AuthSession?> refreshSession({bool forceRefresh = false}) async =>
      session;
}

class _FakeTracksStorage implements TracksStorage {
  _FakeTracksStorage({
    this.authors = const [],
    this.albums = const [],
    this.tracksById = const {},
  });

  final List<Author> authors;
  final List<Album> albums;
  final Map<int, Track> tracksById;

  @override
  Future<List<Author>> getAuthors() async => List<Author>.from(authors);

  @override
  Future<StorageAlbumsList> getAlbumsList({
    int page = 1,
    int pageSize = 100,
    int? authorId,
    String? query,
    bool? isPublished,
  }) async {
    return StorageAlbumsList(
      albums: List<Album>.from(albums),
      page: 1,
      pageSize: pageSize,
      totalItems: albums.length,
      totalPages: 1,
    );
  }

  @override
  Future<StorageTracksList> getTracks({
    int page = 1,
    int pageSize = 20,
    String? query,
    int? authorId,
    int? albumId,
  }) async {
    final normalizedQuery = query?.trim().toLowerCase();
    final items = tracksById.values.where((track) {
      final matchesQuery =
          normalizedQuery == null ||
          normalizedQuery.isEmpty ||
          track.name.toLowerCase().contains(normalizedQuery) ||
          '${track.id}'.contains(normalizedQuery);
      final matchesAlbum = albumId == null || track.albumId == albumId;
      final matchesAuthor =
          authorId == null ||
          track.authors.any((author) => author.id == authorId);
      return matchesQuery && matchesAlbum && matchesAuthor;
    }).toList();
    return StorageTracksList(
      tracks: items,
      page: page,
      pageSize: pageSize,
      totalItems: items.length,
      totalPages: 1,
    );
  }

  @override
  Future<Track> getTrack(int id) async {
    final track = tracksById[id];
    if (track == null) {
      throw StateError('Track $id was not configured in the fake storage.');
    }
    return track;
  }

  @override
  Future<Author> createAuthor(Author author) async {
    return Author(id: 999, currentName: author.currentName);
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeYouTubeImportRepository implements YouTubeImportRepository {
  _FakeYouTubeImportRepository({
    this.currentSession,
    this.startSessionResponse,
    this.skipCurrentResponse,
    this.addCurrentResponse,
    this.attachCurrentResponse,
  });

  YouTubeImportSession? currentSession;
  YouTubeImportSession? startSessionResponse;
  YouTubeImportSession? skipCurrentResponse;
  YouTubeImportAddResponse? addCurrentResponse;
  YouTubeImportAddResponse? attachCurrentResponse;

  String? lastStartUrl;
  DateTime? lastStartReleaseDateCutoff;
  bool? lastStartReplaceExisting;
  String? lastCreateName;
  List<int>? lastCreateAuthorIds;
  int? lastCreateAlbumId;
  int? lastCreateAlbumOrder;
  int? lastAttachTrackId;
  int skipCount = 0;
  int cancelCount = 0;

  @override
  Future<YouTubeImportSession?> getCurrentSession() async => currentSession;

  @override
  Future<YouTubeImportSession> startSession({
    required String url,
    DateTime? releaseDateCutoff,
    bool replaceExisting = false,
  }) async {
    lastStartUrl = url;
    lastStartReleaseDateCutoff = releaseDateCutoff;
    lastStartReplaceExisting = replaceExisting;
    currentSession = startSessionResponse;
    return startSessionResponse ?? _buildSession();
  }

  @override
  Future<YouTubeImportSession> skipCurrent() async {
    skipCount += 1;
    currentSession = skipCurrentResponse;
    return skipCurrentResponse ?? _buildSession();
  }

  @override
  Future<YouTubeImportAddResponse> addCurrentAsNew({
    required String name,
    required List<int> authorIds,
    required int albumId,
    required int albumOrder,
  }) async {
    lastCreateName = name;
    lastCreateAuthorIds = authorIds;
    lastCreateAlbumId = albumId;
    lastCreateAlbumOrder = albumOrder;
    currentSession = addCurrentResponse?.session;
    return addCurrentResponse ?? _buildAddResponse();
  }

  @override
  Future<YouTubeImportAddResponse> attachCurrent({required int trackId}) async {
    lastAttachTrackId = trackId;
    currentSession = attachCurrentResponse?.session;
    return attachCurrentResponse ?? _buildAddResponse(trackId: trackId);
  }

  @override
  Future<void> cancelCurrentSession() async {
    cancelCount += 1;
    currentSession = null;
  }
}

class _FakeTelegramImportRepository implements TelegramImportRepository {
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
