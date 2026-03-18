import 'package:esketit_music_console/domain/author.dart';
import 'package:esketit_music_console/domain/track.dart';
import 'package:esketit_music_console/use_case/track/storage/storage_tracks_list.dart';

abstract class TracksStorage {
  Future<void> putTrack(Track track);

  Future<StorageTracksList> getTracks();

  Future<List<Author>> getAuthors();

  Future<Author> getAuthor(int id);

  Future<Author> updateAuthor(Author author);

  Future<void> deleteAuthor(int id);
}
