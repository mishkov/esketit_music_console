import 'package:esketit_music_console/domain/track_lyrics.dart';
import 'package:esketit_music_console/esketit_rest_api/http_client.dart';
import 'package:esketit_music_console/esketit_rest_api/http_response.dart';
import 'package:esketit_music_console/esketit_rest_api/track/esketit_rest_api_tracks_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EsketitRestApiTracksStorage lyrics', () {
    test('returns null when lyrics endpoint responds with 404', () async {
      final httpClient = _FakeHttpClient(
        getResponses: {
          '/tracks/7/lyrics': const HttpResponse(statusCode: 404, response: ''),
        },
      );
      final storage = EsketitRestApiTracksStorage(
        authenticatedHttpClient: httpClient,
        baseUri: Uri.parse('http://localhost:8080'),
      );

      final lyrics = await storage.getTrackLyrics(7);

      expect(lyrics, isNull);
    });

    test('serializes plain lyrics requests explicitly', () async {
      final httpClient = _FakeHttpClient(
        putResponses: {
          '/tracks/7/lyrics': const HttpResponse(
            statusCode: 201,
            response: {
              'trackId': 7,
              'type': 'plain',
              'languageCode': 'en',
              'isVerified': true,
              'source': 'artist',
              'plainText': 'Full lyrics here',
              'lines': [],
            },
          ),
        },
      );
      final storage = EsketitRestApiTracksStorage(
        authenticatedHttpClient: httpClient,
        baseUri: Uri.parse('http://localhost:8080'),
      );

      await storage.putTrackLyrics(
        const TrackLyrics(
          trackId: 7,
          type: TrackLyricsType.plain,
          languageCode: 'en',
          isVerified: true,
          source: 'artist',
          plainText: 'Full lyrics here',
        ),
      );

      expect(httpClient.lastPutPath, '/tracks/7/lyrics');
      expect(httpClient.lastPutBody, {
        'type': 'plain',
        'languageCode': 'en',
        'isVerified': true,
        'source': 'artist',
        'plainText': 'Full lyrics here',
      });
    });

    test('serializes synced lyrics requests without plain text', () async {
      final httpClient = _FakeHttpClient(
        putResponses: {
          '/tracks/9/lyrics': const HttpResponse(
            statusCode: 200,
            response: {
              'trackId': 9,
              'type': 'synced',
              'languageCode': 'en',
              'isVerified': false,
              'source': 'artist',
              'plainText': null,
              'lines': [
                {'startMs': 0, 'endMs': 4200, 'text': 'First line'},
              ],
            },
          ),
        },
      );
      final storage = EsketitRestApiTracksStorage(
        authenticatedHttpClient: httpClient,
        baseUri: Uri.parse('http://localhost:8080'),
      );

      await storage.putTrackLyrics(
        const TrackLyrics(
          trackId: 9,
          type: TrackLyricsType.synced,
          languageCode: 'en',
          isVerified: false,
          source: 'artist',
          lines: [TrackLyricsLine(startMs: 0, endMs: 4200, text: 'First line')],
        ),
      );

      expect(httpClient.lastPutBody, {
        'type': 'synced',
        'languageCode': 'en',
        'isVerified': false,
        'source': 'artist',
        'lines': [
          {'startMs': 0, 'endMs': 4200, 'text': 'First line'},
        ],
      });
      expect(
        (httpClient.lastPutBody as Map<String, dynamic>).containsKey(
          'plainText',
        ),
        isFalse,
      );
    });

    test('omits optional language code and source when blank', () async {
      final httpClient = _FakeHttpClient(
        putResponses: {
          '/tracks/11/lyrics': const HttpResponse(
            statusCode: 201,
            response: {
              'trackId': 11,
              'type': 'plain',
              'languageCode': '',
              'isVerified': false,
              'source': '',
              'plainText': 'Lyrics',
              'lines': [],
            },
          ),
        },
      );
      final storage = EsketitRestApiTracksStorage(
        authenticatedHttpClient: httpClient,
        baseUri: Uri.parse('http://localhost:8080'),
      );

      await storage.putTrackLyrics(
        const TrackLyrics(
          trackId: 11,
          type: TrackLyricsType.plain,
          languageCode: '   ',
          isVerified: false,
          source: ' ',
          plainText: 'Lyrics',
        ),
      );

      expect(httpClient.lastPutBody, {
        'type': 'plain',
        'isVerified': false,
        'plainText': 'Lyrics',
      });
    });
  });
}

class _FakeHttpClient implements HttpClient {
  _FakeHttpClient({
    Map<String, HttpResponse>? getResponses,
    Map<String, HttpResponse>? putResponses,
  }) : _getResponses = getResponses ?? const {},
       _putResponses = putResponses ?? const {};

  final Map<String, HttpResponse> _getResponses;
  final Map<String, HttpResponse> _putResponses;

  String? lastPutPath;
  Object? lastPutBody;

  @override
  Future<HttpResponse> get(String path, {Map<String, String>? headers}) async {
    final response = _getResponses[path];
    if (response == null) {
      throw StateError('No fake GET response for $path');
    }
    return response;
  }

  @override
  Future<HttpResponse> put(
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    lastPutPath = path;
    lastPutBody = body;
    final response = _putResponses[path];
    if (response == null) {
      throw StateError('No fake PUT response for $path');
    }
    return response;
  }

  @override
  Future<BinaryHttpResponse> getBinary(
    String path, {
    Map<String, String>? headers,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<HttpResponse> post(
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<HttpResponse> delete(String path, {Map<String, String>? headers}) {
    throw UnimplementedError();
  }

  @override
  Future<HttpResponse> postMultipart(
    String path, {
    Map<String, String>? headers,
    required String fieldName,
    required String fileName,
    required List<int> bytes,
  }) {
    throw UnimplementedError();
  }
}
