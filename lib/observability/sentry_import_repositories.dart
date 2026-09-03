import 'package:esketit_music_console/domain/track_info/track_info.dart';
import 'package:esketit_music_console/domain/track_source_metadata.dart';
import 'package:esketit_music_console/errors/http_app_error.dart';
import 'package:esketit_music_console/esketit_rest_api/telegram/telegram_import_models.dart';
import 'package:esketit_music_console/esketit_rest_api/youtube/youtube_import_models.dart';
import 'package:esketit_music_console/use_case/telegram/telegram_import_repository.dart';
import 'package:esketit_music_console/use_case/youtube/youtube_import_repository.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class SentryImportOperationReporter {
  const SentryImportOperationReporter();

  Future<T> track<T>({
    required String source,
    required String operation,
    required Future<T> Function() run,
    Map<String, Object?> data = const {},
    Set<int> ignoredHttpStatusCodes = const {},
  }) async {
    final span = _startSpan(source: source, operation: operation, data: data);
    await _recordState(
      source: source,
      operation: operation,
      state: 'started',
      data: data,
    );

    try {
      final result = await run();
      await _recordState(
        source: source,
        operation: operation,
        state: 'completed',
        data: data,
      );
      await _finishSpan(span, const SpanStatus.ok());
      return result;
    } catch (error, stackTrace) {
      final status = _spanStatusFor(error);
      final isExpected =
          error is HttpAppError &&
          ignoredHttpStatusCodes.contains(error.statusCode);
      final failureData = <String, Object?>{
        ...data,
        'error_type': error.runtimeType.toString(),
        if (error is HttpAppError) 'http_status_code': error.statusCode,
        'expected': isExpected,
      };

      await _recordState(
        source: source,
        operation: operation,
        state: 'failed',
        data: failureData,
        level: isExpected ? SentryLevel.warning : SentryLevel.error,
      );
      if (!isExpected) {
        await _captureException(
          error: error,
          stackTrace: stackTrace,
          span: span,
          source: source,
          operation: operation,
          data: failureData,
        );
      }
      await _finishSpan(span, status, throwable: error);
      rethrow;
    }
  }

  ISentrySpan? _startSpan({
    required String source,
    required String operation,
    required Map<String, Object?> data,
  }) {
    try {
      final span =
          Sentry.getSpan()?.startChild(
            'import.$source',
            description: operation,
          ) ??
          Sentry.startTransaction(
            '$source.import.$operation',
            'import.$source',
          );
      span
        ..setTag('import.source', source)
        ..setTag('import.operation', operation);
      for (final entry in data.entries) {
        if (entry.value != null) {
          span.setData(entry.key, entry.value);
        }
      }
      return span;
    } catch (_) {
      return null;
    }
  }

  Future<void> _recordState({
    required String source,
    required String operation,
    required String state,
    required Map<String, Object?> data,
    SentryLevel level = SentryLevel.info,
  }) async {
    final eventData = <String, Object?>{
      'source': source,
      'operation': operation,
      'state': state,
      ...data,
    };

    try {
      await Sentry.addBreadcrumb(
        Breadcrumb(
          message: 'Import operation $state',
          category: 'import.$source',
          type: 'default',
          level: level,
          data: Map<String, dynamic>.from(eventData)
            ..removeWhere((_, value) => value == null),
        ),
      );
    } catch (_) {
      // Telemetry failures must never interrupt an import operation.
    }

    final attributes = <String, SentryAttribute>{};
    for (final entry in eventData.entries) {
      final attribute = _sentryAttribute(entry.value);
      if (attribute != null) {
        attributes['import.${entry.key}'] = attribute;
      }
    }

    try {
      switch (level) {
        case SentryLevel.fatal:
          await Sentry.logger.fatal(
            'Import operation $state',
            attributes: attributes,
          );
        case SentryLevel.error:
          await Sentry.logger.error(
            'Import operation $state',
            attributes: attributes,
          );
        case SentryLevel.warning:
          await Sentry.logger.warn(
            'Import operation $state',
            attributes: attributes,
          );
        case SentryLevel.debug:
          await Sentry.logger.debug(
            'Import operation $state',
            attributes: attributes,
          );
        case SentryLevel.info:
          await Sentry.logger.info(
            'Import operation $state',
            attributes: attributes,
          );
      }
    } catch (_) {
      // Telemetry failures must never interrupt an import operation.
    }
  }

  Future<void> _captureException({
    required Object error,
    required StackTrace stackTrace,
    required ISentrySpan? span,
    required String source,
    required String operation,
    required Map<String, Object?> data,
  }) async {
    try {
      await Sentry.captureException(
        error,
        stackTrace: stackTrace,
        withScope: (scope) async {
          scope.span = span;
          await scope.setTag('import.source', source);
          await scope.setTag('import.operation', operation);
          await scope.setContexts('import', <String, Object?>{
            'source': source,
            'operation': operation,
            ...data,
          });
        },
      );
    } catch (_) {
      // Preserve the original import error if Sentry reporting fails.
    }
  }

  Future<void> _finishSpan(
    ISentrySpan? span,
    SpanStatus status, {
    Object? throwable,
  }) async {
    if (span == null) {
      return;
    }
    try {
      span.throwable = throwable;
      await span.finish(status: status);
    } catch (_) {
      // Telemetry failures must never interrupt an import operation.
    }
  }

  SpanStatus _spanStatusFor(Object error) {
    if (error is HttpAppError) {
      return SpanStatus.fromHttpStatusCode(error.statusCode);
    }
    return const SpanStatus.internalError();
  }

  SentryAttribute? _sentryAttribute(Object? value) {
    return switch (value) {
      String value => SentryAttribute.string(value),
      bool value => SentryAttribute.bool(value),
      int value => SentryAttribute.int(value),
      double value => SentryAttribute.double(value),
      _ => null,
    };
  }
}

