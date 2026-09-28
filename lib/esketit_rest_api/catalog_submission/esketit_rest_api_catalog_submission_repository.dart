import 'dart:convert';
import 'dart:typed_data';

import 'package:esketit_music_console/domain/catalog_submission.dart';
import 'package:esketit_music_console/domain/track_lyrics.dart';
import 'package:esketit_music_console/errors/http_app_error.dart';
import 'package:esketit_music_console/esketit_rest_api/http_client.dart';
import 'package:esketit_music_console/esketit_rest_api/http_response.dart';
import 'package:esketit_music_console/use_case/catalog_submission/catalog_submission_repository.dart';

class EsketitRestApiCatalogSubmissionRepository
    implements CatalogSubmissionRepository {
  const EsketitRestApiCatalogSubmissionRepository({
    required HttpClient httpClient,
  }) : _httpClient = httpClient;

  final HttpClient _httpClient;

  @override
  Future<CatalogSubmissionList> getOwnSubmissions() async {
    const path = '/catalog-submissions';
    final response = await _httpClient.get(path);
    _expect(response, path: path, statuses: const {200});
    return CatalogSubmissionList.fromJson(_map(response.response, path));
  }

  @override
  Future<CatalogSubmission> submitAuthor(AuthorSubmissionRequest request) =>
      _submissionPost(
        '/catalog-submissions/authors',
        body: request.toJson(),
        statuses: const {201},
      );

  @override
  Future<CatalogSubmission> submitAlbum(AlbumSubmissionRequest request) =>
      _submissionPost(
        '/catalog-submissions/albums',
        body: request.toJson(),
        statuses: const {201},
      );

  @override
  Future<CatalogSubmissionUpload> stageAudio({
    required String fileName,
    required List<int> bytes,
  }) async {
    const path = '/catalog-submissions/audio';
    final response = await _httpClient.postMultipart(
      path,
      fieldName: 'file',
      fileName: fileName,
      bytes: bytes,
    );
    _expect(response, path: path, statuses: const {201});
    return CatalogSubmissionUpload.fromJson(_map(response.response, path));
  }

  @override
  Future<CatalogSubmission> submitTrack(TrackSubmissionRequest request) =>
      _submissionPost(
        '/catalog-submissions/tracks',
        body: request.toJson(),
        statuses: const {201},
      );

  @override
  Future<CatalogSubmission> updateAuthor(
    int authorId,
    AuthorSubmissionRequest request,
  ) => _submissionPut(
    '/catalog-submissions/authors/$authorId',
    body: request.toJson(),
  );

  @override
  Future<CatalogSubmission> updateAlbum(
    int albumId,
    AlbumSubmissionRequest request,
  ) => _submissionPut(
    '/catalog-submissions/albums/$albumId',
    body: request.toJson(),
  );

  @override
  Future<CatalogSubmission> updateTrack(
    int trackId,
    TrackSubmissionRequest request,
  ) => _submissionPut(
    '/catalog-submissions/tracks/$trackId',
    body: request.toJson(),
  );

  @override
  Future<TrackLyrics> putTrackLyrics(int trackId, TrackLyrics lyrics) async {
    final path = '/catalog-submissions/tracks/$trackId/lyrics';
    final response = await _httpClient.put(path, body: _lyricsJson(lyrics));
    _expect(response, path: path, statuses: const {200, 201});
    return _lyricsFromJson(_map(response.response, path), trackId);
  }

  @override
  Future<CatalogSubmission> resubmit(int submissionId) => _submissionPost(
    '/catalog-submissions/$submissionId/resubmit',
    statuses: const {200},
  );

  @override
  Future<CatalogSubmission> cancel(int submissionId) async {
    final path = '/catalog-submissions/$submissionId';
    final response = await _httpClient.delete(path);
    _expect(response, path: path, statuses: const {200});
    return CatalogSubmission.fromJson(_map(response.response, path));
  }

  @override
  Future<List<CatalogReviewRequester>> getReviewRequesters() async {
    const path = '/catalog-reviews/requesters';
    final response = await _httpClient.get(path);
    _expect(response, path: path, statuses: const {200});
    return _maps(
      response.response,
      path,
    ).map(CatalogReviewRequester.fromJson).toList(growable: false);
  }

  @override
  Future<CatalogReviewLease> acquireLease(int requesterId) async {
    final path = '/catalog-reviews/requesters/$requesterId/lease';
    final response = await _httpClient.post(path);
    _expect(response, path: path, statuses: const {201});
    return CatalogReviewLease.fromJson(_map(response.response, path));
  }

  @override
  Future<CatalogReviewLease> renewLease(
    int requesterId,
    String leaseToken,
  ) async {
    final path = '/catalog-reviews/requesters/$requesterId/lease';
    final response = await _httpClient.put(
      path,
      headers: _leaseHeaders(leaseToken),
    );
    _expect(response, path: path, statuses: const {200});
    return CatalogReviewLease.fromJson(_map(response.response, path));
  }

  @override
  Future<void> releaseLease(int requesterId, String leaseToken) async {
    final path = '/catalog-reviews/requesters/$requesterId/lease';
    final response = await _httpClient.delete(
      path,
      headers: _leaseHeaders(leaseToken),
    );
    _expect(response, path: path, statuses: const {204});
  }

  @override
  Future<List<CatalogSubmission>> getReviewSubmissions(
    int requesterId,
    String leaseToken,
  ) async {
    final path = '/catalog-reviews/requesters/$requesterId/submissions';
    final response = await _httpClient.get(
      path,
      headers: _leaseHeaders(leaseToken),
    );
    _expect(response, path: path, statuses: const {200});
    return _maps(
      response.response,
      path,
    ).map(CatalogSubmission.fromJson).toList(growable: false);
  }

  @override
  Future<CatalogSubmission> approve(int submissionId, String leaseToken) =>
      _reviewDecision(submissionId, 'approve', leaseToken);

  @override
  Future<CatalogSubmission> requestChanges(
    int submissionId,
    String leaseToken,
    CatalogReviewDecision decision,
  ) => _reviewDecision(
    submissionId,
    'request-changes',
    leaseToken,
    body: decision.toJson(),
  );

  @override
  Future<CatalogSubmission> reject(
    int submissionId,
    String leaseToken,
    CatalogReviewDecision decision,
  ) => _reviewDecision(
    submissionId,
    'reject',
    leaseToken,
    body: decision.toJson(),
  );

  @override
  Future<CatalogAudioData> getStagedAudio(
    int trackId, {
    String? leaseToken,
  }) async {
    final path = '/catalog-submissions/tracks/$trackId/audio';
    final response = await _httpClient.getBinary(
      path,
      headers: leaseToken == null ? null : _leaseHeaders(leaseToken),
    );
    _expectBinary(response, path: path, statuses: const {200});
    return CatalogAudioData(
      bytes: Uint8List.fromList(response.bytes),
      contentType: response.contentType,
    );
  }

  Future<CatalogSubmission> _submissionPost(
    String path, {
    Object? body,
    required Set<int> statuses,
  }) async {
    final response = await _httpClient.post(path, body: body);
    _expect(response, path: path, statuses: statuses);
    return CatalogSubmission.fromJson(_map(response.response, path));
  }

  Future<CatalogSubmission> _submissionPut(
    String path, {
    required Object body,
  }) async {
    final response = await _httpClient.put(path, body: body);
    _expect(response, path: path, statuses: const {200});
    return CatalogSubmission.fromJson(_map(response.response, path));
  }

  Future<CatalogSubmission> _reviewDecision(
    int submissionId,
    String action,
    String leaseToken, {
    Object? body,
  }) async {
    final path = '/catalog-reviews/submissions/$submissionId/$action';
    final response = await _httpClient.post(
      path,
      headers: _leaseHeaders(leaseToken),
      body: body,
    );
    _expect(response, path: path, statuses: const {200});
    return CatalogSubmission.fromJson(_map(response.response, path));
  }

  static Map<String, String> _leaseHeaders(String token) => {
    'X-Review-Lease': token,
  };

  static void _expect(
    HttpResponse response, {
    required String path,
    required Set<int> statuses,
  }) {
    if (statuses.contains(response.statusCode)) return;
    throw HttpAppError(
      message: _errorMessage(response.response),
      path: path,
      statusCode: response.statusCode,
      responseBody: response.response,
    );
  }

  static void _expectBinary(
    BinaryHttpResponse response, {
    required String path,
    required Set<int> statuses,
  }) {
    if (statuses.contains(response.statusCode)) return;
    throw HttpAppError(
      message: 'Request failed',
      path: path,
      statusCode: response.statusCode,
    );
  }

  static String _errorMessage(Object? response) {
    if (response is String && response.trim().isNotEmpty) {
      return response.trim();
    }
    return 'Request failed';
  }

  static Map<String, dynamic> _map(Object? raw, String path) {
    final decoded = _decode(raw, path);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    throw FormatException('Expected an object from $path');
  }

  static List<Map<String, dynamic>> _maps(Object? raw, String path) {
    final decoded = _decode(raw, path);
    if (decoded is! List) throw FormatException('Expected a list from $path');
    return decoded
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  static Object? _decode(Object? raw, String path) {
    if (raw is! String) return raw;
    try {
      return jsonDecode(raw);
    } on FormatException catch (error) {
      throw FormatException('Invalid JSON from $path: ${error.message}');
    }
  }

  static Map<String, dynamic> _lyricsJson(TrackLyrics lyrics) => {
    'type': lyrics.type == TrackLyricsType.plain ? 'plain' : 'synced',
    if (lyrics.plainText != null) 'plainText': lyrics.plainText,
    if (lyrics.languageCode.trim().isNotEmpty)
      'languageCode': lyrics.languageCode.trim(),
    if (lyrics.source.trim().isNotEmpty) 'source': lyrics.source.trim(),
    'isVerified': lyrics.isVerified,
    'lines': lyrics.lines
        .map(
          (line) => {
            'startMs': line.startMs,
            if (line.endMs != null) 'endMs': line.endMs,
            'text': line.text,
          },
        )
        .toList(growable: false),
  };

  static TrackLyrics _lyricsFromJson(Map<String, dynamic> json, int trackId) =>
      TrackLyrics(
        trackId: (json['trackId'] as num?)?.toInt() ?? trackId,
        type: json['type'] == 'synced'
            ? TrackLyricsType.synced
            : TrackLyricsType.plain,
        languageCode: json['languageCode'] as String? ?? '',
        isVerified: json['isVerified'] as bool? ?? false,
        source: json['source'] as String? ?? '',
        plainText: json['plainText'] as String?,
        lines: (json['lines'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((raw) {
              final line = Map<String, dynamic>.from(raw);
              return TrackLyricsLine(
                startMs: (line['startMs'] as num?)?.toInt() ?? 0,
                endMs: (line['endMs'] as num?)?.toInt(),
                text: line['text'] as String? ?? '',
              );
            })
            .toList(growable: false),
      );
}
