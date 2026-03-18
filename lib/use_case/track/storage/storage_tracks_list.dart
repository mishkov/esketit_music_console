import 'package:equatable/equatable.dart';
import 'package:esketit_music_console/domain/track.dart';

class StorageTracksList extends Equatable {
  final List<Track> tracks;

  const StorageTracksList({required this.tracks});

  @override
  List<Object> get props => [tracks];
}
