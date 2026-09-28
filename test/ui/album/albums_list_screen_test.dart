import 'package:esketit_music_console/domain/album.dart';
import 'package:esketit_music_console/domain/author.dart';
import 'package:esketit_music_console/domain/catalog_publication_status.dart';
import 'package:esketit_music_console/ui/album/albums_list_screen.dart';
import 'package:esketit_music_console/use_case/track/storage/storage_albums_list.dart';
import 'package:esketit_music_console/use_case/track/storage/tracks_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders cover, tags, and bold author text on album cards', (
    tester,
  ) async {
    final tracksStorage = _FakeTracksStorage(
      pages: {
        1: StorageAlbumsList(
          albums: [
            Album(
              id: 1,
              title: 'Test Album',
              coverImagePath: 'cover.jpg',
              authors: const [Author(id: 7, currentName: 'Test Author')],
              releaseDate: DateTime.utc(2024, 1, 1),
              isPublished: true,
              trackIds: const [1, 2, 3],
              additionalInfo: const [],
            ),
          ],
          page: 1,
          pageSize: 20,
          totalItems: 1,
          totalPages: 1,
        ),
      },
    );

    await tester.pumpWidget(
      RepositoryProvider<TracksStorage>.value(
        value: tracksStorage,
        child: const MaterialApp(home: Scaffold(body: AlbumsListScreen())),
      ),
    );
    await tester.pump();

    expect(find.text('Test Album'), findsOneWidget);
    expect(find.text('Published'), findsOneWidget);
    expect(find.text('3 tracks'), findsOneWidget);
    expect(find.text('2024-01-01'), findsOneWidget);

    final richText = tester
        .widgetList<RichText>(find.byType(RichText))
        .firstWhere(
          (widget) => widget.text.toPlainText() == 'Author: Test Author',
        );
    final spans = (richText.text as TextSpan).children!;
    expect(richText.text.toPlainText(), 'Author: Test Author');
    expect((spans[1] as TextSpan).style?.fontWeight, FontWeight.bold);
    expect(tracksStorage.resolvedCoverPaths, ['cover.jpg']);
  });

  testWidgets('loads the selected albums page from the page selector', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final tracksStorage = _FakeTracksStorage(
      pages: {
        1: _buildAlbumsPage(
          page: 1,
          totalPages: 3,
          albumTitle: 'Page One Album',
        ),
        2: _buildAlbumsPage(
          page: 2,
          totalPages: 3,
          albumTitle: 'Page Two Album',
        ),
      },
    );

    await tester.pumpWidget(
      RepositoryProvider<TracksStorage>.value(
        value: tracksStorage,
        child: const MaterialApp(home: Scaffold(body: AlbumsListScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Page One Album'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('albums-page-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2').last);
    await tester.pumpAndSettle();

    expect(tracksStorage.requestedPages, [1, 2]);
    expect(find.text('Page Two Album'), findsOneWidget);
    expect(find.text('Page One Album'), findsNothing);
  });

  testWidgets('shows pending publication status in the existing album list', (
    tester,
  ) async {
    final tracksStorage = _FakeTracksStorage(
      pages: {
        1: StorageAlbumsList(
          albums: [
            Album(
              id: 1,
              title: 'Pending Album',
              coverImagePath: '',
              authors: const [],
              releaseDate: DateTime.utc(2026),
              isPublished: true,
              trackIds: const [],
              additionalInfo: const [],
              publicationStatus: CatalogPublicationStatus.pendingReview,
              requestedByUserId: 7,
            ),
          ],
          page: 1,
          pageSize: 20,
          totalItems: 1,
          totalPages: 1,
        ),
      },
    );

    await tester.pumpWidget(
      RepositoryProvider<TracksStorage>.value(
        value: tracksStorage,
        child: const MaterialApp(home: Scaffold(body: AlbumsListScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pending review'), findsOneWidget);
  });
}

class _FakeTracksStorage extends Fake implements TracksStorage {
  _FakeTracksStorage({required this.pages});

  final Map<int, StorageAlbumsList> pages;
  final List<int> requestedPages = [];
  final List<String> resolvedCoverPaths = [];

  @override
  Future<StorageAlbumsList> getAlbumsList({
    int page = 1,
    int pageSize = 100,
    int? authorId,
    String? query,
    bool? isPublished,
  }) async {
    requestedPages.add(page);
    return pages[page] ?? pages.values.last;
  }

  @override
  Future<List<Author>> getAuthors() async => const [];

  @override
  String resolveAlbumCoverUrl(String coverImagePath) {
    resolvedCoverPaths.add(coverImagePath);
    return coverImagePath;
  }
}

StorageAlbumsList _buildAlbumsPage({
  required int page,
  required int totalPages,
  required String albumTitle,
}) {
  return StorageAlbumsList(
    albums: [
      Album(
        id: page,
        title: albumTitle,
        coverImagePath: '',
        authors: const [],
        releaseDate: DateTime.utc(2024, 1, 1),
        isPublished: true,
        trackIds: const [1],
        additionalInfo: const [],
      ),
    ],
    page: page,
    pageSize: 20,
    totalItems: totalPages * 20,
    totalPages: totalPages,
  );
}
