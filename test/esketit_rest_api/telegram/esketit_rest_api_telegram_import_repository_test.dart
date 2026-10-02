import 'package:esketit_music_console/domain/track_info/external_link_track_info.dart';
import 'package:esketit_music_console/domain/track_source_metadata.dart';
import 'package:esketit_music_console/esketit_rest_api/http_client.dart';
import 'package:esketit_music_console/esketit_rest_api/http_response.dart';
import 'package:esketit_music_console/esketit_rest_api/telegram/esketit_rest_api_telegram_import_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('saveCurrent sends additionalInfo and sourceMetadata', () async {
    final httpClient = _FakeHttpClient(
      postResponses: {
        '/telegram/import-sessions/current/save': const HttpResponse(
          statusCode: 200,
          response: {
            'sessionId': 'session-1',
            'status': 'active',
            'channelUsername': 'music',
            'progress': {
              'total': 1,
              'processed': 1,
              'remaining': 0,
              'skipped': 0,
              'saved': 1,
            },
            'createdAt': '2026-04-28T10:00:00.000Z',
            'updatedAt': '2026-04-28T10:00:00.000Z',
            'currentTrack': null,
          },
        ),
      },
    );
    final repository = EsketitRestApiTelegramImportRepository(
      httpClient: httpClient,
    );

    await repository.saveCurrent(
      name: 'Track title',
      authorIds: const [1, 2],
      albumId: 3,
      albumOrder: 4,
      additionalInfo: const [
        ExternalLinkTrackInfo(
          provider: 'telegram',
          title: 'Telegram message',
          url: 'https://t.me/channel/123',
        ),
      ],
      sourceMetadata: const [
        TrackSourceMetadata(
          provider: 'telegram',
          kind: 'message',
          identity: {'chatId': 'channel_name', 'messageId': '123'},
          url: 'https://t.me/channel_name/123',
        ),
      ],
    );

    expect(httpClient.lastPostPath, '/telegram/import-sessions/current/save');
    expect(httpClient.lastPostBody, {
      'name': 'Track title',
      'authorIds': [1, 2],
      'albumId': 3,
      'albumOrder': 4,
      'additionalInfo': [
        {
          'type': 'external_link',
          'provider': 'telegram',
          'title': 'Telegram message',
          'url': 'https://t.me/channel/123',
        },
      ],
      'sourceMetadata': [
        {
          'provider': 'telegram',
          'kind': 'message',
          'identity': {'chatId': 'channel_name', 'messageId': '123'},
          'url': 'https://t.me/channel_name/123',
        },
      ],
    });
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
