import 'dart:convert';

import 'package:esketit_music_console/domain/mcp_settings.dart';
import 'package:esketit_music_console/errors/app_error.dart';
import 'package:esketit_music_console/errors/http_app_error.dart';
import 'package:esketit_music_console/esketit_rest_api/http_client.dart';
import 'package:esketit_music_console/esketit_rest_api/http_response.dart';
import 'package:esketit_music_console/use_case/mcp/mcp_settings_repository.dart';

class EsketitRestApiMcpSettingsRepository implements McpSettingsRepository {
  const EsketitRestApiMcpSettingsRepository({required HttpClient httpClient})
    : _httpClient = httpClient;

  final HttpClient _httpClient;
  static const _path = '/mcp/settings';

  @override
  Future<McpSettings> getSettings() async =>
      _decode(await _httpClient.get(_path));

  @override
  Future<McpSettings> saveSettings({
    required int expectedVersion,
    required int? actingUserId,
    required String workflowGuidance,
    required String uploadGuidance,
  }) async {
    if (utf8.encode(workflowGuidance).length > 32000 ||
        utf8.encode(uploadGuidance).length > 32000) {
      throw AppError('Each guidance field must be at most 32,000 UTF-8 bytes.');
    }
    return _decode(
      await _httpClient.patch(
        _path,
        body: {
          'expectedVersion': expectedVersion,
          'actingUserId': actingUserId,
          'workflowGuidance': workflowGuidance,
          'uploadGuidance': uploadGuidance,
        },
      ),
    );
  }

  Object? _decodeBody(Object? body) => body is String ? jsonDecode(body) : body;

  McpSettings _decode(HttpResponse response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      var message = 'Could not update MCP settings.';
      if (response.statusCode == 409) {
        message =
            'Settings changed since you loaded them. Reload to review the current settings before saving again.';
      } else {
        try {
          final body = _decodeBody(response.response) as Map<String, dynamic>;
          final error = body['error'] as Map<String, dynamic>?;
          message = error?['message'] as String? ?? message;
        } on FormatException {
          // Keep the fallback message for non-JSON server errors.
        } on TypeError {
          // Keep the fallback message for another response shape.
        }
      }
      throw HttpAppError(
        message: message,
        path: _path,
        statusCode: response.statusCode,
        responseBody: response.response,
      );
    }
    final body = _decodeBody(response.response);
    if (body is! Map<String, dynamic>) {
      throw AppError('Expected MCP settings object.');
    }
    return McpSettings.fromJson(body);
  }
}
