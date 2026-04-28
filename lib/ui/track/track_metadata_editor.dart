// ignore_for_file: use_build_context_synchronously

import 'dart:convert';

import 'package:esketit_music_console/domain/track_info/external_link_track_info.dart';
import 'package:esketit_music_console/domain/track_info/text_track_info.dart';
import 'package:esketit_music_console/domain/track_info/track_info.dart';
import 'package:esketit_music_console/domain/track_source_metadata.dart';
import 'package:flutter/material.dart';

class TrackMetadataEditor extends StatelessWidget {
  const TrackMetadataEditor({
    super.key,
    required this.additionalInfo,
    required this.sourceMetadata,
    required this.enabled,
    required this.onAdditionalInfoChanged,
    required this.onSourceMetadataChanged,
  });

  final List<TrackInfo> additionalInfo;
  final List<TrackSourceMetadata> sourceMetadata;
  final bool enabled;
  final ValueChanged<List<TrackInfo>> onAdditionalInfoChanged;
  final ValueChanged<List<TrackSourceMetadata>> onSourceMetadataChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Additional infos',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        if (additionalInfo.isEmpty)
          const TrackMetadataEmptyState(message: 'No additional infos yet.')
        else
          ...additionalInfo.asMap().entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _TrackInfoCard(
                info: entry.value,
                enabled: enabled,
                onEdit: () => _editTrackInfo(context, entry.key, entry.value),
                onDelete: () => _removeTrackInfo(entry.key),
              ),
            ),
          ),
        const SizedBox(height: 12),
        MenuAnchor(
          menuChildren: [
            MenuItemButton(
              onPressed: enabled ? () => _addTextTrackInfo(context) : null,
              child: const Text('Text info'),
            ),
            MenuItemButton(
              onPressed: enabled
                  ? () => _addExternalLinkTrackInfo(context)
                  : null,
              child: const Text('External link'),
            ),
          ],
          builder: (context, controller, child) {
            return FilledButton.tonalIcon(
              onPressed: !enabled
                  ? null
                  : () => controller.isOpen
                        ? controller.close()
                        : controller.open(),
              icon: const Icon(Icons.add),
              label: const Text('Add additional info'),
            );
          },
        ),
        const SizedBox(height: 24),
        Text('Source metadata', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        if (sourceMetadata.isEmpty)
          const TrackMetadataEmptyState(message: 'No source metadata yet.')
        else
          ...sourceMetadata.asMap().entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _TrackSourceMetadataCard(
                item: entry.value,
                enabled: enabled,
                onEdit: () =>
                    _editSourceMetadata(context, entry.key, entry.value),
                onDelete: () => _removeSourceMetadata(entry.key),
              ),
            ),
          ),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: enabled ? () => _addSourceMetadata(context) : null,
          icon: const Icon(Icons.add),
          label: const Text('Add source metadata'),
        ),
      ],
    );
  }

  Future<void> _addTextTrackInfo(BuildContext context) async {
    final created = await showTextTrackInfoDialog(context);
    if (created == null) {
      return;
    }
    onAdditionalInfoChanged([...additionalInfo, created]);
  }

  Future<void> _addExternalLinkTrackInfo(BuildContext context) async {
    final created = await showExternalLinkTrackInfoDialog(context);
    if (created == null) {
      return;
    }
    onAdditionalInfoChanged([...additionalInfo, created]);
  }

  Future<void> _editTrackInfo(
    BuildContext context,
    int index,
    TrackInfo info,
  ) async {
    final updated = switch (info) {
      TextTrackInfo() => await showTextTrackInfoDialog(
        context,
        initialInfo: info,
      ),
      ExternalLinkTrackInfo() => await showExternalLinkTrackInfoDialog(
        context,
        initialInfo: info,
      ),
      _ => null,
    };

    if (!context.mounted) {
      return;
    }
    if (updated == null) {
      return;
    }

    final next = List<TrackInfo>.from(additionalInfo);
    next[index] = updated;
    onAdditionalInfoChanged(next);
  }

  void _removeTrackInfo(int index) {
    final next = List<TrackInfo>.from(additionalInfo)..removeAt(index);
    onAdditionalInfoChanged(next);
  }

  Future<void> _addSourceMetadata(BuildContext context) async {
    final created = await showTrackSourceMetadataDialog(context);
    if (created == null) {
      return;
    }
    onSourceMetadataChanged([...sourceMetadata, created]);
  }

  Future<void> _editSourceMetadata(
    BuildContext context,
    int index,
    TrackSourceMetadata item,
  ) async {
    final updated = await showTrackSourceMetadataDialog(
      context,
      initialItem: item,
    );
    if (!context.mounted) {
      return;
    }
    if (updated == null) {
      return;
    }

    final next = List<TrackSourceMetadata>.from(sourceMetadata);
    next[index] = updated;
    onSourceMetadataChanged(next);
  }

  void _removeSourceMetadata(int index) {
    final next = List<TrackSourceMetadata>.from(sourceMetadata)
      ..removeAt(index);
    onSourceMetadataChanged(next);
  }
}

