import 'package:esketit_music_console/domain/album.dart';
import 'package:esketit_music_console/domain/access_control.dart';
import 'package:esketit_music_console/domain/auth/app_user.dart';
import 'package:esketit_music_console/domain/auth/auth_session.dart';
import 'package:esketit_music_console/domain/author.dart';
import 'package:esketit_music_console/domain/track.dart';
import 'package:esketit_music_console/firebase/track/storage_file.dart';
import 'package:esketit_music_console/main.dart';
import 'package:esketit_music_console/use_case/auth/auth_repository.dart';
import 'package:esketit_music_console/use_case/auth/bloc/auth_bloc.dart';
import 'package:esketit_music_console/use_case/track/storage/storage_albums_list.dart';
import 'package:esketit_music_console/use_case/track/storage/storage_tracks_list.dart';
import 'package:esketit_music_console/use_case/track/storage/tracks_storage.dart';
import 'package:esketit_music_console/use_case/track/tracks_list/bloc/track_list_bloc.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows Access Control only with the management permission', (
    tester,
  ) async {
    await _pumpMainShell(
      tester,
      size: const Size(1000, 800),
      authSession: _authSession(canManageAccessControl: true),
    );
    expect(find.text('Access Control'), findsOneWidget);

    await _pumpMainShell(
      tester,
      size: const Size(1000, 800),
      authSession: _authSession(canManageAccessControl: false),
    );
    expect(find.text('Access Control'), findsNothing);
  });

  testWidgets('shows catalog submissions only with a relevant permission', (
    tester,
  ) async {
    await _pumpMainShell(
      tester,
      size: const Size(1000, 800),
      authSession: _authSession(
        canManageAccessControl: false,
        catalogPermission: 'catalog_submissions.read_own',
      ),
    );
    expect(find.text('Catalog submissions'), findsOneWidget);

    await _pumpMainShell(
      tester,
      size: const Size(1000, 800),
      authSession: _authSession(canManageAccessControl: false),
    );
    expect(find.text('Catalog submissions'), findsNothing);
  });

  testWidgets('applies app bar search only when Enter is pressed', (
    tester,
  ) async {
    final harness = await _pumpMainShell(tester, size: const Size(1000, 800));

    expect(find.byKey(const ValueKey('track-search-field')), findsOneWidget);
    expect(find.textContaining('Items:'), findsNothing);
    expect(find.textContaining('Found '), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('track-search-field')),
      'needle',
    );
    await tester.pump();
    expect(harness.storage.requestedQueries, [null]);

    final searchCompleted = harness.bloc.stream.firstWhere(
      (state) => !state.isLoading && state.query == 'needle',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await searchCompleted;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(harness.storage.requestedQueries, [null, 'needle']);
    expect(find.text('Found 3 items'), findsOneWidget);
  });

  testWidgets('shows album covers and only author names in track subtitles', (
    tester,
  ) async {
    await _pumpMainShell(tester, size: const Size(1000, 800));

    expect(find.byType(Image), findsNWidgets(3));
    final firstCover = tester.widget<Image>(find.byType(Image).first);
    expect(
      (firstCover.image as NetworkImage).url,
      'https://example.com/covers/test-cover.jpg',
    );
    expect(find.text('Test Author'), findsNWidgets(3));
    expect(find.textContaining('Authors:'), findsNothing);
    expect(find.textContaining('File:'), findsNothing);
    expect(find.textContaining('.mp3'), findsNothing);
  });

  testWidgets('opens desktop filters in a dialog and indicates filters', (
    tester,
  ) async {
    final harness = await _pumpMainShell(
      tester,
      size: const Size(1000, 800),
      initialTrackListState: const TrackListState(tracks: [], authorId: 7),
    );
    var badge = tester.widget<Badge>(
      find.byKey(const ValueKey('track-filter-badge')),
    );
    expect(badge.isLabelVisible, isTrue);

    await tester.tap(find.byTooltip('Filter tracks'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('Filter tracks'), findsOneWidget);

    final filterCompleted = harness.bloc.stream.firstWhere(
      (state) => !state.isLoading && state.authorId == null,
    );
    await tester.tap(find.widgetWithText(TextButton, 'Clear'));
    await filterCompleted;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    badge = tester.widget<Badge>(
      find.byKey(const ValueKey('track-filter-badge')),
    );
    expect(badge.isLabelVisible, isFalse);
    expect(harness.storage.requestedAuthorIds.last, isNull);
    expect(find.text('Found 3 items'), findsOneWidget);
  });

  testWidgets('opens compact filters in a bottom sheet', (tester) async {
    await _pumpMainShell(tester, size: const Size(400, 800));

    await tester.tap(find.byTooltip('Filter tracks'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('Filter tracks'), findsOneWidget);
  });

  testWidgets('refreshes with top overscroll on desktop mouse input', (
    tester,
  ) async {
    final harness = await _pumpMainShell(tester, size: const Size(1000, 800));

    expect(find.byTooltip('Reload tracks'), findsNothing);
    final requestCount = harness.storage.requestedQueries.length;

    await _pullToRefresh(tester, PointerDeviceKind.mouse);

    expect(harness.storage.requestedQueries, hasLength(requestCount + 1));
  });

  testWidgets('refreshes with top overscroll on compact touch input', (
    tester,
  ) async {
    final harness = await _pumpMainShell(tester, size: const Size(400, 800));
    final requestCount = harness.storage.requestedQueries.length;

    await _pullToRefresh(tester, PointerDeviceKind.touch);

    expect(harness.storage.requestedQueries, hasLength(requestCount + 1));
  });
}

Future<void> _pullToRefresh(
  WidgetTester tester,
  PointerDeviceKind pointerDeviceKind,
) async {
  await tester.fling(
    find.text('Track 1'),
    const Offset(0, 320),
    1000,
    deviceKind: pointerDeviceKind,
  );
  await tester.pump();
  await tester.pumpAndSettle();
}

Future<_TestHarness> _pumpMainShell(
  WidgetTester tester, {
  required Size size,
  TrackListState initialTrackListState = const TrackListState(tracks: []),
  AuthSession? authSession,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final storage = _FakeTracksStorage();
  final trackListBloc = TrackListBloc(initialTrackListState, storage: storage);
  final authBloc = AuthBloc(
    authRepository: _FakeAuthRepository(session: authSession),
  );
  if (authSession != null) {
    authBloc.add(const AuthSessionRestoreRequested());
  }
  addTearDown(trackListBloc.close);
  addTearDown(authBloc.close);

  await tester.pumpWidget(
    RepositoryProvider<TracksStorage>.value(
      value: storage,
      child: MultiBlocProvider(
        providers: [
          BlocProvider<TrackListBloc>.value(value: trackListBloc),
          BlocProvider<AuthBloc>.value(value: authBloc),
        ],
        child: const MaterialApp(home: MainShell()),
      ),
    ),
  );
  await tester.pumpAndSettle();

  return _TestHarness(bloc: trackListBloc, storage: storage);
}

class _TestHarness {
  const _TestHarness({required this.bloc, required this.storage});

  final TrackListBloc bloc;
  final _FakeTracksStorage storage;
}

class _FakeAuthRepository extends Fake implements AuthRepository {
  _FakeAuthRepository({this.session});

  final AuthSession? session;

  @override
  Future<AuthSession?> restoreSession() async => session;
}

AuthSession _authSession({
  required bool canManageAccessControl,
  String? catalogPermission,
}) {
  return AuthSession(
    user: AppUser(
      id: 1,
      email: 'user@example.com',
      createdAt: DateTime.utc(2026, 1, 1),
      roles: const [],
      permissions: [
        if (canManageAccessControl)
          AccessPermission(
            id: 1,
            code: 'access_control.manage',
            description: 'Manage access control',
            createdAt: DateTime.utc(2026, 1, 1),
          ),
        if (catalogPermission != null)
          AccessPermission(
            id: 2,
            code: catalogPermission,
            description: 'Catalog submissions',
            createdAt: DateTime.utc(2026, 1, 1),
          ),
      ],
    ),
    accessToken: 'token',
    accessTokenExpiresAt: DateTime.utc(2099, 1, 1),
    refreshToken: 'refresh',
    refreshTokenExpiresAt: DateTime.utc(2099, 1, 2),
  );
}

class _FakeTracksStorage extends Fake implements TracksStorage {
  final List<String?> requestedQueries = [];
  final List<int?> requestedAuthorIds = [];

  @override
  Future<List<Author>> getAuthors() async => [
    const Author(id: 7, currentName: 'Test Author'),
  ];

  @override
  Future<StorageAlbumsList> getAlbumsList({
    int page = 1,
    int pageSize = 100,
    int? authorId,
    String? query,
    bool? isPublished,
  }) async {
    return StorageAlbumsList(
      albums: [
        Album(
          id: 1,
          title: 'Test Album',
          coverImagePath: 'covers/test-cover.jpg',
          authors: const [],
          releaseDate: DateTime.utc(2024),
          isPublished: true,
          trackIds: const [],
          additionalInfo: const [],
        ),
      ],
      page: 1,
      pageSize: pageSize,
      totalItems: 1,
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
    requestedQueries.add(query);
    requestedAuthorIds.add(authorId);
    return StorageTracksList(
      tracks: [_track(1), _track(2), _track(3)],
      page: 1,
      pageSize: pageSize,
      totalItems: 3,
      totalPages: 1,
    );
  }

  @override
  String resolveAlbumCoverUrl(String coverImagePath) {
    return 'https://example.com/$coverImagePath';
  }
}

Track _track(int id) {
  return Track(
    id: id,
    name: 'Track $id',
    authors: const [Author(id: 7, currentName: 'Test Author')],
    albumId: 1,
    additionalInfo: const [],
    sourceMetadata: const [],
    file: StorageFile(
      name: 'track-$id.mp3',
      storagePath: 'songs/track-$id.mp3',
      downloadUrl: 'https://example.com/track-$id.mp3',
    ),
  );
}
