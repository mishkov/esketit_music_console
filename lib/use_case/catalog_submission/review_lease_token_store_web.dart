// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;

import 'package:esketit_music_console/use_case/catalog_submission/review_lease_token_store.dart';

class BrowserReviewLeaseTokenStore implements ReviewLeaseTokenStore {
  @override
  String? read({required int reviewerId, required int requesterId}) =>
      html.window.sessionStorage[reviewLeaseStorageKey(
        reviewerId: reviewerId,
        requesterId: requesterId,
      )];

  @override
  void write({
    required int reviewerId,
    required int requesterId,
    required String token,
  }) {
    html.window.sessionStorage[reviewLeaseStorageKey(
          reviewerId: reviewerId,
          requesterId: requesterId,
        )] =
        token;
  }

  @override
  void remove({required int reviewerId, required int requesterId}) {
    html.window.sessionStorage.remove(
      reviewLeaseStorageKey(reviewerId: reviewerId, requesterId: requesterId),
    );
  }
}
