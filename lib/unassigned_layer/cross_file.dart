import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:esketit_music_console/domain/file/abstract_file.dart';

class CrossFile extends AbstractFile {
  final XFile file;

  CrossFile({required this.file});

  String get name => file.name;

  Future<Uint8List> readAsBytes() => file.readAsBytes();

  @override
  List<Object?> get props => [file.path, file.name, file.mimeType];
}
