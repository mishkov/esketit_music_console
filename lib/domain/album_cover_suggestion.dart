import 'package:equatable/equatable.dart';

class AlbumCoverSuggestion extends Equatable {
  const AlbumCoverSuggestion({
    required this.thumbnailUrl,
    required this.imageUrl,
    required this.width,
    required this.height,
    this.sourcePageUrl,
  });

  final String thumbnailUrl;
  final String imageUrl;
  final int width;
  final int height;
  final String? sourcePageUrl;

  @override
  List<Object?> get props => [
    thumbnailUrl,
    imageUrl,
    width,
    height,
    sourcePageUrl,
  ];
}
