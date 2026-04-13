import 'package:esketit_music_console/domain/track_lyrics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('validateTrackLyrics', () {
    test('requires plain text for plain lyrics', () {
      const lyrics = TrackLyrics(
        trackId: 1,
        type: TrackLyricsType.plain,
        languageCode: 'en',
        isVerified: true,
        source: 'artist',
        plainText: '   ',
      );

      expect(
        validateTrackLyrics(lyrics),
        contains('Plain lyrics text is required.'),
      );
    });

    test('validates synced lyrics ordering and line content', () {
      const lyrics = TrackLyrics(
        trackId: 1,
        type: TrackLyricsType.synced,
        languageCode: 'en',
        isVerified: false,
        source: 'artist',
        lines: [
          TrackLyricsLine(startMs: 1000, endMs: 500, text: 'First'),
          TrackLyricsLine(startMs: 900, text: '   '),
        ],
      );

      final errors = validateTrackLyrics(lyrics);

      expect(
        errors,
        contains(
          'Line 1 end time must be greater than or equal to the start time.',
        ),
      );
      expect(errors, contains('Line 2 text is required.'));
      expect(
        errors,
        contains('Synced lyric lines must be ordered by start time.'),
      );
    });
  });
}
