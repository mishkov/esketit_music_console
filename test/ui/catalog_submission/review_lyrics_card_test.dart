import 'package:esketit_music_console/domain/track_lyrics.dart';
import 'package:esketit_music_console/ui/catalog_submission/review_lyrics_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final lyrics = TrackLyrics(
    trackId: 1,
    type: TrackLyricsType.synced,
    languageCode: 'en',
    isVerified: false,
    source: 'test',
    lines: List.generate(
      12,
      (index) => TrackLyricsLine(
        startMs: index * 2000 + 500,
        endMs: index * 2000 + 1500,
        text: 'Line $index',
      ),
    ),
  );

  test(
    'timing matches client semantics at boundaries, gaps and backward seeks',
    () {
      expect(lyrics.syncedLineIndexAt(Duration.zero), isNull);
      expect(lyrics.syncedLineIndexAt(const Duration(milliseconds: 500)), 0);
      expect(lyrics.syncedLineIndexAt(const Duration(milliseconds: 1499)), 0);
      expect(
        lyrics.syncedLineIndexAt(const Duration(milliseconds: 1500)),
        isNull,
      );
      expect(lyrics.syncedLineIndexAt(const Duration(milliseconds: 8500)), 4);
      expect(lyrics.syncedLineIndexAt(const Duration(milliseconds: 2500)), 1);
      expect(lyrics.syncedLineIndexAt(const Duration(seconds: 60)), isNull);
      const lastWithoutEnd = TrackLyrics(
        trackId: 1,
        type: TrackLyricsType.synced,
        languageCode: '',
        isVerified: false,
        source: '',
        lines: [TrackLyricsLine(startMs: 100, text: 'Last')],
      );
      expect(lastWithoutEnd.syncedLineIndexAt(const Duration(seconds: 60)), 0);
    },
  );

  testWidgets(
    'bounded lyrics follows position and dialog includes every line',
    (tester) async {
      final position = ValueNotifier(Duration.zero);
      addTearDown(position.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReviewLyricsCard(lyrics: lyrics, position: position),
          ),
        ),
      );
      expect(find.text('Line 0'), findsOneWidget);
      expect(find.text('Line 11'), findsNothing);
      position.value = const Duration(milliseconds: 12500);
      await tester.pumpAndSettle();
      expect(find.text('Line 0'), findsNothing);
      expect(find.text('Line 6'), findsOneWidget);
      final activeStyle = tester
          .widget<AnimatedDefaultTextStyle>(
            find.byKey(const ValueKey('review-lyric-line-6')),
          )
          .style;
      expect(activeStyle.fontWeight, FontWeight.w700);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is AnimatedDefaultTextStyle &&
              widget.key.toString().contains('review-lyric-line-'),
        ),
        findsNWidgets(5),
      );
      position.value = const Duration(milliseconds: 13500);
      await tester.pumpAndSettle();
      final gapStyle = tester
          .widget<AnimatedDefaultTextStyle>(
            find.byKey(const ValueKey('review-lyric-line-6')),
          )
          .style;
      expect(gapStyle.fontWeight, FontWeight.w400);
      position.value = const Duration(milliseconds: 2500);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<AnimatedDefaultTextStyle>(
              find.byKey(const ValueKey('review-lyric-line-1')),
            )
            .style
            .fontWeight,
        FontWeight.w700,
      );
      await tester.tap(find.byKey(const ValueKey('show-entire-lyrics')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<SelectableText>(find.byType(SelectableText)).data,
        contains('Line 11'),
      );
      position.value = const Duration(seconds: 60);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
