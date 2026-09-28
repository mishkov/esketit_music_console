import 'package:esketit_music_console/domain/author.dart';
import 'package:esketit_music_console/domain/catalog_publication_status.dart';
import 'package:esketit_music_console/domain/track.dart';
import 'package:esketit_music_console/esketit_rest_api/track/track_metadata_codec.dart';
import 'package:esketit_music_console/firebase/track/storage_file.dart';

Track parseTrackJson(
  Map<String, dynamic> json, {
  required Uri baseUri,
  Map<int, Author> authorsById = const {},
}) {
  final audioFilePath = (json['audioFilePath'] as String?) ?? '';
  final authorIds = (json['authorIds'] as List<dynamic>? ?? const [])
      .whereType<num>()
      .map((id) => id.toInt());

  return Track(
    id: (json['id'] as num?)?.toInt(),
    name: (json['name'] as String?) ?? '',
    authors: authorIds
        .map(
          (id) =>
              authorsById[id] ??
              Author(id: id, currentName: 'Unknown author #$id'),
        )
        .toList(),
    albumId: (json['albumId'] as num?)?.toInt() ?? 0,
    additionalInfo: parseTrackInfos(json['additionalInfo']),
    sourceMetadata: parseTrackSourceMetadata(json['sourceMetadata']),
    file: StorageFile(
      name: songFileName(audioFilePath),
      storagePath: audioFilePath,
      downloadUrl: songDownloadUrl(
        baseUri: baseUri,
        songReference: audioFilePath,
      ),
    ),
    publicationStatus: CatalogPublicationStatus.fromJson(
      json['publicationStatus'],
    ),
    requestedByUserId: (json['requestedByUserId'] as num?)?.toInt(),
  );
}

String songDownloadUrl({required Uri baseUri, required String songReference}) {
  final trimmed = songReference.trim();
  if (trimmed.isEmpty) {
    return baseUri.resolve('/api/songs/').toString();
  }
  final uri = Uri.tryParse(trimmed);
  if (uri != null && uri.hasScheme) {
    return trimmed;
  }
  if (trimmed.startsWith('/api/songs/')) {
    return baseUri.resolve(trimmed).toString();
  }
  return baseUri
      .resolve('/api/songs/${Uri.encodeComponent(trimmed)}')
      .toString();
}

String songFileName(String? songReference) {
  final trimmed = songReference?.trim() ?? '';
  if (trimmed.isEmpty) {
    return '';
  }

  final uri = Uri.tryParse(trimmed);
  if (uri != null && uri.hasScheme) {
    if (uri.pathSegments.isEmpty) {
      return trimmed;
    }
    return _decodeUriComponentIfPossible(uri.pathSegments.last);
  }
  if (trimmed.startsWith('/api/songs/')) {
    final withoutPrefix = trimmed.substring('/api/songs/'.length);
    return _decodeUriComponentIfPossible(withoutPrefix);
  }
  return _decodeUriComponentIfPossible(trimmed);
}

String _decodeUriComponentIfPossible(String value) {
  try {
    return Uri.decodeComponent(value);
  } on ArgumentError {
    return value;
  }
}
