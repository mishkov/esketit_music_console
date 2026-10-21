import 'package:esketit_music_console/domain/album_track_order_proposal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const base = [
    {'trackId': 1, 'trackNumber': 1},
    {'trackId': 2, 'trackNumber': 10},
  ];
  Map<String, dynamic> data() => {
    'albumId': 1,
    'baseTracks': base,
    'tracks': base,
    'currentTracks': base.reversed.toList(),
    'targetAvailable': true,
    'expectedOrderRevision': 3,
    'currentOrderRevision': 3,
  };

  test('compares numbered slots independently of JSON array order', () {
    final proposal = AlbumTrackOrderProposal.fromJson(data());
    expect(proposal.isOutdated, isFalse);
    expect(proposal.before.map((track) => track.trackNumber), [1, 10]);
  });

  for (final change in <String, Object?>{
    'currentOrderRevision': 4,
    'targetAvailable': false,
    'outdated': true,
    'currentTracks': [
      {'trackId': 1, 'trackNumber': 1},
      {'trackId': 2, 'trackNumber': 4},
    ],
    'baseTracks': [
      {'trackId': 1, 'trackNumber': 1},
    ],
  }.entries) {
    test('marks ${change.key} changes outdated', () {
      expect(
        AlbumTrackOrderProposal.fromJson(
          data()..[change.key] = change.value,
        ).isOutdated,
        isTrue,
      );
    });
  }

  test('missing current order cannot be treated as approvable', () {
    expect(
      AlbumTrackOrderProposal.fromJson(
        data()..remove('currentTracks'),
      ).isOutdated,
      isTrue,
    );
  });
}
