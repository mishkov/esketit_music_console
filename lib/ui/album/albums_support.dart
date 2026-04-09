import 'package:esketit_music_console/domain/album.dart';
import 'package:esketit_music_console/use_case/track/storage/tracks_storage.dart';

const albumsBatchPageSize = 100;

Future<List<Album>> loadAllAlbums(
  TracksStorage storage, {
  int pageSize = albumsBatchPageSize,
  int? authorId,
  String? query,
  bool? isPublished,
}) async {
  final albums = <Album>[];
  var page = 1;

  while (true) {
    final chunk = await storage.getAlbumsList(
      page: page,
      pageSize: pageSize,
      authorId: authorId,
      query: query,
      isPublished: isPublished,
    );
    albums.addAll(chunk.albums);
    if (page >= chunk.totalPages || chunk.albums.length < pageSize) {
      return albums;
    }
    page += 1;
  }
}

Album? findBestMatchingAlbum(List<Album> albums, String rawTitle) {
  final normalizedQuery = normalizeAlbumTitle(rawTitle);
  if (normalizedQuery.isEmpty) {
    return null;
  }

  Album? exactMatch;
  Album? containsMatch;

  for (final album in albums) {
    final normalizedAlbumTitle = normalizeAlbumTitle(album.title);
    if (normalizedAlbumTitle == normalizedQuery) {
      exactMatch = album;
      break;
    }
    if (normalizedAlbumTitle.contains(normalizedQuery) ||
        normalizedQuery.contains(normalizedAlbumTitle)) {
      if (containsMatch != null) {
        containsMatch = null;
        continue;
      }
      containsMatch = album;
    }
  }

  return exactMatch ?? containsMatch;
}

String normalizeAlbumTitle(String value) {
  final collapsedWhitespace = value.trim().toLowerCase().replaceAll(
    RegExp(r'\s+'),
    ' ',
  );
  final lettersAndDigitsOnly = collapsedWhitespace.replaceAll(
    RegExp(r'[^\p{L}\p{N}]+', unicode: true),
    '',
  );
  return lettersAndDigitsOnly.replaceAll('ё', 'е');
}
