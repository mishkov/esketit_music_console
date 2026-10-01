import 'package:esketit_music_console/domain/track_info/external_link_track_info.dart';
import 'package:esketit_music_console/esketit_rest_api/track/track_metadata_codec.dart';
import 'package:flutter/material.dart';

class ExternalLinksInformationCard extends StatelessWidget {
  const ExternalLinksInformationCard({super.key, required this.additionalInfo});

  final Object? additionalInfo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final items = parseTrackInfos(
      additionalInfo,
    ).whereType<ExternalLinkTrackInfo>().toList();

    return Container(
      key: const ValueKey('external-links-information-card'),
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
              Icon(Icons.link_outlined, size: 18, color: colors.onSurface),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'External links',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const Text('No external links.')
          else
            SizedBox(
              width: double.infinity,
              child: DataTable(
                horizontalMargin: 8,
                columnSpacing: 12,
                headingRowHeight: 72,
                dataRowMaxHeight: double.infinity,
                columns: const [
                  DataColumn(
                    columnWidth: FlexColumnWidth(3),
                    label: Expanded(child: Text('Provider')),
                  ),
                  DataColumn(
                    columnWidth: FlexColumnWidth(3),
                    label: Expanded(child: Text('Title')),
                  ),
                  DataColumn(
                    columnWidth: FlexColumnWidth(5),
                    label: Expanded(child: Text('URL')),
                  ),
                ],
                rows: [
                  for (final item in items)
                    DataRow(
                      cells: [
                        DataCell(SelectableText(item.provider)),
                        DataCell(SelectableText(item.title ?? '—')),
                        DataCell(SelectableText(item.url)),
                      ],
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
