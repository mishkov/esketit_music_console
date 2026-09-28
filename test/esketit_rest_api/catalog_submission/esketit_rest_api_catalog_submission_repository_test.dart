import 'package:esketit_music_console/domain/catalog_submission.dart';
import 'package:esketit_music_console/errors/http_app_error.dart';
import 'package:esketit_music_console/esketit_rest_api/catalog_submission/esketit_rest_api_catalog_submission_repository.dart';
import 'package:esketit_music_console/esketit_rest_api/http_client.dart';
import 'package:esketit_music_console/esketit_rest_api/http_response.dart';
import 'package:esketit_music_console/use_case/catalog_submission/catalog_submission_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'parses personal history with status, feedback, snapshots, and rating',
    () async {
      final client = _RecordingClient(
        getResponses: {
          '/catalog-submissions': HttpResponse(
            statusCode: 200,
            response: {
              'items': [
                _submissionJson(
                  status: 'changes_requested',
                  feedback: const [
                    {
                      'id': 9,
                      'submissionId': 10,
                      'reviewerUserId': 3,
                      'kind': 'changes_requested',
                      'message': 'Correct the author',
                      'ratingPenalty': 2,
                      'createdAt': '2026-09-26T03:00:00Z',
                    },
                  ],
                ),
              ],
              'importRating': -2,
            },
          ),
        },
      );
      final repository = EsketitRestApiCatalogSubmissionRepository(
        httpClient: client,
      );

      final result = await repository.getOwnSubmissions();

      expect(result.importRating, -2);
      expect(
        result.items.single.status,
        CatalogSubmissionStatus.changesRequested,
      );
      expect(result.items.single.entityName, 'Track name');
      expect(result.items.single.feedback.single.message, 'Correct the author');
      expect(result.items.single.feedback.single.ratingPenalty, 2);
    },
  );

  test('executes author, album, audio, and track submission flow', () async {
    final client = _RecordingClient(
      postResponses: {
        '/catalog-submissions/authors': HttpResponse(
          statusCode: 201,
          response: _submissionJson(entityType: 'author', entityId: 21),
        ),
        '/catalog-submissions/albums': HttpResponse(
          statusCode: 201,
          response: _submissionJson(entityType: 'album', entityId: 22),
        ),
        '/catalog-submissions/tracks': HttpResponse(
          statusCode: 201,
          response: _submissionJson(entityType: 'track', entityId: 23),
        ),
      },
      multipartResponses: const {
        '/catalog-submissions/audio': HttpResponse(
          statusCode: 201,
          response: {
            'token': 'stage-token',
            'requesterUserId': 7,
            'originalName': 'song.mp3',
            'createdAt': '2026-09-26T01:00:00Z',
            'sizeBytes': 3,
          },
        ),
      },
    );
    final repository = EsketitRestApiCatalogSubmissionRepository(
      httpClient: client,
    );

    final author = await repository.submitAuthor(
      const AuthorSubmissionRequest(currentName: 'Artist'),
    );
    final album = await repository.submitAlbum(
      AlbumSubmissionRequest(
        title: 'Album',
        coverImagePath: '',
        authorIds: [author.entityId],
        releaseDate: DateTime.utc(2026, 9, 26),
        isPublished: true,
      ),
    );
    final upload = await repository.stageAudio(
      fileName: 'song.mp3',
      bytes: const [1, 2, 3],
    );
    await repository.submitTrack(
      TrackSubmissionRequest(
        name: 'Track',
        authorIds: [author.entityId],
        albumId: album.entityId,
        albumOrder: 0,
        audioUploadToken: upload.token,
      ),
    );

    expect(client.postBodies['/catalog-submissions/authors'], {
      'currentName': 'Artist',
      'photos': <String>[],
    });
    expect(
      (client.postBodies['/catalog-submissions/albums'] as Map)['trackIds'],
      isEmpty,
    );
    expect(client.multipartField, 'file');
    expect(client.multipartFileName, 'song.mp3');
    expect(client.postBodies['/catalog-submissions/tracks'], {
      'name': 'Track',
      'authorIds': [21],
      'albumId': 22,
      'albumOrder': 0,
      'audioUploadToken': 'stage-token',
      'additionalInfo': <Map<String, dynamic>>[],
      'sourceMetadata': <Map<String, dynamic>>[],
    });
  });

  test(
    'sends lease header for lifecycle, decisions, and staged audio',
    () async {
      final client = _RecordingClient(
        getResponses: {
          '/catalog-reviews/requesters': const HttpResponse(
            statusCode: 200,
            response: [
              {
                'user': {'id': 7, 'email': 'requester@example.com'},
                'pendingCount': 2,
                'importRating': 10,
                'oldestPendingAt': '2026-09-20T00:00:00Z',
              },
            ],
          ),
          '/catalog-reviews/requesters/7/submissions': HttpResponse(
            statusCode: 200,
            response: [_submissionJson()],
          ),
        },
        postResponses: {
          '/catalog-reviews/requesters/7/lease': const HttpResponse(
            statusCode: 201,
            response: _leaseJson,
          ),
          '/catalog-reviews/submissions/10/approve': HttpResponse(
            statusCode: 200,
            response: _submissionJson(status: 'approved'),
          ),
          '/catalog-reviews/submissions/10/request-changes': HttpResponse(
            statusCode: 200,
            response: _submissionJson(status: 'changes_requested'),
          ),
          '/catalog-reviews/submissions/10/reject': HttpResponse(
            statusCode: 200,
            response: _submissionJson(status: 'rejected'),
          ),
        },
        putResponses: const {
          '/catalog-reviews/requesters/7/lease': HttpResponse(
            statusCode: 200,
            response: _leaseJson,
          ),
        },
        deleteResponses: const {
          '/catalog-reviews/requesters/7/lease': HttpResponse(
            statusCode: 204,
            response: '',
          ),
        },
        binaryResponses: const {
          '/catalog-submissions/tracks/42/audio': BinaryHttpResponse(
            statusCode: 200,
            bytes: [1, 2],
            contentType: 'audio/mpeg',
          ),
        },
      );
      final repository = EsketitRestApiCatalogSubmissionRepository(
        httpClient: client,
      );

      expect((await repository.getReviewRequesters()).single.pendingCount, 2);
      final lease = await repository.acquireLease(7);
      await repository.renewLease(7, lease.leaseToken);
      await repository.getReviewSubmissions(7, lease.leaseToken);
      await repository.approve(10, lease.leaseToken);
      await repository.requestChanges(
        10,
        lease.leaseToken,
        const CatalogReviewDecision(message: 'Fix it'),
      );
      await repository.reject(
        10,
        lease.leaseToken,
        const CatalogReviewDecision(message: 'Invalid', ratingPenalty: 4),
      );
      await repository.getStagedAudio(42, leaseToken: lease.leaseToken);
      await repository.releaseLease(7, lease.leaseToken);

      for (final headers in client.leaseProtectedHeaders) {
        expect(headers['X-Review-Lease'], 'secret-token');
      }
      expect(
        client.postBodies['/catalog-reviews/submissions/10/request-changes'],
        {'message': 'Fix it', 'ratingPenalty': 0},
      );
      expect(client.postBodies['/catalog-reviews/submissions/10/reject'], {
        'message': 'Invalid',
        'ratingPenalty': 4,
      });
    },
  );

  test('preserves a plain-text 409 lease error', () async {
    final repository = EsketitRestApiCatalogSubmissionRepository(
      httpClient: _RecordingClient(
        postResponses: const {
          '/catalog-reviews/requesters/7/lease': HttpResponse(
            statusCode: 409,
            response: 'requester is already being reviewed',
          ),
        },
      ),
    );

    await expectLater(
      repository.acquireLease(7),
      throwsA(
        isA<HttpAppError>()
            .having((error) => error.statusCode, 'status', 409)
            .having(
              (error) => error.message,
              'message',
              'requester is already being reviewed',
            ),
      ),
    );
  });
}

