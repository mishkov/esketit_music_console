import 'dart:convert';

import 'package:esketit_music_console/domain/auth/app_user.dart';
import 'package:esketit_music_console/domain/auth/auth_session.dart';
import 'package:esketit_music_console/errors/app_error.dart';
import 'package:esketit_music_console/errors/http_app_error.dart';
import 'package:esketit_music_console/esketit_rest_api/http_client.dart';
import 'package:esketit_music_console/esketit_rest_api/http_response.dart';
import 'package:esketit_music_console/use_case/auth/auth_repository.dart';
import 'package:esketit_music_console/use_case/auth/auth_session_storage.dart';

class EsketitRestApiAuthRepository implements AuthRepository {
  EsketitRestApiAuthRepository({
    required HttpClient unauthenticatedHttpClient,
    required HttpClient authenticatedHttpClient,
    required AuthSessionStorage sessionStorage,
  }) : _unauthenticatedHttpClient = unauthenticatedHttpClient,
       _authenticatedHttpClient = authenticatedHttpClient,
       _sessionStorage = sessionStorage;

  final HttpClient _unauthenticatedHttpClient;
  final HttpClient _authenticatedHttpClient;
  final AuthSessionStorage _sessionStorage;

  AuthSession? _cachedSession;

  @override
  Future<AuthSession?> restoreSession() async {
    final storedSession = await _sessionStorage.read();
    if (storedSession == null) {
      _cachedSession = null;
      return null;
    }

    _cachedSession = storedSession;
    final refreshedSession = await refreshSession(
      forceRefresh: storedSession.isAccessTokenExpired,
    );
    if (refreshedSession == null) {
      return null;
    }

    final meResponse = await _authenticatedHttpClient.get('/auth/me');
    final meBody = _decodeJsonMap(meResponse.response, path: '/auth/me');
    final user = _parseUser(meBody);
    final restoredSession = refreshedSession.copyWith(user: user);
    await _persistSession(restoredSession);
    return restoredSession;
  }

  @override
  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _unauthenticatedHttpClient.post(
      '/auth/login',
      body: {'email': email, 'password': password},
    );
    final session = _parseAuthResponse(response, path: '/auth/login');
    await _persistSession(session);
    return session;
  }

  @override
  Future<void> signOut() async {
    final currentSession = _cachedSession ?? await _sessionStorage.read();
    if (currentSession != null) {
      try {
        await _unauthenticatedHttpClient.post(
          '/auth/logout',
          body: {'refreshToken': currentSession.refreshToken},
        );
      } catch (_) {
        // Remote logout failure should not keep local session alive.
      }
    }

    await _clearSession();
  }

  @override
  Future<AuthSession?> refreshSession({bool forceRefresh = false}) async {
    final currentSession = _cachedSession ?? await _sessionStorage.read();
    if (currentSession == null) {
      _cachedSession = null;
      return null;
    }

    if (!forceRefresh && !currentSession.isAccessTokenExpired) {
      _cachedSession = currentSession;
      return currentSession;
    }

    if (currentSession.isRefreshTokenExpired) {
      await _clearSession();
      return null;
    }

    final response = await _unauthenticatedHttpClient.post(
      '/auth/refresh',
      body: {'refreshToken': currentSession.refreshToken},
    );
    final refreshedSession = _parseAuthResponse(
      response,
      path: '/auth/refresh',
    );
    await _persistSession(refreshedSession);
    return refreshedSession;
  }

  Future<void> _persistSession(AuthSession session) async {
    _cachedSession = session;
    await _sessionStorage.write(session);
  }

  Future<void> _clearSession() async {
    _cachedSession = null;
    await _sessionStorage.clear();
  }

  AuthSession _parseAuthResponse(
    HttpResponse response, {
    required String path,
  }) {
    _throwIfUnauthorizedOrForbidden(response, path: path);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpAppError(
        message: 'Request failed',
        path: path,
        statusCode: response.statusCode,
        responseBody: response.response,
      );
    }

    final body = _decodeJsonMap(response.response, path: path);
    return AuthSession(
      user: _parseUser(_jsonMap(body['user'], path: path, fieldName: 'user')),
      accessToken: body['accessToken'] as String,
      accessTokenExpiresAt: DateTime.parse(
        body['accessTokenExpiresAt'] as String,
      ),
      refreshToken: body['refreshToken'] as String,
      refreshTokenExpiresAt: DateTime.parse(
        body['refreshTokenExpiresAt'] as String,
      ),
    );
  }

  AppUser _parseUser(Map<String, dynamic> json) {
    return AppUser(
      id: (json['id'] as num).toInt(),
      email: json['email'] as String,
      role: AppUserRole.values.firstWhere(
        (role) => role.name == json['role'],
        orElse: () => AppUserRole.listener,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> _decodeJsonMap(Object? body, {required String path}) {
    final decoded = body is String ? jsonDecode(body) : body;
    if (decoded is! Map<String, dynamic>) {
      throw AppError('Expected JSON object response for $path', cause: decoded);
    }
    return decoded;
  }

  Map<String, dynamic> _jsonMap(
    Object? value, {
    required String path,
    required String fieldName,
  }) {
    if (value is! Map<String, dynamic>) {
      throw AppError(
        'Expected "$fieldName" to be a JSON object for $path',
        cause: value,
      );
    }

    return value;
  }

  void _throwIfUnauthorizedOrForbidden(
    HttpResponse response, {
    required String path,
  }) {
    if (response.statusCode == 401) {
      throw UnauthorizedAppError(path: path, responseBody: response.response);
    }
    if (response.statusCode == 403) {
      throw ForbiddenAppError(path: path, responseBody: response.response);
    }
  }
}