Future<TextTrackInfo?> showTextTrackInfoDialog(
  BuildContext context, {
  TextTrackInfo? initialInfo,
}) async {
  final titleController = TextEditingController(text: initialInfo?.title ?? '');
  final textController = TextEditingController(text: initialInfo?.text ?? '');

  final info = await showDialog<TextTrackInfo>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(initialInfo == null ? 'Add text info' : 'Edit text info'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Info title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Info text',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final title = titleController.text.trim();
              final text = textController.text.trim();
              if (title.isEmpty && text.isEmpty) {
                Navigator.of(context).pop();
                return;
              }
              Navigator.of(
                context,
              ).pop(TextTrackInfo(title: title, text: text));
            },
            child: Text(initialInfo == null ? 'Add' : 'Save'),
          ),
        ],
      );
    },
  );

  titleController.dispose();
  textController.dispose();
  return info;
}

Future<ExternalLinkTrackInfo?> showExternalLinkTrackInfoDialog(
  BuildContext context, {
  ExternalLinkTrackInfo? initialInfo,
}) async {
  final providerController = TextEditingController(
    text: initialInfo?.provider ?? '',
  );
  final titleController = TextEditingController(text: initialInfo?.title ?? '');
  final urlController = TextEditingController(text: initialInfo?.url ?? '');

  final info = await showDialog<ExternalLinkTrackInfo>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(
          initialInfo == null ? 'Add external link' : 'Edit external link',
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: providerController,
                decoration: const InputDecoration(
                  labelText: 'Provider',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: urlController,
                decoration: const InputDecoration(
                  labelText: 'URL',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Title (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop(
                ExternalLinkTrackInfo(
                  id: initialInfo?.id,
                  provider: providerController.text.trim(),
                  title: titleController.text.trim().isEmpty
                      ? null
                      : titleController.text.trim(),
                  url: urlController.text.trim(),
                ),
              );
            },
            child: Text(initialInfo == null ? 'Add' : 'Save'),
          ),
        ],
      );
    },
  );

  providerController.dispose();
  titleController.dispose();
  urlController.dispose();
  return info;
}

