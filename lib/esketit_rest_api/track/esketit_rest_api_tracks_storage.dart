import 'dart:convert';

import 'package:esketit_music_console/domain/album.dart';
import 'package:esketit_music_console/domain/album_cover_suggestion.dart';
import 'package:esketit_music_console/domain/author.dart';
import 'package:esketit_music_console/domain/file/media_file_info.dart';
import 'package:esketit_music_console/domain/track.dart';
import 'package:esketit_music_console/domain/track_lyrics.dart';
import 'package:esketit_music_console/errors/album_cover_suggestions_unavailable_error.dart';
import 'package:esketit_music_console/errors/app_error.dart';
import 'package:esketit_music_console/errors/http_app_error.dart';
import 'package:esketit_music_console/esketit_rest_api/http_client.dart';
import 'package:esketit_music_console/esketit_rest_api/http_response.dart';
import 'package:esketit_music_console/esketit_rest_api/track/track_json_parser.dart';
import 'package:esketit_music_console/esketit_rest_api/track/track_metadata_codec.dart';
import 'package:esketit_music_console/firebase/track/storage_file.dart';
import 'package:esketit_music_console/unassigned_layer/cross_file.dart';
import 'package:esketit_music_console/use_case/track/storage/storage_albums_list.dart';
import 'package:esketit_music_console/use_case/track/storage/storage_tracks_list.dart';
import 'package:esketit_music_console/use_case/track/storage/tracks_storage.dart';

class EsketitRestApiTracksStorage implements TracksStorage {
  EsketitRestApiTracksStorage({
    required HttpClient authenticatedHttpClient,
    required Uri baseUri,
  }) : _authenticatedHttpClient = authenticatedHttpClient,
       _baseUri = baseUri;

  final HttpClient _authenticatedHttpClient;
  final Uri _baseUri;

