import 'dart:typed_data';

import 'package:equatable/equatable.dart';

const authorsSubmitPermission = 'authors.submit';
const albumsSubmitPermission = 'albums.submit';
const tracksSubmitPermission = 'tracks.submit';
const catalogSubmissionsReadOwnPermission = 'catalog_submissions.read_own';
const catalogSubmissionsUpdateOwnPermission = 'catalog_submissions.update_own';
const catalogSubmissionsCancelOwnPermission = 'catalog_submissions.cancel_own';
const catalogSubmissionsReviewPermission = 'catalog_submissions.review';

const catalogSubmissionPermissionCodes = <String>{
  authorsSubmitPermission,
  albumsSubmitPermission,
  tracksSubmitPermission,
  catalogSubmissionsReadOwnPermission,
  catalogSubmissionsUpdateOwnPermission,
  catalogSubmissionsCancelOwnPermission,
  catalogSubmissionsReviewPermission,
};

enum CatalogSubmissionStatus {
  pendingReview('pending_review', 'Pending review'),
  changesRequested('changes_requested', 'Changes requested'),
  approved('approved', 'Approved'),
  rejected('rejected', 'Rejected'),
  cancelled('cancelled', 'Cancelled');

  const CatalogSubmissionStatus(this.code, this.label);

  final String code;
  final String label;

  static CatalogSubmissionStatus fromJson(Object? value) {
    return values.firstWhere(
      (status) => status.code == value,
      orElse: () => throw FormatException(
        'Unsupported catalog submission status: $value',
      ),
    );
  }
}

enum CatalogSubmissionEntityType {
  author('author', 'Author'),
  album('album', 'Album'),
  track('track', 'Track');

  const CatalogSubmissionEntityType(this.code, this.label);

  final String code;
  final String label;

  static CatalogSubmissionEntityType fromJson(Object? value) {
    return values.firstWhere(
      (type) => type.code == value,
      orElse: () => throw FormatException(
        'Unsupported catalog submission entity type: $value',
      ),
    );
  }
}

class CatalogSubmissionFeedback extends Equatable {
  const CatalogSubmissionFeedback({
    required this.id,
    required this.submissionId,
    required this.kind,
    required this.message,
    required this.ratingPenalty,
    required this.createdAt,
    this.reviewerUserId,
  });

  final int id;
  final int submissionId;
  final int? reviewerUserId;
  final CatalogSubmissionStatus kind;
  final String message;
  final int ratingPenalty;
  final DateTime createdAt;

  factory CatalogSubmissionFeedback.fromJson(Map<String, dynamic> json) {
    return CatalogSubmissionFeedback(
      id: _requiredInt(json, 'id'),
      submissionId: _requiredInt(json, 'submissionId'),
      reviewerUserId: (json['reviewerUserId'] as num?)?.toInt(),
      kind: CatalogSubmissionStatus.fromJson(json['kind']),
      message: json['message'] as String? ?? '',
      ratingPenalty: (json['ratingPenalty'] as num?)?.toInt() ?? 0,
      createdAt: _requiredDate(json, 'createdAt'),
    );
  }

  @override
  List<Object?> get props => [
    id,
    submissionId,
    reviewerUserId,
    kind,
    message,
    ratingPenalty,
    createdAt,
  ];
}

class CatalogSubmission extends Equatable {
  const CatalogSubmission({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.requesterUserId,
    required this.status,
    required this.snapshot,
    required this.entity,
    required this.feedback,
    required this.createdAt,
    required this.submittedAt,
    required this.updatedAt,
    this.decidedAt,
    this.decidedByUserId,
  });

  final int id;
  final CatalogSubmissionEntityType entityType;
  final int entityId;
  final int requesterUserId;
  final CatalogSubmissionStatus status;
  final Map<String, dynamic> snapshot;
  final Map<String, dynamic> entity;
  final List<CatalogSubmissionFeedback> feedback;
  final DateTime createdAt;
  final DateTime submittedAt;
  final DateTime updatedAt;
  final DateTime? decidedAt;
  final int? decidedByUserId;

