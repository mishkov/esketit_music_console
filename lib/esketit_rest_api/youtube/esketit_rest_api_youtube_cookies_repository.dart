import 'dart:convert';

import 'package:esketit_music_console/errors/app_error.dart';
import 'package:esketit_music_console/errors/http_app_error.dart';
import 'package:esketit_music_console/esketit_rest_api/http_client.dart';
import 'package:esketit_music_console/esketit_rest_api/http_response.dart';
import 'package:esketit_music_console/esketit_rest_api/youtube/youtube_cookies_models.dart';
import 'package:esketit_music_console/use_case/youtube/youtube_cookies_repository.dart';

class EsketitRestApiYouTubeCookiesRepository
    implements YouTubeCookiesRepository {
  EsketitRestApiYouTubeCookiesRepository({required HttpClient httpClient})
    : _httpClient = httpClient;

  final HttpClient _httpClient;

  @override
  Future<YouTubeCookiesStatus> getStatus() async {
    final response = await _httpClient.get('/youtube/cookies/status');
    _throwIfUnexpectedStatus(response, path: '/youtube/cookies/status');
    return YouTubeCookiesStatus.fromJson(
      _decodeJsonMap(response.response, path: '/youtube/cookies/status'),
    );
  }

  @override
  Future<YouTubeCookiesStatus> uploadCookies({
    required String fileName,
    required List<int> bytes,
  }) async {
    final response = await _httpClient.postMultipart(
      '/youtube/cookies',
      fieldName: 'file',
      fileName: fileName,
      bytes: bytes,
    );
    _throwIfUnexpectedStatus(
      response,
      path: '/youtube/cookies',
      expectedStatusCodes: {200, 201},
    );
    return YouTubeCookiesStatus.fromJson(
      _decodeJsonMap(response.response, path: '/youtube/cookies'),
    );
  }

  @override
  Future<void> deleteCookies() async {
    final response = await _httpClient.delete('/youtube/cookies');
    _throwIfUnexpectedStatus(
      response,
      path: '/youtube/cookies',
      expectedStatusCodes: {200, 204},
    );
  }

  Map<String, dynamic> _decodeJsonMap(Object? body, {required String path}) {
    final decoded = body is String ? jsonDecode(body) : body;
    if (decoded is! Map<String, dynamic>) {
      throw AppError('Expected JSON object response for $path', cause: decoded);
    }
    return decoded;
  }

  void _throwIfUnexpectedStatus(
    HttpResponse response, {
    required String path,
    Set<int> expectedStatusCodes = const {200},
  }) {
    if (!expectedStatusCodes.contains(response.statusCode)) {
      throw HttpAppError(
        message: _errorMessageFromBody(response.response),
        path: path,
        statusCode: response.statusCode,
        responseBody: response.response,
      );
    }
  }

  String _errorMessageFromBody(Object? body) {
    final text = body is String ? body.trim() : '';
    return text.isEmpty ? 'Request failed' : text;
  }
}