class SentryYouTubeImportRepository implements YouTubeImportRepository {
  SentryYouTubeImportRepository({
    required YouTubeImportRepository delegate,
    SentryImportOperationReporter reporter =
        const SentryImportOperationReporter(),
  }) : _delegate = delegate,
       _reporter = reporter;

  final YouTubeImportRepository _delegate;
  final SentryImportOperationReporter _reporter;

  @override
  Future<YouTubeImportSession?> getCurrentSession() {
    return _reporter.track(
      source: 'youtube',
      operation: 'get_current_session',
      run: _delegate.getCurrentSession,
    );
  }

  @override
  Future<YouTubeImportSession> startSession({
    required String url,
    DateTime? releaseDateCutoff,
    bool replaceExisting = false,
  }) {
    return _reporter.track(
      source: 'youtube',
      operation: 'start_session',
      data: {
        'has_release_date_cutoff': releaseDateCutoff != null,
        'replace_existing': replaceExisting,
      },
      ignoredHttpStatusCodes: replaceExisting ? const {} : const {409},
      run: () => _delegate.startSession(
        url: url,
        releaseDateCutoff: releaseDateCutoff,
        replaceExisting: replaceExisting,
      ),
    );
  }

  @override
  Future<YouTubeImportSession> skipCurrent() {
    return _reporter.track(
      source: 'youtube',
      operation: 'skip_current',
      run: _delegate.skipCurrent,
    );
  }

  @override
  Future<YouTubeImportAddResponse> addCurrentAsNew({
    required String name,
    required List<int> authorIds,
    required int albumId,
    required int albumOrder,
  }) {
    return _reporter.track(
      source: 'youtube',
      operation: 'add_current_as_new',
      data: {
        'name_length': name.length,
        'author_count': authorIds.length,
        'album_id': albumId,
        'album_order': albumOrder,
      },
      run: () => _delegate.addCurrentAsNew(
        name: name,
        authorIds: authorIds,
        albumId: albumId,
        albumOrder: albumOrder,
      ),
    );
  }

