import 'dart:typed_data';

import 'package:esketit_music_console/domain/catalog_submission.dart';
import 'package:esketit_music_console/errors/http_app_error.dart';
import 'package:esketit_music_console/use_case/catalog_submission/catalog_review_controller.dart';
import 'package:esketit_music_console/use_case/catalog_submission/catalog_submission_repository.dart';
import 'package:esketit_music_console/use_case/catalog_submission/review_lease_token_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'acquires, stores, heartbeats, restores, and releases a lease',
    () async {
      final repository = _FakeRepository();
      final tokens = _MemoryTokens();
      final controller = CatalogReviewController(
        repository: repository,
        reviewerId: 8,
        tokenStore: tokens,
        heartbeatInterval: const Duration(milliseconds: 10),
      );
      addTearDown(controller.dispose);

      await controller.loadQueue();
      await controller.startReview(repository.requester);
      await Future<void>.delayed(const Duration(milliseconds: 35));

      expect(controller.hasActiveReview, isTrue);
      expect(tokens.value, 'secret');
      expect(repository.renewCalls, greaterThanOrEqualTo(1));
      expect(controller.submissions, hasLength(1));

      await controller.endReview();

      expect(repository.releaseCalls, 1);
      expect(tokens.value, isNull);
      expect(controller.hasActiveReview, isFalse);
    },
  );

  test('restores a reviewer-scoped token after refresh', () async {
    final repository = _FakeRepository(activeLeaseInQueue: true);
    final tokens = _MemoryTokens()..value = 'secret';
    final controller = CatalogReviewController(
      repository: repository,
      reviewerId: 8,
      tokenStore: tokens,
      heartbeatInterval: const Duration(hours: 1),
    );
    addTearDown(controller.dispose);

    await controller.loadQueue();

    expect(controller.hasActiveReview, isTrue);
    expect(repository.renewCalls, 1);
    expect(repository.submissionLoads, 1);
  });

  test('the Resume review action renews the saved lease', () async {
    final repository = _FakeRepository(activeLeaseInQueue: true);
    final tokens = _MemoryTokens()..value = 'secret';
    final controller = CatalogReviewController(
      repository: repository,
      reviewerId: 8,
      tokenStore: tokens,
      heartbeatInterval: const Duration(hours: 1),
    );

    await controller.startReview(repository.requester);

    expect(controller.hasActiveReview, isTrue);
    expect(repository.renewCalls, 1);
    expect(repository.acquireCalls, 0);
    expect(repository.submissionLoads, 1);

    controller.dispose();
    expect(repository.releaseCalls, 0);
    expect(tokens.value, 'secret');
  });

  test('an unrecoverable own lease reports the missing token', () async {
    final repository = _FakeRepository(
      activeLeaseInQueue: true,
      acquireConflict: true,
    );
    final controller = CatalogReviewController(
      repository: repository,
      reviewerId: 8,
      tokenStore: _MemoryTokens(),
    );
    addTearDown(controller.dispose);

    await controller.startReview(repository.requester);

    expect(controller.hasActiveReview, isFalse);
    expect(controller.notice, contains('no longer has its lease token'));
    expect(repository.acquireCalls, 1);
  });

  test('409 lease loss clears local state and refreshes the queue', () async {
    final repository = _FakeRepository(renewConflict: true);
    final tokens = _MemoryTokens();
    final controller = CatalogReviewController(
      repository: repository,
      reviewerId: 8,
      tokenStore: tokens,
      heartbeatInterval: const Duration(hours: 1),
    );
    addTearDown(controller.dispose);

    await controller.startReview(repository.requester);
    await controller.renewNow();

    expect(controller.hasActiveReview, isFalse);
    expect(tokens.value, isNull);
    expect(controller.notice, contains('lease was lost'));
    expect(repository.queueLoads, 1);
  });

  test(
    'validates feedback and refreshes after every confirmed decision',
    () async {
      final repository = _FakeRepository();
      final controller = CatalogReviewController(
        repository: repository,
        reviewerId: 8,
        tokenStore: _MemoryTokens(),
        heartbeatInterval: const Duration(hours: 1),
      );
      addTearDown(controller.dispose);
      await controller.startReview(repository.requester);

      await controller.decide(
        submission: repository.submission,
        action: CatalogReviewAction.requestChanges,
      );
      expect(controller.errorMessage, 'Feedback message is required.');
      expect(repository.requestChangesCalls, 0);

      await controller.decide(
        submission: repository.submission,
        action: CatalogReviewAction.reject,
        message: 'No',
        ratingPenalty: -1,
      );
      expect(
        controller.errorMessage,
        'Rating penalty must be zero or greater.',
      );
      expect(repository.rejectCalls, 0);

      await controller.decide(
        submission: repository.submission,
        action: CatalogReviewAction.approve,
      );
      await controller.decide(
        submission: repository.submission,
        action: CatalogReviewAction.requestChanges,
        message: 'Fix metadata',
      );
      await controller.decide(
        submission: repository.submission,
        action: CatalogReviewAction.reject,
        message: 'Not catalog content',
        ratingPenalty: 3,
      );

      expect(repository.approveCalls, 1);
      expect(repository.requestChangesCalls, 1);
      expect(repository.lastDecision?.ratingPenalty, 3);
      expect(repository.rejectCalls, 1);
      expect(repository.submissionLoads, 4);
      expect(repository.queueLoads, 3);
    },
  );

  for (final action in CatalogReviewAction.values) {
    test(
      '$action conflict preserves a valid review and the server error',
      () async {
        const message =
            'catalog submission has unresolved dependencies: review album and authors first';
        final repository = _FakeRepository()
          ..decisionError = const HttpAppError(
            message: 'Request failed',
            path: '/decision',
            statusCode: 409,
            responseBody: '$message\n',
          );
        final tokens = _MemoryTokens();
        final controller = CatalogReviewController(
          repository: repository,
          reviewerId: 8,
          tokenStore: tokens,
        );
        addTearDown(controller.dispose);
        await controller.startReview(repository.requester);

        await controller.decide(
          submission: repository.submission,
          action: action,
          message: 'Fix metadata',
        );

        expect(controller.hasActiveReview, isTrue);
        expect(controller.activeRequester?.userId, 7);
        expect(
          controller.submissions.single.status,
          CatalogSubmissionStatus.pendingReview,
        );
        expect(controller.leaseToken, 'secret');
        expect(tokens.value, 'secret');
        expect(controller.errorMessage, message);
        expect(controller.isMutating, isFalse);
        expect(controller.notice, isNull);
        expect(repository.submissionLoads, 2);
        expect(repository.queueLoads, 1);

        repository.decisionError = null;
        await controller.decide(
          submission: repository.submission,
          action: action,
          message: 'Fix metadata',
        );
        expect(controller.errorMessage, isNull);
        expect(controller.hasActiveReview, isTrue);
        expect(repository.submissionLoads, 3);
      },
    );
  }

  test(
    'decision conflict with a lost lease clears review but preserves error',
    () async {
      final repository = _FakeRepository()
        ..decisionError = const HttpAppError(
          message: 'review lease expired',
          path: '/approve',
          statusCode: 409,
        );
      final tokens = _MemoryTokens();
      final controller = CatalogReviewController(
        repository: repository,
        reviewerId: 8,
        tokenStore: tokens,
      );
      addTearDown(controller.dispose);
      await controller.startReview(repository.requester);
      repository.submissionsError = repository.decisionError;

      await controller.decide(
        submission: repository.submission,
        action: CatalogReviewAction.approve,
      );

      expect(controller.hasActiveReview, isFalse);
      expect(tokens.value, isNull);
      expect(controller.submissions, isEmpty);
      expect(controller.errorMessage, 'review lease expired');
      expect(controller.notice, contains('lease was lost'));
      expect(controller.isMutating, isFalse);
      expect(repository.queueLoads, 1);
    },
  );

  test('failed conflict refresh retains the original decision error', () async {
    final repository = _FakeRepository()
      ..decisionError = const HttpAppError(
        message: 'unresolved dependencies',
        path: '/approve',
        statusCode: 409,
      );
    final controller = CatalogReviewController(
      repository: repository,
      reviewerId: 8,
      tokenStore: _MemoryTokens(),
    );
    addTearDown(controller.dispose);
    await controller.startReview(repository.requester);
    repository.submissionsError = StateError('refresh failed');

    await controller.decide(
      submission: repository.submission,
      action: CatalogReviewAction.approve,
    );

    expect(controller.hasActiveReview, isTrue);
    expect(controller.errorMessage, 'unresolved dependencies');
    expect(controller.isMutating, isFalse);
  });
}

