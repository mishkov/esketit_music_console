import 'package:esketit_music_console/esketit_rest_api/telegram/telegram_import_models.dart';
import 'package:esketit_music_console/esketit_rest_api/youtube/youtube_import_models.dart';
import 'package:esketit_music_console/observability/sentry_import_repositories.dart';
import 'package:esketit_music_console/use_case/telegram/telegram_import_repository.dart';
import 'package:esketit_music_console/use_case/youtube/youtube_import_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('YouTube start is reported without exposing its URL', () async {
    final delegate = _FakeYouTubeImportRepository();
    final reporter = _RecordingReporter();
    final repository = SentryYouTubeImportRepository(
      delegate: delegate,
      reporter: reporter,
    );
    final cutoff = DateTime.utc(2025, 1, 2);

    await repository.startSession(
      url: 'https://music.youtube.com/watch?v=private-id',
      releaseDateCutoff: cutoff,
    );

    expect(delegate.startUrl, contains('private-id'));
    expect(delegate.releaseDateCutoff, cutoff);
    expect(reporter.records, hasLength(1));
    expect(reporter.records.single.source, 'youtube');
    expect(reporter.records.single.operation, 'start_session');
    expect(reporter.records.single.data, {
      'has_release_date_cutoff': true,
      'replace_existing': false,
    });
    expect(reporter.records.single.ignoredHttpStatusCodes, {409});
    expect(
      reporter.records.single.data.toString(),
      isNot(contains('private-id')),
    );
  });

  test('Telegram auth is reported without exposing credentials', () async {
    final delegate = _FakeTelegramImportRepository();
    final reporter = _RecordingReporter();
    final repository = SentryTelegramImportRepository(
      delegate: delegate,
      reporter: reporter,
    );

    await repository.requestAuthCode(phoneNumber: '+375-secret');
    await repository.confirmAuthCode(
      phoneNumber: '+375-secret',
      code: 'code-secret',
    );
    await repository.confirmPassword(password: 'password-secret');

    expect(delegate.phoneNumber, '+375-secret');
    expect(delegate.code, 'code-secret');
    expect(delegate.password, 'password-secret');
    expect(reporter.records.map((record) => record.operation), [
      'request_auth_code',
      'confirm_auth_code',
      'confirm_password',
    ]);
    expect(reporter.records.every((record) => record.data.isEmpty), isTrue);
    expect(
      reporter.records.toString(),
      isNot(anyOf(contains('+375-secret'), contains('code-secret'))),
    );
    expect(reporter.records.toString(), isNot(contains('password-secret')));
  });
}

class _RecordingReporter extends SentryImportOperationReporter {
  final records = <_OperationRecord>[];

  @override
  Future<T> track<T>({
    required String source,
    required String operation,
    required Future<T> Function() run,
    Map<String, Object?> data = const {},
    Set<int> ignoredHttpStatusCodes = const {},
  }) async {
    records.add(
      _OperationRecord(
        source: source,
        operation: operation,
        data: Map.unmodifiable(data),
        ignoredHttpStatusCodes: Set.unmodifiable(ignoredHttpStatusCodes),
      ),
    );
    return run();
  }
}

class _OperationRecord {
  const _OperationRecord({
    required this.source,
    required this.operation,
    required this.data,
    required this.ignoredHttpStatusCodes,
  });

  final String source;
  final String operation;
  final Map<String, Object?> data;
  final Set<int> ignoredHttpStatusCodes;

  @override
  String toString() => '$source $operation $data $ignoredHttpStatusCodes';
}

class _FakeYouTubeImportRepository implements YouTubeImportRepository {
  String? startUrl;
  DateTime? releaseDateCutoff;

  @override
  Future<YouTubeImportSession> startSession({
    required String url,
    DateTime? releaseDateCutoff,
    bool replaceExisting = false,
  }) async {
    startUrl = url;
    this.releaseDateCutoff = releaseDateCutoff;
    return _youTubeSession;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeTelegramImportRepository implements TelegramImportRepository {
  String? phoneNumber;
  String? code;
  String? password;

  @override
  Future<void> requestAuthCode({required String phoneNumber}) async {
    this.phoneNumber = phoneNumber;
  }

  @override
  Future<TelegramStatus> confirmAuthCode({
    required String phoneNumber,
    required String code,
  }) async {
    this.phoneNumber = phoneNumber;
    this.code = code;
    return _telegramStatus;
  }

  @override
  Future<TelegramStatus> confirmPassword({required String password}) async {
    this.password = password;
    return _telegramStatus;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _youTubeSession = YouTubeImportSession(
  sessionId: 'session-1',
  status: 'active',
  sourceType: 'track',
  sourceUrl: '',
  progress: const YouTubeImportProgress(
    total: 1,
    processed: 0,
    remaining: 1,
    skipped: 0,
    saved: 0,
  ),
  createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
);

const _telegramStatus = TelegramStatus(
  configured: true,
  authorized: true,
  passwordRequired: false,
);
