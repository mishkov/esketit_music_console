import 'dart:convert';

import 'package:esketit_music_console/domain/catalog_submission.dart';
import 'package:esketit_music_console/ui/catalog_submission/staged_audio_player.dart';
import 'package:esketit_music_console/use_case/catalog_submission/catalog_submission_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TrackUpdateComparisonCard extends StatefulWidget {
  const TrackUpdateComparisonCard({
    super.key,
    required this.submission,
    this.leaseToken,
  });

  final CatalogSubmission submission;
  final String? leaseToken;

  @override
  State<TrackUpdateComparisonCard> createState() =>
      _TrackUpdateComparisonCardState();
}

class _TrackUpdateComparisonCardState extends State<TrackUpdateComparisonCard> {
  bool _changesOnly = false;

  Map<String, dynamic> _map(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : {};

  @override
  Widget build(BuildContext context) {
    final data = widget.submission.retainedEntity;
    final before = _map(data['before']);
    final after = _map(data['after']);
    final fields = (data['changedFields'] as List? ?? const []).cast<String>();
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context).textTheme;
    final reason = data['reason']?.toString() ?? '';
    final labels = <String, String>{
      'name': 'Title',
      'authorIds': 'Artists',
      'albumId': 'Album',
      'trackNumber': 'Track number',
      'additionalInfo': 'Additional information',
      'sourceMetadata': 'Sources',
      'lyrics': 'Lyrics',
    };
    final keys = labels.keys
        .where((key) => !_changesOnly || fields.contains(key))
        .toList();

    Widget value(
      String key,
      Map<String, dynamic> version, {
      required bool proposed,
    }) {
      final changed = fields.contains(key);
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: changed
              ? (proposed
                    ? colors.primaryContainer.withValues(alpha: .32)
                    : colors.surfaceContainerHighest.withValues(alpha: .5))
              : null,
          border: Border(
            bottom: BorderSide(
              color: colors.outlineVariant.withValues(alpha: .45),
            ),
          ),
        ),
        child: SelectableText(
          _format(key, version[key], data, proposed),
          style: theme.bodyMedium?.copyWith(height: 1.5),
        ),
      );
    }

    Widget comparison(bool wide) {
      if (!wide) {
        return Column(
          children: [
            for (final key in keys)
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${labels[key]}${fields.contains(key) ? ' · Changed' : ''}',
                      style: theme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Text('Before · Published', style: theme.labelSmall),
                    value(key, before, proposed: false),
                    const SizedBox(height: 6),
                    Text('After · Proposed', style: theme.labelSmall),
                    value(key, after, proposed: true),
                  ],
                ),
              ),
          ],
        );
      }
      return Table(
        columnWidths: const {
          0: FixedColumnWidth(152),
          1: FlexColumnWidth(),
          2: FlexColumnWidth(),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.top,
        children: [
          TableRow(
            children: [
              const SizedBox(),
              _columnHeading(
                'Before',
                'Published version',
                colors.onSurfaceVariant,
              ),
              _columnHeading('After', 'Proposed version', colors.primary),
            ],
          ),
          for (final key in keys)
            TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 14, 12, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(labels[key]!, style: theme.labelLarge),
                      if (fields.contains(key))
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Changed',
                            style: theme.labelSmall?.copyWith(
                              color: colors.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                value(key, before, proposed: false),
                value(key, after, proposed: true),
              ],
            ),
        ],
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Icon(Icons.difference_outlined, color: colors.primary),
                Text('Compare track changes', style: theme.titleLarge),
                Chip(
                  label: Text(
                    '${fields.length} changed ${fields.length == 1 ? 'field' : 'fields'}',
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Track #${widget.submission.entityId} · ${widget.submission.canBeCancelled ? 'The published version stays live until approval.' : 'Retained ${widget.submission.status.label.toLowerCase()} comparison.'}',
              style: theme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
            if (widget.submission.isTrackUpdateOutdated) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Published track changed',
                      style: theme.titleMedium?.copyWith(
                        color: colors.onErrorContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'This proposal uses an older version. Request a refreshed proposal before approving.',
                    ),
                    Material(
                      color: colors.errorContainer,
                      child: ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: const Text('View latest published data'),
                        children: [
                          for (final key in labels.keys)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(labels[key]!),
                              subtitle: SelectableText(
                                _format(
                                  key,
                                  _map(data['current'])[key],
                                  {},
                                  false,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (reason.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Reason for update', style: theme.labelLarge),
                    const SizedBox(height: 5),
                    SelectableText(reason),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            Text(
              fields.contains('audioFilePath')
                  ? 'Audio replacement'
                  : 'Audio · Unchanged',
              style: theme.titleMedium,
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final players = [
                  _audioVersion('Before · Published', before, false),
                  _audioVersion('After · Proposed', after, true),
                ];
                return constraints.maxWidth >= 760
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: players[0]),
                          const SizedBox(width: 16),
                          Expanded(child: players[1]),
                        ],
                      )
                    : Column(
                        children: [
                          players[0],
                          const SizedBox(height: 12),
                          players[1],
                        ],
                      );
              },
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 16,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Track information', style: theme.titleMedium),
                FilterChip(
                  label: const Text('Show changed fields only'),
                  selected: _changesOnly,
                  onSelected: (value) => setState(() => _changesOnly = value),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) =>
                  comparison(constraints.maxWidth >= 760),
            ),
          ],
        ),
      ),
    );
  }

  Widget _columnHeading(String title, String subtitle, Color color) => Padding(
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: color),
        ),
        Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );

  Widget _audioVersion(
    String title,
    Map<String, dynamic> state,
    bool proposed,
  ) {
    final path = state['audioFilePath'] as String? ?? '';
    final private = path.startsWith('/api/catalog-submissions/track-updates/');
    final colors = Theme.of(context).colorScheme;
    final repository = context.read<CatalogSubmissionRepository>();
    String fileName;
    try {
      fileName = Uri.decodeComponent(Uri.parse(path).pathSegments.last);
    } catch (_) {
      fileName = path;
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Text(
            private
                ? (widget.submission.canBeCancelled
                      ? 'Replacement recording · Ready for review'
                      : 'Replacement recording · No longer staged')
                : fileName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          if (path.isNotEmpty && (!private || widget.submission.canBeCancelled))
            StagedAudioPlayer(
              key: ValueKey(
                'track-update-audio-${widget.submission.id}-$proposed',
              ),
              trackId: widget.submission.entityId,
              repository: repository,
              leaseToken: widget.leaseToken,
              trackUpdateSubmissionId: private ? widget.submission.id : null,
              publishedAudioPath: private ? null : path,
            ),
        ],
      ),
    );
  }

  String _format(
    String key,
    Object? value,
    Map<String, dynamic> data,
    bool proposed,
  ) {
    if (value == null || value is List && value.isEmpty) return 'None';
    if (key == 'authorIds') {
      final names = data[proposed ? 'afterAuthorNames' : 'beforeAuthorNames'];
      return names is List && names.isNotEmpty
          ? names.join(', ')
          : (value as List).map((id) => 'Artist #$id').join(', ');
    }
    if (key == 'albumId') {
      return '${data[proposed ? 'afterAlbumTitle' : 'beforeAlbumTitle'] ?? 'Album'} · #$value';
    }
    if (key == 'lyrics' && value is Map) {
      final text = value['type'] == 'synced'
          ? (value['lines'] as List? ?? const [])
                .map((line) {
                  final ms = (line['startMs'] as num?)?.toInt() ?? 0;
                  return '${(ms ~/ 60000).toString().padLeft(2, '0')}:${(ms ~/ 1000 % 60).toString().padLeft(2, '0')}  ${line['text']}';
                })
                .join('\n')
          : value['plainText']?.toString() ?? '';
      final info = [
        value['type'] == 'synced' ? 'Synced lyrics' : 'Plain lyrics',
        if (value['languageCode'] != null) value['languageCode'],
        if (value['isVerified'] == true) 'Verified',
        if (value['source'] != null) value['source'],
      ];
      return '${info.join(' · ')}\n$text';
    }
    if (value is List) {
      return value
          .map((item) {
            if (item is! Map) return item.toString();
            if (key == 'additionalInfo') {
              return [
                item['title'],
                item['text'],
                item['provider'],
                item['url'],
              ].where((v) => v != null && v.toString().isNotEmpty).join('\n');
            }
            final identity = item['identity'];
            return [
              item['provider'],
              item['url'],
              if (identity is Map)
                identity.entries.map((e) => '${e.key}: ${e.value}').join(' · '),
            ].where((v) => v != null).join('\n');
          })
          .join('\n\n');
    }
    return value is Map
        ? const JsonEncoder.withIndent('  ').convert(value)
        : value.toString();
  }
}
