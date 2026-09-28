import 'package:esketit_music_console/domain/access_control.dart';
import 'package:esketit_music_console/domain/auth/app_user.dart';
import 'package:esketit_music_console/domain/auth/auth_session.dart';
import 'package:esketit_music_console/domain/catalog_submission.dart';
import 'package:esketit_music_console/ui/catalog_submission/my_submissions_screen.dart';
import 'package:esketit_music_console/use_case/auth/auth_repository.dart';
import 'package:esketit_music_console/use_case/auth/bloc/auth_bloc.dart';
import 'package:esketit_music_console/use_case/catalog_submission/catalog_submission_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the empty personal list and current rating', (
    tester,
  ) async {
    final repository = _FakeRepository(
      const CatalogSubmissionList(items: [], importRating: 4),
    );

    await _pump(tester, repository);

    expect(find.text('4'), findsOneWidget);
    expect(find.text('No submissions match this status.'), findsOneWidget);
  });

  testWidgets('renders statuses, feedback history, and retained snapshots', (
    tester,
  ) async {
    final repository = _FakeRepository(
      CatalogSubmissionList(
        items: [_submission(CatalogSubmissionStatus.rejected)],
        importRating: -3,
      ),
    );

    await _pump(tester, repository);
    await tester.tap(find.text('Track rejected'));
    await tester.pumpAndSettle();

    expect(find.text('Rejected'), findsWidgets);
    expect(find.text('Use the correct album'), findsOneWidget);
    expect(find.text('Retained snapshot'), findsOneWidget);
    expect(find.textContaining('Penalty 3'), findsOneWidget);
  });

  testWidgets('allows editing and explicit resubmission only after feedback', (
    tester,
  ) async {
    final repository = _FakeRepository(
      CatalogSubmissionList(
        items: [
          _submission(CatalogSubmissionStatus.pendingReview, id: 1),
          _submission(CatalogSubmissionStatus.changesRequested, id: 2),
        ],
        importRating: 0,
      ),
    );

    await _pump(tester, repository);
    await tester.tap(find.text('Track pending_review'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('resubmit-1')), findsNothing);
    await tester.tap(find.text('Track pending_review'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Track changes_requested'));
    await tester.tap(find.text('Track changes_requested'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(OutlinedButton, 'Edit'), findsOneWidget);
    expect(find.byKey(const ValueKey('resubmit-2')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('resubmit-2')));
    await tester.tap(find.byKey(const ValueKey('resubmit-2')));
    await tester.pumpAndSettle();

    expect(repository.resubmittedIds, [2]);
  });

  testWidgets('requires confirmation before cancellation', (tester) async {
    final repository = _FakeRepository(
      CatalogSubmissionList(
        items: [_submission(CatalogSubmissionStatus.pendingReview, id: 1)],
        importRating: 0,
      ),
    );

    await _pump(tester, repository);
    await tester.tap(find.text('Track pending_review'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel submission'));
    await tester.pumpAndSettle();

    expect(find.text('Cancel submission?'), findsOneWidget);
    expect(repository.cancelledIds, isEmpty);

    await tester.tap(find.widgetWithText(FilledButton, 'Cancel submission'));
    await tester.pumpAndSettle();
    expect(repository.cancelledIds, [1]);
  });
}

Future<void> _pump(WidgetTester tester, _FakeRepository repository) async {
  tester.view.physicalSize = const Size(1200, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final authBloc = AuthBloc(authRepository: _FakeAuthRepository())
    ..add(const AuthSessionRestoreRequested());
  addTearDown(authBloc.close);
  await tester.pumpWidget(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<CatalogSubmissionRepository>.value(
          value: repository,
        ),
      ],
      child: BlocProvider.value(
        value: authBloc,
        child: const MaterialApp(home: Scaffold(body: MySubmissionsScreen())),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

CatalogSubmission _submission(CatalogSubmissionStatus status, {int id = 10}) =>
    CatalogSubmission(
      id: id,
      entityType: CatalogSubmissionEntityType.track,
      entityId: 42 + id,
      requesterUserId: 7,
      status: status,
      snapshot: {'name': 'Track ${status.code}'},
      entity: status == CatalogSubmissionStatus.rejected
          ? const {}
          : {'name': 'Track ${status.code}'},
      feedback: status == CatalogSubmissionStatus.pendingReview
          ? const []
          : [
              CatalogSubmissionFeedback(
                id: 1,
                submissionId: id,
                reviewerUserId: 8,
                kind: status == CatalogSubmissionStatus.rejected
                    ? CatalogSubmissionStatus.rejected
                    : CatalogSubmissionStatus.changesRequested,
                message: 'Use the correct album',
                ratingPenalty: 3,
                createdAt: DateTime.utc(2026, 9, 26),
              ),
            ],
      createdAt: DateTime.utc(2026, 9, 26),
      submittedAt: DateTime.utc(2026, 9, 26),
      updatedAt: DateTime.utc(2026, 9, 26),
    );

class _FakeRepository extends Fake implements CatalogSubmissionRepository {
  _FakeRepository(this.result);

  CatalogSubmissionList result;
  final List<int> resubmittedIds = [];
  final List<int> cancelledIds = [];

  @override
  Future<CatalogSubmissionList> getOwnSubmissions() async => result;

  @override
  Future<CatalogSubmission> resubmit(int submissionId) async {
    resubmittedIds.add(submissionId);
    return result.items.firstWhere((item) => item.id == submissionId);
  }

  @override
  Future<CatalogSubmission> cancel(int submissionId) async {
    cancelledIds.add(submissionId);
    return result.items.firstWhere((item) => item.id == submissionId);
  }
}

class _FakeAuthRepository extends Fake implements AuthRepository {
  @override
  Future<AuthSession?> restoreSession() async => AuthSession(
    user: AppUser(
      id: 7,
      email: 'requester@example.com',
      createdAt: DateTime.utc(2026),
      roles: const [],
      permissions: [
        for (final (id, code) in <(int, String)>[
          (1, catalogSubmissionsReadOwnPermission),
          (2, catalogSubmissionsUpdateOwnPermission),
          (3, catalogSubmissionsCancelOwnPermission),
        ])
          AccessPermission(
            id: id,
            code: code,
            description: code,
            createdAt: DateTime.utc(2026),
          ),
      ],
    ),
    accessToken: 'token',
    accessTokenExpiresAt: DateTime.utc(2099),
    refreshToken: 'refresh',
    refreshTokenExpiresAt: DateTime.utc(2099),
  );
}
