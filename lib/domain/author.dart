import 'package:equatable/equatable.dart';
import 'package:esketit_music_console/domain/catalog_publication_status.dart';

class Author extends Equatable {
  /// Because Author can change their name (for example due to cesonrship).
  final int? id;
  final String currentName;
  final List<String> photos;
  final CatalogPublicationStatus publicationStatus;
  final int? requestedByUserId;

  const Author({
    this.id,
    required this.currentName,
    this.photos = const [],
    this.publicationStatus = CatalogPublicationStatus.published,
    this.requestedByUserId,
  });

  @override
  List<Object?> get props => [
    id,
    currentName,
    photos,
    publicationStatus,
    requestedByUserId,
  ];
}
