import 'package:esketit_music_console/domain/track.dart';
import 'package:esketit_music_console/use_case/track/storage/storage_tracks_list.dart';

abstract class TracksStorage {
  Future<void> putTrack(Track track);

  Future<StorageTracksList> getTracks();
}
