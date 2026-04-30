import 'package:esketit_music_console/esketit_rest_api/youtube/youtube_cookies_models.dart';

abstract class YouTubeCookiesRepository {
  Future<YouTubeCookiesStatus> getStatus();

  Future<YouTubeCookiesStatus> uploadCookies({
    required String fileName,
    required List<int> bytes,
  });

  Future<void> deleteCookies();
}
