import 'package:esketit_music_console/esketit_rest_api/http_client.dart';
import 'package:esketit_music_console/esketit_rest_api/http_response.dart';
import 'package:esketit_music_console/esketit_rest_api/youtube/esketit_rest_api_youtube_import_repository.dart';
import 'package:esketit_music_console/firebase/track/storage_file.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('startSession sends URL, cutoff, and replaceExisting', () async {
    final httpClient = _FakeHttpClient(
      postResponses: {
        '/youtube/import-sessions': const HttpResponse(
          statusCode: 201,
          response: {
            'sessionId': 'session-1',
            'status': 'active',
            'sourceType': 'playlist',
            'sourceUrl': 'https://music.youtube.com/playlist?list=1',
            'progress': {
              'total': 3,
              'processed': 0,
              'remaining': 3,
              'skipped': 0,
              'saved': 0,
            },
            'createdAt': '2026-04-29T10:00:00.000Z',
            'updatedAt': '2026-04-29T10:00:00.000Z',
          },
        ),
      },
    );
    final repository = EsketitRestApiYouTubeImportRepository(
      httpClient: httpClient,
      baseUri: Uri.parse('http://localhost:8080'),
    );

    await repository.startSession(
      url: 'https://music.youtube.com/playlist?list=1',
      releaseDateCutoff: DateTime.utc(2024, 6, 1, 23, 59, 59, 999),
      replaceExisting: true,
    );

    expect(httpClient.lastPostPath, '/youtube/import-sessions');
    expect(httpClient.lastPostBody, {
      'url': 'https://music.youtube.com/playlist?list=1',
      'replaceExisting': true,
      'releaseDateCutoff': '2024-06-01T23:59:59.999Z',
    });
  });

  test('addCurrentAsNew sends create payload', () async {
    final httpClient = _FakeHttpClient(
      postResponses: {
        '/youtube/import-sessions/current/add': const HttpResponse(
          statusCode: 200,
          response: {
            'session': {
              'sessionId': 'session-2',
              'status': 'active',
              'sourceType': 'playlist',
              'sourceUrl': 'https://music.youtube.com/playlist?list=1',
              'progress': {
                'total': 3,
                'processed': 1,
                'remaining': 2,
                'skipped': 0,
                'saved': 1,
              },
              'createdAt': '2026-04-29T10:00:00.000Z',
              'updatedAt': '2026-04-29T10:05:00.000Z',
            },
            'track': {
              'id': 42,
              'name': 'Imported track',
              'authorIds': [7],
              'albumId': 3,
              'audioFilePath': '/songs/imported.mp3',
              'additionalInfo': [],
              'sourceMetadata': [],
              'isFavorite': false,
              'isAvailable': true,
            },
          },
        ),
      },
    );
    final repository = EsketitRestApiYouTubeImportRepository(
      httpClient: httpClient,
      baseUri: Uri.parse('http://localhost:8080'),
    );

    final response = await repository.addCurrentAsNew(
      name: 'Imported track',
      authorIds: const [7],
      albumId: 3,
      albumOrder: 5,
    );

    expect(httpClient.lastPostBody, {
      'mode': 'create',
      'name': 'Imported track',
      'authorIds': [7],
      'albumId': 3,
      'albumOrder': 5,
    });
    expect(response.track.id, 42);
    expect(
      (response.track.file as StorageFile).storagePath,
      '/songs/imported.mp3',
    );
  });

  test('attachCurrent sends attach payload', () async {
    final httpClient = _FakeHttpClient(
      postResponses: {
        '/youtube/import-sessions/current/add': const HttpResponse(
          statusCode: 200,
          response: {
            'session': {
              'sessionId': 'session-2',
              'status': 'active',
              'sourceType': 'track',
              'sourceUrl': 'https://music.youtube.com/watch?v=1',
              'progress': {
                'total': 1,
                'processed': 1,
                'remaining': 0,
                'skipped': 0,
                'saved': 1,
              },
              'createdAt': '2026-04-29T10:00:00.000Z',
              'updatedAt': '2026-04-29T10:05:00.000Z',
            },
            'track': {
              'id': 99,
              'name': 'Existing track',
              'authorIds': [],
              'albumId': 8,
              'audioFilePath': '/songs/existing.mp3',
              'additionalInfo': [],
              'sourceMetadata': [],
              'isFavorite': false,
              'isAvailable': true,
            },
          },
        ),
      },
    );
    final repository = EsketitRestApiYouTubeImportRepository(
      httpClient: httpClient,
      baseUri: Uri.parse('http://localhost:8080'),
    );

    await repository.attachCurrent(trackId: 99);

    expect(httpClient.lastPostPath, '/youtube/import-sessions/current/add');
    expect(httpClient.lastPostBody, {'mode': 'attach', 'trackId': 99});
  });
}

class _FakeHttpClient implements HttpClient {
  _FakeHttpClient({Map<String, HttpResponse>? postResponses})
    : _postResponses = postResponses ?? const {};

  final Map<String, HttpResponse> _postResponses;

  String? lastPostPath;
  Object? lastPostBody;

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
    lastPostPath = path;
    lastPostBody = body;
    final response = _postResponses[path];
    if (response == null) {
      throw StateError('No fake POST response for $path');
    }
    return response;
  }

  @override
  Future<HttpResponse> get(String path, {Map<String, String>? headers}) {
    throw UnimplementedError();
  }

  @override
  Future<BinaryHttpResponse> getBinary(
    String path, {
    Map<String, String>? headers,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<HttpResponse> put(
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