  bool get canBeCancelled =>
      status == CatalogSubmissionStatus.pendingReview ||
      status == CatalogSubmissionStatus.changesRequested;

  String get entityName => switch (entityType) {
    CatalogSubmissionEntityType.author =>
      (entity['currentName'] ?? snapshot['currentName'] ?? 'Author #$entityId')
          .toString(),
    CatalogSubmissionEntityType.album =>
      (entity['title'] ?? snapshot['title'] ?? 'Album #$entityId').toString(),
    CatalogSubmissionEntityType.track =>
      (entity['name'] ?? snapshot['name'] ?? 'Track #$entityId').toString(),
  };

  Map<String, dynamic> get retainedEntity =>
      entity.isNotEmpty ? entity : snapshot;

  CatalogSubmissionFeedback? get latestFeedback =>
      feedback.isEmpty ? null : feedback.last;

  factory CatalogSubmission.fromJson(Map<String, dynamic> json) {
    return CatalogSubmission(
      id: _requiredInt(json, 'id'),
      entityType: CatalogSubmissionEntityType.fromJson(json['entityType']),
      entityId: _requiredInt(json, 'entityId'),
      requesterUserId: _requiredInt(json, 'requesterUserId'),
      status: CatalogSubmissionStatus.fromJson(json['status']),
      snapshot: _jsonMap(json['snapshot']),
      entity: _jsonMap(json['entity']),
      feedback: _jsonMaps(
        json['feedback'],
      ).map(CatalogSubmissionFeedback.fromJson).toList(growable: false),
      createdAt: _requiredDate(json, 'createdAt'),
      submittedAt: _requiredDate(json, 'submittedAt'),
      updatedAt: _requiredDate(json, 'updatedAt'),
      decidedAt: _optionalDate(json['decidedAt']),
      decidedByUserId: (json['decidedByUserId'] as num?)?.toInt(),
    );
  }

  @override
  List<Object?> get props => [
    id,
    entityType,
    entityId,
    requesterUserId,
    status,
    snapshot,
    entity,
    feedback,
    createdAt,
    submittedAt,
    updatedAt,
    decidedAt,
    decidedByUserId,
  ];
}

class CatalogSubmissionList extends Equatable {
  const CatalogSubmissionList({
    required this.items,
    required this.importRating,
  });

  final List<CatalogSubmission> items;
  final int importRating;

