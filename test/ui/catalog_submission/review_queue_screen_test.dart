import 'package:esketit_music_console/domain/catalog_submission.dart';
import 'package:esketit_music_console/ui/catalog_submission/review_queue_screen.dart';
import 'package:esketit_music_console/ui/catalog_submission/staged_audio_player.dart';
import 'package:esketit_music_console/use_case/catalog_submission/catalog_submission_repository.dart';
import 'package:esketit_music_console/use_case/track/storage/tracks_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'shows author name and navigable photos without unsupported blocks',
    (tester) async {
      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<CatalogSubmissionRepository>.value(
              value: _FakeAuthorReviewRepository(),
            ),
            RepositoryProvider<TracksStorage>.value(value: _FakePhotoStorage()),
          ],
          child: const MaterialApp(
            home: Scaffold(body: ReviewQueueScreen(reviewerId: 8)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('start-review-7')));
      await tester.pumpAndSettle();

      final card = find.byKey(const ValueKey('author-information-card'));
      expect(card, findsOneWidget);
      expect(
        find.descendant(of: card, matching: find.text('The Full Author Name')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('additional-info-card')), findsNothing);
      expect(find.byKey(const ValueKey('source-metadata-card')), findsNothing);
      expect(find.byKey(const ValueKey('track-preview-card')), findsNothing);
      expect(find.text('1 of 2'), findsOneWidget);
      expect(
        tester
            .widget<Image>(find.byKey(const ValueKey('author-photo-image')))
            .image,
        isA<NetworkImage>().having(
          (image) => image.url,
          'url',
          'https://example.com/first.jpg',
        ),
      );

      await tester.tap(find.byKey(const ValueKey('next-author-photo')));
      await tester.pumpAndSettle();
      expect(find.text('2 of 2'), findsOneWidget);
      expect(
        (tester
                    .widget<Image>(
                      find.byKey(const ValueKey('author-photo-image')),
                    )
                    .image
                as NetworkImage)
            .url,
        'https://example.com/second.jpg',
      );
      await tester.tap(find.byKey(const ValueKey('open-author-photo')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('full-screen-author-photo')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('previous-full-screen-author-photo')),
      );
      await tester.pumpAndSettle();
      expect(find.text('1 of 2'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('close-author-photo')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('full-screen-author-photo')),
        findsNothing,
      );
    },
  );

  testWidgets('wraps source metadata within the card at desktop width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      RepositoryProvider<CatalogSubmissionRepository>.value(
        value: _FakeReviewRepository(),
        child: const MaterialApp(
          home: Scaffold(body: ReviewQueueScreen(reviewerId: 8)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('start-review-7')));
    await tester.pumpAndSettle();

    final card = find.byKey(const ValueKey('source-metadata-card'));
    await tester.scrollUntilVisible(
      card,
      200,
      scrollable: find.byType(Scrollable).first,
    );

    final url = find.text('https://music.youtube.com/watch?v=abc123');
    expect(
      find.descendant(
        of: card,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              (widget.axisDirection == AxisDirection.left ||
                  widget.axisDirection == AxisDirection.right),
        ),
      ),
      findsNothing,
    );
    expect(tester.getSize(url).height, greaterThan(24));
    expect(tester.getTopRight(url).dx, lessThan(tester.getTopRight(card).dx));
  });

  testWidgets(
    'stacks source metadata without horizontal overflow on narrow screens',
    (tester) async {
      tester.view.physicalSize = const Size(400, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        RepositoryProvider<CatalogSubmissionRepository>.value(
          value: _FakeReviewRepository(),
          child: const MaterialApp(
            home: Scaffold(body: ReviewQueueScreen(reviewerId: 8)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('start-review-7')));
      await tester.pumpAndSettle();

      final card = find.byKey(const ValueKey('source-metadata-card'));
      await tester.scrollUntilVisible(
        card,
        200,
        scrollable: find.byType(Scrollable).first,
      );

      expect(
        find.descendant(of: card, matching: find.byType(DataTable)),
        findsNothing,
      );
      expect(
        find.descendant(
          of: card,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                (widget.axisDirection == AxisDirection.left ||
                    widget.axisDirection == AxisDirection.right),
          ),
        ),
        findsNothing,
      );
      expect(find.text('Provider'), findsNWidgets(2));
      expect(
        find.text('https://music.youtube.com/watch?v=abc123'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'keeps the track preview player alive while it is scrolled away',
    (tester) async {
      tester.view.physicalSize = const Size(800, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = _FakeReviewRepository(includeSecondSubmission: true);
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

      final preview = find.byType(StagedAudioPlayer);
      await tester.scrollUntilVisible(
        preview,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      final playerState = tester.state(preview);
      final scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
      await tester.pumpAndSettle();

      expect(playerState.mounted, isTrue);

      scrollable.position.jumpTo(0);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        preview,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.state(preview), same(playerState));

      scrollable.position.jumpTo(0);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('next-review-submission')));
      await tester.pumpAndSettle();
      expect(playerState.mounted, isFalse);
    },
  );

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
    expect(find.text('Track information'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byKey(const ValueKey('track-information-card')),
        matching: find.byKey(const ValueKey('review-submission-10')),
      ),
      findsNothing,
    );
    expect(find.byType(ExpansionTile), findsNothing);
    expect(find.text('Edit'), findsNothing);
    final decisionBar = find.byKey(const ValueKey('review-decision-bar'));
    final reviewBounds = tester.getBottomRight(find.byType(ReviewQueueScreen));
    final barPosition = tester.getBottomRight(decisionBar);
    expect(barPosition.dx, closeTo(reviewBounds.dx - 16, 1));
    expect(barPosition.dy, closeTo(reviewBounds.dy - 16, 1));
    expect(find.byKey(const ValueKey('approve-10')), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('track-preview-card')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Track preview'), findsOneWidget);
    expect(find.byKey(const ValueKey('track-preview-card')), findsOneWidget);
    expect(
      tester
          .getTopLeft(find.byKey(const ValueKey('track-information-card')))
          .dy,
      lessThan(
        tester.getTopLeft(find.byKey(const ValueKey('track-preview-card'))).dy,
      ),
    );
    expect(
      find.ancestor(
        of: find.byKey(const ValueKey('staged-audio-progress-42')),
        matching: find.byKey(const ValueKey('review-submission-10')),
      ),
      findsNothing,
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('source-metadata-card')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Source metadata'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('additional-info-card'))).dy,
      lessThan(
        tester
            .getTopLeft(find.byKey(const ValueKey('source-metadata-card')))
            .dy,
      ),
    );
    expect(tester.widget<DataTable>(find.byType(DataTable)).rows, hasLength(2));
    expect(find.text('youtube_music'), findsOneWidget);
    expect(find.text('telegram'), findsOneWidget);
    expect(find.text('{"videoId":"abc123"}'), findsOneWidget);
    expect(
      find.text('https://music.youtube.com/watch?v=abc123'),
      findsOneWidget,
    );
    expect(
      find.ancestor(
        of: find.byKey(const ValueKey('source-metadata-card')),
        matching: find.byKey(const ValueKey('review-submission-10')),
      ),
      findsNothing,
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('additional-info-card')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Additional info'), findsOneWidget);
    expect(find.text('Credits'), findsOneWidget);
    expect(find.text('Recorded live'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('First take'), findsOneWidget);
    expect(find.text('Streaming link'), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('review-submission-10')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Raw JSON'), findsOneWidget);
    expect(find.textContaining('rawOnly'), findsNothing);
    await tester.tap(find.text('Raw JSON'));
    await tester.pumpAndSettle();
    expect(find.textContaining('rawOnly'), findsOneWidget);
    await tester.tap(find.text('Raw JSON'));
    await tester.pumpAndSettle();
    expect(find.textContaining('rawOnly'), findsNothing);
    expect(find.byKey(const ValueKey('approve-10')), findsOneWidget);
    expect(tester.getBottomRight(decisionBar), barPosition);
    expect(
      find.ancestor(
        of: decisionBar,
        matching: find.byKey(const ValueKey('review-submission-10')),
      ),
      findsNothing,
    );
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

  testWidgets('shows one submission and switches with the review header', (
    tester,
  ) async {
    final repository = _FakeReviewRepository(includeSecondSubmission: true);
    final selectedNames = <String?>[];
    await tester.pumpWidget(
      RepositoryProvider<CatalogSubmissionRepository>.value(
        value: repository,
        child: MaterialApp(
          home: Scaffold(
            body: ReviewQueueScreen(
              reviewerId: 8,
              onSelectedSubmissionChanged: selectedNames.add,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('start-review-7')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('review-navigation-header')),
      findsOneWidget,
    );
    expect(find.text('Submission #10'), findsOneWidget);
    expect(selectedNames.last, 'Track');
    expect(find.text('1 of 2'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('track-information-card')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('review-submission-11')), findsNothing);
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const ValueKey('previous-review-submission')),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const ValueKey('next-review-submission')));
    await tester.pumpAndSettle();

    expect(find.text('Submission #11'), findsOneWidget);
    expect(selectedNames.last, 'Second album');
    expect(find.text('2 of 2'), findsOneWidget);
    expect(find.byKey(const ValueKey('review-submission-10')), findsNothing);
    expect(find.byKey(const ValueKey('review-submission-11')), findsOneWidget);
    expect(find.byKey(const ValueKey('track-preview-card')), findsNothing);
    expect(find.byKey(const ValueKey('approve-10')), findsNothing);
    expect(find.byKey(const ValueKey('approve-11')), findsOneWidget);
    expect(find.text('Second album'), findsOneWidget);
    expect(find.text('Raw JSON'), findsOneWidget);
    expect(find.byType(ExpansionTile), findsOneWidget);
    expect(find.text('No text additional info.'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const ValueKey('next-review-submission')),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const ValueKey('end-review')));
    await tester.pumpAndSettle();
    expect(selectedNames.last, isNull);
    expect(find.byKey(const ValueKey('review-decision-bar')), findsNothing);
  });
}

class _FakeReviewRepository extends Fake
    implements CatalogSubmissionRepository {
  _FakeReviewRepository({this.includeSecondSubmission = false});

  final bool includeSecondSubmission;
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
    entity: const {
      'name': 'Track',
      'rawOnly': 'Visible only when expanded',
      'additionalInfo': [
        {'type': 'text', 'title': 'Credits', 'text': 'Recorded live'},
        {
          'type': 'external_link',
          'provider': 'music',
          'title': 'Streaming link',
          'url': 'https://example.com',
        },
        {'type': 'text', 'title': 'Notes', 'text': 'First take'},
      ],
      'sourceMetadata': [
        {
          'provider': 'youtube_music',
          'kind': 'stream',
          'identity': {'videoId': 'abc123'},
          'url': 'https://music.youtube.com/watch?v=abc123',
        },
        {
          'provider': 'telegram',
          'identity': {'messageId': 42},
        },
      ],
    },
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
  ) async => [
    submission,
    if (includeSecondSubmission)
      CatalogSubmission(
        id: 11,
        entityType: CatalogSubmissionEntityType.album,
        entityId: 43,
        requesterUserId: 7,
        status: CatalogSubmissionStatus.pendingReview,
        snapshot: const {'title': 'Second album'},
        entity: const {'title': 'Second album'},
        feedback: const [],
        createdAt: DateTime.utc(2026, 9, 26),
        submittedAt: DateTime.utc(2026, 9, 26),
        updatedAt: DateTime.utc(2026, 9, 26),
      ),
  ];

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

class _FakeAuthorReviewRepository extends _FakeReviewRepository {
  @override
  CatalogSubmission get submission => CatalogSubmission(
    id: 12,
    entityType: CatalogSubmissionEntityType.author,
    entityId: 44,
    requesterUserId: 7,
    status: CatalogSubmissionStatus.pendingReview,
    snapshot: const {},
    entity: const {
      'currentName': 'The Full Author Name',
      'photos': ['first.jpg', 'second.jpg'],
    },
    feedback: const [],
    createdAt: DateTime.utc(2026, 9, 26),
    submittedAt: DateTime.utc(2026, 9, 26),
    updatedAt: DateTime.utc(2026, 9, 26),
  );
}

class _FakePhotoStorage extends Fake implements TracksStorage {
  @override
  String resolveAuthorPhotoUrl(String photoPath) =>
      'https://example.com/$photoPath';
}
