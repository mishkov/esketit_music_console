import 'package:esketit_music_console/domain/catalog_submission.dart';
import 'package:flutter/material.dart';

class SubmissionTypeBadge extends StatelessWidget {
  const SubmissionTypeBadge({super.key, required this.entityType});

  final CatalogSubmissionEntityType entityType;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final icon = switch (entityType) {
      CatalogSubmissionEntityType.author => Icons.person_outline,
      CatalogSubmissionEntityType.album => Icons.album_outlined,
      CatalogSubmissionEntityType.track => Icons.music_note_outlined,
    };

    return Semantics(
      label: 'Submission type: ${entityType.label}',
      child: Chip(
        visualDensity: VisualDensity.compact,
        avatar: Icon(icon, size: 16, color: colors.onPrimaryContainer),
        label: Text(entityType.label),
        labelStyle: TextStyle(color: colors.onPrimaryContainer),
        side: BorderSide.none,
        backgroundColor: colors.primaryContainer,
      ),
    );
  }
}
