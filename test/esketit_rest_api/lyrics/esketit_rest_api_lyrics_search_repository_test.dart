import 'package:esketit_music_console/errors/http_app_error.dart';
import 'package:esketit_music_console/esketit_rest_api/http_client.dart';
import 'package:esketit_music_console/esketit_rest_api/http_response.dart';
import 'package:esketit_music_console/esketit_rest_api/lyrics/esketit_rest_api_lyrics_search_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'posts edit-form metadata and parses provider-neutral candidates',
    () async {
      final httpClient = _FakeHttpClient(
        response: const HttpResponse(
          statusCode: 200,
          response: {
            'items': [
              {
                'provider': 'lrclib',
                'providerId': 3396226,
                'source': 'LRCLIB #3396226',
                'trackName': 'Track title',
                'artistName': 'Artist',
                'albumName': 'Album',
                'durationMs': 213000,
                'instrumental': false,
                'plainText': 'First line\nSecond line',
                'syncedLines': [
                  {'startMs': 1200, 'endMs': 3400, 'text': 'First line'},
                  {'startMs': 3400, 'endMs': null, 'text': 'Second line'},
                ],
              },
            ],
          },
        ),
      );
      final repository = EsketitRestApiLyricsSearchRepository(
        httpClient: httpClient,
      );

      final result = await repository.search(
        trackId: 7,
        trackName: ' Track title ',
        artistNames: const [' Artist ', 'Featured artist'],
        albumName: ' Album ',
        durationMs: 213000,
      );

      expect(httpClient.lastPath, '/tracks/7/lyrics/search');
      expect(httpClient.lastBody, {
        'trackName': 'Track title',
        'artistNames': ['Artist', 'Featured artist'],
        'albumName': 'Album',
        'durationMs': 213000,
      });
      expect(result, hasLength(1));
      expect(result.single.providerId, 3396226);
      expect(result.single.hasPlainLyrics, isTrue);
      expect(result.single.hasSyncedLyrics, isTrue);
      expect(result.single.syncedLines.first.startMs, 1200);
      expect(result.single.syncedLines.last.endMs, isNull);
    },
  );

  test('surfaces backend search failures as HttpAppError', () async {
    final repository = EsketitRestApiLyricsSearchRepository(
      httpClient: _FakeHttpClient(
        response: const HttpResponse(
          statusCode: 504,
          response: 'lyrics provider timed out',
        ),
      ),
    );

    await expectLater(
      repository.search(
        trackId: 7,
        trackName: 'Track',
        artistNames: const ['Artist'],
        albumName: '',
      ),
      throwsA(
        isA<HttpAppError>()
            .having((error) => error.statusCode, 'statusCode', 504)
            .having((error) => error.message, 'message', contains('timed out')),
      ),
    );
  });
}

class _FakeHttpClient implements HttpClient {
  _FakeHttpClient({required this.response});

  final HttpResponse response;
  String? lastPath;
  Object? lastBody;

  @override
  Future<HttpResponse> patch(
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) => throw UnimplementedError('PATCH is not used in this fixture');

  @override
  Future<HttpResponse> post(
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    lastPath = path;
    lastBody = body;
    return response;
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
