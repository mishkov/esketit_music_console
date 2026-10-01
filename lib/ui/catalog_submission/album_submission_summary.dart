import 'package:esketit_music_console/domain/catalog_submission.dart';
import 'package:esketit_music_console/ui/catalog_submission/album_cover_preview.dart';
import 'package:esketit_music_console/ui/catalog_submission/submission_status_badge.dart';
import 'package:esketit_music_console/use_case/track/storage/tracks_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AlbumSubmissionSummary extends StatelessWidget {
  const AlbumSubmissionSummary({
    super.key,
    required this.submission,
    this.children = const [],
  });

  final CatalogSubmission submission;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = submission.retainedEntity;
    final coverPath = data['coverImagePath'];
    final coverUrl = coverPath is String && coverPath.trim().isNotEmpty
        ? context.read<TracksStorage>().resolveAlbumCoverUrl(coverPath.trim())
        : '';
    final releaseDate = DateTime.tryParse(
      data['releaseDate']?.toString() ?? '',
    );

    return LayoutBuilder(
      builder: (context, constraints) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AlbumCoverPreview(
            url: coverUrl,
            size: constraints.maxWidth < 520 ? 72 : 136,
          ),
          SizedBox(width: constraints.maxWidth < 520 ? 12 : 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, infoConstraints) {
                    final title = Text(
                      submission.entityName,
                      style: theme.textTheme.titleLarge,
                    );
                    final status = SubmissionStatusBadge(
                      status: submission.status,
                    );
                    if (infoConstraints.maxWidth < 360) {
                      return Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [title, status],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: title),
                        const SizedBox(width: 12),
                        status,
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Release date',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            releaseDate == null
                                ? 'Not provided'
                                : _formatDate(releaseDate),
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                ...children,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}
