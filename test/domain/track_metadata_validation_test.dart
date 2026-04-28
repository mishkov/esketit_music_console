import 'package:esketit_music_console/domain/track_info/external_link_track_info.dart';
import 'package:esketit_music_console/domain/track_metadata_validation.dart';
import 'package:esketit_music_console/domain/track_source_metadata.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('validateTrackAdditionalInfo', () {
    test('requires provider and URL for external links', () {
      final errors = validateTrackAdditionalInfo([
        const ExternalLinkTrackInfo(provider: ' ', url: ''),
      ]);

      expect(errors, contains('External link 1 provider is required.'));
      expect(errors, contains('External link 1 URL is required.'));
    });
  });

  group('validateTrackSourceMetadata', () {
    test('requires provider and non-empty identity object', () {
      final errors = validateTrackSourceMetadata([
        const TrackSourceMetadata(provider: ' ', identity: {}),
      ]);

      expect(errors, contains('Source metadata 1 provider is required.'));
      expect(errors, contains('Source metadata 1 identity is required.'));
    });

    test('rejects empty URL when present', () {
      final errors = validateTrackSourceMetadata([
        const TrackSourceMetadata(
          provider: 'telegram',
          identity: {'messageId': '123'},
          url: '   ',
        ),
      ]);

      expect(
        errors,
        contains('Source metadata 1 URL cannot be empty when provided.'),
      );
    });

    test('rejects duplicate provider and identity pairs after normalization', () {
      final errors = validateTrackSourceMetadata([
        const TrackSourceMetadata(
          provider: ' YouTube_Music ',
          identity: {'videoId': ' abc123 ', 'region': ' BY '},
        ),
        const TrackSourceMetadata(
          provider: 'youtube_music',
          identity: {'region': 'BY', 'videoId': 'abc123'},
        ),
      ]);

      expect(
        errors,
        contains(
          'Source metadata 2 duplicates provider/identity pair for "youtube_music".',
        ),
      );
    });
  });
}
