import 'package:equatable/equatable.dart';

class MediaFileInfo extends Equatable {
  const MediaFileInfo({
    required this.name,
    required this.sizeBytes,
    required this.lastModified,
    required this.path,
    required this.url,
  });

  final String name;
  final int sizeBytes;
  final DateTime lastModified;
  final String path;
  final String url;

  @override
  List<Object?> get props => [name, sizeBytes, lastModified, path, url];
}
