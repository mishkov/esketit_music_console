import 'dart:convert';

import 'package:esketit_music_console/domain/album.dart';
import 'package:esketit_music_console/domain/author.dart';
import 'package:esketit_music_console/domain/file/media_file_info.dart';
import 'package:esketit_music_console/domain/track.dart';
import 'package:esketit_music_console/domain/track_info/text_track_info.dart';
import 'package:esketit_music_console/domain/track_info/track_info.dart';
import 'package:esketit_music_console/errors/app_error.dart';
import 'package:esketit_music_console/errors/http_app_error.dart';
import 'package:esketit_music_console/esketit_rest_api/http_client.dart';
import 'package:esketit_music_console/esketit_rest_api/http_response.dart';
import 'package:esketit_music_console/firebase/track/storage_file.dart';
import 'package:esketit_music_console/unassigned_layer/cross_file.dart';
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
        .map((track) => _parseTrack(track, authorsById))
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

    return items.map((album) => _parseAlbum(album, authorsById)).toList();
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
    ).map((track) => _parseTrack(track, authorsById)).toList();
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
      fallbackGetPathPrefix: '/album-covers/',
    );
    return uploaded.name;
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
      fallbackGetPathPrefix: '/songs/',
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
          'additionalInfo': _serializeTrackInfos(track.additionalInfo),
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
    return _parseTrack(
      _decodeJsonMap(response.response, path: '/tracks/$id'),
      await _getAuthorsById(),
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
      fallbackGetPathPrefix: '/songs/',
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
          'additionalInfo': _serializeTrackInfos(track.additionalInfo),
        },
      );
      _throwIfUnexpectedStatus(response, path: '/tracks/$id');

      if (_songReferencesDiffer(previousSongReference, uploadedSong.name)) {
        await _deleteSongFileIfPossible(
          previousSongReference,
          ignoreReferencedOrMissing: true,
        );
      }

      return _parseTrack(
        _decodeJsonMap(response.response, path: '/tracks/$id'),
        await _getAuthorsById(),
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
      additionalInfo: _parseTrackInfos(json['additionalInfo']),
    );
  }

  Track _parseTrack(Map<String, dynamic> json, Map<int, Author> authorsById) {
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
      additionalInfo: _parseTrackInfos(json['additionalInfo']),
      file: StorageFile(
        name: _songFileName(audioFilePath),
        storagePath: audioFilePath,
        downloadUrl: _songDownloadUrl(audioFilePath),
      ),
    );
  }

  List<TrackInfo> _parseTrackInfos(Object? rawInfos) {
    return (rawInfos as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(_parseTrackInfo)
        .whereType<TrackInfo>()
        .toList();
  }

  TrackInfo? _parseTrackInfo(Map<String, dynamic> json) {
    switch (json['type']) {
      case 'text':
        return TextTrackInfo(
          title: (json['title'] as String?) ?? '',
          text: (json['text'] as String?) ?? '',
        );
      default:
        return null;
    }
  }

  List<Map<String, dynamic>> _serializeTrackInfos(List<TrackInfo> infos) {
    return infos
        .map(_serializeTrackInfo)
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  Map<String, dynamic>? _serializeTrackInfo(TrackInfo info) {
    if (info is TextTrackInfo) {
      return {'type': 'text', 'title': info.title, 'text': info.text};
    }
    return null;
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
      'additionalInfo': _serializeTrackInfos(album.additionalInfo),
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
    final songName = _songFileName(songReference);
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
    return _songFileName(first) != _songFileName(second);
  }

  String _songDownloadUrl(String songReference) {
    final trimmed = songReference.trim();
    if (trimmed.isEmpty) {
      return _baseUri.resolve('/songs/').toString();
    }
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.hasScheme) {
      return trimmed;
    }
    if (trimmed.startsWith('/songs/')) {
      return _baseUri.resolve(trimmed).toString();
    }
    return _baseUri
        .resolve('/songs/${Uri.encodeComponent(trimmed)}')
        .toString();
  }

  String _songFileName(String? songReference) {
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
    if (trimmed.startsWith('/songs/')) {
      final withoutPrefix = trimmed.substring('/songs/'.length);
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
