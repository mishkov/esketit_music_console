import 'package:esketit_music_console/errors/http_app_error.dart';
import 'package:esketit_music_console/esketit_rest_api/access_control/esketit_rest_api_access_control_repository.dart';
import 'package:esketit_music_console/esketit_rest_api/http_client.dart';
import 'package:esketit_music_console/esketit_rest_api/http_response.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads users, roles, permissions, and audit events', () async {
    final client = _RecordingHttpClient(
      getResponses: {
        '/access-control/users': HttpResponse(
          statusCode: 200,
          response: [_userJson],
        ),
        '/access-control/roles': HttpResponse(
          statusCode: 200,
          response: [_roleJson],
        ),
        '/access-control/permissions': HttpResponse(
          statusCode: 200,
          response: [_permissionJson],
        ),
        '/access-control/audit-events?limit=100': const HttpResponse(
          statusCode: 200,
          response: [
            {
              'id': 4,
              'actorUserId': 1,
              'action': 'role.permissions.replace',
              'targetRoleId': 2,
              'details': {
                'permissionIds': [1],
              },
              'createdAt': '2026-01-04T00:00:00Z',
            },
          ],
        ),
      },
    );
    final repository = EsketitRestApiAccessControlRepository(
      httpClient: client,
    );

    final users = await repository.getUsers();
    final roles = await repository.getRoles();
    final permissions = await repository.getPermissions();
    final events = await repository.getAuditEvents();

    expect(users.single.email, 'user@example.com');
    expect(users.single.roles.single.name, 'admin');
    expect(users.single.permissions.single.code, 'access_control.manage');
    expect(roles.single.permissions, hasLength(1));
    expect(permissions.single.description, 'Manage access control');
    expect(events.single.action, 'role.permissions.replace');
    expect(events.single.targetRoleId, 2);
  });

  test('sends complete replacement payloads', () async {
    final client = _RecordingHttpClient(
      putResponses: {
        '/access-control/users/7/roles': HttpResponse(
          statusCode: 200,
          response: {
            'roles': [_roleJson],
            'permissions': [_permissionJson],
          },
        ),
        '/access-control/roles/2/permissions': HttpResponse(
          statusCode: 200,
          response: _roleJson,
        ),
      },
    );
    final repository = EsketitRestApiAccessControlRepository(
      httpClient: client,
    );

    await repository.replaceUserRoles(7, const [1, 2]);
    expect(client.putBodies['/access-control/users/7/roles'], {
      'roleIds': [1, 2],
    });

    await repository.replaceRolePermissions(2, const [1, 4, 7]);
    expect(client.putBodies['/access-control/roles/2/permissions'], {
      'permissionIds': [1, 4, 7],
    });
  });

  test('creates, updates, and deletes roles', () async {
    final client = _RecordingHttpClient(
      postResponses: {
        '/access-control/roles': HttpResponse(
          statusCode: 201,
          response: _roleJson,
        ),
      },
      putResponses: {
        '/access-control/roles/1': HttpResponse(
          statusCode: 200,
          response: _roleJson,
        ),
      },
      deleteResponses: const {
        '/access-control/roles/1': HttpResponse(statusCode: 204, response: ''),
      },
    );
    final repository = EsketitRestApiAccessControlRepository(
      httpClient: client,
    );

    await repository.createRole(name: 'importer', description: 'Imports');
    await repository.updateRole(1, name: 'editor', description: 'Edits');
    await repository.deleteRole(1);

    expect(client.postBodies['/access-control/roles'], {
      'name': 'importer',
      'description': 'Imports',
    });
    expect(client.putBodies['/access-control/roles/1'], {
      'name': 'editor',
      'description': 'Edits',
    });
    expect(client.deletedPaths, ['/access-control/roles/1']);
  });

  test('preserves a backend conflict message', () async {
    final client = _RecordingHttpClient(
      putResponses: const {
        '/access-control/users/7/roles': HttpResponse(
          statusCode: 409,
          response:
              'at least one user must retain access-control management permission',
        ),
      },
    );
    final repository = EsketitRestApiAccessControlRepository(
      httpClient: client,
    );

    await expectLater(
      repository.replaceUserRoles(7, const []),
      throwsA(
        isA<HttpAppError>().having(
          (error) => error.message,
          'message',
          contains('at least one user'),
        ),
      ),
    );
  });
}

const _permissionJson = {
  'id': 1,
  'code': 'access_control.manage',
  'description': 'Manage access control',
  'createdAt': '2026-01-01T00:00:00Z',
};

const _roleJson = {
  'id': 1,
  'name': 'admin',
  'description': 'Full administration',
  'system': true,
  'createdAt': '2026-01-01T00:00:00Z',
  'permissions': [_permissionJson],
};

const _userJson = {
  'id': 7,
  'email': 'user@example.com',
  'createdAt': '2026-01-02T00:00:00Z',
  'roles': [_roleJson],
  'permissions': [_permissionJson],
};

class _RecordingHttpClient implements HttpClient {
  _RecordingHttpClient({
    this.getResponses = const {},
    this.postResponses = const {},
    this.putResponses = const {},
    this.deleteResponses = const {},
  });

  final Map<String, HttpResponse> getResponses;
  final Map<String, HttpResponse> postResponses;
  final Map<String, HttpResponse> putResponses;
  final Map<String, HttpResponse> deleteResponses;
  final Map<String, Object?> postBodies = {};
  final Map<String, Object?> putBodies = {};
  final List<String> deletedPaths = [];

  @override
  Future<HttpResponse> get(String path, {Map<String, String>? headers}) async =>
      _response(getResponses, path);

  @override
  Future<HttpResponse> post(
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    postBodies[path] = body;
    return _response(postResponses, path);
  }

  @override
  Future<HttpResponse> put(
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    putBodies[path] = body;
    return _response(putResponses, path);
  }

  @override
  Future<HttpResponse> delete(
    String path, {
    Map<String, String>? headers,
  }) async {
    deletedPaths.add(path);
    return _response(deleteResponses, path);
  }

  HttpResponse _response(Map<String, HttpResponse> responses, String path) {
    final response = responses[path];
    if (response == null) {
      throw StateError('No response configured for $path');
    }
    return response;
  }

  @override
  Future<BinaryHttpResponse> getBinary(
    String path, {
    Map<String, String>? headers,
  }) => throw UnimplementedError();

  @override
  Future<HttpResponse> postMultipart(
    String path, {
    Map<String, String>? headers,
    required String fieldName,
    required String fileName,
    required List<int> bytes,
  }) => throw UnimplementedError();
}
