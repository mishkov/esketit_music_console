import 'package:esketit_music_console/domain/track_number_assignment.dart';

class AlbumTrackOrderProposal {
  AlbumTrackOrderProposal.fromJson(Map<String, dynamic> json)
    : before = _assignments(json['baseTracks']),
      after = _assignments(json['tracks']),
      _current = _assignments(json['currentTracks']),
      _json = json;

  final Map<String, dynamic> _json;
  final List<TrackNumberAssignment> before;
  final List<TrackNumberAssignment> after;
  final List<TrackNumberAssignment> _current;

  String get albumTitle =>
      _json['albumTitle']?.toString() ?? 'Album #${_json['albumId']}';
  String get coverImagePath => _json['coverImagePath']?.toString() ?? '';
  String get reason => _json['reason']?.toString() ?? '';

  Map<int, String> get trackNames => {
    for (final item
        in (_json['trackDetails'] as List? ?? const []).whereType<Map>())
      (item['id'] as num).toInt(): item['name'].toString(),
  };

  bool get isOutdated {
    if (_json['outdated'] == true ||
        _json['targetAvailable'] != true ||
        _json['baseTracks'] is! List ||
        _json['currentTracks'] is! List ||
        _json['currentOrderRevision'] == null ||
        _json['expectedOrderRevision'] != _json['currentOrderRevision'] ||
        before.length != _current.length) {
      return true;
    }
    final current = {
      for (final item in _current) item.trackId: item.trackNumber,
    };
    return current.length != _current.length ||
        before.map((item) => item.trackId).toSet().length != before.length ||
        before.any((item) => current[item.trackId] != item.trackNumber);
  }
}

List<TrackNumberAssignment> _assignments(Object? value) => [
  for (final item in (value is List ? value : const []).whereType<Map>())
    TrackNumberAssignment(
      trackId: (item['trackId'] as num).toInt(),
      trackNumber: (item['trackNumber'] as num).toInt(),
    ),
]..sort((left, right) => left.trackNumber.compareTo(right.trackNumber));
