import 'package:esketit_music_console/esketit_rest_api/http_response.dart';

abstract class HttpClient {
  Future<HttpResponse> get(String path, {Map<String, String>? headers});

  Future<HttpResponse> post(
    String path, {
    Map<String, String>? headers,
    Object? body,
  });
}
