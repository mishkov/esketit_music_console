import 'package:esketit_music_console/domain/track_info/external_link_track_info.dart';
import 'package:esketit_music_console/domain/track_info/track_info.dart';
import 'package:esketit_music_console/domain/track_source_metadata.dart';

List<String> validateTrackAdditionalInfo(List<TrackInfo> additionalInfo) {
  final errors = <String>[];

  for (var index = 0; index < additionalInfo.length; index++) {
    final info = additionalInfo[index];
    final itemNumber = index + 1;

    if (info is ExternalLinkTrackInfo) {
      if (info.provider.trim().isEmpty) {
        errors.add('External link $itemNumber provider is required.');
      }
      if (info.url.trim().isEmpty) {
        errors.add('External link $itemNumber URL is required.');
      }
    }
  }

  return errors;
}

List<String> validateTrackSourceMetadata(
  List<TrackSourceMetadata> sourceMetadata,
) {
  final errors = <String>[];
  final seenPairs = <String>{};

  for (var index = 0; index < sourceMetadata.length; index++) {
    final item = sourceMetadata[index];
    final itemNumber = index + 1;
    final provider = item.provider.trim();
    final identity = item.normalizedIdentity;
    final normalizedUrl = item.normalizedUrl;

    if (provider.isEmpty) {
      errors.add('Source metadata $itemNumber provider is required.');
    }
    if (identity.isEmpty) {
      errors.add('Source metadata $itemNumber identity is required.');
    }
    if (item.url != null && normalizedUrl == null) {
      errors.add(
        'Source metadata $itemNumber URL cannot be empty when provided.',
      );
    }

    if (provider.isEmpty || identity.isEmpty) {
      continue;
    }

    final key =
        '${provider.toLowerCase()}::${canonicalizeJsonObject(identity)}';
    if (!seenPairs.add(key)) {
      errors.add(
        'Source metadata $itemNumber duplicates provider/identity pair for "$provider".',
      );
    }
  }

  return errors;
}
