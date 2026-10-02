import 'package:esketit_music_console/domain/catalog_submission.dart';
import 'package:flutter/material.dart';

class SubmissionHistoryCard extends StatelessWidget {
  const SubmissionHistoryCard({super.key, required this.submission});

  final CatalogSubmission submission;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: ValueKey('history-card-${submission.id}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('History', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            if (submission.feedback.isEmpty)
              const Text('No feedback history.')
            else
              for (final feedback in submission.feedback)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(feedback.message),
                  subtitle: Text(
                    '${feedback.kind.label} · penalty ${feedback.ratingPenalty} · '
                    '${_formatDateTime(feedback.createdAt)}',
                  ),
                ),
            if (submission.status != CatalogSubmissionStatus.pendingReview) ...[
              const SizedBox(height: 12),
              const Text(
                'Context only — only pending submissions can receive a decision.',
              ),
            ],
          ],
        ),
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
