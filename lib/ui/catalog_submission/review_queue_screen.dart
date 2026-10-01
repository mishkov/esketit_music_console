import 'dart:convert';

import 'package:esketit_music_console/domain/catalog_submission.dart';
import 'package:esketit_music_console/domain/track_info/text_track_info.dart';
import 'package:esketit_music_console/esketit_rest_api/track/track_metadata_codec.dart';
import 'package:esketit_music_console/ui/catalog_submission/author_information_card.dart';
import 'package:esketit_music_console/ui/catalog_submission/external_links_information_card.dart';
import 'package:esketit_music_console/ui/catalog_submission/album_submission_summary.dart';
import 'package:esketit_music_console/ui/catalog_submission/staged_audio_player.dart';
import 'package:esketit_music_console/ui/catalog_submission/submission_raw_json.dart';
import 'package:esketit_music_console/ui/catalog_submission/submission_status_badge.dart';
import 'package:esketit_music_console/ui/catalog_submission/submission_type_badge.dart';
import 'package:esketit_music_console/ui/catalog_submission/track_information_card.dart';
import 'package:esketit_music_console/use_case/catalog_submission/catalog_review_controller.dart';
import 'package:esketit_music_console/use_case/catalog_submission/catalog_submission_repository.dart';
import 'package:esketit_music_console/use_case/catalog_submission/review_lease_token_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ReviewQueueScreen extends StatefulWidget {
  const ReviewQueueScreen({
    super.key,
    required this.reviewerId,
    this.onSelectedSubmissionChanged,
    this.onReviewActionChanged,
  });

  final int reviewerId;
  final ValueChanged<String?>? onSelectedSubmissionChanged;
  final ValueChanged<ReviewHeaderAction?>? onReviewActionChanged;

  @override
  State<ReviewQueueScreen> createState() => _ReviewQueueScreenState();
}

class ReviewHeaderAction {
  const ReviewHeaderAction({required this.onPressed, required this.isEnabled});

  final VoidCallback onPressed;
  final bool isEnabled;
}

class _ReviewQueueScreenState extends State<ReviewQueueScreen>
    with WidgetsBindingObserver {
  CatalogReviewController? _controller;
  String? _lastReportedSubmissionName;
  bool? _lastReportedReviewIsActive;
  bool? _lastReportedReviewIsMutating;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    _controller = CatalogReviewController(
      repository: context.read<CatalogSubmissionRepository>(),
      reviewerId: widget.reviewerId,
      tokenStore: BrowserReviewLeaseTokenStore(),
    )..loadQueue();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _controller?.renewNow();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        _reportReviewAction(controller);
        if (controller.hasActiveReview) {
          return _ActiveReview(
            controller: controller,
            onSelectedSubmissionChanged: _reportSelectedSubmission,
            showEndReviewButton: widget.onReviewActionChanged == null,
          );
        }
        _reportSelectedSubmission(null);
        return _RequesterQueue(controller: controller);
      },
    );
  }

  void _reportSelectedSubmission(String? name) {
    if (_lastReportedSubmissionName == name) return;
    _lastReportedSubmissionName = name;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onSelectedSubmissionChanged?.call(name);
    });
  }

  void _reportReviewAction(CatalogReviewController controller) {
    if (widget.onReviewActionChanged == null) return;
    final isActive = controller.hasActiveReview;
    final isMutating = controller.isMutating;
    if (_lastReportedReviewIsActive == isActive &&
        _lastReportedReviewIsMutating == isMutating) {
      return;
    }
    _lastReportedReviewIsActive = isActive;
    _lastReportedReviewIsMutating = isMutating;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onReviewActionChanged?.call(
        isActive
            ? ReviewHeaderAction(
                onPressed: controller.endReview,
                isEnabled: !isMutating,
              )
            : null,
      );
    });
  }
}

class _RequesterQueue extends StatelessWidget {
  const _RequesterQueue({required this.controller});

