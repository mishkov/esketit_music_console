import 'package:equatable/equatable.dart';
import 'package:esketit_music_console/domain/author.dart';
import 'package:esketit_music_console/domain/catalog_publication_status.dart';
import 'package:esketit_music_console/domain/track_info/track_info.dart';

class Album extends Equatable {
  const Album({
    this.id,
    required this.title,
    required this.coverImagePath,
    required this.authors,
    required this.releaseDate,
    required this.isPublished,
    required this.trackIds,
    required this.additionalInfo,
    this.publicationStatus = CatalogPublicationStatus.published,
    this.requestedByUserId,
  });

  final int? id;
  final String title;
  final String coverImagePath;
  final List<Author> authors;
  final DateTime releaseDate;
  final bool isPublished;
  final List<int> trackIds;
  final List<TrackInfo> additionalInfo;
  final CatalogPublicationStatus publicationStatus;
  final int? requestedByUserId;

  @override
  List<Object?> get props => [
    id,
    title,
    coverImagePath,
    authors,
    releaseDate,
    isPublished,
    trackIds,
    additionalInfo,
    publicationStatus,
    requestedByUserId,
  ];
}