const _leaseJson = {
  'requesterUserId': 7,
  'reviewerUserId': 8,
  'leaseToken': 'secret-token',
  'acquiredAt': '2026-09-26T01:00:00Z',
  'heartbeatAt': '2026-09-26T01:00:00Z',
  'expiresAt': '2026-09-26T01:10:00Z',
};

Map<String, dynamic> _submissionJson({
  String status = 'pending_review',
  String entityType = 'track',
  int entityId = 42,
  List<Map<String, dynamic>> feedback = const [],
}) => {
  'id': 10,
  'entityType': entityType,
  'entityId': entityId,
  'requesterUserId': 7,
  'status': status,
  'snapshot': {
    if (entityType == 'track') 'name': 'Track name',
    if (entityType == 'author') 'currentName': 'Artist',
    if (entityType == 'album') 'title': 'Album',
  },
  'entity': {
    if (entityType == 'track') 'name': 'Track name',
    if (entityType == 'author') 'currentName': 'Artist',
    if (entityType == 'album') 'title': 'Album',
  },
  'feedback': feedback,
  'createdAt': '2026-09-26T01:00:00Z',
  'submittedAt': '2026-09-26T01:00:00Z',
  'updatedAt': '2026-09-26T01:00:00Z',
};

class _RecordingClient implements HttpClient {
  _RecordingClient({
    this.getResponses = const {},
    this.postResponses = const {},
    this.putResponses = const {},
    this.deleteResponses = const {},
    this.multipartResponses = const {},
    this.binaryResponses = const {},
  });

