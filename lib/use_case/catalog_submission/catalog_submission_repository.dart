import 'package:esketit_music_console/domain/catalog_submission.dart';
import 'package:esketit_music_console/domain/track_lyrics.dart';

class AuthorSubmissionRequest {
  const AuthorSubmissionRequest({
    required this.currentName,
    this.photos = const [],
  });

  final String currentName;
  final List<String> photos;

  Map<String, dynamic> toJson() => {
    'currentName': currentName.trim(),
    'photos': photos,
  };
}

class AlbumSubmissionRequest {
  const AlbumSubmissionRequest({
    required this.title,
    required this.coverImagePath,
    required this.authorIds,
    required this.releaseDate,
    required this.isPublished,
    this.trackIds = const [],
    this.additionalInfo = const [],
  });

  final String title;
  final String coverImagePath;
  final List<int> authorIds;
  final DateTime releaseDate;
  final bool isPublished;
  final List<int> trackIds;
  final List<Map<String, dynamic>> additionalInfo;

  Map<String, dynamic> toJson() => {
    'title': title.trim(),
    'coverImagePath': coverImagePath.trim(),
    'authorIds': authorIds,
    'releaseDate': releaseDate.toUtc().toIso8601String(),
    'isPublished': isPublished,
    'trackIds': trackIds,
    'additionalInfo': additionalInfo,
  };
}

class TrackSubmissionRequest {
  const TrackSubmissionRequest({
    required this.name,
    required this.authorIds,
    required this.albumId,
    required this.albumOrder,
    this.audioUploadToken,
    this.additionalInfo = const [],
    this.sourceMetadata = const [],
  });

  final String name;
  final List<int> authorIds;
  final int albumId;
  final int albumOrder;
  final String? audioUploadToken;
  final List<Map<String, dynamic>> additionalInfo;
  final List<Map<String, dynamic>> sourceMetadata;

  Map<String, dynamic> toJson() => {
    'name': name.trim(),
    'authorIds': authorIds,
    'albumId': albumId,
    'albumOrder': albumOrder,
    if (audioUploadToken?.trim().isNotEmpty ?? false)
      'audioUploadToken': audioUploadToken!.trim(),
    'additionalInfo': additionalInfo,
    'sourceMetadata': sourceMetadata,
  };
}

abstract class CatalogSubmissionRepository {
  Future<CatalogSubmissionList> getOwnSubmissions();

  Future<CatalogSubmission> submitAuthor(AuthorSubmissionRequest request);

  Future<CatalogSubmission> submitAlbum(AlbumSubmissionRequest request);

  Future<CatalogSubmissionUpload> stageAudio({
    required String fileName,
    required List<int> bytes,
  });

  Future<CatalogSubmission> submitTrack(TrackSubmissionRequest request);

  Future<CatalogSubmission> updateAuthor(
    int authorId,
    AuthorSubmissionRequest request,
  );

  Future<CatalogSubmission> updateAlbum(
    int albumId,
    AlbumSubmissionRequest request,
  );

  Future<CatalogSubmission> updateTrack(
    int trackId,
    TrackSubmissionRequest request,
  );

  Future<TrackLyrics> putTrackLyrics(int trackId, TrackLyrics lyrics);

  Future<CatalogSubmission> resubmit(int submissionId);

  Future<CatalogSubmission> cancel(int submissionId);

  Future<List<CatalogReviewRequester>> getReviewRequesters();

  Future<CatalogReviewLease> acquireLease(int requesterId);

  Future<CatalogReviewLease> renewLease(int requesterId, String leaseToken);

  Future<void> releaseLease(int requesterId, String leaseToken);

  Future<List<CatalogSubmission>> getReviewSubmissions(
    int requesterId,
    String leaseToken,
  );

  Future<CatalogSubmission> approve(int submissionId, String leaseToken);

  Future<CatalogSubmission> requestChanges(
    int submissionId,
    String leaseToken,
    CatalogReviewDecision decision,
  );

  Future<CatalogSubmission> reject(
    int submissionId,
    String leaseToken,
    CatalogReviewDecision decision,
  );

  Future<CatalogAudioData> getStagedAudio(int trackId, {String? leaseToken});
}
