import 'dart:convert';

import 'package:esketit_music_console/esketit_rest_api/http_client.dart';
import 'package:esketit_music_console/esketit_rest_api/http_response.dart';
import 'package:http/http.dart' as http;

class HttpPackageHttpClient implements HttpClient {
  HttpPackageHttpClient({required this.baseUri, http.Client? client})
    : _client = client ?? http.Client();

  final Uri baseUri;
  final http.Client _client;

  @override
  Future<HttpResponse> get(String path, {Map<String, String>? headers}) async {
    final response = await _client.get(_resolve(path), headers: headers);
    return HttpResponse(
      statusCode: response.statusCode,
      response: response.body,
    );
  }

  @override
  Future<HttpResponse> post(
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final preparedBody = _prepareBody(body);
    final response = await _client.post(
      _resolve(path),
      headers: {
        if (preparedBody != null) 'Content-Type': 'application/json',
        ...?headers,
      },
      body: preparedBody,
    );
    return HttpResponse(
      statusCode: response.statusCode,
      response: response.body,
    );
  }

  @override
  Future<HttpResponse> postMultipart(
    String path, {
    Map<String, String>? headers,
    required String fieldName,
    required String fileName,
    required List<int> bytes,
  }) async {
    final request = http.MultipartRequest('POST', _resolve(path))
      ..headers.addAll(headers ?? const {})
      ..files.add(
        http.MultipartFile.fromBytes(fieldName, bytes, filename: fileName),
      );

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);
    return HttpResponse(
      statusCode: response.statusCode,
      response: response.body,
    );
  }

  Uri _resolve(String path) {
    final sanitizedPath = path.startsWith('/') ? path.substring(1) : path;
    return baseUri.resolve(sanitizedPath);
  }

  String? _prepareBody(Object? body) {
    if (body == null) {
      return null;
    }
    if (body is String) {
      return body;
    }

    return jsonEncode(body);
  }
}
