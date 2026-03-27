import 'package:equatable/equatable.dart';
import 'package:esketit_music_console/domain/track.dart';
import 'package:esketit_music_console/use_case/track/storage/tracks_storage.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

sealed class TrackListEvent extends Equatable {
  const TrackListEvent();
}

class LoadTracks extends TrackListEvent {
  final int? page;
  final int? pageSize;
  final String? query;
  final int? authorId;
  final int? albumId;
  final bool clearQuery;
  final bool clearAuthorId;
  final bool clearAlbumId;

  const LoadTracks({
    this.page,
    this.pageSize,
    this.query,
    this.authorId,
    this.albumId,
    this.clearQuery = false,
    this.clearAuthorId = false,
    this.clearAlbumId = false,
  });

  @override
  List<Object?> get props => [
    page,
    pageSize,
    query,
    authorId,
    albumId,
    clearQuery,
    clearAuthorId,
    clearAlbumId,
  ];
}

class AddTrack extends TrackListEvent {
  final Track track;

  const AddTrack({required this.track});

  @override
  List<Object?> get props => [track];
}

class TrackListBloc extends Bloc<TrackListEvent, TrackListState> {
  final TracksStorage _storage;

  TrackListBloc(super.initialState, {required TracksStorage storage})
    : _storage = storage {
    on<LoadTracks>((event, emit) async {
      final selectedQuery = event.query ?? state.query;
      final query = event.clearQuery ? null : selectedQuery?.trim();
      final normalizedQuery = query == null || query.isEmpty ? null : query;
      final authorId = event.clearAuthorId
          ? null
          : event.authorId ?? state.authorId;
      final albumId = event.clearAlbumId
          ? null
          : event.albumId ?? state.albumId;
      final pageSize = event.pageSize ?? state.pageSize;
      final page = event.page ?? (event.pageSize != null ? 1 : state.page);

      emit(
        state.copyWith(
          isLoading: true,
          errorMessage: null,
          setErrorMessage: true,
          query: normalizedQuery,
          setQuery: true,
          authorId: authorId,
          setAuthorId: true,
          albumId: albumId,
          setAlbumId: true,
          page: page,
          pageSize: pageSize,
        ),
      );
      try {
        final result = await _storage.getTracks(
          page: page,
          pageSize: pageSize,
          query: normalizedQuery,
          authorId: authorId,
          albumId: albumId,
        );
        emit(
          state.copyWith(
            tracks: result.tracks,
            page: result.page,
            pageSize: result.pageSize,
            totalItems: result.totalItems,
            totalPages: result.totalPages,
            isLoading: false,
          ),
        );
      } catch (error, stackTrace) {
        print('$error $stackTrace');
        emit(
          state.copyWith(
            isLoading: false,
            errorMessage: error.toString(),
            setErrorMessage: true,
          ),
        );
      }
    });

    on<AddTrack>((event, emit) async {
      emit(
        state.copyWith(
          isLoading: true,
          errorMessage: null,
          setErrorMessage: true,
        ),
      );
      try {
        await _storage.putTrack(event.track);
        final result = await _storage.getTracks(
          page: state.page,
          pageSize: state.pageSize,
          query: state.query,
          authorId: state.authorId,
          albumId: state.albumId,
        );
        emit(
          state.copyWith(
            tracks: result.tracks,
            page: result.page,
            pageSize: result.pageSize,
            totalItems: result.totalItems,
            totalPages: result.totalPages,
            isLoading: false,
          ),
        );
      } catch (error) {
        emit(
          state.copyWith(
            isLoading: false,
            errorMessage: error.toString(),
            setErrorMessage: true,
          ),
        );
      }
    });
  }
}

class TrackListState extends Equatable {
  final List<Track> tracks;
  final int page;
  final int pageSize;
  final int totalItems;
  final int totalPages;
  final String? query;
  final int? authorId;
  final int? albumId;
  final bool isLoading;
  final String? errorMessage;

  const TrackListState({
    required this.tracks,
    this.page = 1,
    this.pageSize = 20,
    this.totalItems = 0,
    this.totalPages = 0,
    this.query,
    this.authorId,
    this.albumId,
    this.isLoading = false,
    this.errorMessage,
  });

  @override
  List<Object?> get props => [
    tracks,
    page,
    pageSize,
    totalItems,
    totalPages,
    query,
    authorId,
    albumId,
    isLoading,
    errorMessage,
  ];

  TrackListState copyWith({
    List<Track>? tracks,
    int? page,
    int? pageSize,
    int? totalItems,
    int? totalPages,
    String? query,
    bool setQuery = false,
    int? authorId,
    bool setAuthorId = false,
    int? albumId,
    bool setAlbumId = false,
    bool? isLoading,
    String? errorMessage,
    bool setErrorMessage = false,
  }) {
    return TrackListState(
      tracks: tracks ?? this.tracks,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      totalItems: totalItems ?? this.totalItems,
      totalPages: totalPages ?? this.totalPages,
      query: setQuery ? query : this.query,
      authorId: setAuthorId ? authorId : this.authorId,
      albumId: setAlbumId ? albumId : this.albumId,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: setErrorMessage ? errorMessage : this.errorMessage,
    );
  }
}
