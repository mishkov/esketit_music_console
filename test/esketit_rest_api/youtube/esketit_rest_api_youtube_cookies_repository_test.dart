import 'package:esketit_music_console/esketit_rest_api/http_client.dart';
import 'package:esketit_music_console/esketit_rest_api/http_response.dart';
import 'package:esketit_music_console/esketit_rest_api/youtube/esketit_rest_api_youtube_cookies_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('getStatus reads the YouTube cookies status payload', () async {
    final httpClient = _FakeHttpClient(
      getResponses: {
        '/youtube/cookies/status': const HttpResponse(
          statusCode: 200,
          response: {
            'configured': true,
            'filePresent': true,
            'lastModified': '2026-04-29T08:15:00.000Z',
          },
        ),
      },
    );
    final repository = EsketitRestApiYouTubeCookiesRepository(
      httpClient: httpClient,
    );

    final status = await repository.getStatus();

    expect(httpClient.lastGetPath, '/youtube/cookies/status');
    expect(status.configured, isTrue);
    expect(status.filePresent, isTrue);
    expect(status.lastModified, DateTime.utc(2026, 4, 29, 8, 15));
  });

  test(
    'uploadCookies sends multipart file upload with field name file',
    () async {
      final httpClient = _FakeHttpClient(
        postMultipartResponses: {
          '/youtube/cookies': const HttpResponse(
            statusCode: 201,
            response: {
              'configured': true,
              'filePresent': true,
              'lastModified': '2026-04-29T09:00:00.000Z',
            },
          ),
        },
      );
      final repository = EsketitRestApiYouTubeCookiesRepository(
        httpClient: httpClient,
      );

      await repository.uploadCookies(
        fileName: 'youtube-cookies.txt',
        bytes: const [1, 2, 3],
      );

      expect(httpClient.lastPostMultipartPath, '/youtube/cookies');
      expect(httpClient.lastPostMultipartFieldName, 'file');
      expect(httpClient.lastPostMultipartFileName, 'youtube-cookies.txt');
      expect(httpClient.lastPostMultipartBytes, [1, 2, 3]);
    },
  );

  test('deleteCookies calls the delete endpoint', () async {
    final httpClient = _FakeHttpClient(
      deleteResponses: {
        '/youtube/cookies': const HttpResponse(statusCode: 204, response: ''),
      },
    );
    final repository = EsketitRestApiYouTubeCookiesRepository(
      httpClient: httpClient,
    );

    await repository.deleteCookies();

    expect(httpClient.lastDeletePath, '/youtube/cookies');
  });
}

class _FakeHttpClient implements HttpClient {
  _FakeHttpClient({
    Map<String, HttpResponse>? getResponses,
    Map<String, HttpResponse>? deleteResponses,
    Map<String, HttpResponse>? postMultipartResponses,
  }) : _getResponses = getResponses ?? const {},
       _deleteResponses = deleteResponses ?? const {},
       _postMultipartResponses = postMultipartResponses ?? const {};

  final Map<String, HttpResponse> _getResponses;
  final Map<String, HttpResponse> _deleteResponses;
  final Map<String, HttpResponse> _postMultipartResponses;

  String? lastGetPath;
  String? lastDeletePath;
  String? lastPostMultipartPath;
  String? lastPostMultipartFieldName;
  String? lastPostMultipartFileName;
  List<int>? lastPostMultipartBytes;

  @override
  Future<HttpResponse> patch(
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) => throw UnimplementedError('PATCH is not used in this fixture');

  @override
  Future<HttpResponse> get(String path, {Map<String, String>? headers}) async {
    lastGetPath = path;
    final response = _getResponses[path];
    if (response == null) {
      throw StateError('No fake GET response for $path');
    }
    return response;
  }

  @override
  Future<HttpResponse> delete(
    String path, {
    Map<String, String>? headers,
  }) async {
    lastDeletePath = path;
    final response = _deleteResponses[path];
    if (response == null) {
      throw StateError('No fake DELETE response for $path');
    }
    return response;
  }

  @override
  Future<HttpResponse> postMultipart(
    String path, {
    Map<String, String>? headers,
    required String fieldName,
    required String fileName,
    required List<int> bytes,
  }) async {
    lastPostMultipartPath = path;
    lastPostMultipartFieldName = fieldName;
    lastPostMultipartFileName = fileName;
    lastPostMultipartBytes = bytes;
    final response = _postMultipartResponses[path];
    if (response == null) {
      throw StateError('No fake multipart POST response for $path');
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
  Future<HttpResponse> put(
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) {
    throw UnimplementedError();
  }
}