  final Map<String, HttpResponse> getResponses;
  final Map<String, HttpResponse> postResponses;
  final Map<String, HttpResponse> putResponses;
  final Map<String, HttpResponse> deleteResponses;
  final Map<String, HttpResponse> multipartResponses;
  final Map<String, BinaryHttpResponse> binaryResponses;
  final Map<String, Object?> postBodies = {};
  final List<Map<String, String>> leaseProtectedHeaders = [];
  String? multipartField;
  String? multipartFileName;

  @override
  Future<HttpResponse> get(String path, {Map<String, String>? headers}) async {
    _recordHeaders(headers);
    return _response(getResponses, path);
  }

  @override
  Future<HttpResponse> post(
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    postBodies[path] = body;
    _recordHeaders(headers);
    return _response(postResponses, path);
  }

  @override
  Future<HttpResponse> put(
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    _recordHeaders(headers);
    return _response(putResponses, path);
  }

  @override
  Future<HttpResponse> delete(
    String path, {
    Map<String, String>? headers,
  }) async {
    _recordHeaders(headers);
    return _response(deleteResponses, path);
  }

  @override
  Future<HttpResponse> postMultipart(
    String path, {
    Map<String, String>? headers,
    required String fieldName,
    required String fileName,
    required List<int> bytes,
  }) async {
    multipartField = fieldName;
    multipartFileName = fileName;
    return _response(multipartResponses, path);
  }

  @override
  Future<BinaryHttpResponse> getBinary(
    String path, {
    Map<String, String>? headers,
  }) async {
    _recordHeaders(headers);
    final response = binaryResponses[path];
    if (response == null) throw StateError('No binary response for $path');
    return response;
  }

  HttpResponse _response(Map<String, HttpResponse> responses, String path) {
    final response = responses[path];
    if (response == null) throw StateError('No response for $path');
    return response;
  }

  void _recordHeaders(Map<String, String>? headers) {
    if (headers?.containsKey('X-Review-Lease') ?? false) {
      leaseProtectedHeaders.add(headers!);
    }
  }
}
