import 'package:esketit_music_console/domain/track.dart';
import 'package:esketit_music_console/firebase/track/storage_file.dart';
import 'package:esketit_music_console/use_case/track/storage/storage_tracks_list.dart';
import 'package:esketit_music_console/use_case/track/storage/tracks_storage.dart';
import 'package:esketit_music_console/use_case/track/tracks_list/bloc/track_list_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loads and appends tracks in fixed batches of 20', () async {
    final storage = _FakeTracksStorage(
      pages: {
        1: _tracksPage(page: 1, trackIds: [1, 2], totalPages: 2),
        2: _tracksPage(page: 2, trackIds: [3], totalPages: 2),
      },
    );
    final bloc = TrackListBloc(
      const TrackListState(tracks: []),
      storage: storage,
    );
    addTearDown(bloc.close);

    final firstPageLoaded = bloc.stream.firstWhere(
      (state) => !state.isLoading && state.tracks.isNotEmpty,
    );
    bloc.add(const LoadTracks());
    await firstPageLoaded;

    final secondPageLoaded = bloc.stream.firstWhere(
      (state) => !state.isLoadingMore && state.page == 2,
    );
    bloc.add(const LoadMoreTracks());
    final state = await secondPageLoaded;

    expect(state.tracks.map((track) => track.id), [1, 2, 3]);
    expect(storage.requestedPages, [1, 2]);
    expect(storage.requestedPageSizes, everyElement(20));
  });

  test('a new load replaces appended tracks with the first page', () async {
    final storage = _FakeTracksStorage(
      pages: {
        1: _tracksPage(page: 1, trackIds: [1], totalPages: 2),
        2: _tracksPage(page: 2, trackIds: [2], totalPages: 2),
      },
      filteredPage: _tracksPage(page: 1, trackIds: [9], totalPages: 1),
    );
    final bloc = TrackListBloc(
      const TrackListState(tracks: []),
      storage: storage,
    );
    addTearDown(bloc.close);

    final firstPageLoaded = bloc.stream.firstWhere(
      (state) => !state.isLoading && state.tracks.isNotEmpty,
    );
    bloc.add(const LoadTracks());
    await firstPageLoaded;

    final secondPageLoaded = bloc.stream.firstWhere(
      (state) => !state.isLoadingMore && state.page == 2,
    );
    bloc.add(const LoadMoreTracks());
    await secondPageLoaded;

    final filteredPageLoaded = bloc.stream.firstWhere(
      (state) => !state.isLoading && state.query == 'filtered',
    );
    bloc.add(const LoadTracks(query: 'filtered'));
    final state = await filteredPageLoaded;

    expect(state.tracks.map((track) => track.id), [9]);
    expect(state.page, 1);
    expect(storage.requestedPages, [1, 2, 1]);
    expect(storage.requestedPageSizes, everyElement(20));
  });
}

class _FakeTracksStorage extends Fake implements TracksStorage {
  _FakeTracksStorage({required this.pages, this.filteredPage});

  final Map<int, StorageTracksList> pages;
  final StorageTracksList? filteredPage;
  final List<int> requestedPages = [];
  final List<int> requestedPageSizes = [];

  @override
  Future<StorageTracksList> getTracks({
    int page = 1,
    int pageSize = 20,
    String? query,
    int? authorId,
    int? albumId,
  }) async {
    requestedPages.add(page);
    requestedPageSizes.add(pageSize);
    if (query == 'filtered' && filteredPage != null) {
      return filteredPage!;
    }
    return pages[page]!;
  }
}

StorageTracksList _tracksPage({
  required int page,
  required List<int> trackIds,
  required int totalPages,
}) {
  return StorageTracksList(
    tracks: trackIds.map(_track).toList(),
    page: page,
    pageSize: 20,
    totalItems: totalPages == 1 ? trackIds.length : 3,
    totalPages: totalPages,
  );
}

Track _track(int id) {
  return Track(
    id: id,
    name: 'Track $id',
    authors: const [],
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
