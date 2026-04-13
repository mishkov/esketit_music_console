import 'package:equatable/equatable.dart';

enum TrackLyricsType { plain, synced }

class TrackLyricsLine extends Equatable {
  const TrackLyricsLine({
    required this.startMs,
    this.endMs,
    required this.text,
  });

  final int startMs;
  final int? endMs;
  final String text;

  @override
  List<Object?> get props => [startMs, endMs, text];
}

class TrackLyrics extends Equatable {
  const TrackLyrics({
    required this.trackId,
    required this.type,
    required this.languageCode,
    required this.isVerified,
    required this.source,
    this.plainText,
    this.lines = const [],
  });

  final int trackId;
  final TrackLyricsType type;
  final String languageCode;
  final bool isVerified;
  final String source;
  final String? plainText;
  final List<TrackLyricsLine> lines;

  bool get isPlain => type == TrackLyricsType.plain;
  bool get isSynced => type == TrackLyricsType.synced;

  @override
  List<Object?> get props => [
    trackId,
    type,
    languageCode,
    isVerified,
    source,
    plainText,
    lines,
  ];
}

List<String> validateTrackLyrics(TrackLyrics lyrics) {
  final errors = <String>[];
  final plainText = lyrics.plainText?.trim() ?? '';

  switch (lyrics.type) {
    case TrackLyricsType.plain:
      if (plainText.isEmpty) {
        errors.add('Plain lyrics text is required.');
      }
      if (lyrics.lines.isNotEmpty) {
        errors.add('Plain lyrics cannot contain synced lines.');
      }
      break;
    case TrackLyricsType.synced:
      if (plainText.isNotEmpty) {
        errors.add('Synced lyrics cannot contain plain text.');
      }
      if (lyrics.lines.isEmpty) {
        errors.add('Synced lyrics must contain at least one line.');
      }
      for (var index = 0; index < lyrics.lines.length; index++) {
        final line = lyrics.lines[index];
        final lineNumber = index + 1;
        if (line.startMs < 0) {
          errors.add('Line $lineNumber start time must be 0 or greater.');
        }
        if (line.endMs != null && line.endMs! < line.startMs) {
          errors.add(
            'Line $lineNumber end time must be greater than or equal to the start time.',
          );
        }
        if (line.text.trim().isEmpty) {
          errors.add('Line $lineNumber text is required.');
        }
        if (index > 0 &&
            lyrics.lines[index - 1].startMs > lyrics.lines[index].startMs) {
          errors.add('Synced lyric lines must be ordered by start time.');
          break;
        }
      }
      break;
  }

  return errors;
}