  final CatalogReviewController controller;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator.adaptive(
      onRefresh: () => controller.loadQueue(tryResume: false),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Review queue by requester',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: 'Refresh queue',
                onPressed: controller.isLoadingQueue
                    ? null
                    : () => controller.loadQueue(tryResume: false),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          if (controller.notice != null) ...[
            const SizedBox(height: 12),
            _MessageCard(message: controller.notice!),
          ],
          if (controller.errorMessage != null) ...[
            const SizedBox(height: 12),
            _MessageCard(message: controller.errorMessage!, isError: true),
          ],
          if (controller.isLoadingQueue) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
          if (!controller.isLoadingQueue && controller.requesters.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 64),
              child: Center(
                child: Text('No requesters are waiting for review.'),
              ),
            ),
          for (final requester in controller.requesters) ...[
            const SizedBox(height: 12),
            _RequesterCard(requester: requester, controller: controller),
          ],
        ],
      ),
    );
  }
}

class _RequesterCard extends StatelessWidget {
  const _RequesterCard({required this.requester, required this.controller});

  final CatalogReviewRequester requester;
  final CatalogReviewController controller;

  @override
  Widget build(BuildContext context) {
    final lease = requester.activeLease;
    final heldByAnother =
        lease != null && lease.reviewerUserId != controller.reviewerId;
    return Card(
      key: ValueKey('review-requester-${requester.userId}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_circle_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    requester.email,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                FilledButton(
                  key: ValueKey('start-review-${requester.userId}'),
                  onPressed: heldByAnother || controller.isMutating
                      ? null
                      : () => controller.startReview(requester),
                  child: Text(
                    lease?.reviewerUserId == controller.reviewerId
                        ? 'Resume review'
                        : 'Start review',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                Text('Pending: ${requester.pendingCount}'),
                Text('Import rating: ${requester.importRating}'),
                Text('Oldest: ${_formatDateTime(requester.oldestPendingAt)}'),
              ],
            ),
            if (lease != null) ...[
              const SizedBox(height: 8),
              Text(
                heldByAnother
                    ? 'Another reviewer holds this lease until ${_formatDateTime(lease.expiresAt)}.'
                    : 'Your lease is active until ${_formatDateTime(lease.expiresAt)}.',
                style: TextStyle(
                  color: heldByAnother
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActiveReview extends StatefulWidget {
  const _ActiveReview({
    required this.controller,
    required this.onSelectedSubmissionChanged,
    required this.showEndReviewButton,
  });

  final CatalogReviewController controller;
  final ValueChanged<String?> onSelectedSubmissionChanged;
  final bool showEndReviewButton;

  @override
  State<_ActiveReview> createState() => _ActiveReviewState();
}

class _ActiveReviewState extends State<_ActiveReview> {
  int? _selectedSubmissionId;
  int _lastIndex = 0;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final ordered = [...controller.submissions]
      ..sort((left, right) {
        int weight(CatalogSubmission item) => switch (item.entityType) {
          CatalogSubmissionEntityType.author => 0,
          CatalogSubmissionEntityType.album => 1,
          CatalogSubmissionEntityType.track => 2,
        };
        final statusComparison =
            left.status == CatalogSubmissionStatus.pendingReview
            ? (right.status == CatalogSubmissionStatus.pendingReview ? 0 : -1)
            : (right.status == CatalogSubmissionStatus.pendingReview ? 1 : 0);
        return statusComparison != 0
            ? statusComparison
            : weight(left).compareTo(weight(right));
      });
    final selectedIndex = ordered.isEmpty
        ? -1
        : _selectedSubmissionId == null
        ? 0
        : ordered.indexWhere((item) => item.id == _selectedSubmissionId);
    final currentIndex = selectedIndex < 0 && ordered.isNotEmpty
        ? _lastIndex.clamp(0, ordered.length - 1)
        : selectedIndex;
    final current = currentIndex < 0 ? null : ordered[currentIndex];
    widget.onSelectedSubmissionChanged(current?.entityName);

    void select(int index) {
      setState(() {
        _selectedSubmissionId = ordered[index].id;
        _lastIndex = index;
      });
    }

    return Stack(
      children: [
        ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            current?.status == CatalogSubmissionStatus.pendingReview ? 192 : 16,
          ),
          children: [
            if (widget.showEndReviewButton) ...[
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  key: const ValueKey('end-review'),
                  onPressed: controller.isMutating
                      ? null
                      : controller.endReview,
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: const Text('End review'),
                ),
              ),
              const SizedBox(height: 12),
            ],
            _ReviewNavigationHeader(
              requester: controller.activeRequester!,
              lease: controller.activeLease,
              submission: current,
              currentIndex: currentIndex,
              total: ordered.length,
              onPrevious: currentIndex > 0
                  ? () => select(currentIndex - 1)
                  : null,
              onNext: currentIndex >= 0 && currentIndex < ordered.length - 1
                  ? () => select(currentIndex + 1)
                  : null,
            ),
            if (controller.notice != null) ...[
              const SizedBox(height: 12),
              _MessageCard(message: controller.notice!),
            ],
            if (controller.errorMessage != null) ...[
              const SizedBox(height: 12),
              _MessageCard(message: controller.errorMessage!, isError: true),
            ],
            if (controller.isLoadingReview || controller.isMutating) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            const SizedBox(height: 12),
            if (!controller.isLoadingReview && ordered.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 64),
                child: Center(
                  child: Text('No submissions remain in this review.'),
                ),
              ),
            if (current != null) ...[
              if (current.entityType == CatalogSubmissionEntityType.author) ...[
                AuthorInformationCard(
                  key: ValueKey('author-information-${current.id}'),
                  submission: current,
                ),
                const SizedBox(height: 12),
              ],
              if (current.entityType == CatalogSubmissionEntityType.track) ...[
                TrackInformationCard(
                  submission: current,
                  relatedSubmissions: controller.submissions,
                  requesterEmail: controller.activeRequester!.email,
                ),
                const SizedBox(height: 12),
                _TrackPreviewCard(
                  trackId: current.entityId,
                  leaseToken: controller.leaseToken,
                ),
                const SizedBox(height: 12),
              ],
              if (current.entityType != CatalogSubmissionEntityType.author) ...[
                _AdditionalInfoCard(
                  additionalInfo: current.retainedEntity['additionalInfo'],
                ),
                const SizedBox(height: 12),
              ],
              ExternalLinksInformationCard(
                additionalInfo: current.retainedEntity['additionalInfo'],
              ),
              const SizedBox(height: 12),
              if (current.entityType == CatalogSubmissionEntityType.track) ...[
                _SourceMetadataCard(
                  sourceMetadata: current.retainedEntity['sourceMetadata'],
                ),
                const SizedBox(height: 12),
              ],
              _ReviewSubmissionCard(submission: current),
              const SizedBox(height: 12),
              if (current.entityType == CatalogSubmissionEntityType.album) ...[
                Card(
                  key: ValueKey('raw-json-card-${current.id}'),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SubmissionRawJson(submission: current),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ],
        ),
        if (current?.status == CatalogSubmissionStatus.pendingReview)
          Positioned(
            right: 16,
            bottom: 16,
            left: 16,
            child: SafeArea(
              top: false,
              left: false,
              right: false,
              child: Align(
                alignment: Alignment.bottomRight,
                child: _ReviewDecisionBar(
                  submission: current!,
                  controller: controller,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ReviewNavigationHeader extends StatelessWidget {
  const _ReviewNavigationHeader({
    required this.requester,
    required this.lease,
    required this.submission,
    required this.currentIndex,
    required this.total,
    required this.onPrevious,
    required this.onNext,
  });

  final CatalogReviewRequester requester;
  final CatalogReviewLease? lease;
  final CatalogSubmission? submission;
  final int currentIndex;
  final int total;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              submission == null
                  ? 'No submission selected'
                  : 'Submission #${submission!.id}',
              style: theme.textTheme.bodyMedium,
            ),
            if (submission != null)
              SubmissionTypeBadge(entityType: submission!.entityType),
          ],
        ),
        Text(
          submission?.status == CatalogSubmissionStatus.pendingReview
              ? 'In review'
              : submission?.status.label ?? 'Waiting for submissions',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
    final navigation = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('${currentIndex < 0 ? 0 : currentIndex + 1} of $total'),
        const SizedBox(width: 8),
        IconButton(
          key: const ValueKey('previous-review-submission'),
          tooltip: 'Previous submission',
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
        ),
        IconButton(
          key: const ValueKey('next-review-submission'),
          tooltip: 'Next submission',
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );

    return Container(
      key: const ValueKey('review-navigation-header'),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final requesterInfo = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: colors.primaryContainer,
                foregroundColor: colors.onPrimaryContainer,
                child: const Icon(Icons.person_outline),
              ),
              const SizedBox(width: 16),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reviewing ${requester.email}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    if (lease != null)
                      Text(
                        'Lease expires ${_formatDateTime(lease!.expiresAt)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );

          if (constraints.maxWidth < 680) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                requesterInfo,
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: details),
                    navigation,
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: requesterInfo),
              const SizedBox(height: 48, child: VerticalDivider(width: 24)),
              Expanded(child: details),
              navigation,
            ],
          );
        },
      ),
    );
  }
}

class _ReviewSubmissionCard extends StatelessWidget {
  const _ReviewSubmissionCard({required this.submission});

  final CatalogSubmission submission;

  @override
  Widget build(BuildContext context) {
    final details = <Widget>[
      if (submission.feedback.isNotEmpty) ...[
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Feedback history',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        for (final feedback in submission.feedback)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(feedback.message),
            subtitle: Text(
              '${feedback.kind.label} · penalty ${feedback.ratingPenalty} · '
              '${_formatDateTime(feedback.createdAt)}',
            ),
          ),
      ],
      if (submission.status != CatalogSubmissionStatus.pendingReview) ...[
        const SizedBox(height: 12),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Context only — only pending submissions can receive a decision.',
          ),
        ),
      ],
    ];
    return Card(
      key: ValueKey('review-submission-${submission.id}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: submission.entityType == CatalogSubmissionEntityType.album
            ? AlbumSubmissionSummary(submission: submission, children: details)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (submission.entityType !=
                      CatalogSubmissionEntityType.track) ...[
                    Row(
                      children: [
                        const Icon(Icons.person),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            submission.entityName,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    SubmissionStatusBadge(status: submission.status),
                    const SizedBox(height: 16),
                  ],
                  SubmissionRawJson(submission: submission),
                  ...details,
                ],
              ),
      ),
    );
  }
}