class _FakeRepository extends Fake implements CatalogSubmissionRepository {
  _FakeRepository({
    this.activeLeaseInQueue = false,
    this.renewConflict = false,
    this.acquireConflict = false,
  });

  final bool activeLeaseInQueue;
  final bool renewConflict;
  final bool acquireConflict;
  int acquireCalls = 0;
  int queueLoads = 0;
  int submissionLoads = 0;
  int renewCalls = 0;
  int releaseCalls = 0;
  int approveCalls = 0;
  int requestChangesCalls = 0;
  int rejectCalls = 0;
  CatalogReviewDecision? lastDecision;
  Object? decisionError;
  Object? submissionsError;

  CatalogReviewRequester get requester => CatalogReviewRequester(
    userId: 7,
    email: 'requester@example.com',
    pendingCount: 1,
    importRating: 0,
    oldestPendingAt: DateTime.utc(2026, 9, 26),
    activeLease: activeLeaseInQueue
        ? CatalogReviewLeaseStatus(
            reviewerUserId: 8,
            acquiredAt: DateTime.utc(2026, 9, 26),
            heartbeatAt: DateTime.utc(2026, 9, 26),
            expiresAt: DateTime.utc(2099),
          )
        : null,
  );

  CatalogSubmission get submission => CatalogSubmission(
    id: 10,
    entityType: CatalogSubmissionEntityType.track,
    entityId: 42,
    requesterUserId: 7,
    status: CatalogSubmissionStatus.pendingReview,
    snapshot: const {'name': 'Track'},
    entity: const {'name': 'Track'},
    feedback: const [],
    createdAt: DateTime.utc(2026, 9, 26),
    submittedAt: DateTime.utc(2026, 9, 26),
    updatedAt: DateTime.utc(2026, 9, 26),
  );

