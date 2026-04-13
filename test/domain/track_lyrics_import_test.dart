import 'dart:convert';

import 'package:esketit_music_console/domain/track_lyrics_import.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parsePlainLyricsFile', () {
    test('trims surrounding whitespace', () {
      final result = parsePlainLyricsFile(utf8.encode('\n Hello world \n'));

      expect(result, 'Hello world');
    });
  });

  group('parseLrcLyricsFile', () {
    test('parses timestamped lines and infers end times', () {
      final result = parseLrcLyricsFile(
        utf8.encode('[00:00.00]First line\n[00:04.20]Second line\n'),
      );

      expect(result.length, 2);
      expect(result[0].startMs, 0);
      expect(result[0].endMs, 4200);
      expect(result[0].text, 'First line');
      expect(result[1].startMs, 4200);
      expect(result[1].endMs, isNull);
      expect(result[1].text, 'Second line');
    });

    test('ignores metadata tags and throws when no lyric timestamps exist', () {
      expect(
        () => parseLrcLyricsFile(utf8.encode('[ar:Artist]\n[ti:Song]\n')),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
