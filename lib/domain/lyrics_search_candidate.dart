import 'package:equatable/equatable.dart';
import 'package:esketit_music_console/domain/track_lyrics.dart';

class LyricsSearchCandidate extends Equatable {
  const LyricsSearchCandidate({
    required this.provider,
    required this.providerId,
    required this.source,
    required this.trackName,
    required this.artistName,
    required this.albumName,
    required this.durationMs,
    required this.instrumental,
    required this.plainText,
    required this.syncedLines,
  });

  final String provider;
  final int providerId;
  final String source;
  final String trackName;
  final String artistName;
  final String albumName;
  final int durationMs;
  final bool instrumental;
  final String? plainText;
  final List<TrackLyricsLine> syncedLines;

  bool get hasPlainLyrics => plainText?.trim().isNotEmpty ?? false;
  bool get hasSyncedLyrics => syncedLines.isNotEmpty;

  @override
  List<Object?> get props => [
    provider,
    providerId,
    source,
    trackName,
    artistName,
    albumName,
    durationMs,
    instrumental,
    plainText,
    syncedLines,
  ];
}
