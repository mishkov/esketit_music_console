import 'dart:convert';
import 'dart:typed_data';

import 'package:esketit_music_console/domain/track_info/track_info.dart';
import 'package:esketit_music_console/domain/track_source_metadata.dart';
import 'package:esketit_music_console/errors/app_error.dart';
import 'package:esketit_music_console/errors/http_app_error.dart';
import 'package:esketit_music_console/esketit_rest_api/http_client.dart';
import 'package:esketit_music_console/esketit_rest_api/http_response.dart';
import 'package:esketit_music_console/esketit_rest_api/track/track_metadata_codec.dart';
import 'package:esketit_music_console/esketit_rest_api/telegram/telegram_import_models.dart';
import 'package:esketit_music_console/use_case/telegram/telegram_import_repository.dart';

class EsketitRestApiTelegramImportRepository
    implements TelegramImportRepository {
  EsketitRestApiTelegramImportRepository({required HttpClient httpClient})
    : _httpClient = httpClient;

  final HttpClient _httpClient;

  @override
  Future<TelegramStatus> getStatus() async {
    final response = await _httpClient.get('/telegram/status');
    _throwIfUnexpectedStatus(response, path: '/telegram/status');
    return TelegramStatus.fromJson(
      _decodeJsonMap(response.response, path: '/telegram/status'),
    );
  }

  @override
  Future<void> requestAuthCode({required String phoneNumber}) async {
    final response = await _httpClient.post(
      '/telegram/auth/request',
      body: {'phoneNumber': phoneNumber},
    );
    _throwIfUnexpectedStatus(
      response,
      path: '/telegram/auth/request',
      expectedStatusCodes: {200, 204},
    );
  }

  @override
  Future<TelegramStatus> confirmAuthCode({
    required String phoneNumber,
    required String code,
  }) async {
    final response = await _httpClient.post(
      '/telegram/auth/confirm',
      body: {'phoneNumber': phoneNumber, 'code': code},
    );
    _throwIfUnexpectedStatus(
      response,
      path: '/telegram/auth/confirm',
      expectedStatusCodes: {200},
    );
    return TelegramStatus.fromJson(
      _decodeJsonMap(response.response, path: '/telegram/auth/confirm'),
    );
  }

  @override
  Future<TelegramStatus> confirmPassword({required String password}) async {
    final response = await _httpClient.post(
      '/telegram/auth/password',
      body: {'password': password},
    );
    _throwIfUnexpectedStatus(
      response,
      path: '/telegram/auth/password',
      expectedStatusCodes: {200},
    );
    return TelegramStatus.fromJson(
      _decodeJsonMap(response.response, path: '/telegram/auth/password'),
    );
  }

  @override
  Future<TelegramImportSession?> getCurrentSession() async {
    final response = await _httpClient.get('/telegram/import-sessions/current');
    if (response.statusCode == 404) {
      return null;
    }
    _throwIfUnexpectedStatus(
      response,
      path: '/telegram/import-sessions/current',
    );
    return TelegramImportSession.fromJson(
      _decodeJsonMap(
        response.response,
        path: '/telegram/import-sessions/current',
      ),
    );
  }

  @override
  Future<TelegramImportSession> startSession({
    required String channelUsername,
    int? startMessageId,
    bool replaceExisting = false,
  }) async {
    final body = <String, dynamic>{
      'channelUsername': channelUsername,
      'replaceExisting': replaceExisting,
    };
    if (startMessageId != null) {
      body['startMessageId'] = startMessageId;
    }
    final response = await _httpClient.post(
      '/telegram/import-sessions',
      body: body,
    );
    _throwIfUnexpectedStatus(
      response,
      path: '/telegram/import-sessions',
      expectedStatusCodes: {200, 201},
    );
    return TelegramImportSession.fromJson(
      _decodeJsonMap(response.response, path: '/telegram/import-sessions'),
    );
  }

  @override
  Future<TelegramImportSession> skipCurrent() async {
    final response = await _httpClient.post(
      '/telegram/import-sessions/current/skip',
    );
    _throwIfUnexpectedStatus(
      response,
      path: '/telegram/import-sessions/current/skip',
    );
    return TelegramImportSession.fromJson(
      _decodeJsonMap(
        response.response,
        path: '/telegram/import-sessions/current/skip',
      ),
    );
  }

  @override
  Future<TelegramImportSession> saveCurrent({
    required String name,
    required List<int> authorIds,
    required int albumId,
    required int albumOrder,
    required List<TrackInfo> additionalInfo,
    required List<TrackSourceMetadata> sourceMetadata,
  }) async {
    final response = await _httpClient.post(
      '/telegram/import-sessions/current/save',
      body: {
        'name': name,
        'authorIds': authorIds,
        'albumId': albumId,
        'albumOrder': albumOrder,
        'additionalInfo': serializeTrackInfos(additionalInfo),
        'sourceMetadata': serializeTrackSourceMetadata(sourceMetadata),
      },
    );
    _throwIfUnexpectedStatus(
      response,
      path: '/telegram/import-sessions/current/save',
    );
    return TelegramImportSession.fromJson(
      _decodeJsonMap(
        response.response,
        path: '/telegram/import-sessions/current/save',
      ),
    );
  }

  @override
  Future<void> cancelCurrentSession() async {
    final response = await _httpClient.delete(
      '/telegram/import-sessions/current',
    );
    _throwIfUnexpectedStatus(
      response,
      path: '/telegram/import-sessions/current',
      expectedStatusCodes: {200, 204},
    );
  }

  @override
  Future<DownloadedBinaryFile> downloadCurrentAudio() async {
    final response = await _httpClient.getBinary(
      '/telegram/import-sessions/current/audio',
    );
    _throwIfUnexpectedBinaryStatus(
      response,
      path: '/telegram/import-sessions/current/audio',
    );
    return DownloadedBinaryFile(
      bytes: Uint8List.fromList(response.bytes),
      fileName:
          _fileNameFromDisposition(response.contentDisposition) ?? 'track.mp3',
      contentType: response.contentType ?? 'audio/mpeg',
    );
  }

  @override
  Future<DownloadedBinaryFile> downloadSkippedReport() async {
    final response = await _httpClient.getBinary(
      '/telegram/import-sessions/current/skipped-report',
    );
    _throwIfUnexpectedBinaryStatus(
      response,
      path: '/telegram/import-sessions/current/skipped-report',
    );
    return DownloadedBinaryFile(
      bytes: Uint8List.fromList(response.bytes),
      fileName:
          _fileNameFromDisposition(response.contentDisposition) ??
          'telegram-skipped-report.csv',
      contentType: response.contentType ?? 'text/csv',
    );
  }

  Map<String, dynamic> _decodeJsonMap(Object? body, {required String path}) {
    final decoded = body is String ? jsonDecode(body) : body;
    if (decoded is! Map<String, dynamic>) {
      throw AppError('Expected JSON object response for $path', cause: decoded);
    }
    return decoded;
  }

  void _throwIfUnexpectedStatus(
    HttpResponse response, {
    required String path,
    Set<int> expectedStatusCodes = const {200},
  }) {
    if (!expectedStatusCodes.contains(response.statusCode)) {
      throw HttpAppError(
        message: _errorMessageFromBody(response.response),
        path: path,
        statusCode: response.statusCode,
        responseBody: response.response,
      );
    }
  }

  void _throwIfUnexpectedBinaryStatus(
    BinaryHttpResponse response, {
    required String path,
    Set<int> expectedStatusCodes = const {200},
  }) {
    if (!expectedStatusCodes.contains(response.statusCode)) {
      throw HttpAppError(
        message: _errorMessageFromBytes(response.bytes),
        path: path,
        statusCode: response.statusCode,
        responseBody: response.bytes,
      );
    }
  }

  String _errorMessageFromBody(Object? body) {
    final text = body is String ? body.trim() : '';
    return text.isEmpty ? 'Request failed' : text;
  }

  String _errorMessageFromBytes(List<int> bytes) {
    final text = utf8.decode(bytes, allowMalformed: true).trim();
    return text.isEmpty ? 'Request failed' : text;
  }

  String? _fileNameFromDisposition(String? disposition) {
    if (disposition == null || disposition.isEmpty) {
      return null;
    }

    final utf8Match = RegExp(
      r'''filename\*=UTF-8''([^;]+)''',
      caseSensitive: false,
    ).firstMatch(disposition);
    if (utf8Match != null) {
      return Uri.decodeComponent(utf8Match.group(1)!);
    }

    final simpleMatch = RegExp(
      r'filename="?([^";]+)"?',
      caseSensitive: false,
    ).firstMatch(disposition);
    return simpleMatch?.group(1);
  }
}
