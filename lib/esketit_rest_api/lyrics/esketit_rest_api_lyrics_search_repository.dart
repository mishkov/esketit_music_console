import 'dart:convert';

import 'package:esketit_music_console/domain/lyrics_search_candidate.dart';
import 'package:esketit_music_console/domain/track_lyrics.dart';
import 'package:esketit_music_console/errors/app_error.dart';
import 'package:esketit_music_console/errors/http_app_error.dart';
import 'package:esketit_music_console/esketit_rest_api/http_client.dart';
import 'package:esketit_music_console/esketit_rest_api/http_response.dart';
import 'package:esketit_music_console/use_case/lyrics/lyrics_search_repository.dart';

class EsketitRestApiLyricsSearchRepository implements LyricsSearchRepository {
  const EsketitRestApiLyricsSearchRepository({required HttpClient httpClient})
    : _httpClient = httpClient;

  final HttpClient _httpClient;

  @override
  Future<List<LyricsSearchCandidate>> search({
    required int trackId,
    required String trackName,
    required List<String> artistNames,
    required String albumName,
    int? durationMs,
  }) async {
    final path = '/tracks/$trackId/lyrics/search';
    final response = await _httpClient.post(
      path,
      body: {
        'trackName': trackName.trim(),
        'artistNames': artistNames.map((name) => name.trim()).toList(),
        'albumName': albumName.trim(),
        'durationMs': ?durationMs,
      },
    );
    _throwIfUnexpectedStatus(response, path: path);

    final body = _decodeJsonMap(response.response, path: path);
    final rawItems = body['items'];
    if (rawItems is! List<dynamic>) {
      throw AppError(
        'Expected items array response for $path',
        cause: rawItems,
      );
    }

    return rawItems.map((item) {
      if (item is! Map<String, dynamic>) {
        throw AppError(
          'Expected lyrics candidate object for $path',
          cause: item,
        );
      }
      return _parseCandidate(item, path: path);
    }).toList();
  }

  LyricsSearchCandidate _parseCandidate(
    Map<String, dynamic> json, {
    required String path,
  }) {
    final providerId = (json['providerId'] as num?)?.toInt();
    if (providerId == null || providerId <= 0) {
      throw AppError(
        'Invalid lyrics candidate providerId for $path',
        cause: json,
      );
    }

    final rawSyncedLines = json['syncedLines'];
    if (rawSyncedLines is! List<dynamic>) {
      throw AppError(
        'Expected syncedLines array for lyrics candidate',
        cause: json,
      );
    }

    final syncedLines = rawSyncedLines.map((item) {
      if (item is! Map<String, dynamic>) {
        throw AppError('Invalid synced lyrics line for $path', cause: item);
      }
      final startMs = (item['startMs'] as num?)?.toInt();
      final text = item['text'] as String?;
      if (startMs == null ||
          startMs < 0 ||
          text == null ||
          text.trim().isEmpty) {
        throw AppError('Invalid synced lyrics line for $path', cause: item);
      }
      return TrackLyricsLine(
        startMs: startMs,
        endMs: (item['endMs'] as num?)?.toInt(),
        text: text,
      );
    }).toList();

    return LyricsSearchCandidate(
      provider: (json['provider'] as String?) ?? '',
      providerId: providerId,
      source: (json['source'] as String?) ?? '',
      trackName: (json['trackName'] as String?) ?? '',
      artistName: (json['artistName'] as String?) ?? '',
      albumName: (json['albumName'] as String?) ?? '',
      durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
      instrumental: json['instrumental'] as bool? ?? false,
      plainText: json['plainText'] as String?,
      syncedLines: syncedLines,
    );
  }

  Map<String, dynamic> _decodeJsonMap(Object? body, {required String path}) {
    final decoded = body is String ? jsonDecode(body) : body;
    if (decoded is! Map<String, dynamic>) {
      throw AppError('Expected JSON object response for $path', cause: decoded);
    }
    return decoded;
  }

  void _throwIfUnexpectedStatus(HttpResponse response, {required String path}) {
    if (response.statusCode != 200) {
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
    return text.isEmpty ? 'Lyrics search failed' : text;
  }
}