Future<TrackSourceMetadata?> showTrackSourceMetadataDialog(
  BuildContext context, {
  TrackSourceMetadata? initialItem,
}) async {
  final providerController = TextEditingController(
    text: initialItem?.provider ?? '',
  );
  final identityController = TextEditingController(
    text: formatJsonObject(initialItem?.identity ?? const {}),
  );
  final kindController = TextEditingController(text: initialItem?.kind ?? '');
  final urlController = TextEditingController(text: initialItem?.url ?? '');
  String? identityError;

  final item = await showDialog<TrackSourceMetadata>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(
              initialItem == null
                  ? 'Add source metadata'
                  : 'Edit source metadata',
            ),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: providerController,
                      decoration: const InputDecoration(
                        labelText: 'Provider',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: kindController,
                      decoration: const InputDecoration(
                        labelText: 'Kind (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: urlController,
                      decoration: const InputDecoration(
                        labelText: 'URL (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: identityController,
                      minLines: 5,
                      maxLines: 8,
                      decoration: InputDecoration(
                        labelText: 'Identity JSON object',
                        helperText:
                            'Enter a JSON object, for example {"videoId":"abc123"} or {"chatId":"channel","messageId":"123"}.',
                        errorText: identityError,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final parsedIdentity = _parseIdentityInput(
                    identityController.text,
                  );
                  if (parsedIdentity.error != null) {
                    setState(() {
                      identityError = parsedIdentity.error;
                    });
                    return;
                  }

                  Navigator.of(context).pop(
                    TrackSourceMetadata(
                      provider: providerController.text.trim(),
                      kind: kindController.text.trim().isEmpty
                          ? null
                          : kindController.text.trim(),
                      url: urlController.text.trim().isEmpty
                          ? null
                          : urlController.text.trim(),
                      identity: parsedIdentity.identity!,
                    ),
                  );
                },
                child: Text(initialItem == null ? 'Add' : 'Save'),
              ),
            ],
          );
        },
      );
    },
  );

  providerController.dispose();
  identityController.dispose();
  kindController.dispose();
  urlController.dispose();
  return item;
}

class TrackMetadataEmptyState extends StatelessWidget {
  const TrackMetadataEmptyState({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message),
    );
  }
}

class _TrackInfoCard extends StatelessWidget {
  const _TrackInfoCard({
    required this.info,
    required this.enabled,
    required this.onEdit,
    required this.onDelete,
  });

  final TrackInfo info;
  final bool enabled;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final (title, subtitle) = switch (info) {
      TextTrackInfo(title: final title, text: final text) => (
        title.isEmpty ? 'Untitled info' : title,
        text.isEmpty ? null : text,
      ),
      ExternalLinkTrackInfo(
        provider: final provider,
        title: final title,
        url: final url,
      ) =>
        (
          title?.trim().isNotEmpty ?? false ? title!.trim() : 'External link',
          [
            provider.trim().isEmpty ? 'Unknown provider' : provider.trim(),
            url,
          ].where((part) => part.trim().isNotEmpty).join('\n'),
        ),
      _ => ('Unsupported info', null),
    };

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: enabled ? onEdit : null,
        title: Text(title),
        subtitle: subtitle == null || subtitle.isEmpty ? null : Text(subtitle),
        trailing: IconButton(
          onPressed: enabled ? onDelete : null,
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Remove',
        ),
      ),
    );
  }
}

class _TrackSourceMetadataCard extends StatelessWidget {
  const _TrackSourceMetadataCard({
    required this.item,
    required this.enabled,
    required this.onEdit,
    required this.onDelete,
  });

  final TrackSourceMetadata item;
  final bool enabled;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final title = item.provider.trim().isEmpty
        ? 'Unnamed source'
        : item.provider.trim();
    final subtitleParts = <String>[
      if (item.kind?.trim().isNotEmpty ?? false) 'Kind: ${item.kind!.trim()}',
      if (item.normalizedUrl != null) item.normalizedUrl!,
      'Identity:\n${formatJsonObject(item.identity)}',
    ];

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: enabled ? onEdit : null,
        title: Text(title),
        subtitle: subtitleParts.isEmpty ? null : Text(subtitleParts.join('\n')),
        trailing: IconButton(
          onPressed: enabled ? onDelete : null,
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Remove',
        ),
      ),
    );
  }
}

({Map<String, Object?>? identity, String? error}) _parseIdentityInput(
  String rawInput,
) {
  final trimmed = rawInput.trim();
  if (trimmed.isEmpty) {
    return (identity: null, error: 'Identity JSON is required.');
  }

  try {
    final decoded = jsonDecode(trimmed);
    final identity = jsonObjectFromDynamic(decoded);
    if (decoded is! Map) {
      return (identity: null, error: 'Identity must be a JSON object.');
    }
    if (normalizeJsonObject(identity).isEmpty) {
      return (identity: null, error: 'Identity object cannot be empty.');
    }
    return (identity: identity, error: null);
  } on FormatException {
    return (identity: null, error: 'Identity must be valid JSON.');
  }
}
