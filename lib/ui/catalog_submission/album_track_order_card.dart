import 'package:esketit_music_console/domain/album_track_order_proposal.dart';
import 'package:esketit_music_console/domain/catalog_submission.dart';
import 'package:esketit_music_console/domain/track_number_assignment.dart';
import 'package:esketit_music_console/ui/catalog_submission/album_cover_preview.dart';
import 'package:esketit_music_console/use_case/track/storage/tracks_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AlbumTrackOrderCard extends StatelessWidget {
  const AlbumTrackOrderCard({required this.submission, super.key});

  final CatalogSubmission submission;

  @override
  Widget build(BuildContext context) {
    final proposal = AlbumTrackOrderProposal.fromJson(
      submission.retainedEntity,
    );
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final coverPath = proposal.coverImagePath.trim();
    final coverUrl = coverPath.isEmpty
        ? ''
        : context.read<TracksStorage>().resolveAlbumCoverUrl(coverPath);
    final names = proposal.trackNames;

    return Container(
      key: const ValueKey('album-track-order-card'),
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
              Icon(
                Icons.format_list_numbered,
                size: 18,
                color: colors.onSurface,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Track order',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (submission.isAlbumTrackOrderOutdated)
                Chip(
                  label: const Text('Outdated'),
                  avatar: Icon(
                    Icons.warning_amber_rounded,
                    color: colors.onErrorContainer,
                    size: 18,
                  ),
                  backgroundColor: colors.errorContainer,
                  labelStyle: TextStyle(color: colors.onErrorContainer),
                  side: BorderSide.none,
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AlbumCoverPreview(url: coverUrl, size: 88),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      proposal.albumTitle,
                      style: theme.textTheme.titleLarge,
                    ),
                    Text(
                      'Album #${submission.entityId}',
                      style: theme.textTheme.bodySmall,
                    ),
                    if (proposal.reason.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(proposal.reason),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (submission.isAlbumTrackOrderOutdated) ...[
            const SizedBox(height: 16),
            Text(
              'The album order has changed since this proposal was submitted, or the album is unavailable. Request changes or reject it; approval is unavailable.',
              key: const ValueKey('outdated-track-order-message'),
              style: TextStyle(color: colors.error),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _order(context, 'Before', proposal.before, names),
              ),
              const SizedBox(width: 24),
              Expanded(child: _order(context, 'After', proposal.after, names)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _order(
    BuildContext context,
    String label,
    List<TrackNumberAssignment> tracks,
    Map<int, String> names,
  ) => Column(
    key: ValueKey('track-order-${label.toLowerCase()}'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 8),
      if (tracks.isEmpty) const Text('No tracks.'),
      for (final item in tracks)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 36, child: Text('${item.trackNumber}.')),
              Expanded(
                child: Text(
                  '${names[item.trackId] ?? 'Track'} (#${item.trackId})',
                ),
              ),
            ],
          ),
        ),
    ],
  );
}
