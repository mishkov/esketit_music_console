import 'package:equatable/equatable.dart';

class TrackNumberAssignment extends Equatable {
  const TrackNumberAssignment({
    required this.trackId,
    required this.trackNumber,
  });
  final int trackId;
  final int trackNumber;
  @override
  List<Object?> get props => [trackId, trackNumber];
}