  CatalogReviewLease get lease => CatalogReviewLease(
    requesterUserId: 7,
    reviewerUserId: 8,
    leaseToken: 'secret',
    acquiredAt: DateTime.utc(2026, 9, 26),
    heartbeatAt: DateTime.utc(2026, 9, 26),
    expiresAt: DateTime.utc(2099),
  );

  @override
  Future<List<CatalogReviewRequester>> getReviewRequesters() async {
    queueLoads += 1;
    return [requester];
  }

  @override
  Future<CatalogReviewLease> acquireLease(int requesterId) async {
    acquireCalls += 1;
    if (acquireConflict) {
      throw const HttpAppError(
        message: 'requester is already being reviewed',
        path: '/lease',
        statusCode: 409,
      );
    }
    return lease;
  }

  @override
  Future<CatalogReviewLease> renewLease(
    int requesterId,
    String leaseToken,
  ) async {
    renewCalls += 1;
    if (renewConflict) {
      throw const HttpAppError(
        message: 'lease lost',
        path: '/lease',
        statusCode: 409,
      );
    }
    return lease;
  }

  @override
  Future<void> releaseLease(int requesterId, String leaseToken) async {
    releaseCalls += 1;
  }

  @override
  Future<List<CatalogSubmission>> getReviewSubmissions(
    int requesterId,
    String leaseToken,
  ) async {
    submissionLoads += 1;
    if (submissionsError != null) throw submissionsError!;
    return [submission];
  }

  @override
  Future<CatalogSubmission> approve(int submissionId, String leaseToken) async {
    approveCalls += 1;
    if (decisionError != null) throw decisionError!;
    return submission;
  }

  @override
  Future<CatalogSubmission> requestChanges(
    int submissionId,
    String leaseToken,
    CatalogReviewDecision decision,
  ) async {
    requestChangesCalls += 1;
    if (decisionError != null) throw decisionError!;
    lastDecision = decision;
    return submission;
  }

  @override
  Future<CatalogSubmission> reject(
    int submissionId,
    String leaseToken,
    CatalogReviewDecision decision,
  ) async {
    rejectCalls += 1;
    if (decisionError != null) throw decisionError!;
    lastDecision = decision;
    return submission;
  }

  @override
  Future<CatalogAudioData> getStagedAudio(
    int trackId, {
    String? leaseToken,
  }) async => CatalogAudioData(bytes: Uint8List.fromList(const [1]));
}

class _MemoryTokens implements ReviewLeaseTokenStore {
  String? value;

  @override
  String? read({required int reviewerId, required int requesterId}) => value;

  @override
  void remove({required int reviewerId, required int requesterId}) {
    value = null;
  }

  @override
  void write({
    required int reviewerId,
    required int requesterId,
    required String token,
  }) {
    value = token;
  }
}
