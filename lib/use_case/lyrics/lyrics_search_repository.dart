import 'package:esketit_music_console/domain/lyrics_search_candidate.dart';

abstract class LyricsSearchRepository {
  Future<List<LyricsSearchCandidate>> search({
    required int trackId,
    required String trackName,
    required List<String> artistNames,
    required String albumName,
    int? durationMs,
  });
}
