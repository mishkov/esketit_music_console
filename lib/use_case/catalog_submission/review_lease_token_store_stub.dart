import 'package:esketit_music_console/use_case/catalog_submission/review_lease_token_store.dart';

class BrowserReviewLeaseTokenStore implements ReviewLeaseTokenStore {
  static final Map<String, String> _fallbackSession = {};

  @override
  String? read({required int reviewerId, required int requesterId}) =>
      _fallbackSession[reviewLeaseStorageKey(
        reviewerId: reviewerId,
        requesterId: requesterId,
      )];

  @override
  void write({
    required int reviewerId,
    required int requesterId,
    required String token,
  }) {
    _fallbackSession[reviewLeaseStorageKey(
          reviewerId: reviewerId,
          requesterId: requesterId,
        )] =
        token;
  }

  @override
  void remove({required int reviewerId, required int requesterId}) {
    _fallbackSession.remove(
      reviewLeaseStorageKey(reviewerId: reviewerId, requesterId: requesterId),
    );
  }
}
