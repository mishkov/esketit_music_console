import 'package:esketit_music_console/domain/file/abstract_file.dart';

class StorageFile extends AbstractFile {
  final String name;
  final String storagePath;
  final String downloadUrl;

  StorageFile({
    required this.name,
    required this.storagePath,
    required this.downloadUrl,
  });

  @override
  List<Object?> get props => [name, storagePath, downloadUrl];
}
