import 'dart:math' as math;

import 'package:esketit_music_console/domain/track_lyrics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A bounded view of the same timed lines used by the client player.
class ReviewLyricsCard extends StatelessWidget {
  const ReviewLyricsCard({
    super.key,
    required this.lyrics,
    required this.position,
  });

  final TrackLyrics lyrics;
  final ValueListenable<Duration> position;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      key: const ValueKey('review-lyrics-card'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lyrics_outlined, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  lyrics.isSynced ? 'Synced lyrics' : 'Lyrics',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton.icon(
                key: const ValueKey('show-entire-lyrics'),
                onPressed: () => _showEntireLyrics(context),
                icon: const Icon(Icons.open_in_full, size: 16),
                label: const Text('Entire lyrics'),
              ),
            ],
          ),
          const Divider(height: 24),
          if (lyrics.isSynced)
            ValueListenableBuilder<Duration>(
              valueListenable: position,
              builder: (context, playbackPosition, _) {
                final active = lyrics.syncedLineIndexAt(playbackPosition);
                // During instrumental gaps keep nearby context without highlighting.
                var anchor =
                    active ??
                    lyrics.lines.indexWhere(
                      (line) => line.startMs > playbackPosition.inMilliseconds,
                    );
                if (anchor < 0) anchor = lyrics.lines.length - 1;
                final first = math.max(0, anchor - 2);
                final last = math.min(lyrics.lines.length, anchor + 3);
                return SizedBox(
                  height: 220,
                  child: ClipRect(
                    child: SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var index = first; index < last; index++)
                            Semantics(
                              selected: index == active,
                              child: AnimatedDefaultTextStyle(
                                key: ValueKey('review-lyric-line-$index'),
                                duration: const Duration(milliseconds: 180),
                                style:
                                    (theme.textTheme.bodyLarge ??
                                            const TextStyle())
                                        .copyWith(
                                          color: index == active
                                              ? colors.primary
                                              : colors.onSurfaceVariant
                                                    .withValues(alpha: 0.65),
                                          fontWeight: index == active
                                              ? FontWeight.w700
                                              : FontWeight.w400,
                                          fontSize: index == active ? 21 : 16,
                                        ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    lyrics.lines[index].text,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            )
          else
            Text(
              lyrics.plainText ?? '',
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }

  Future<void> _showEntireLyrics(BuildContext context) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Entire lyrics'),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: SelectableText(
            lyrics.isSynced
                ? lyrics.lines.map((line) => line.text).join('\n\n')
                : lyrics.plainText ?? '',
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
