import 'dart:convert';

import 'package:esketit_music_console/domain/track_lyrics.dart';

String parsePlainLyricsFile(List<int> bytes) {
  return _decodeText(bytes).trim();
}

List<TrackLyricsLine> parseLrcLyricsFile(List<int> bytes) {
  final content = _decodeText(bytes);
  final timestampPattern = RegExp(r'\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]');
  final parsedEntries = <({int startMs, String text})>[];

  for (final rawLine in const LineSplitter().convert(content)) {
    final matches = timestampPattern.allMatches(rawLine).toList();
    if (matches.isEmpty) {
      continue;
    }

    final text = rawLine.replaceAll(timestampPattern, '').trim();
    if (text.isEmpty) {
      continue;
    }

    for (final match in matches) {
      parsedEntries.add((startMs: _parseTimestampMs(match), text: text));
    }
  }

  if (parsedEntries.isEmpty) {
    throw const FormatException(
      'The selected LRC file does not contain timestamped lyric lines.',
    );
  }

  parsedEntries.sort((left, right) => left.startMs.compareTo(right.startMs));

  return List<TrackLyricsLine>.generate(parsedEntries.length, (index) {
    final current = parsedEntries[index];
    final next = index + 1 < parsedEntries.length
        ? parsedEntries[index + 1]
        : null;
    final endMs = next != null && next.startMs >= current.startMs
        ? next.startMs
        : null;
    return TrackLyricsLine(
      startMs: current.startMs,
      endMs: endMs,
      text: current.text,
    );
  });
}

String _decodeText(List<int> bytes) {
  final decoded = utf8.decode(bytes, allowMalformed: true);
  return decoded.startsWith('\ufeff') ? decoded.substring(1) : decoded;
}

int _parseTimestampMs(RegExpMatch match) {
  final minutes = int.parse(match.group(1)!);
  final seconds = int.parse(match.group(2)!);
  final fraction = match.group(3);
  final fractionMs = switch (fraction?.length ?? 0) {
    0 => 0,
    1 => int.parse(fraction!) * 100,
    2 => int.parse(fraction!) * 10,
    _ => int.parse(fraction!.substring(0, 3)),
  };

  return (minutes * 60 * 1000) + (seconds * 1000) + fractionMs;
}
