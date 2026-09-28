import 'dart:async';

import 'package:esketit_music_console/domain/catalog_submission.dart';
import 'package:esketit_music_console/errors/http_app_error.dart';
import 'package:esketit_music_console/use_case/catalog_submission/catalog_submission_repository.dart';
import 'package:esketit_music_console/use_case/catalog_submission/review_lease_token_store.dart';
import 'package:flutter/foundation.dart';

class CatalogReviewController extends ChangeNotifier {
  CatalogReviewController({
    required CatalogSubmissionRepository repository,
    required this.reviewerId,
    required ReviewLeaseTokenStore tokenStore,
    this.heartbeatInterval = const Duration(minutes: 3),
  }) : _repository = repository,
       _tokenStore = tokenStore;

  final CatalogSubmissionRepository _repository;
  final ReviewLeaseTokenStore _tokenStore;
  final int reviewerId;
  final Duration heartbeatInterval;

  List<CatalogReviewRequester> requesters = const [];
  List<CatalogSubmission> submissions = const [];
  CatalogReviewRequester? activeRequester;
  CatalogReviewLease? activeLease;
  bool isLoadingQueue = false;
  bool isLoadingReview = false;
  bool isMutating = false;
  String? errorMessage;
  String? notice;
  Timer? _heartbeatTimer;
  String? _leaseToken;

  String? get leaseToken => _leaseToken;
  bool get hasActiveReview => activeRequester != null && _leaseToken != null;

  Future<void> loadQueue({bool tryResume = true}) async {
    isLoadingQueue = true;
    errorMessage = null;
    notifyListeners();
    try {
      requesters = await _repository.getReviewRequesters();
      isLoadingQueue = false;
      notifyListeners();
      if (tryResume && !hasActiveReview) {
        for (final requester in requesters) {
          if (requester.activeLease?.reviewerUserId != reviewerId) continue;
          final storedToken = _tokenStore.read(
            reviewerId: reviewerId,
            requesterId: requester.userId,
          );
          if (storedToken != null && storedToken.isNotEmpty) {
            await _activate(requester, storedToken, renewFirst: true);
          }
          break;
        }
      }
    } catch (error) {
      isLoadingQueue = false;
      errorMessage = describeCatalogError(error);
      notifyListeners();
    }
  }

  Future<void> startReview(CatalogReviewRequester requester) async {
    isMutating = true;
    errorMessage = null;
    notice = null;
    notifyListeners();
    try {
      final lease = await _repository.acquireLease(requester.userId);
      activeLease = lease;
      _tokenStore.write(
        reviewerId: reviewerId,
        requesterId: requester.userId,
        token: lease.leaseToken,
      );
      await _activate(requester, lease.leaseToken);
    } on HttpAppError catch (error) {
      if (error.statusCode == 409) {
        _clearLease(requesterId: requester.userId);
        notice =
            'The requester is already being reviewed or your previous lease changed.';
        await loadQueue(tryResume: false);
      } else {
        errorMessage = describeCatalogError(error);
      }
    } catch (error) {
      errorMessage = describeCatalogError(error);
    } finally {
      isMutating = false;
      notifyListeners();
    }
  }

  Future<void> _activate(
    CatalogReviewRequester requester,
    String token, {
    bool renewFirst = false,
  }) async {
    activeRequester = requester;
    _leaseToken = token;
    isLoadingReview = true;
    notifyListeners();
    try {
      if (renewFirst) {
        activeLease = await _repository.renewLease(requester.userId, token);
      }
      submissions = await _repository.getReviewSubmissions(
        requester.userId,
        token,
      );
      _startHeartbeat();
    } on HttpAppError catch (error) {
      if (error.statusCode == 409) {
        await _handleLeaseLoss();
      } else {
        errorMessage = describeCatalogError(error);
      }
    } catch (error) {
      errorMessage = describeCatalogError(error);
    } finally {
      isLoadingReview = false;
      notifyListeners();
    }
  }

  Future<void> renewNow() async {
    final requester = activeRequester;
    final token = _leaseToken;
    if (requester == null || token == null || isMutating) return;
    try {
      activeLease = await _repository.renewLease(requester.userId, token);
      notifyListeners();
    } on HttpAppError catch (error) {
      if (error.statusCode == 409) {
        await _handleLeaseLoss();
      } else {
        errorMessage = describeCatalogError(error);
        notifyListeners();
      }
    } catch (error) {
      errorMessage = describeCatalogError(error);
      notifyListeners();
    }
  }

