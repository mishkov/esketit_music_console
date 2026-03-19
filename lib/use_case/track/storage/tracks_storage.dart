import 'package:esketit_music_console/domain/album.dart';
import 'package:esketit_music_console/domain/author.dart';
import 'package:esketit_music_console/domain/track.dart';
import 'package:esketit_music_console/use_case/track/storage/storage_tracks_list.dart';

abstract class TracksStorage {
  Future<void> putTrack(Track track);

  Future<StorageTracksList> getTracks();

  Future<List<Album>> getAlbums({
    int page,
    int pageSize,
    int? authorId,
    String? query,
    bool? isPublished,
  });

  Future<Album> getAlbum(int id);

  Future<Album> createAlbum(Album album);

  Future<Album> updateAlbum(Album album);

  Future<List<Track>> getAlbumTracks(int albumId);

  Future<void> deleteAlbum(int id);

  Future<String> uploadAlbumCover(Object file);

  Future<List<Author>> getAuthors();

  Future<Author> getAuthor(int id);

  Future<Author> updateAuthor(Author author);

  Future<void> deleteAuthor(int id);
}
