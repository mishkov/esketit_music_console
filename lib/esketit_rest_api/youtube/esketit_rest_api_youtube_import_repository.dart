import 'dart:convert';

import 'package:esketit_music_console/errors/app_error.dart';
import 'package:esketit_music_console/errors/http_app_error.dart';
import 'package:esketit_music_console/esketit_rest_api/http_client.dart';
import 'package:esketit_music_console/esketit_rest_api/http_response.dart';
import 'package:esketit_music_console/esketit_rest_api/youtube/youtube_import_models.dart';
import 'package:esketit_music_console/use_case/youtube/youtube_import_repository.dart';

class EsketitRestApiYouTubeImportRepository implements YouTubeImportRepository {
  EsketitRestApiYouTubeImportRepository({
    required HttpClient httpClient,
    required Uri baseUri,
  }) : _httpClient = httpClient,
       _baseUri = baseUri;

  final HttpClient _httpClient;
  final Uri _baseUri;

  @override
  Future<YouTubeImportSession?> getCurrentSession() async {
    final response = await _httpClient.get('/youtube/import-sessions/current');
    if (response.statusCode == 404) {
      return null;
    }
    _throwIfUnexpectedStatus(
      response,
      path: '/youtube/import-sessions/current',
    );
    return YouTubeImportSession.fromJson(
      _decodeJsonMap(
        response.response,
        path: '/youtube/import-sessions/current',
      ),
    );
  }

  @override
  Future<YouTubeImportSession> startSession({
    required String url,
    DateTime? releaseDateCutoff,
    bool replaceExisting = false,
  }) async {
    final body = <String, dynamic>{
      'url': url.trim(),
      'replaceExisting': replaceExisting,
      if (releaseDateCutoff != null)
        'releaseDateCutoff': releaseDateCutoff.toUtc().toIso8601String(),
    };
    final response = await _httpClient.post(
      '/youtube/import-sessions',
      body: body,
    );
    _throwIfUnexpectedStatus(
      response,
      path: '/youtube/import-sessions',
      expectedStatusCodes: {200, 201},
    );
    return YouTubeImportSession.fromJson(
      _decodeJsonMap(response.response, path: '/youtube/import-sessions'),
    );
  }

  @override
  Future<YouTubeImportSession> skipCurrent() async {
    final response = await _httpClient.post(
      '/youtube/import-sessions/current/skip',
    );
    _throwIfUnexpectedStatus(
      response,
      path: '/youtube/import-sessions/current/skip',
    );
    return YouTubeImportSession.fromJson(
      _decodeJsonMap(
        response.response,
        path: '/youtube/import-sessions/current/skip',
      ),
    );
  }

  @override
  Future<YouTubeImportAddResponse> addCurrentAsNew({
    required String name,
    required List<int> authorIds,
    required int albumId,
    required int albumOrder,
  }) {
    return _addCurrent(
      body: {
        'mode': 'create',
        'name': name.trim(),
        'authorIds': authorIds,
        'albumId': albumId,
        'albumOrder': albumOrder,
      },
    );
  }

  @override
  Future<YouTubeImportAddResponse> attachCurrent({required int trackId}) {
    return _addCurrent(body: {'mode': 'attach', 'trackId': trackId});
  }

  Future<YouTubeImportAddResponse> _addCurrent({
    required Map<String, dynamic> body,
  }) async {
    final response = await _httpClient.post(
      '/youtube/import-sessions/current/add',
      body: body,
    );
    _throwIfUnexpectedStatus(
      response,
      path: '/youtube/import-sessions/current/add',
    );
    return YouTubeImportAddResponse.fromJson(
      _decodeJsonMap(
        response.response,
        path: '/youtube/import-sessions/current/add',
      ),
      baseUri: _baseUri,
    );
  }

  @override
  Future<void> cancelCurrentSession() async {
    final response = await _httpClient.delete(
      '/youtube/import-sessions/current',
    );
    _throwIfUnexpectedStatus(
      response,
      path: '/youtube/import-sessions/current',
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
