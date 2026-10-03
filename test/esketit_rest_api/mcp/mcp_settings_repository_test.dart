import 'dart:convert';

import 'package:esketit_music_console/errors/http_app_error.dart';
import 'package:esketit_music_console/esketit_rest_api/http_client.dart';
import 'package:esketit_music_console/esketit_rest_api/http_response.dart';
import 'package:esketit_music_console/esketit_rest_api/mcp/esketit_rest_api_mcp_settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'reads settings and PATCHes selected user with version and guidance',
    () async {
      final client = _Client();
      final repository = EsketitRestApiMcpSettingsRepository(
        httpClient: client,
      );
      final settings = await repository.getSettings();
      expect(settings.actingUserId, 7);
      expect(settings.credentialConfigured, isTrue);
      await repository.saveSettings(
        expectedVersion: settings.version,
        actingUserId: null,
        workflowGuidance: 'Careful review',
        uploadGuidance: 'MP3',
      );
      expect(client.path, '/mcp/settings');
      expect(client.body, {
        'expectedVersion': 2,
        'actingUserId': null,
        'workflowGuidance': 'Careful review',
        'uploadGuidance': 'MP3',
      });
    },
  );

  test('reports stale settings and preserves a failed save', () async {
    final client = _Client()..status = 409;
    final repository = EsketitRestApiMcpSettingsRepository(httpClient: client);
    await expectLater(
      repository.saveSettings(
        expectedVersion: 2,
        actingUserId: 7,
        workflowGuidance: 'Draft',
        uploadGuidance: '',
      ),
      throwsA(
        isA<HttpAppError>()
            .having((e) => e.statusCode, 'status', 409)
            .having((e) => e.message, 'message', contains('Reload')),
      ),
    );
  });
}

class _Client implements HttpClient {
  int status = 200;
  String? path;
  Object? body;

  HttpResponse get response => HttpResponse(
    statusCode: status,
    response: jsonEncode({
      'actingUserId': 7,
      'workflowGuidance': 'Workflow',
      'uploadGuidance': 'Uploads',
      'version': 2,
      'credentialConfigured': true,
    }),
  );

  @override
  Future<HttpResponse> get(String path, {Map<String, String>? headers}) async {
    this.path = path;
    return response;
  }

  @override
  Future<HttpResponse> patch(
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    this.path = path;
    this.body = body;
    return response;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
