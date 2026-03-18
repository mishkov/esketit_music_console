import 'dart:convert';

import 'package:esketit_music_console/domain/author.dart';
import 'package:esketit_music_console/domain/track.dart';
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

  static const _defaultAlbumImagePath = 'placeholder';

  final HttpClient _authenticatedHttpClient;
  final Uri _baseUri;

  @override
  Future<StorageTracksList> getTracks() async {
    final tracksResponse = await _authenticatedHttpClient.get('/tracks');
    _throwIfUnexpectedStatus(tracksResponse, path: '/tracks');
    final authorMaps = await _getAuthorMaps();
    final authorsByIdMap = {
      for (final author in authorMaps)
        (author['id'] as num).toInt(): Author(
          currentName: (author['currentName'] as String?) ?? '',
        ),
    };

    final tracks = _decodeJsonListOfMaps(
      tracksResponse.response,
      path: '/tracks',
    ).map((track) => _parseTrack(track, authorsByIdMap)).toList();

    return StorageTracksList(tracks: tracks);
  }

  @override
  Future<List<Author>> getAuthors() async {
    final authorMaps = await _getAuthorMaps();
    return authorMaps
        .map(
          (author) =>
              Author(currentName: (author['currentName'] as String?) ?? ''),
        )
        .where((author) => author.currentName.trim().isNotEmpty)
        .toList();
  }

  @override
  Future<void> putTrack(Track track) async {
    final uploadedSong = await _uploadSong(track.file);
    final authorIds = await _resolveAuthorIds(track.authors);

    final response = await _authenticatedHttpClient.post(
      '/tracks',
      body: {
        'name': track.name,
        'authorIds': authorIds,
        'albumImagePath': _defaultAlbumImagePath,
        'audioFilePath': uploadedSong.name,
      },
    );
    _throwIfUnexpectedStatus(
      response,
      path: '/tracks',
      expectedStatusCodes: {201},
    );
  }

  Track _parseTrack(Map<String, dynamic> json, Map<int, Author> authorsById) {
    final audioFilePath = (json['audioFilePath'] as String?) ?? '';
    final authorIds = (json['authorIds'] as List<dynamic>? ?? const [])
        .whereType<num>()
        .map((id) => id.toInt());

    return Track(
      name: (json['name'] as String?) ?? '',
      authors: authorIds
          .map(
            (id) =>
                authorsById[id] ?? Author(currentName: 'Unknown author #$id'),
          )
          .toList(),
      addionalInfo: const [],
      file: StorageFile(
        name: audioFilePath,
        storagePath: audioFilePath,
        downloadUrl: _baseUri
            .resolve('/songs/${Uri.encodeComponent(audioFilePath)}')
            .toString(),
      ),
    );
  }

  Future<_SongInfo> _uploadSong(Object file) async {
    if (file is StorageFile) {
      return _SongInfo(name: file.storagePath, url: file.downloadUrl);
    }
    if (file is! CrossFile) {
      throw UnsupportedError(
        'Unsupported file type: ${file.runtimeType}. Use CrossFile for uploads.',
      );
    }

    final response = await _authenticatedHttpClient.postMultipart(
      '/songs',
      fieldName: 'file',
      fileName: file.name,
      bytes: await file.readAsBytes(),
    );
    _throwIfUnexpectedStatus(
      response,
      path: '/songs',
      expectedStatusCodes: {201},
    );

    final body = _decodeJsonMap(response.response, path: '/songs');
    return _SongInfo(
      name: (body['name'] as String?) ?? file.name,
      url: _baseUri
          .resolve(
            (body['url'] as String?) ??
                '/songs/${Uri.encodeComponent(file.name)}',
          )
          .toString(),
    );
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

class _SongInfo {
  const _SongInfo({required this.name, required this.url});

  final String name;
  final String url;
}
