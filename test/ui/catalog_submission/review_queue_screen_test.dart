import 'package:esketit_music_console/domain/catalog_submission.dart';
import 'package:esketit_music_console/ui/catalog_submission/review_queue_screen.dart';
import 'package:esketit_music_console/use_case/catalog_submission/catalog_submission_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('groups the queue and never exposes requester editing', (
    tester,
  ) async {
    final repository = _FakeReviewRepository();
    await tester.pumpWidget(
      RepositoryProvider<CatalogSubmissionRepository>.value(
        value: repository,
        child: const MaterialApp(
          home: Scaffold(body: ReviewQueueScreen(reviewerId: 8)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('requester@example.com'), findsOneWidget);
    expect(find.text('Pending: 1'), findsOneWidget);
    expect(find.text('Import rating: 10'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('start-review-7')));
    await tester.pumpAndSettle();

    expect(find.text('Reviewing requester@example.com'), findsOneWidget);
    expect(find.text('Track'), findsWidgets);
    expect(find.text('Edit'), findsNothing);
    expect(find.byKey(const ValueKey('approve-10')), findsOneWidget);
  });

  testWidgets('validates required feedback and non-negative penalty', (
    tester,
  ) async {
    final repository = _FakeReviewRepository();
    await tester.pumpWidget(
      RepositoryProvider<CatalogSubmissionRepository>.value(
        value: repository,
        child: const MaterialApp(
          home: Scaffold(body: ReviewQueueScreen(reviewerId: 8)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('start-review-7')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('request-changes-10')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('review-rating-penalty')),
          )
          .controller
          ?.text,
      '0',
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Request changes').last);
    await tester.pump();
    expect(find.text('Feedback message is required.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('review-feedback-message')),
      'Fix the author',
    );
    await tester.enterText(
      find.byKey(const ValueKey('review-rating-penalty')),
      '-1',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Request changes').last);
    await tester.pump();
    expect(
      find.text('Enter an integer that is zero or greater.'),
      findsOneWidget,
    );
    expect(repository.requestChangesCalls, 0);
  });
}

class _FakeReviewRepository extends Fake
    implements CatalogSubmissionRepository {
  int requestChangesCalls = 0;

  CatalogReviewRequester get requester => CatalogReviewRequester(
    userId: 7,
    email: 'requester@example.com',
    pendingCount: 1,
    importRating: 10,
    oldestPendingAt: DateTime.utc(2026, 9, 20),
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

  @override
  Future<List<CatalogReviewRequester>> getReviewRequesters() async => [
    requester,
  ];

  @override
  Future<CatalogReviewLease> acquireLease(int requesterId) async =>
      CatalogReviewLease(
        requesterUserId: 7,
        reviewerUserId: 8,
        leaseToken: 'widget-secret',
        acquiredAt: DateTime.utc(2026, 9, 26),
        heartbeatAt: DateTime.utc(2026, 9, 26),
        expiresAt: DateTime.utc(2099),
      );

  @override
  Future<List<CatalogSubmission>> getReviewSubmissions(
    int requesterId,
    String leaseToken,
  ) async => [submission];

  @override
  Future<CatalogSubmission> requestChanges(
    int submissionId,
    String leaseToken,
    CatalogReviewDecision decision,
  ) async {
    requestChangesCalls += 1;
    return submission;
  }

  @override
  Future<void> releaseLease(int requesterId, String leaseToken) async {}
}
