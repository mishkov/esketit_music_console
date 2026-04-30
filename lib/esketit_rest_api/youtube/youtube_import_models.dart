import 'package:esketit_music_console/domain/track.dart';
import 'package:esketit_music_console/domain/track_source_metadata.dart';
import 'package:esketit_music_console/esketit_rest_api/track/track_json_parser.dart';

class YouTubeImportSession {
  const YouTubeImportSession({
    required this.sessionId,
    required this.status,
    required this.sourceType,
    required this.sourceUrl,
    required this.progress,
    required this.createdAt,
    required this.updatedAt,
    this.currentItem,
  });

  final String sessionId;
  final String status;
  final String sourceType;
  final String sourceUrl;
  final YouTubeImportProgress progress;
  final DateTime createdAt;
  final DateTime updatedAt;
  final YouTubeCurrentImportItem? currentItem;

  bool get isActive => status == 'active';

  bool get isCompleted => status == 'completed';

  factory YouTubeImportSession.fromJson(Map<String, dynamic> json) {
    return YouTubeImportSession(
      sessionId: (json['sessionId'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'active',
      sourceType: (json['sourceType'] as String?) ?? '',
      sourceUrl: (json['sourceUrl'] as String?) ?? '',
      progress: YouTubeImportProgress.fromJson(
        json['progress'] as Map<String, dynamic>? ?? const {},
      ),
      createdAt:
          DateTime.tryParse((json['createdAt'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      updatedAt:
          DateTime.tryParse((json['updatedAt'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      currentItem: json['currentItem'] is Map<String, dynamic>
          ? YouTubeCurrentImportItem.fromJson(
              json['currentItem'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

class YouTubeImportProgress {
  const YouTubeImportProgress({
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

  factory YouTubeImportProgress.fromJson(Map<String, dynamic> json) {
    return YouTubeImportProgress(
      total: (json['total'] as num?)?.toInt() ?? 0,
      processed: (json['processed'] as num?)?.toInt() ?? 0,
      remaining: (json['remaining'] as num?)?.toInt() ?? 0,
      skipped: (json['skipped'] as num?)?.toInt() ?? 0,
      saved: (json['saved'] as num?)?.toInt() ?? 0,
    );
  }
}

class YouTubeCurrentImportItem {
  const YouTubeCurrentImportItem({
    required this.sourceType,
    required this.sourceUrl,
    required this.originalSourceUrl,
    required this.videoId,
    required this.parsedTitle,
    required this.parsedAuthorNames,
    required this.suggestions,
    this.parsedAlbumTitle,
    this.parsedReleaseDate,
    this.coverImageUrl,
    this.durationSeconds,
  });

  final String sourceType;
  final String sourceUrl;
  final String originalSourceUrl;
  final String videoId;
  final String parsedTitle;
  final List<String> parsedAuthorNames;
  final String? parsedAlbumTitle;
  final DateTime? parsedReleaseDate;
  final String? coverImageUrl;
  final int? durationSeconds;
  final List<YouTubeImportSuggestion> suggestions;

  bool get hasExactSourceMatch =>
      suggestions.any((suggestion) => suggestion.type == 'exact_source_match');

  factory YouTubeCurrentImportItem.fromJson(Map<String, dynamic> json) {
    return YouTubeCurrentImportItem(
      sourceType: (json['sourceType'] as String?) ?? '',
      sourceUrl: (json['sourceUrl'] as String?) ?? '',
      originalSourceUrl: (json['originalSourceUrl'] as String?) ?? '',
      videoId: (json['videoId'] as String?) ?? '',
      parsedTitle: (json['parsedTitle'] as String?) ?? '',
      parsedAuthorNames:
          (json['parsedAuthorNames'] as List<dynamic>? ?? const [])
              .whereType<String>()
              .toList(),
      parsedAlbumTitle:
          (json['parsedAlbumTitle'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['parsedAlbumTitle'] as String).trim(),
      parsedReleaseDate: DateTime.tryParse(
        (json['parsedReleaseDate'] as String?) ?? '',
      ),
      coverImageUrl: (json['coverImageUrl'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['coverImageUrl'] as String).trim(),
      durationSeconds: (json['durationSeconds'] as num?)?.toInt(),
      suggestions: (json['suggestions'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(YouTubeImportSuggestion.fromJson)
          .toList(),
    );
  }
}

class YouTubeImportSuggestion {
  const YouTubeImportSuggestion({
    required this.type,
    required this.trackId,
    required this.confidence,
    required this.metadata,
  });

  final String type;
  final int trackId;
  final double confidence;
  final Map<String, Object?> metadata;

  bool get isExactSourceMatch => type == 'exact_source_match';

  factory YouTubeImportSuggestion.fromJson(Map<String, dynamic> json) {
    return YouTubeImportSuggestion(
      type: (json['type'] as String?) ?? '',
      trackId: (json['trackId'] as num?)?.toInt() ?? 0,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      metadata: jsonObjectFromDynamic(json['metadata']),
    );
  }
}

class YouTubeImportAddResponse {
  const YouTubeImportAddResponse({required this.session, required this.track});

  final YouTubeImportSession session;
  final Track track;

  factory YouTubeImportAddResponse.fromJson(
    Map<String, dynamic> json, {
    required Uri baseUri,
  }) {
    return YouTubeImportAddResponse(
      session: YouTubeImportSession.fromJson(
        json['session'] as Map<String, dynamic>? ?? const {},
      ),
      track: parseTrackJson(
        json['track'] as Map<String, dynamic>? ?? const {},
        baseUri: baseUri,
      ),
    );
  }
}