  @override
  Future<StorageTracksList> getTracks({
    int page = 1,
    int pageSize = 20,
    String? query,
    int? authorId,
    int? albumId,
  }) async {
    final tracksResponse = await _authenticatedHttpClient.get(
      _withQueryParameters('/tracks', {
        'page': '$page',
        'pageSize': '$pageSize',
        if (query != null && query.trim().isNotEmpty) 'query': query.trim(),
        if (authorId != null) 'authorId': '$authorId',
        if (albumId != null) 'albumId': '$albumId',
      }),
    );
    _throwIfUnexpectedStatus(tracksResponse, path: '/tracks');
    final authorsById = await _getAuthorsById();
    final body = _decodeJsonMap(tracksResponse.response, path: '/tracks');

    final tracks = (body['items'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(
          (track) => parseTrackJson(
            track,
            baseUri: _baseUri,
            authorsById: authorsById,
          ),
        )
        .toList();

    return StorageTracksList(
      tracks: tracks,
      page: (body['page'] as num?)?.toInt() ?? page,
      pageSize: (body['pageSize'] as num?)?.toInt() ?? pageSize,
      totalItems: (body['totalItems'] as num?)?.toInt() ?? tracks.length,
      totalPages: (body['totalPages'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Future<List<Album>> getAlbums({
    int page = 1,
    int pageSize = 100,
    int? authorId,
    String? query,
    bool? isPublished,
  }) async {
    final albumsList = await getAlbumsList(
      page: page,
      pageSize: pageSize,
      authorId: authorId,
      query: query,
      isPublished: isPublished,
    );
    return albumsList.albums;
  }

  @override
  Future<StorageAlbumsList> getAlbumsList({
    int page = 1,
    int pageSize = 100,
    int? authorId,
    String? query,
    bool? isPublished,
  }) async {
    final response = await _authenticatedHttpClient.get(
      _withQueryParameters('/albums', {
        'page': '$page',
        'pageSize': '$pageSize',
        if (authorId != null) 'authorId': '$authorId',
        if (query != null && query.trim().isNotEmpty) 'query': query.trim(),
        if (isPublished != null) 'isPublished': '$isPublished',
      }),
    );
    _throwIfUnexpectedStatus(response, path: '/albums');

    final authorsById = await _getAuthorsById();
    final body = _decodeJsonMap(response.response, path: '/albums');
    final items = (body['items'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>();

    final albums = items
        .map((album) => _parseAlbum(album, authorsById))
        .toList();
    return StorageAlbumsList(
      albums: albums,
      page: (body['page'] as num?)?.toInt() ?? page,
      pageSize: (body['pageSize'] as num?)?.toInt() ?? pageSize,
      totalItems: (body['totalItems'] as num?)?.toInt() ?? albums.length,
      totalPages: (body['totalPages'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Future<Album> getAlbum(int id) async {
    final response = await _authenticatedHttpClient.get('/albums/$id');
    _throwIfUnexpectedStatus(response, path: '/albums/$id');
    return _parseAlbum(
      _decodeJsonMap(response.response, path: '/albums/$id'),
      await _getAuthorsById(),
    );
  }

  @override
  Future<Album> createAlbum(Album album) async {
    final response = await _authenticatedHttpClient.post(
      '/albums',
      body: _serializeAlbum(album),
    );
    _throwIfUnexpectedStatus(
      response,
      path: '/albums',
      expectedStatusCodes: {201},
    );
    return _parseAlbum(
      _decodeJsonMap(response.response, path: '/albums'),
      await _getAuthorsById(),
    );
  }

  @override
  Future<Album> updateAlbum(Album album) async {
    final id = album.id;
    if (id == null) {
      throw const AppError('Album ID is required for update');
    }

    final response = await _authenticatedHttpClient.put(
      '/albums/$id',
      body: _serializeAlbum(album),
    );
    _throwIfUnexpectedStatus(response, path: '/albums/$id');
    return _parseAlbum(
      _decodeJsonMap(response.response, path: '/albums/$id'),
      await _getAuthorsById(),
    );
  }

  @override
  Future<List<Track>> getAlbumTracks(int albumId) async {
    final response = await _authenticatedHttpClient.get(
      '/albums/$albumId/tracks',
    );
    _throwIfUnexpectedStatus(response, path: '/albums/$albumId/tracks');
    final authorsById = await _getAuthorsById();
    return _decodeJsonListOfMaps(
          response.response,
          path: '/albums/$albumId/tracks',
        )
        .map(
          (track) => parseTrackJson(
            track,
            baseUri: _baseUri,
            authorsById: authorsById,
          ),
        )
        .toList();
  }

  @override
  Future<void> deleteAlbum(int id) async {
    final response = await _authenticatedHttpClient.delete('/albums/$id');
    _throwIfUnexpectedStatus(
      response,
      path: '/albums/$id',
      expectedStatusCodes: {204},
    );
  }

  @override
  Future<List<MediaFileInfo>> getUnusedSongs() async {
    final response = await _authenticatedHttpClient.get('/songs/unused');
    _throwIfUnexpectedStatus(response, path: '/songs/unused');
    return _decodeJsonListOfMaps(
      response.response,
      path: '/songs/unused',
    ).map(_parseMediaFileInfo).toList();
  }

  @override
  Future<void> deleteSongFile(String songReference) async {
    await _deleteSongFileIfPossible(
      songReference,
      ignoreReferencedOrMissing: false,
    );
  }

  @override
  Future<String> uploadAlbumCover(Object file) async {
    final uploaded = await _uploadBinaryFile(
      path: '/album-covers',
      file: file,
      fallbackGetPathPrefix: '/api/album-covers/',
    );
    return uploaded.name;
  }

  @override
  String resolveAlbumCoverUrl(String coverImagePath) {
    final trimmedPath = coverImagePath.trim();
    if (trimmedPath.isEmpty) {
      return '';
    }

    final absoluteUri = Uri.tryParse(trimmedPath);
    if (absoluteUri != null && absoluteUri.hasScheme) {
      return absoluteUri.toString();
    }

    final normalizedPath = _normalizeRelativeMediaPath(
      trimmedPath.startsWith('/api/album-covers/')
          ? trimmedPath
          : '/api/album-covers/$trimmedPath',
    );
    return _baseUri.resolve(normalizedPath).toString();
  }

  @override
  Future<List<AlbumCoverSuggestion>> searchAlbumCoverSuggestions(
    String query,
  ) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      return const [];
    }

    final response = await _authenticatedHttpClient.get(
      _withQueryParameters('/album-covers/suggestions', {
        'query': trimmedQuery,
        'limit': '20',
      }),
    );

    if (response.statusCode == 404 || response.statusCode == 501) {
      throw const AlbumCoverSuggestionsUnavailableError();
    }

    _throwIfUnexpectedStatus(response, path: '/album-covers/suggestions');

    final body = _decodeJsonMap(
      response.response,
      path: '/album-covers/suggestions',
    );
    final items = (body['items'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>();
    return items.map(_parseAlbumCoverSuggestion).toList();
  }

  @override
  Future<String> importAlbumCoverFromUrl({
    required String imageUrl,
    String? suggestedFileName,
  }) async {
    final response = await _authenticatedHttpClient.post(
      '/album-covers/import',
      body: {
        'imageUrl': imageUrl,
        if (suggestedFileName != null && suggestedFileName.trim().isNotEmpty)
          'suggestedFileName': suggestedFileName.trim(),
      },
    );

    if (response.statusCode == 404 || response.statusCode == 501) {
      throw const AlbumCoverSuggestionsUnavailableError(
        'Album cover import is not available yet. Add the backend import endpoint first.',
      );
    }

    _throwIfUnexpectedStatus(
      response,
      path: '/album-covers/import',
      expectedStatusCodes: {201},
    );

    final body = _decodeJsonMap(
      response.response,
      path: '/album-covers/import',
    );
    return (body['name'] as String?) ?? '';
  }

  @override
  Future<List<Author>> getAuthors() async {
    final authorMaps = await _getAuthorMaps();
    return authorMaps
        .map(_parseAuthor)
        .where((author) => author.currentName.trim().isNotEmpty)
        .toList();
  }

  @override
  Future<Author> getAuthor(int id) async {
    final response = await _authenticatedHttpClient.get('/authors/$id');
    _throwIfUnexpectedStatus(response, path: '/authors/$id');
    return _parseAuthor(
      _decodeJsonMap(response.response, path: '/authors/$id'),
    );
  }

  @override
  Future<Author> createAuthor(Author author) async {
    final response = await _authenticatedHttpClient.post(
      '/authors',
      body: {'currentName': author.currentName, 'photos': author.photos},
    );
    _throwIfUnexpectedStatus(
      response,
      path: '/authors',
      expectedStatusCodes: {201},
    );
    return _parseAuthor(_decodeJsonMap(response.response, path: '/authors'));
  }

  @override
  Future<Author> updateAuthor(Author author) async {
    final id = author.id;
    if (id == null) {
      throw const AppError('Author ID is required for update');
    }

    final response = await _authenticatedHttpClient.put(
      '/authors/$id',
      body: {'currentName': author.currentName, 'photos': author.photos},
    );
    _throwIfUnexpectedStatus(response, path: '/authors/$id');
    return _parseAuthor(
      _decodeJsonMap(response.response, path: '/authors/$id'),
    );
  }

  @override
  Future<void> deleteAuthor(int id) async {
    final response = await _authenticatedHttpClient.delete('/authors/$id');
    _throwIfUnexpectedStatus(
      response,
      path: '/authors/$id',
      expectedStatusCodes: {204},
    );
  }

  @override
  Future<void> putTrack(Track track) async {
    if (track.albumOrder == null) {
      throw const AppError('Album order is required for track creation');
    }

    final uploadedSong = await _uploadBinaryFile(
      path: '/songs',
      file: track.file,
      fallbackGetPathPrefix: '/api/songs/',
    );
    final authorIds = await _resolveAuthorIds(track.authors);

    try {
      final response = await _authenticatedHttpClient.post(
        '/tracks',
        body: {
          'name': track.name,
          'authorIds': authorIds,
          'albumId': track.albumId,
          'albumOrder': track.albumOrder,
          'audioFilePath': uploadedSong.name,
          'additionalInfo': serializeTrackInfos(track.additionalInfo),
          'sourceMetadata': serializeTrackSourceMetadata(track.sourceMetadata),
        },
      );
      _throwIfUnexpectedStatus(
        response,
        path: '/tracks',
        expectedStatusCodes: {201},
      );
    } catch (_) {
      await _deleteSongFileIfPossible(
        uploadedSong.name,
        ignoreReferencedOrMissing: true,
      );
      rethrow;
    }
  }

  @override
  Future<Track> getTrack(int id) async {
    final response = await _authenticatedHttpClient.get('/tracks/$id');
    _throwIfUnexpectedStatus(response, path: '/tracks/$id');
    return parseTrackJson(
      _decodeJsonMap(response.response, path: '/tracks/$id'),
      baseUri: _baseUri,
      authorsById: await _getAuthorsById(),
    );
  }

  @override
  Future<Track> updateTrack(Track track) async {
    final id = track.id;
    if (id == null) {
      throw const AppError('Track ID is required for update');
    }
    final albumOrder = track.albumOrder;
    if (albumOrder == null) {
      throw const AppError('Album order is required for update');
    }

    final existingTrack = await getTrack(id);
    final previousSongReference = _songReferenceFromFile(existingTrack.file);
    final uploadedSong = await _uploadBinaryFile(
      path: '/songs',
      file: track.file,
      fallbackGetPathPrefix: '/api/songs/',
    );
    final authorIds = await _resolveAuthorIds(track.authors);

    try {
      final response = await _authenticatedHttpClient.put(
        '/tracks/$id',
        body: {
          'name': track.name,
          'authorIds': authorIds,
          'albumId': track.albumId,
          'albumOrder': albumOrder,
          'audioFilePath': uploadedSong.name,
          'additionalInfo': serializeTrackInfos(track.additionalInfo),
          'sourceMetadata': serializeTrackSourceMetadata(track.sourceMetadata),
        },
      );
      _throwIfUnexpectedStatus(response, path: '/tracks/$id');

      if (_songReferencesDiffer(previousSongReference, uploadedSong.name)) {
        await _deleteSongFileIfPossible(
          previousSongReference,
          ignoreReferencedOrMissing: true,
        );
      }

      return parseTrackJson(
        _decodeJsonMap(response.response, path: '/tracks/$id'),
        baseUri: _baseUri,
        authorsById: await _getAuthorsById(),
      );
    } catch (_) {
      if (_songReferencesDiffer(previousSongReference, uploadedSong.name)) {
        await _deleteSongFileIfPossible(
          uploadedSong.name,
          ignoreReferencedOrMissing: true,
        );
      }
      rethrow;
    }
  }

  @override
  Future<TrackLyrics?> getTrackLyrics(int trackId) async {
    final path = '/tracks/$trackId/lyrics';
    final response = await _authenticatedHttpClient.get(path);
    if (response.statusCode == 404) {
      return null;
    }
    _throwIfUnexpectedStatus(response, path: path);
    return _parseTrackLyrics(
      _decodeJsonMap(response.response, path: path),
      fallbackTrackId: trackId,
    );
  }

  @override
  Future<TrackLyrics> putTrackLyrics(TrackLyrics lyrics) async {
    final path = '/tracks/${lyrics.trackId}/lyrics';
    final response = await _authenticatedHttpClient.put(
      path,
      body: _serializeTrackLyrics(lyrics),
    );
    _throwIfUnexpectedStatus(
      response,
      path: path,
      expectedStatusCodes: {200, 201},
    );
    return _parseTrackLyrics(
      _decodeJsonMap(response.response, path: path),
      fallbackTrackId: lyrics.trackId,
    );
  }

  @override
  Future<void> deleteTrackLyrics(int trackId) async {
    final path = '/tracks/$trackId/lyrics';
    final response = await _authenticatedHttpClient.delete(path);
    _throwIfUnexpectedStatus(response, path: path, expectedStatusCodes: {204});
  }

  @override
  Future<void> deleteTrack(int id) async {
    final existingTrack = await getTrack(id);
    final response = await _authenticatedHttpClient.delete('/tracks/$id');
    _throwIfUnexpectedStatus(
      response,
      path: '/tracks/$id',
      expectedStatusCodes: {204},
    );
    await _deleteSongFileIfPossible(
      _songReferenceFromFile(existingTrack.file),
      ignoreReferencedOrMissing: true,
    );
  }

  Album _parseAlbum(Map<String, dynamic> json, Map<int, Author> authorsById) {
    final authorIds = (json['authorIds'] as List<dynamic>? ?? const [])
        .whereType<num>()
        .map((id) => id.toInt());

    return Album(
      id: (json['id'] as num?)?.toInt(),
      title: (json['title'] as String?) ?? '',
      coverImagePath: (json['coverImagePath'] as String?) ?? '',
      authors: authorIds
          .map(
            (id) =>
                authorsById[id] ??
                Author(id: id, currentName: 'Unknown author #$id'),
          )
          .toList(),
      releaseDate:
          DateTime.tryParse((json['releaseDate'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      isPublished: json['isPublished'] as bool? ?? false,
      trackIds: (json['trackIds'] as List<dynamic>? ?? const [])
          .whereType<num>()
          .map((id) => id.toInt())
          .toList(),
      additionalInfo: parseTrackInfos(json['additionalInfo']),
    );
  }

  AlbumCoverSuggestion _parseAlbumCoverSuggestion(Map<String, dynamic> json) {
    final thumbnailUrl = (json['thumbnailUrl'] as String?)?.trim() ?? '';
    final imageUrl = (json['imageUrl'] as String?)?.trim() ?? '';
    final width = (json['width'] as num?)?.toInt() ?? 0;
    final height = (json['height'] as num?)?.toInt() ?? 0;

    if (thumbnailUrl.isEmpty || imageUrl.isEmpty || width <= 0 || height <= 0) {
      throw const AppError('Invalid album cover suggestion payload.');
    }

    return AlbumCoverSuggestion(
      thumbnailUrl: thumbnailUrl,
      imageUrl: imageUrl,
      width: width,
      height: height,
      sourcePageUrl: (json['sourcePageUrl'] as String?)?.trim(),
    );
  }

  TrackLyrics _parseTrackLyrics(
    Map<String, dynamic> json, {
    required int fallbackTrackId,
  }) {
    return TrackLyrics(
      trackId: (json['trackId'] as num?)?.toInt() ?? fallbackTrackId,
      type: _parseTrackLyricsType((json['type'] as String?) ?? 'plain'),
      languageCode: (json['languageCode'] as String?) ?? '',
      isVerified: json['isVerified'] as bool? ?? false,
      source: (json['source'] as String?) ?? '',
      plainText: json['plainText'] as String?,
      lines: (json['lines'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_parseTrackLyricsLine)
          .toList(),
    );
  }

  TrackLyricsLine _parseTrackLyricsLine(Map<String, dynamic> json) {
    return TrackLyricsLine(
      startMs: (json['startMs'] as num?)?.toInt() ?? 0,
      endMs: (json['endMs'] as num?)?.toInt(),
      text: (json['text'] as String?) ?? '',
    );
  }

  TrackLyricsType _parseTrackLyricsType(String value) {
    switch (value) {
      case 'plain':
        return TrackLyricsType.plain;
      case 'synced':
        return TrackLyricsType.synced;
      default:
        throw AppError('Unsupported lyrics type: $value');
    }
  }

  Map<String, dynamic> _serializeTrackLyrics(TrackLyrics lyrics) {
    final languageCode = lyrics.languageCode.trim();
    final source = lyrics.source.trim();

    return {
      'type': switch (lyrics.type) {
        TrackLyricsType.plain => 'plain',
        TrackLyricsType.synced => 'synced',
      },
      if (languageCode.isNotEmpty) 'languageCode': languageCode,
      'isVerified': lyrics.isVerified,
      if (source.isNotEmpty) 'source': source,
      if (lyrics.type == TrackLyricsType.plain)
        'plainText': (lyrics.plainText ?? '').trim(),
      if (lyrics.type == TrackLyricsType.synced)
        'lines': lyrics.lines.map(_serializeTrackLyricsLine).toList(),
    };
  }

  Map<String, dynamic> _serializeTrackLyricsLine(TrackLyricsLine line) {
    return {
      'startMs': line.startMs,
      if (line.endMs != null) 'endMs': line.endMs,
      'text': line.text.trim(),
    };
  }

  Map<String, dynamic> _serializeAlbum(Album album) {
    return {
      'title': album.title,
      if (album.coverImagePath.trim().isNotEmpty)
        'coverImagePath': album.coverImagePath.trim(),
      'authorIds': album.authors
          .map((author) => author.id)
          .whereType<int>()
          .toList(),
      'releaseDate': album.releaseDate.toUtc().toIso8601String(),
      'isPublished': album.isPublished,
      'trackIds': album.trackIds,
      'additionalInfo': serializeTrackInfos(album.additionalInfo),
    };
  }

  Future<_UploadedFileInfo> _uploadBinaryFile({
    required String path,
    required Object file,
    required String fallbackGetPathPrefix,
  }) async {
    if (file is StorageFile) {
      return _UploadedFileInfo(name: file.storagePath, url: file.downloadUrl);
    }
    if (file is! CrossFile) {
      throw UnsupportedError(
        'Unsupported file type: ${file.runtimeType}. Use CrossFile for uploads.',
      );
    }

    final response = await _authenticatedHttpClient.postMultipart(
      path,
      fieldName: 'file',
      fileName: file.name,
      bytes: await file.readAsBytes(),
    );
    _throwIfUnexpectedStatus(response, path: path, expectedStatusCodes: {201});

    final body = _decodeJsonMap(response.response, path: path);
    return _UploadedFileInfo(
      name: (body['name'] as String?) ?? file.name,
      url: _baseUri
          .resolve(
            (body['url'] as String?) ??
                '$fallbackGetPathPrefix${Uri.encodeComponent(file.name)}',
          )
          .toString(),
    );
  }

  Future<void> _deleteSongFileIfPossible(
    String? songReference, {
    required bool ignoreReferencedOrMissing,
  }) async {
    final songName = songFileName(songReference);
    if (songName.isEmpty) {
      return;
    }

    final path = '/songs/${Uri.encodeComponent(songName)}';
    try {
      final response = await _authenticatedHttpClient.delete(path);
      _throwIfUnexpectedStatus(
        response,
        path: path,
        expectedStatusCodes: {204},
      );
    } on HttpAppError catch (error) {
      if (ignoreReferencedOrMissing &&
          (error.statusCode == 404 || error.statusCode == 409)) {
        return;
      }
      rethrow;
    }
  }

  String _songReferenceFromFile(Object file) {
    if (file is StorageFile) {
      return file.storagePath;
    }
    return '';
  }

  bool _songReferencesDiffer(String? first, String? second) {
    return songFileName(first) != songFileName(second);
  }

  String _decodeUriComponentIfPossible(String value) {
    try {
      return Uri.decodeComponent(value);
    } on ArgumentError {
      return value;
    }
  }

  Future<List<int>> _resolveAuthorIds(List<Author> authors) async {
    final names = authors
        .map((author) => author.currentName.trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList();
    if (names.isEmpty) {
      throw const AppError('At least one author is required');
    }

    final existingAuthors = await _getAuthorMaps();
    final authorIdsByName = <String, int>{
      for (final author in existingAuthors)
        ((author['currentName'] as String?) ?? '').trim(): (author['id'] as num)
            .toInt(),
    };

    final resolvedIds = <int>[];
    for (final name in names) {
      final existingId = authorIdsByName[name];
      if (existingId != null) {
        resolvedIds.add(existingId);
        continue;
      }

      final createAuthorResponse = await _authenticatedHttpClient.post(
        '/authors',
        body: {'currentName': name, 'photos': const <String>[]},
      );
      _throwIfUnexpectedStatus(
        createAuthorResponse,
        path: '/authors',
        expectedStatusCodes: {201},
      );
      final createdAuthor = _decodeJsonMap(
        createAuthorResponse.response,
        path: '/authors',
      );
      final id = (createdAuthor['id'] as num).toInt();
      authorIdsByName[name] = id;
      resolvedIds.add(id);
    }

    return resolvedIds;
  }

  Future<Map<int, Author>> _getAuthorsById() async {
    final authorMaps = await _getAuthorMaps();
    return {
      for (final author in authorMaps)
        _parseAuthor(author).id!: _parseAuthor(author),
    };
  }

  List<Map<String, dynamic>> _decodeJsonListOfMaps(
    Object? body, {
    required String path,
  }) {
    final decoded = body is String ? jsonDecode(body) : body;
    if (decoded is! List) {
      throw AppError('Expected JSON list response for $path', cause: decoded);
    }

    return decoded.whereType<Map<String, dynamic>>().toList();
  }

  Map<String, dynamic> _decodeJsonMap(Object? body, {required String path}) {
    final decoded = body is String ? jsonDecode(body) : body;
    if (decoded is! Map<String, dynamic>) {
      throw AppError('Expected JSON object response for $path', cause: decoded);
    }
    return decoded;
  }

  Future<List<Map<String, dynamic>>> _getAuthorMaps() async {
    final authorsResponse = await _authenticatedHttpClient.get('/authors');
    _throwIfUnexpectedStatus(authorsResponse, path: '/authors');
    return _decodeJsonListOfMaps(authorsResponse.response, path: '/authors');
  }

  Author _parseAuthor(Map<String, dynamic> json) {
    return Author(
      id: (json['id'] as num?)?.toInt(),
      currentName: (json['currentName'] as String?) ?? '',
      photos: (json['photos'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
    );
  }

  MediaFileInfo _parseMediaFileInfo(Map<String, dynamic> json) {
    final path = (json['path'] as String?) ?? '';
    final url = (json['url'] as String?) ?? '';
    return MediaFileInfo(
      name: (json['name'] as String?) ?? '',
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      lastModified:
          DateTime.tryParse((json['lastModified'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      path: path,
      url: _resolveMediaUrl(url: url, fallbackPath: path),
    );
  }

  String _resolveMediaUrl({required String url, required String fallbackPath}) {
    final trimmedUrl = url.trim();
    if (trimmedUrl.isNotEmpty) {
      final absoluteUri = Uri.tryParse(trimmedUrl);
      if (absoluteUri != null && absoluteUri.hasScheme) {
        return absoluteUri.toString();
      }
    }

    final candidatePath = trimmedUrl.isNotEmpty
        ? trimmedUrl
        : fallbackPath.trim();
    if (candidatePath.isEmpty) {
      return '';
    }

    final normalizedPath = _normalizeRelativeMediaPath(candidatePath);
    return _baseUri.resolve(normalizedPath).toString();
  }

  String _normalizeRelativeMediaPath(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) {
      return '/';
    }

    final segments = trimmed
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .map(_encodePathSegmentPreservingEscapes)
        .toList();

    return '/${segments.join('/')}';
  }

  String _encodePathSegmentPreservingEscapes(String segment) {
    final decoded = _decodeUriComponentIfPossible(segment);
    return Uri.encodeComponent(decoded);
  }

  String _withQueryParameters(
    String path,
    Map<String, String> queryParameters,
  ) {
    final uri = Uri(
      path: path,
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );
    return uri.toString();
  }

  void _throwIfUnexpectedStatus(
    HttpResponse response, {
    required String path,
    Set<int> expectedStatusCodes = const {200},
  }) {
    if (!expectedStatusCodes.contains(response.statusCode)) {
      throw HttpAppError(
        message: 'Request failed',
        path: path,
        statusCode: response.statusCode,
        responseBody: response.response,
      );
    }
  }
}

class _UploadedFileInfo {
  const _UploadedFileInfo({required this.name, required this.url});

  final String name;
  final String url;
}
