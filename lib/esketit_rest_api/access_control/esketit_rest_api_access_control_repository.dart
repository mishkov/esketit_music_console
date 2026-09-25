import 'dart:convert';

import 'package:esketit_music_console/domain/access_control.dart';
import 'package:esketit_music_console/errors/app_error.dart';
import 'package:esketit_music_console/errors/http_app_error.dart';
import 'package:esketit_music_console/esketit_rest_api/http_client.dart';
import 'package:esketit_music_console/esketit_rest_api/http_response.dart';
import 'package:esketit_music_console/use_case/access_control/access_control_repository.dart';

class EsketitRestApiAccessControlRepository implements AccessControlRepository {
  const EsketitRestApiAccessControlRepository({required HttpClient httpClient})
    : _httpClient = httpClient;

  final HttpClient _httpClient;

  @override
  Future<List<AccessControlUser>> getUsers() async {
    final response = await _httpClient.get('/access-control/users');
    return _decodeList(
      response,
      '/access-control/users',
    ).map(AccessControlUser.fromJson).toList(growable: false);
  }

  @override
  Future<List<AccessRole>> getRoles() async {
    final response = await _httpClient.get('/access-control/roles');
    return _decodeList(
      response,
      '/access-control/roles',
    ).map(AccessRole.fromJson).toList(growable: false);
  }

  @override
  Future<List<AccessPermission>> getPermissions() async {
    final response = await _httpClient.get('/access-control/permissions');
    return _decodeList(
      response,
      '/access-control/permissions',
    ).map(AccessPermission.fromJson).toList(growable: false);
  }

  @override
  Future<List<AccessControlAuditEvent>> getAuditEvents({
    int limit = 100,
  }) async {
    if (limit < 1 || limit > 500) {
      throw ArgumentError.value(limit, 'limit', 'must be between 1 and 500');
    }
    final path = '/access-control/audit-events?limit=$limit';
    final response = await _httpClient.get(path);
    return _decodeList(
      response,
      path,
    ).map(AccessControlAuditEvent.fromJson).toList(growable: false);
  }

  @override
  Future<UserAccessProfile> replaceUserRoles(
    int userId,
    List<int> roleIds,
  ) async {
    final path = '/access-control/users/$userId/roles';
    final response = await _httpClient.put(path, body: {'roleIds': roleIds});
    return UserAccessProfile.fromJson(_decodeMap(response, path));
  }

  @override
  Future<AccessRole> createRole({
    required String name,
    required String description,
  }) async {
    const path = '/access-control/roles';
    final response = await _httpClient.post(
      path,
      body: {'name': name, 'description': description},
    );
    return AccessRole.fromJson(_decodeMap(response, path));
  }

  @override
  Future<AccessRole> updateRole(
    int roleId, {
    required String name,
    required String description,
  }) async {
    final path = '/access-control/roles/$roleId';
    final response = await _httpClient.put(
      path,
      body: {'name': name, 'description': description},
    );
    return AccessRole.fromJson(_decodeMap(response, path));
  }

  @override
  Future<void> deleteRole(int roleId) async {
    final path = '/access-control/roles/$roleId';
    final response = await _httpClient.delete(path);
    _ensureSuccess(response, path);
  }

  @override
  Future<AccessRole> replaceRolePermissions(
    int roleId,
    List<int> permissionIds,
  ) async {
    final path = '/access-control/roles/$roleId/permissions';
    final response = await _httpClient.put(
      path,
      body: {'permissionIds': permissionIds},
    );
    return AccessRole.fromJson(_decodeMap(response, path));
  }

  List<Map<String, dynamic>> _decodeList(HttpResponse response, String path) {
    _ensureSuccess(response, path);
    final decoded = _decode(response.response, path);
    if (decoded is! List) {
      throw AppError('Expected JSON array response for $path', cause: decoded);
    }
    return decoded
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList(growable: false);
  }

  Map<String, dynamic> _decodeMap(HttpResponse response, String path) {
    _ensureSuccess(response, path);
    final decoded = _decode(response.response, path);
    if (decoded is! Map) {
      throw AppError('Expected JSON object response for $path', cause: decoded);
    }
    return Map<String, dynamic>.from(decoded);
  }

  void _ensureSuccess(HttpResponse response, String path) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }
    throw HttpAppError(
      message: _errorMessage(response.response) ?? 'Request failed',
      path: path,
      statusCode: response.statusCode,
      responseBody: response.response,
    );
  }

  Object? _decode(Object? body, String path) {
    if (body is! String) {
      return body;
    }
    try {
      return jsonDecode(body);
    } on FormatException catch (error, stackTrace) {
      throw AppError(
        'Expected JSON response for $path',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  String? _errorMessage(Object? body) {
    if (body is String) {
      final trimmed = body.trim();
      if (trimmed.isEmpty) {
        return null;
      }
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map) {
          return decoded['message'] as String? ?? decoded['error'] as String?;
        }
      } on FormatException {
        return trimmed;
      }
      return trimmed;
    }
    if (body is Map) {
      return body['message'] as String? ?? body['error'] as String?;
    }
    return null;
  }
}
