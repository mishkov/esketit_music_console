import 'package:esketit_music_console/domain/track_info/external_link_track_info.dart';
import 'package:esketit_music_console/domain/track_info/text_track_info.dart';
import 'package:esketit_music_console/domain/track_info/track_info.dart';
import 'package:esketit_music_console/domain/track_source_metadata.dart';

List<TrackInfo> parseTrackInfos(Object? rawInfos) {
  return (rawInfos as List<dynamic>? ?? const [])
      .whereType<Map<String, dynamic>>()
      .map(parseTrackInfo)
      .whereType<TrackInfo>()
      .toList();
}

TrackInfo? parseTrackInfo(Map<String, dynamic> json) {
  switch (json['type']) {
    case 'text':
      return TextTrackInfo(
        title: (json['title'] as String?) ?? '',
        text: (json['text'] as String?) ?? '',
      );
    case 'external_link':
      return ExternalLinkTrackInfo(
        id: (json['id'] as String?)?.trim().isEmpty ?? true
            ? null
            : (json['id'] as String).trim(),
        provider: (json['provider'] as String?) ?? '',
        title: (json['title'] as String?)?.trim().isEmpty ?? true
            ? null
            : (json['title'] as String).trim(),
        url: (json['url'] as String?) ?? '',
      );
    default:
      return null;
  }
}

List<Map<String, dynamic>> serializeTrackInfos(List<TrackInfo> infos) {
  return infos
      .map(serializeTrackInfo)
      .whereType<Map<String, dynamic>>()
      .toList();
}

Map<String, dynamic>? serializeTrackInfo(TrackInfo info) {
  if (info is TextTrackInfo) {
    return {'type': 'text', 'title': info.title, 'text': info.text};
  }
  if (info is ExternalLinkTrackInfo) {
    return {
      if (info.id?.trim().isNotEmpty ?? false) 'id': info.id!.trim(),
      'type': 'external_link',
      'provider': info.provider.trim(),
      if (info.title?.trim().isNotEmpty ?? false) 'title': info.title!.trim(),
      'url': info.url.trim(),
    };
  }
  return null;
}

List<TrackSourceMetadata> parseTrackSourceMetadata(Object? rawMetadata) {
  return (rawMetadata as List<dynamic>? ?? const [])
      .whereType<Map<String, dynamic>>()
      .map(
        (json) => TrackSourceMetadata(
          provider: (json['provider'] as String?) ?? '',
          identity: jsonObjectFromDynamic(json['identity']),
          kind: (json['kind'] as String?)?.trim().isEmpty ?? true
              ? null
              : (json['kind'] as String).trim(),
          url: (json['url'] as String?)?.trim().isEmpty ?? true
              ? null
              : (json['url'] as String).trim(),
        ),
      )
      .toList();
}

List<Map<String, dynamic>> serializeTrackSourceMetadata(
  List<TrackSourceMetadata> sourceMetadata,
) {
  return sourceMetadata
      .map(
        (item) => {
          'provider': item.provider.trim(),
          'identity': normalizeJsonObject(item.identity),
          if (item.kind?.trim().isNotEmpty ?? false) 'kind': item.kind!.trim(),
          if (item.normalizedUrl != null) 'url': item.normalizedUrl,
        },
      )
      .toList();
}
