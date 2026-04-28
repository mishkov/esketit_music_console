import 'package:esketit_music_console/domain/track_info/external_link_track_info.dart';
import 'package:esketit_music_console/domain/track_info/track_info.dart';
import 'package:esketit_music_console/domain/track_source_metadata.dart';
import 'package:esketit_music_console/ui/track/track_metadata_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders existing external link and source metadata', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _TrackMetadataEditorHarness(
            initialAdditionalInfo: const [
              ExternalLinkTrackInfo(
                provider: 'telegram',
                title: 'Telegram message',
                url: 'https://t.me/channel/123',
              ),
            ],
            initialSourceMetadata: const [
              TrackSourceMetadata(
                provider: 'telegram',
                kind: 'message',
                identity: {'chatId': 'channel_name', 'messageId': '123'},
                url: 'https://t.me/channel_name/123',
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Telegram message'), findsOneWidget);
    expect(find.textContaining('https://t.me/channel/123'), findsOneWidget);
    expect(find.text('telegram'), findsOneWidget);
    expect(
      find.textContaining('https://t.me/channel_name/123'),
      findsOneWidget,
    );
    expect(find.textContaining('"messageId": "123"'), findsOneWidget);
  });

  testWidgets('renders empty states and action buttons', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: _TrackMetadataEditorHarness())),
    );

    expect(find.text('No additional infos yet.'), findsOneWidget);
    expect(find.text('No source metadata yet.'), findsOneWidget);
    expect(find.text('Add additional info'), findsOneWidget);
    expect(find.text('Add source metadata'), findsOneWidget);
  });
}

class _TrackMetadataEditorHarness extends StatefulWidget {
  const _TrackMetadataEditorHarness({
    this.initialAdditionalInfo = const [],
    this.initialSourceMetadata = const [],
  });

  final List<TrackInfo> initialAdditionalInfo;
  final List<TrackSourceMetadata> initialSourceMetadata;

  @override
  State<_TrackMetadataEditorHarness> createState() =>
      _TrackMetadataEditorHarnessState();
}

class _TrackMetadataEditorHarnessState
    extends State<_TrackMetadataEditorHarness> {
  late List<TrackInfo> _additionalInfo = List<TrackInfo>.from(
    widget.initialAdditionalInfo,
  );
  late List<TrackSourceMetadata> _sourceMetadata =
      List<TrackSourceMetadata>.from(widget.initialSourceMetadata);

  @override
  Widget build(BuildContext context) {
    return TrackMetadataEditor(
      additionalInfo: _additionalInfo,
      sourceMetadata: _sourceMetadata,
      enabled: true,
      onAdditionalInfoChanged: (items) {
        setState(() {
          _additionalInfo = items;
        });
      },
      onSourceMetadataChanged: (items) {
        setState(() {
          _sourceMetadata = items;
        });
      },
    );
  }
}