  Future<void> refreshActiveAndQueue() async {
    final requester = activeRequester;
    final token = _leaseToken;
    if (requester == null || token == null) return;
    try {
      submissions = await _repository.getReviewSubmissions(
        requester.userId,
        token,
      );
      requesters = await _repository.getReviewRequesters();
      notifyListeners();
    } on HttpAppError catch (error) {
      if (error.statusCode == 409) {
        await _handleLeaseLoss();
      } else {
        errorMessage = describeCatalogError(error);
        notifyListeners();
      }
    }
  }

  Future<void> decide({
    required CatalogSubmission submission,
    required CatalogReviewAction action,
    String message = '',
    int ratingPenalty = 0,
  }) async {
    final token = _leaseToken;
    if (token == null ||
        submission.status != CatalogSubmissionStatus.pendingReview) {
      return;
    }
    if (action != CatalogReviewAction.approve && message.trim().isEmpty) {
      errorMessage = 'Feedback message is required.';
      notifyListeners();
      return;
    }
    if (ratingPenalty < 0) {
      errorMessage = 'Rating penalty must be zero or greater.';
      notifyListeners();
      return;
    }

    isMutating = true;
    errorMessage = null;
    notifyListeners();
    try {
      switch (action) {
        case CatalogReviewAction.approve:
          await _repository.approve(submission.id, token);
          break;
        case CatalogReviewAction.requestChanges:
          await _repository.requestChanges(
            submission.id,
            token,
            CatalogReviewDecision(
              message: message,
              ratingPenalty: ratingPenalty,
            ),
          );
          break;
        case CatalogReviewAction.reject:
          await _repository.reject(
            submission.id,
            token,
            CatalogReviewDecision(
              message: message,
              ratingPenalty: ratingPenalty,
            ),
          );
          break;
      }
      await refreshActiveAndQueue();
    } on HttpAppError catch (error) {
      if (error.statusCode == 409) {
        await _handleLeaseLoss();
      } else {
        errorMessage = describeCatalogError(error);
      }
    } catch (error) {
      errorMessage = describeCatalogError(error);
    } finally {
      isMutating = false;
      notifyListeners();
    }
  }

  Future<void> endReview() async {
    final requester = activeRequester;
    final token = _leaseToken;
    if (requester == null || token == null) return;
    isMutating = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _repository.releaseLease(requester.userId, token);
      _clearLease(requesterId: requester.userId);
      notice = 'Review ended.';
      await loadQueue(tryResume: false);
    } on HttpAppError catch (error) {
      if (error.statusCode == 409) {
        await _handleLeaseLoss();
      } else {
        errorMessage = describeCatalogError(error);
      }
    } catch (error) {
      errorMessage = describeCatalogError(error);
    } finally {
      isMutating = false;
      notifyListeners();
    }
  }

  Future<void> bestEffortRelease() async {
    final requester = activeRequester;
    final token = _leaseToken;
    if (requester == null || token == null) return;
    try {
      await _repository.releaseLease(requester.userId, token);
      _clearLease(requesterId: requester.userId);
    } catch (_) {
      // Server expiry is authoritative; unload/disposal release is best effort.
    }
  }

  Future<void> _handleLeaseLoss() async {
    final requesterId = activeRequester?.userId;
    if (requesterId != null) _clearLease(requesterId: requesterId);
    notice =
        'The review lease was lost or the submission state changed. The queue has been refreshed.';
    await loadQueue(tryResume: false);
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(heartbeatInterval, (_) => renewNow());
  }

  void _clearLease({required int requesterId}) {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _tokenStore.remove(reviewerId: reviewerId, requesterId: requesterId);
    _leaseToken = null;
    activeLease = null;
    activeRequester = null;
    submissions = const [];
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    unawaited(bestEffortRelease());
    super.dispose();
  }
}

enum CatalogReviewAction { approve, requestChanges, reject }

String describeCatalogError(Object error) {
  if (error is HttpAppError) {
    final response = error.responseBody;
    if (response is String && response.trim().isNotEmpty) {
      return response.trim();
    }
    return error.message;
  }
  return error.toString();
}
