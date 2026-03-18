import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:esketit_music_console/domain/track.dart';
import 'package:esketit_music_console/use_case/track/storage/tracks_storage.dart';

sealed class TrackListEvent extends Equatable {
  const TrackListEvent();
}

class LoadTracks extends TrackListEvent {
  const LoadTracks();

  @override
  List<Object?> get props => [];
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
      emit(
        state.copyWith(
          isLoading: true,
          errorMessage: null,
          setErrorMessage: true,
        ),
      );
      try {
        emit(
          state.copyWith(
            tracks: (await _storage.getTracks()).tracks,
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
        emit(
          state.copyWith(
            tracks: (await _storage.getTracks()).tracks,
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
  final bool isLoading;
  final String? errorMessage;

  const TrackListState({
    required this.tracks,
    this.isLoading = false,
    this.errorMessage,
  });

  @override
  List<Object?> get props => [tracks, isLoading, errorMessage];

  TrackListState copyWith({
    List<Track>? tracks,
    bool? isLoading,
    String? errorMessage,
    bool setErrorMessage = false,
  }) {
    return TrackListState(
      tracks: tracks ?? this.tracks,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: setErrorMessage ? errorMessage : this.errorMessage,
    );
  }
}
