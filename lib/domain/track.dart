import 'package:equatable/equatable.dart';
import 'package:esketit_music_console/domain/author.dart';
import 'package:esketit_music_console/domain/file/abstract_file.dart';
import 'package:esketit_music_console/domain/track_info/track_info.dart';

class Track extends Equatable {
  final int? id;
  final String name;
  final List<Author> authors;
  final int albumId;
  final int? albumOrder;
  final AbstractFile file;

  /// Any related info like history of track, who inspired, how it was written,
  /// link to videos, link to tik toks, link to covers etc.
  final List<TrackInfo> additionalInfo;

  const Track({
    this.id,
    required this.name,
    required this.authors,
    required this.albumId,
    this.albumOrder,
    required this.additionalInfo,
    required this.file,
  });

  List<TrackInfo> get addionalInfo => additionalInfo;

  @override
  List<Object?> get props => [
    id,
    name,
    authors,
    albumId,
    albumOrder,
    file,
    additionalInfo,
  ];
}
