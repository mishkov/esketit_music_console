import 'package:esketit_music_console/domain/catalog_submission.dart';
import 'package:flutter/material.dart';

class SubmissionStatusBadge extends StatelessWidget {
  const SubmissionStatusBadge({super.key, required this.status});

  final CatalogSubmissionStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (background, foreground, icon) = switch (status) {
      CatalogSubmissionStatus.pendingReview => (
        colors.tertiaryContainer,
        colors.onTertiaryContainer,
        Icons.hourglass_top,
      ),
      CatalogSubmissionStatus.changesRequested => (
        colors.errorContainer,
        colors.onErrorContainer,
        Icons.edit_note,
      ),
      CatalogSubmissionStatus.approved => (
        colors.primaryContainer,
        colors.onPrimaryContainer,
        Icons.check_circle_outline,
      ),
      CatalogSubmissionStatus.rejected => (
        colors.error,
        colors.onError,
        Icons.block,
      ),
      CatalogSubmissionStatus.cancelled => (
        colors.surfaceContainerHighest,
        colors.onSurfaceVariant,
        Icons.cancel_outlined,
      ),
    };

    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(icon, size: 16, color: foreground),
      label: Text(status.label),
      labelStyle: TextStyle(color: foreground),
      side: BorderSide.none,
      backgroundColor: background,
    );
  }
}
