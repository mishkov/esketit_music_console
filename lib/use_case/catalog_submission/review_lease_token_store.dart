export 'review_lease_token_store_stub.dart'
    if (dart.library.html) 'review_lease_token_store_web.dart';

abstract class ReviewLeaseTokenStore {
  String? read({required int reviewerId, required int requesterId});

  void write({
    required int reviewerId,
    required int requesterId,
    required String token,
  });

  void remove({required int reviewerId, required int requesterId});
}

String reviewLeaseStorageKey({
  required int reviewerId,
  required int requesterId,
}) => 'catalog-review-lease:$reviewerId:$requesterId';
