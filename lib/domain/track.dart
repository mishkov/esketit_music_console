import 'package:equatable/equatable.dart';
import 'package:esketit_music_console/domain/file/abstract_file.dart';
import 'package:esketit_music_console/domain/author.dart';
import 'package:esketit_music_console/domain/track_info/track_info.dart';

class Track extends Equatable {
  final String name;
  final List<Author> authors;
  final AbstractFile file;

  /// Any related info like history of track, who inspired, how it was written,
  /// link to videos, link to tik toks, link to covers etc.
  final List<TrackInfo> addionalInfo;

  const Track({
    required this.name,
    required this.authors,
    required this.addionalInfo,
    required this.file,
  });

  @override
  List<Object> get props => [name, authors, file, addionalInfo];
}
