import 'package:equatable/equatable.dart';
import 'package:esketit_music_console/domain/album.dart';

class StorageAlbumsList extends Equatable {
  const StorageAlbumsList({
    required this.albums,
    required this.page,
    required this.pageSize,
    required this.totalItems,
    required this.totalPages,
  });

  final List<Album> albums;
  final int page;
  final int pageSize;
  final int totalItems;
  final int totalPages;

  @override
  List<Object> get props => [albums, page, pageSize, totalItems, totalPages];
}
