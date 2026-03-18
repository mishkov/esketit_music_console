import 'package:esketit_music_console/esketit_rest_api/http_response.dart';

abstract class HttpClient {
  Future<HttpResponse> get(String path, {Map<String, String>? headers});

  Future<HttpResponse> post(
    String path, {
    Map<String, String>? headers,
    Object? body,
  });

  Future<HttpResponse> put(
    String path, {
    Map<String, String>? headers,
    Object? body,
  });

  Future<HttpResponse> delete(String path, {Map<String, String>? headers});

  Future<HttpResponse> postMultipart(
    String path, {
    Map<String, String>? headers,
    required String fieldName,
    required String fileName,
    required List<int> bytes,
  });
}