class _AdditionalInfoCard extends StatelessWidget {
  const _AdditionalInfoCard({required this.additionalInfo});

  final Object? additionalInfo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final items = parseTrackInfos(
      additionalInfo,
    ).whereType<TextTrackInfo>().toList();

    return Container(
      key: const ValueKey('additional-info-card'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notes_outlined, size: 18, color: colors.onSurface),
              const SizedBox(width: 8),
              Text(
                'Additional info',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const Text('No text additional info.')
          else
            for (final (index, item) in items.indexed) ...[
              Text(item.title, style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              SelectableText(item.text),
              if (index < items.length - 1) const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}

class _ReviewDecisionBar extends StatelessWidget {
  const _ReviewDecisionBar({
    required this.submission,
    required this.controller,
  });

  final CatalogSubmission submission;
  final CatalogReviewController controller;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ConstrainedBox(
      key: const ValueKey('review-decision-bar'),
      constraints: const BoxConstraints(maxWidth: 570),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          children: [
            FilledButton.tonalIcon(
              key: ValueKey('request-changes-${submission.id}'),
              onPressed: controller.isMutating
                  ? null
                  : () => _feedbackDecision(
                      context,
                      CatalogReviewAction.requestChanges,
                    ),
              icon: const Icon(Icons.edit_note),
              label: const Text('Request changes'),
            ),
            FilledButton.icon(
              key: ValueKey('approve-${submission.id}'),
              onPressed: controller.isMutating
                  ? null
                  : () => controller.decide(
                      submission: submission,
                      action: CatalogReviewAction.approve,
                    ),
              icon: const Icon(Icons.check),
              label: const Text('Approve'),
            ),
            FilledButton.icon(
              key: ValueKey('reject-${submission.id}'),
              style: FilledButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: colors.onError,
              ),
              onPressed: controller.isMutating
                  ? null
                  : () =>
                        _feedbackDecision(context, CatalogReviewAction.reject),
              icon: const Icon(Icons.block),
              label: const Text('Reject permanently'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _feedbackDecision(
    BuildContext context,
    CatalogReviewAction action,
  ) async {
    final decision = await showDialog<_FeedbackDecision>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _FeedbackDialog(action: action),
    );
    if (decision == null) return;
    await controller.decide(
      submission: submission,
      action: action,
      message: decision.message,
      ratingPenalty: decision.ratingPenalty,
    );
  }
}

class _TrackPreviewCard extends StatefulWidget {
  const _TrackPreviewCard({required this.trackId, required this.leaseToken});

  final int trackId;
  final String? leaseToken;

  @override
  State<_TrackPreviewCard> createState() => _TrackPreviewCardState();
}

class _TrackPreviewCardState extends State<_TrackPreviewCard>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      key: const ValueKey('track-preview-card'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.play_circle_filled, size: 18, color: colors.onSurface),
              const SizedBox(width: 8),
              Text(
                'Track preview',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          StagedAudioPlayer(
            trackId: widget.trackId,
            repository: context.read<CatalogSubmissionRepository>(),
            leaseToken: widget.leaseToken,
          ),
        ],
      ),
    );
  }
}

class _SourceMetadataCard extends StatelessWidget {
  const _SourceMetadataCard({required this.sourceMetadata});

  final Object? sourceMetadata;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final items = parseTrackSourceMetadata(sourceMetadata);

    return Container(
      key: const ValueKey('source-metadata-card'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.list_alt_outlined, size: 18, color: colors.onSurface),
              const SizedBox(width: 8),
              Text(
                'Source metadata',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const Text('No source metadata.')
          else
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 640) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final (index, item) in items.indexed) ...[
                        if (index > 0) const Divider(height: 24),
                        _SourceMetadataField('Provider', item.provider),
                        _SourceMetadataField('Kind', item.kind ?? '—'),
                        _SourceMetadataField(
                          'Identity',
                          jsonEncode(item.normalizedIdentity),
                        ),
                        _SourceMetadataField('URL', item.normalizedUrl ?? '—'),
                      ],
                    ],
                  );
                }

                return SizedBox(
                  width: constraints.maxWidth,
                  child: DataTable(
                    horizontalMargin: 12,
                    columnSpacing: 16,
                    dataRowMaxHeight: double.infinity,
                    columns: const [
                      DataColumn(
                        columnWidth: FlexColumnWidth(2),
                        label: Text('Provider'),
                      ),
                      DataColumn(
                        columnWidth: FlexColumnWidth(1),
                        label: Text('Kind'),
                      ),
                      DataColumn(
                        columnWidth: FlexColumnWidth(3),
                        label: Text('Identity'),
                      ),
                      DataColumn(
                        columnWidth: FlexColumnWidth(4),
                        label: Text('URL'),
                      ),
                    ],
                    rows: [
                      for (final item in items)
                        DataRow(
                          cells: [
                            DataCell(SelectableText(item.provider)),
                            DataCell(SelectableText(item.kind ?? '—')),
                            DataCell(
                              SelectableText(
                                jsonEncode(item.normalizedIdentity),
                              ),
                            ),
                            DataCell(SelectableText(item.normalizedUrl ?? '—')),
                          ],
                        ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _SourceMetadataField extends StatelessWidget {
  const _SourceMetadataField(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        SelectableText(value),
      ],
    ),
  );
}

class _FeedbackDialog extends StatefulWidget {
  const _FeedbackDialog({required this.action});

  final CatalogReviewAction action;

  @override
  State<_FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<_FeedbackDialog> {
  final _formKey = GlobalKey<FormState>();
  final _message = TextEditingController();
  final _penalty = TextEditingController(text: '0');

  @override
  void dispose() {
    _message.dispose();
    _penalty.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reject = widget.action == CatalogReviewAction.reject;
    return AlertDialog(
      title: Text(reject ? 'Reject permanently?' : 'Request changes'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (reject)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'This removes the pending catalog entity and staged media. The immutable history remains.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              TextFormField(
                key: const ValueKey('review-feedback-message'),
                controller: _message,
                autofocus: true,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Feedback message',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Feedback message is required.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('review-rating-penalty'),
                controller: _penalty,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Rating penalty',
                  helperText: 'Defaults to zero.',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final parsed = int.tryParse(value ?? '');
                  return parsed == null || parsed < 0
                      ? 'Enter an integer that is zero or greater.'
                      : null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: reject
              ? FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                )
              : null,
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(
              context,
              _FeedbackDecision(
                message: _message.text.trim(),
                ratingPenalty: int.parse(_penalty.text),
              ),
            );
          },
          child: Text(reject ? 'Reject permanently' : 'Request changes'),
        ),
      ],
    );
  }
}

class _FeedbackDecision {
  const _FeedbackDecision({required this.message, required this.ratingPenalty});

  final String message;
  final int ratingPenalty;
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message, this.isError = false});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isError
          ? Theme.of(context).colorScheme.errorContainer
          : Theme.of(context).colorScheme.secondaryContainer,
      child: ListTile(
        leading: Icon(isError ? Icons.error_outline : Icons.info_outline),
        title: Text(message),
      ),
    );
  }
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}