  factory CatalogSubmissionList.fromJson(Map<String, dynamic> json) {
    return CatalogSubmissionList(
      items: _jsonMaps(
        json['items'],
      ).map(CatalogSubmission.fromJson).toList(growable: false),
      importRating: (json['importRating'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  List<Object?> get props => [items, importRating];
}

class CatalogSubmissionUpload extends Equatable {
  const CatalogSubmissionUpload({
    required this.token,
    required this.requesterUserId,
    required this.originalName,
    required this.createdAt,
    required this.sizeBytes,
    this.claimedTrackId,
  });

  final String token;
  final int requesterUserId;
  final String originalName;
  final DateTime createdAt;
  final int sizeBytes;
  final int? claimedTrackId;

  factory CatalogSubmissionUpload.fromJson(Map<String, dynamic> json) {
    return CatalogSubmissionUpload(
      token: json['token'] as String? ?? '',
      requesterUserId: _requiredInt(json, 'requesterUserId'),
      originalName: json['originalName'] as String? ?? '',
      createdAt: _requiredDate(json, 'createdAt'),
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      claimedTrackId: (json['claimedTrackId'] as num?)?.toInt(),
    );
  }

  @override
  List<Object?> get props => [
    token,
    requesterUserId,
    originalName,
    createdAt,
    sizeBytes,
    claimedTrackId,
  ];
}

class CatalogReviewLease extends Equatable {
  const CatalogReviewLease({
    required this.requesterUserId,
    required this.reviewerUserId,
    required this.leaseToken,
    required this.acquiredAt,
    required this.heartbeatAt,
    required this.expiresAt,
  });

  final int requesterUserId;
  final int reviewerUserId;
  final String leaseToken;
  final DateTime acquiredAt;
  final DateTime heartbeatAt;
  final DateTime expiresAt;

  factory CatalogReviewLease.fromJson(Map<String, dynamic> json) {
    return CatalogReviewLease(
      requesterUserId: _requiredInt(json, 'requesterUserId'),
      reviewerUserId: _requiredInt(json, 'reviewerUserId'),
      leaseToken: json['leaseToken'] as String? ?? '',
      acquiredAt: _requiredDate(json, 'acquiredAt'),
      heartbeatAt: _requiredDate(json, 'heartbeatAt'),
      expiresAt: _requiredDate(json, 'expiresAt'),
    );
  }

  @override
  List<Object?> get props => [
    requesterUserId,
    reviewerUserId,
    leaseToken,
    acquiredAt,
    heartbeatAt,
    expiresAt,
  ];
}

class CatalogReviewLeaseStatus extends Equatable {
  const CatalogReviewLeaseStatus({
    required this.reviewerUserId,
    required this.acquiredAt,
    required this.heartbeatAt,
    required this.expiresAt,
  });

  final int reviewerUserId;
  final DateTime acquiredAt;
  final DateTime heartbeatAt;
  final DateTime expiresAt;

  factory CatalogReviewLeaseStatus.fromJson(Map<String, dynamic> json) {
    return CatalogReviewLeaseStatus(
      reviewerUserId: _requiredInt(json, 'reviewerUserId'),
      acquiredAt: _requiredDate(json, 'acquiredAt'),
      heartbeatAt: _requiredDate(json, 'heartbeatAt'),
      expiresAt: _requiredDate(json, 'expiresAt'),
    );
  }

  @override
  List<Object?> get props => [
    reviewerUserId,
    acquiredAt,
    heartbeatAt,
    expiresAt,
  ];
}

class CatalogReviewRequester extends Equatable {
  const CatalogReviewRequester({
    required this.userId,
    required this.email,
    required this.pendingCount,
    required this.importRating,
    required this.oldestPendingAt,
    this.activeLease,
  });

  final int userId;
  final String email;
  final int pendingCount;
  final int importRating;
  final DateTime oldestPendingAt;
  final CatalogReviewLeaseStatus? activeLease;

  factory CatalogReviewRequester.fromJson(Map<String, dynamic> json) {
    final user = _jsonMap(json['user']);
    final rawLease = json['activeLease'];
    return CatalogReviewRequester(
      userId: _requiredInt(user, 'id'),
      email: user['email'] as String? ?? '',
      pendingCount: (json['pendingCount'] as num?)?.toInt() ?? 0,
      importRating: (json['importRating'] as num?)?.toInt() ?? 0,
      oldestPendingAt: _requiredDate(json, 'oldestPendingAt'),
      activeLease: rawLease is Map
          ? CatalogReviewLeaseStatus.fromJson(
              Map<String, dynamic>.from(rawLease),
            )
          : null,
    );
  }

  @override
  List<Object?> get props => [
    userId,
    email,
    pendingCount,
    importRating,
    oldestPendingAt,
    activeLease,
  ];
}

class CatalogAudioData extends Equatable {
  const CatalogAudioData({required this.bytes, this.contentType});

  final Uint8List bytes;
  final String? contentType;

  @override
  List<Object?> get props => [bytes, contentType];
}

class CatalogReviewDecision {
  const CatalogReviewDecision({required this.message, this.ratingPenalty = 0});

  final String message;
  final int ratingPenalty;

  Map<String, dynamic> toJson() => {
    'message': message.trim(),
    'ratingPenalty': ratingPenalty,
  };
}

Map<String, dynamic> _jsonMap(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<Map<String, dynamic>> _jsonMaps(Object? value) => value is List
    ? value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false)
    : const [];

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num) return value.toInt();
  throw FormatException('Missing integer field: $key');
}

DateTime _requiredDate(Map<String, dynamic> json, String key) {
  final parsed = _optionalDate(json[key]);
  if (parsed != null) return parsed;
  throw FormatException('Missing date field: $key');
}

DateTime? _optionalDate(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;
