class TelegramStatus {
  const TelegramStatus({
    required this.configured,
    required this.authorized,
    required this.passwordRequired,
    this.accountIdentifier,
    this.importTempDir,
    this.sessionStorageFile,
  });

  final bool configured;
  final bool authorized;
  final bool passwordRequired;
  final String? accountIdentifier;
  final String? importTempDir;
  final String? sessionStorageFile;

  factory TelegramStatus.fromJson(Map<String, dynamic> json) {
    return TelegramStatus(
      configured: json['configured'] as bool? ?? false,
      authorized: json['authorized'] as bool? ?? false,
      passwordRequired: json['passwordRequired'] as bool? ?? false,
      accountIdentifier: json['accountIdentifier'] as String?,
      importTempDir: json['importTempDir'] as String?,
      sessionStorageFile: json['sessionStorageFile'] as String?,
    );
  }
}

class TelegramImportSession {
  const TelegramImportSession({
    required this.sessionId,
    required this.status,
    required this.channelUsername,
    required this.progress,
    required this.createdAt,
    required this.updatedAt,
    this.currentTrack,
  });

  final String sessionId;
  final String status;
  final String channelUsername;
  final TelegramImportProgress progress;
  final DateTime createdAt;
  final DateTime updatedAt;
  final TelegramImportTrack? currentTrack;

  bool get isActive => status == 'active';

  bool get isCompleted => status == 'completed';

  factory TelegramImportSession.fromJson(Map<String, dynamic> json) {
    return TelegramImportSession(
      sessionId: (json['sessionId'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'active',
      channelUsername: (json['channelUsername'] as String?) ?? '',
      progress: TelegramImportProgress.fromJson(
        json['progress'] as Map<String, dynamic>? ?? const {},
      ),
      createdAt:
          DateTime.tryParse((json['createdAt'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          DateTime.tryParse((json['updatedAt'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      currentTrack: json['currentTrack'] is Map<String, dynamic>
          ? TelegramImportTrack.fromJson(
              json['currentTrack'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

class TelegramImportProgress {
  const TelegramImportProgress({
    required this.total,
    required this.processed,
    required this.remaining,
    required this.skipped,
    required this.saved,
  });

  final int total;
  final int processed;
  final int remaining;
  final int skipped;
  final int saved;

  factory TelegramImportProgress.fromJson(Map<String, dynamic> json) {
    return TelegramImportProgress(
      total: (json['total'] as num?)?.toInt() ?? 0,
      processed: (json['processed'] as num?)?.toInt() ?? 0,
      remaining: (json['remaining'] as num?)?.toInt() ?? 0,
      skipped: (json['skipped'] as num?)?.toInt() ?? 0,
      saved: (json['saved'] as num?)?.toInt() ?? 0,
    );
  }
}

class TelegramImportTrack {
  const TelegramImportTrack({
    required this.messageId,
    required this.telegramMessageLink,
    required this.parsedTitle,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    required this.tempFileDownloadUrl,
  });

  final int messageId;
  final String telegramMessageLink;
  final String parsedTitle;
  final String fileName;
  final String mimeType;
  final int sizeBytes;
  final String tempFileDownloadUrl;

  factory TelegramImportTrack.fromJson(Map<String, dynamic> json) {
    return TelegramImportTrack(
      messageId: (json['messageId'] as num?)?.toInt() ?? 0,
      telegramMessageLink: (json['telegramMessageLink'] as String?) ?? '',
      parsedTitle: (json['parsedTitle'] as String?) ?? '',
      fileName: (json['fileName'] as String?) ?? '',
      mimeType: (json['mimeType'] as String?) ?? '',
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      tempFileDownloadUrl: (json['tempFileDownloadUrl'] as String?) ?? '',
    );
  }
}
