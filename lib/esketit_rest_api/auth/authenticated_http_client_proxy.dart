import 'package:esketit_music_console/domain/auth/auth_session.dart';
import 'package:esketit_music_console/errors/http_app_error.dart';
import 'package:esketit_music_console/esketit_rest_api/http_client.dart';
import 'package:esketit_music_console/esketit_rest_api/http_response.dart';

class AuthenticatedHttpClientProxy implements HttpClient {
  const AuthenticatedHttpClientProxy({
    required HttpClient httpClient,
    required this.refreshSession,
  }) : _httpClient = httpClient;

  final HttpClient _httpClient;
  final Future<AuthSession?> Function({bool forceRefresh}) refreshSession;

  @override
  Future<HttpResponse> get(String path, {Map<String, String>? headers}) {
    return _sendAuthenticated(
      path: path,
      headers: headers,
      send: (mergedHeaders) => _httpClient.get(path, headers: mergedHeaders),
    );
  }

  @override
  Future<BinaryHttpResponse> getBinary(
    String path, {
    Map<String, String>? headers,
  }) {
    return _sendBinaryAuthenticated(
      path: path,
      headers: headers,
      send: (mergedHeaders) =>
          _httpClient.getBinary(path, headers: mergedHeaders),
    );
  }

  @override
  Future<HttpResponse> post(
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) {
    return _sendAuthenticated(
      path: path,
      headers: headers,
      send: (mergedHeaders) =>
          _httpClient.post(path, headers: mergedHeaders, body: body),
    );
  }

  @override
  Future<HttpResponse> put(
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) {
    return _sendAuthenticated(
      path: path,
      headers: headers,
      send: (mergedHeaders) =>
          _httpClient.put(path, headers: mergedHeaders, body: body),
    );
  }

  @override
  Future<HttpResponse> delete(String path, {Map<String, String>? headers}) {
    return _sendAuthenticated(
      path: path,
      headers: headers,
      send: (mergedHeaders) => _httpClient.delete(path, headers: mergedHeaders),
    );
  }

  @override
  Future<HttpResponse> postMultipart(
    String path, {
    Map<String, String>? headers,
    required String fieldName,
    required String fileName,
    required List<int> bytes,
  }) {
    return _sendAuthenticated(
      path: path,
      headers: headers,
      send: (mergedHeaders) => _httpClient.postMultipart(
        path,
        headers: mergedHeaders,
        fieldName: fieldName,
        fileName: fileName,
        bytes: bytes,
      ),
    );
  }

  Future<HttpResponse> _sendAuthenticated({
    required String path,
    required Map<String, String>? headers,
    required Future<HttpResponse> Function(Map<String, String> headers) send,
  }) async {
    final session = await refreshSession();
    if (session == null) {
      throw UnauthorizedAppError(path: path);
    }

    var response = await send(_authorizationHeaders(session, headers));
    if (response.statusCode == 401) {
      final refreshedSession = await refreshSession(forceRefresh: true);
      if (refreshedSession == null) {
        throw UnauthorizedAppError(path: path, responseBody: response.response);
      }

      response = await send(_authorizationHeaders(refreshedSession, headers));
    }

    _throwIfUnauthorizedOrForbidden(response, path: path);
    return response;
  }

  Future<BinaryHttpResponse> _sendBinaryAuthenticated({
    required String path,
    required Map<String, String>? headers,
    required Future<BinaryHttpResponse> Function(Map<String, String> headers)
    send,
  }) async {
    final session = await refreshSession();
    if (session == null) {
      throw UnauthorizedAppError(path: path);
    }

    var response = await send(_authorizationHeaders(session, headers));
    if (response.statusCode == 401) {
      final refreshedSession = await refreshSession(forceRefresh: true);
      if (refreshedSession == null) {
        throw UnauthorizedAppError(path: path);
      }

      response = await send(_authorizationHeaders(refreshedSession, headers));
    }

    _throwIfUnauthorizedOrForbiddenBinary(response, path: path);
    return response;
  }

  static Map<String, String> _authorizationHeaders(
    AuthSession session,
    Map<String, String>? headers,
  ) {
    return {...?headers, 'Authorization': 'Bearer ${session.accessToken}'};
  }

  static void _throwIfUnauthorizedOrForbidden(
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

  static void _throwIfUnauthorizedOrForbiddenBinary(
    BinaryHttpResponse response, {
    required String path,
  }) {
    if (response.statusCode == 401) {
      throw UnauthorizedAppError(path: path);
    }
    if (response.statusCode == 403) {
      throw ForbiddenAppError(path: path);
    }
  }
}
