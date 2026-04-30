import 'package:esketit_music_console/esketit_rest_api/youtube/youtube_import_models.dart';

abstract class YouTubeImportRepository {
  Future<YouTubeImportSession?> getCurrentSession();

  Future<YouTubeImportSession> startSession({
    required String url,
    DateTime? releaseDateCutoff,
    bool replaceExisting = false,
  });

  Future<YouTubeImportSession> skipCurrent();

  Future<YouTubeImportAddResponse> addCurrentAsNew({
    required String name,
    required List<int> authorIds,
    required int albumId,
    required int albumOrder,
  });

  Future<YouTubeImportAddResponse> attachCurrent({required int trackId});

  Future<void> cancelCurrentSession();
}