  @override
  Future<YouTubeImportAddResponse> attachCurrent({required int trackId}) {
    return _reporter.track(
      source: 'youtube',
      operation: 'attach_current',
      data: {'track_id': trackId},
      run: () => _delegate.attachCurrent(trackId: trackId),
    );
  }

  @override
  Future<void> cancelCurrentSession() {
    return _reporter.track(
      source: 'youtube',
      operation: 'cancel_current_session',
      run: _delegate.cancelCurrentSession,
    );
  }
}

class SentryTelegramImportRepository implements TelegramImportRepository {
  SentryTelegramImportRepository({
    required TelegramImportRepository delegate,
    SentryImportOperationReporter reporter =
        const SentryImportOperationReporter(),
  }) : _delegate = delegate,
       _reporter = reporter;

  final TelegramImportRepository _delegate;
  final SentryImportOperationReporter _reporter;

  @override
  Future<TelegramStatus> getStatus() {
    return _reporter.track(
      source: 'telegram',
      operation: 'get_status',
      run: _delegate.getStatus,
    );
  }

  @override
  Future<void> requestAuthCode({required String phoneNumber}) {
    return _reporter.track(
      source: 'telegram',
      operation: 'request_auth_code',
      run: () => _delegate.requestAuthCode(phoneNumber: phoneNumber),
    );
  }

  @override
  Future<TelegramStatus> confirmAuthCode({
    required String phoneNumber,
    required String code,
  }) {
    return _reporter.track(
      source: 'telegram',
      operation: 'confirm_auth_code',
      run: () =>
          _delegate.confirmAuthCode(phoneNumber: phoneNumber, code: code),
    );
  }

  @override
  Future<TelegramStatus> confirmPassword({required String password}) {
    return _reporter.track(
      source: 'telegram',
      operation: 'confirm_password',
      run: () => _delegate.confirmPassword(password: password),
    );
  }

  @override
  Future<TelegramImportSession?> getCurrentSession() {
    return _reporter.track(
      source: 'telegram',
      operation: 'get_current_session',
      run: _delegate.getCurrentSession,
    );
  }

  @override
  Future<TelegramImportSession> startSession({
    required String channelUsername,
    int? startMessageId,
    bool replaceExisting = false,
  }) {
    return _reporter.track(
      source: 'telegram',
      operation: 'start_session',
      data: {
        'has_start_message_id': startMessageId != null,
        'replace_existing': replaceExisting,
      },
      ignoredHttpStatusCodes: replaceExisting ? const {} : const {409},
      run: () => _delegate.startSession(
        channelUsername: channelUsername,
        startMessageId: startMessageId,
        replaceExisting: replaceExisting,
      ),
    );
  }

  @override
  Future<TelegramImportSession> skipCurrent() {
    return _reporter.track(
      source: 'telegram',
      operation: 'skip_current',
      run: _delegate.skipCurrent,
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
  }) {
    return _reporter.track(
      source: 'telegram',
      operation: 'save_current',
      data: {
        'name_length': name.length,
        'author_count': authorIds.length,
        'album_id': albumId,
        'album_order': albumOrder,
        'additional_info_count': additionalInfo.length,
        'source_metadata_count': sourceMetadata.length,
      },
      run: () => _delegate.saveCurrent(
        name: name,
        authorIds: authorIds,
        albumId: albumId,
        albumOrder: albumOrder,
        additionalInfo: additionalInfo,
        sourceMetadata: sourceMetadata,
      ),
    );
  }

  @override
  Future<void> cancelCurrentSession() {
    return _reporter.track(
      source: 'telegram',
      operation: 'cancel_current_session',
      run: _delegate.cancelCurrentSession,
    );
  }

  @override
  Future<DownloadedBinaryFile> downloadCurrentAudio() {
    return _reporter.track(
      source: 'telegram',
      operation: 'download_current_audio',
      run: _delegate.downloadCurrentAudio,
    );
  }

  @override
  Future<DownloadedBinaryFile> downloadSkippedReport() {
    return _reporter.track(
      source: 'telegram',
      operation: 'download_skipped_report',
      run: _delegate.downloadSkippedReport,
    );
  }
}
