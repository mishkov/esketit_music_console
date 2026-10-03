import 'package:esketit_music_console/domain/auth/auth_session.dart';
import 'package:esketit_music_console/esketit_rest_api/auth/esketit_rest_api_auth_repository.dart';
import 'package:esketit_music_console/esketit_rest_api/http_client.dart';
import 'package:esketit_music_console/esketit_rest_api/http_response.dart';
import 'package:esketit_music_console/use_case/auth/auth_session_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'parses normalized roles and effective permissions at sign in',
    () async {
      final storage = _MemorySessionStorage();
      final repository = EsketitRestApiAuthRepository(
        unauthenticatedHttpClient: _AuthHttpClient(
          postResponses: {'/auth/login': _authResponse(_userJson)},
        ),
        authenticatedHttpClient: _AuthHttpClient(),
        sessionStorage: storage,
      );

      final session = await repository.signIn(
        email: 'admin@example.com',
        password: 'secret',
      );

      expect(session.user.roles.map((role) => role.name), ['admin', 'editor']);
      expect(session.user.permissions.map((permission) => permission.code), [
        'access_control.manage',
        'tracks.create',
      ]);
      expect(session.user.hasPermission('access_control.manage'), isTrue);
      expect(session.user.hasPermission('admin'), isFalse);
      expect(storage.session, session);
    },
  );

  test('refreshCurrentUser replaces the stored profile from auth/me', () async {
    final storage = _MemorySessionStorage();
    final authenticatedClient = _AuthHttpClient(
      getResponses: {
        '/auth/me': const HttpResponse(
          statusCode: 200,
          response: {
            'id': 7,
            'email': 'admin@example.com',
            'createdAt': '2026-01-01T00:00:00Z',
            'roles': [],
            'permissions': [],
          },
        ),
      },
    );
    final repository = EsketitRestApiAuthRepository(
      unauthenticatedHttpClient: _AuthHttpClient(
        postResponses: {'/auth/login': _authResponse(_userJson)},
      ),
      authenticatedHttpClient: authenticatedClient,
      sessionStorage: storage,
    );
    await repository.signIn(email: 'admin@example.com', password: 'secret');

    final refreshed = await repository.refreshCurrentUser();

    expect(authenticatedClient.getPaths, ['/auth/me']);
    expect(refreshed?.user.roles, isEmpty);
    expect(refreshed?.user.permissions, isEmpty);
    expect(storage.session?.user.permissions, isEmpty);
  });
}

HttpResponse _authResponse(Map<String, Object> user) {
  return HttpResponse(
    statusCode: 200,
    response: {
      'user': user,
      'accessToken': 'access',
      'accessTokenExpiresAt': '2099-01-01T00:00:00Z',
      'refreshToken': 'refresh',
      'refreshTokenExpiresAt': '2099-02-01T00:00:00Z',
    },
  );
}

const _managePermissionJson = {
  'id': 1,
  'code': 'access_control.manage',
  'description': 'Manage access control',
  'createdAt': '2026-01-01T00:00:00Z',
};

const _trackPermissionJson = {
  'id': 2,
  'code': 'tracks.create',
  'description': 'Create tracks',
  'createdAt': '2026-01-01T00:00:00Z',
};

const _userJson = {
  'id': 7,
  'email': 'admin@example.com',
  'createdAt': '2026-01-01T00:00:00Z',
  'roles': [
    {
      'id': 1,
      'name': 'admin',
      'description': 'Full administration',
      'system': true,
      'createdAt': '2026-01-01T00:00:00Z',
      'permissions': [_managePermissionJson, _trackPermissionJson],
    },
    {
      'id': 2,
      'name': 'editor',
      'description': 'Catalog editor',
      'system': false,
      'createdAt': '2026-01-01T00:00:00Z',
      'permissions': [_trackPermissionJson],
    },
  ],
  'permissions': [_managePermissionJson, _trackPermissionJson],
};

class _MemorySessionStorage implements AuthSessionStorage {
  AuthSession? session;

  @override
  Future<AuthSession?> read() async => session;

  @override
  Future<void> write(AuthSession session) async => this.session = session;

  @override
  Future<void> clear() async => session = null;
}

class _AuthHttpClient implements HttpClient {
  _AuthHttpClient({
    this.getResponses = const {},
    this.postResponses = const {},
  });

  final Map<String, HttpResponse> getResponses;
  final Map<String, HttpResponse> postResponses;
  final List<String> getPaths = [];

  @override
  Future<HttpResponse> patch(
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) => throw UnimplementedError('PATCH is not used in this fixture');

  @override
  Future<HttpResponse> get(String path, {Map<String, String>? headers}) async {
    getPaths.add(path);
    return _response(getResponses, path);
  }

  @override
  Future<HttpResponse> post(
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) async => _response(postResponses, path);

  HttpResponse _response(Map<String, HttpResponse> responses, String path) {
    final response = responses[path];
    if (response == null) {
      throw StateError('No response configured for $path');
    }
    return response;
  }

  @override
  Future<HttpResponse> delete(String path, {Map<String, String>? headers}) =>
      throw UnimplementedError();

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

  @override
  Future<HttpResponse> put(
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) => throw UnimplementedError();
}
