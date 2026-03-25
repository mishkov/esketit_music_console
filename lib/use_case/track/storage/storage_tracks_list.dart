import 'package:equatable/equatable.dart';
import 'package:esketit_music_console/domain/track.dart';

class StorageTracksList extends Equatable {
  final List<Track> tracks;
  final int page;
  final int pageSize;
  final int totalItems;
  final int totalPages;

  const StorageTracksList({
    required this.tracks,
    required this.page,
    required this.pageSize,
    required this.totalItems,
    required this.totalPages,
  });

  @override
  List<Object> get props => [tracks, page, pageSize, totalItems, totalPages];
}
