import 'package:esketit_music_console/domain/catalog_publication_status.dart';
import 'package:flutter/material.dart';

class PublicationStatusBadge extends StatelessWidget {
  const PublicationStatusBadge({super.key, required this.status});

  final CatalogPublicationStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (background, foreground, icon) = switch (status) {
      CatalogPublicationStatus.published => (
        colors.primaryContainer,
        colors.onPrimaryContainer,
        Icons.public,
      ),
      CatalogPublicationStatus.pendingReview => (
        colors.tertiaryContainer,
        colors.onTertiaryContainer,
        Icons.hourglass_top,
      ),
      CatalogPublicationStatus.changesRequested => (
        colors.errorContainer,
        colors.onErrorContainer,
        Icons.edit_note,
      ),
    };

    return Semantics(
      label: 'Publication status: ${status.label}',
      child: Chip(
        visualDensity: VisualDensity.compact,
        avatar: Icon(icon, size: 16, color: foreground),
        label: Text(status.label),
        labelStyle: TextStyle(color: foreground),
        side: BorderSide.none,
        backgroundColor: background,
      ),
    );
  }
}
