import 'dart:convert';

import 'package:esketit_music_console/domain/catalog_submission.dart';
import 'package:esketit_music_console/domain/track_lyrics.dart';
import 'package:esketit_music_console/use_case/auth/bloc/auth_bloc.dart';
import 'package:esketit_music_console/use_case/catalog_submission/catalog_submission_repository.dart';
import 'package:esketit_music_console/use_case/catalog_submission/catalog_review_controller.dart';
import 'package:esketit_music_console/ui/catalog_submission/staged_audio_player.dart';
import 'package:esketit_music_console/ui/catalog_submission/submission_status_badge.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class MySubmissionsScreen extends StatefulWidget {
  const MySubmissionsScreen({super.key});

  @override
  State<MySubmissionsScreen> createState() => _MySubmissionsScreenState();
}

class _MySubmissionsScreenState extends State<MySubmissionsScreen> {
  CatalogSubmissionList? _result;
  CatalogSubmissionStatus? _statusFilter;
  bool _isLoading = true;
  int? _mutatingId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final items =
        result?.items
            .where(
              (item) => _statusFilter == null || item.status == _statusFilter,
            )
            .toList(growable: false) ??
        const <CatalogSubmission>[];

    return RefreshIndicator.adaptive(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Card.filled(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current import rating',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${result?.importRating ?? 0}',
                          key: const ValueKey('catalog-import-rating'),
                          style: Theme.of(context).textTheme.displaySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              DropdownButton<CatalogSubmissionStatus?>(
                key: const ValueKey('submission-status-filter'),
                value: _statusFilter,
                hint: const Text('All statuses'),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('All statuses'),
                  ),
                  for (final status in CatalogSubmissionStatus.values)
                    DropdownMenuItem(value: status, child: Text(status.label)),
                ],
                onChanged: (value) => setState(() => _statusFilter = value),
              ),
            ],
          ),
          if (_isLoading) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            _ErrorCard(message: _error!, onRetry: _load),
          ],
          const SizedBox(height: 12),
          if (!_isLoading && _error == null && items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 64),
              child: Center(child: Text('No submissions match this status.')),
            ),
          for (final item in items) ...[
            _SubmissionCard(
              submission: item,
              isMutating: _mutatingId == item.id,
              onEdit: _canUpdate(item) ? () => _edit(item) : null,
              onResubmit: _canUpdate(item) ? () => _resubmit(item) : null,
              onCancel: _canCancel(item) ? () => _cancel(item) : null,
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  bool _hasPermission(String code) =>
      context.read<AuthBloc>().state.session?.user.hasPermission(code) ?? false;

  bool _canUpdate(CatalogSubmission item) =>
      item.status == CatalogSubmissionStatus.changesRequested &&
      _hasPermission(catalogSubmissionsUpdateOwnPermission);

  bool _canCancel(CatalogSubmission item) =>
      item.canBeCancelled &&
      _hasPermission(catalogSubmissionsCancelOwnPermission);

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await context
          .read<CatalogSubmissionRepository>()
          .getOwnSubmissions();
      if (!mounted) return;
      setState(() {
        _result = result;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = describeCatalogError(error);
      });
    }
  }

  Future<void> _edit(CatalogSubmission item) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => RepositoryProvider.value(
        value: context.read<CatalogSubmissionRepository>(),
        child: _EditSubmissionDialog(submission: item),
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Changes saved. Press Resubmit when you are ready.'),
        ),
      );
      await _load();
    }
  }

  Future<void> _resubmit(CatalogSubmission item) async {
    await _mutate(
      item.id,
      () => context.read<CatalogSubmissionRepository>().resubmit(item.id),
      successMessage: 'Submission sent back for review.',
    );
  }

  Future<void> _cancel(CatalogSubmission item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel submission?'),
        content: Text(
          'Cancel ${item.entityType.label.toLowerCase()} “${item.entityName}”? '
          'Its history will remain visible, but pending content is removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep submission'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cancel submission'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _mutate(
      item.id,
      () => context.read<CatalogSubmissionRepository>().cancel(item.id),
      successMessage: 'Submission cancelled.',
    );
  }

  Future<void> _mutate(
    int id,
    Future<CatalogSubmission> Function() action, {
    required String successMessage,
  }) async {
    setState(() {
      _mutatingId = id;
      _error = null;
    });
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = describeCatalogError(error));
    } finally {
      if (mounted) setState(() => _mutatingId = null);
    }
  }
}

class _SubmissionCard extends StatelessWidget {
  const _SubmissionCard({
    required this.submission,
    required this.isMutating,
    this.onEdit,
    this.onResubmit,
    this.onCancel,
  });

  final CatalogSubmission submission;
  final bool isMutating;
  final VoidCallback? onEdit;
  final VoidCallback? onResubmit;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final latestFeedback = submission.latestFeedback;
    return Card(
      key: ValueKey('submission-${submission.id}'),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: Icon(switch (submission.entityType) {
          CatalogSubmissionEntityType.author => Icons.person_outline,
          CatalogSubmissionEntityType.album => Icons.album_outlined,
          CatalogSubmissionEntityType.track => Icons.music_note_outlined,
        }),
        title: Text(submission.entityName),
        subtitle: Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(submission.entityType.label),
            SubmissionStatusBadge(status: submission.status),
            Text('Submitted ${_formatDateTime(submission.submittedAt)}'),
          ],
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          if (submission.status == CatalogSubmissionStatus.changesRequested &&
              latestFeedback != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Reviewer feedback: ${latestFeedback.message}'
                '${latestFeedback.ratingPenalty > 0 ? '\nRating penalty: -${latestFeedback.ratingPenalty}' : ''}',
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Created ${_formatDateTime(submission.createdAt)} · '
              'Updated ${_formatDateTime(submission.updatedAt)}',
            ),
          ),
          if (submission.entityType == CatalogSubmissionEntityType.track &&
              (submission.status == CatalogSubmissionStatus.pendingReview ||
                  submission.status ==
                      CatalogSubmissionStatus.changesRequested)) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: StagedAudioPlayer(
                trackId: submission.entityId,
                repository: context.read<CatalogSubmissionRepository>(),
              ),
            ),
          ],
          const SizedBox(height: 12),
          _JsonDetails(
            title:
                submission.status == CatalogSubmissionStatus.rejected ||
                    submission.status == CatalogSubmissionStatus.cancelled
                ? 'Retained snapshot'
                : 'Current entity data',
            value: submission.retainedEntity,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Feedback history',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          if (submission.feedback.isEmpty)
            const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('No feedback yet.'),
              ),
            )
          else
            for (final feedback in submission.feedback)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  feedback.kind == CatalogSubmissionStatus.rejected
                      ? Icons.block
                      : Icons.edit_note,
                ),
                title: Text(feedback.message),
                subtitle: Text(
                  '${feedback.kind.label} · ${_formatDateTime(feedback.createdAt)} · '
                  'Penalty ${feedback.ratingPenalty}',
                ),
              ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (onCancel != null)
                TextButton(
                  onPressed: isMutating ? null : onCancel,
                  child: const Text('Cancel submission'),
                ),
              if (onEdit != null) ...[
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: isMutating ? null : onEdit,
                  child: const Text('Edit'),
                ),
              ],
              if (onResubmit != null) ...[
                const SizedBox(width: 8),
                FilledButton(
                  key: ValueKey('resubmit-${submission.id}'),
                  onPressed: isMutating ? null : onResubmit,
                  child: const Text('Resubmit'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _EditSubmissionDialog extends StatefulWidget {
  const _EditSubmissionDialog({required this.submission});

  final CatalogSubmission submission;

  @override
  State<_EditSubmissionDialog> createState() => _EditSubmissionDialogState();
}

class _EditSubmissionDialogState extends State<_EditSubmissionDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _cover;
  late final TextEditingController _authorIds;
  late final TextEditingController _albumId;
  late final TextEditingController _albumOrder;
  late final TextEditingController _releaseDate;
  final _lyrics = TextEditingController();
  final _lyricsLanguage = TextEditingController(text: 'en');
  final _lyricsSource = TextEditingController();
  bool _isPublished = true;
  bool _isSaving = false;
  String? _replacementAudioToken;
  String? _replacementAudioName;
  String? _error;

  Map<String, dynamic> get data => widget.submission.retainedEntity;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(
      text:
          switch (widget.submission.entityType) {
            CatalogSubmissionEntityType.author => data['currentName'],
            CatalogSubmissionEntityType.album => data['title'],
            CatalogSubmissionEntityType.track => data['name'],
          }?.toString() ??
          '',
    );
    _cover = TextEditingController(
      text: data['coverImagePath']?.toString() ?? '',
    );
    _authorIds = TextEditingController(
      text: (data['authorIds'] as List<dynamic>? ?? const []).join(', '),
    );
    _albumId = TextEditingController(text: data['albumId']?.toString() ?? '');
    _albumOrder = TextEditingController(
      text: data['albumOrder']?.toString() ?? '0',
    );
    _releaseDate = TextEditingController(
      text: data['releaseDate']?.toString().split('T').first ?? '',
    );
    _isPublished = data['isPublished'] as bool? ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _cover.dispose();
    _authorIds.dispose();
    _albumId.dispose();
    _albumOrder.dispose();
    _releaseDate.dispose();
    _lyrics.dispose();
    _lyricsLanguage.dispose();
    _lyricsSource.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit ${widget.submission.entityType.label.toLowerCase()}'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  enabled: !_isSaving,
                  decoration: InputDecoration(
                    labelText:
                        widget.submission.entityType ==
                            CatalogSubmissionEntityType.author
                        ? 'Current name'
                        : 'Title',
                    border: const OutlineInputBorder(),
                  ),
                  validator: _required,
                ),
                if (widget.submission.entityType !=
                    CatalogSubmissionEntityType.author) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _authorIds,
                    enabled: !_isSaving,
                    decoration: const InputDecoration(
                      labelText: 'Author IDs (comma separated)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => _parseIds(value).isEmpty
                        ? 'Select at least one author.'
                        : null,
                  ),
                ],
                if (widget.submission.entityType ==
                    CatalogSubmissionEntityType.album) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _cover,
                    enabled: !_isSaving,
                    decoration: const InputDecoration(
                      labelText: 'Cover image path',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _releaseDate,
                    enabled: !_isSaving,
                    decoration: const InputDecoration(
                      labelText: 'Release date (YYYY-MM-DD)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => DateTime.tryParse(value ?? '') == null
                        ? 'Enter a valid date.'
                        : null,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Published on release'),
                    value: _isPublished,
                    onChanged: _isSaving
                        ? null
                        : (value) => setState(() => _isPublished = value),
                  ),
                ],
                if (widget.submission.entityType ==
                    CatalogSubmissionEntityType.track) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _albumId,
                    enabled: !_isSaving,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Album ID',
                      border: OutlineInputBorder(),
                    ),
                    validator: _positiveInteger,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _albumOrder,
                    enabled: !_isSaving,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Album order',
                      border: OutlineInputBorder(),
                    ),
                    validator: _nonNegativeInteger,
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.tonalIcon(
                      onPressed: _isSaving ? null : _pickReplacementAudio,
                      icon: const Icon(Icons.upload_file),
                      label: Text(
                        _replacementAudioName ??
                            'Optionally replace staged audio',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _lyrics,
                    enabled: !_isSaving,
                    minLines: 3,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      labelText: 'Optional replacement lyrics',
                      helperText: 'Leave empty to keep the current lyrics.',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _lyricsLanguage,
                    enabled: !_isSaving,
                    decoration: const InputDecoration(
                      labelText: 'Lyrics language code',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _lyricsSource,
                    enabled: !_isSaving,
                    decoration: const InputDecoration(
                      labelText: 'Lyrics source',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                if (_isSaving) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('save-submission-edits'),
          onPressed: _isSaving ? null : _save,
          child: const Text('Save changes'),
        ),
      ],
    );
  }

  Future<void> _pickReplacementAudio() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      withData: true,
    );
    final file = result?.files.single;
    if (file?.bytes == null || !mounted) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final upload = await context
          .read<CatalogSubmissionRepository>()
          .stageAudio(fileName: file!.name, bytes: file.bytes!);
      if (!mounted) return;
      setState(() {
        _replacementAudioToken = upload.token;
        _replacementAudioName = upload.originalName;
      });
    } catch (error) {
      if (mounted) setState(() => _error = describeCatalogError(error));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });
    final repository = context.read<CatalogSubmissionRepository>();
    try {
      switch (widget.submission.entityType) {
        case CatalogSubmissionEntityType.author:
          await repository.updateAuthor(
            widget.submission.entityId,
            AuthorSubmissionRequest(
              currentName: _name.text,
              photos: (data['photos'] as List<dynamic>? ?? const [])
                  .whereType<String>()
                  .toList(growable: false),
            ),
          );
          break;
        case CatalogSubmissionEntityType.album:
          await repository.updateAlbum(
            widget.submission.entityId,
            AlbumSubmissionRequest(
              title: _name.text,
              coverImagePath: _cover.text,
              authorIds: _parseIds(_authorIds.text),
              releaseDate: DateTime.parse(_releaseDate.text),
              isPublished: _isPublished,
              trackIds: (data['trackIds'] as List<dynamic>? ?? const [])
                  .whereType<num>()
                  .map((id) => id.toInt())
                  .toList(growable: false),
              additionalInfo: _mapList(data['additionalInfo']),
            ),
          );
          break;
        case CatalogSubmissionEntityType.track:
          await repository.updateTrack(
            widget.submission.entityId,
            TrackSubmissionRequest(
              name: _name.text,
              authorIds: _parseIds(_authorIds.text),
              albumId: int.parse(_albumId.text),
              albumOrder: int.parse(_albumOrder.text),
              audioUploadToken: _replacementAudioToken,
              additionalInfo: _mapList(data['additionalInfo']),
              sourceMetadata: _mapList(data['sourceMetadata']),
            ),
          );
          if (_lyrics.text.trim().isNotEmpty) {
            await repository.putTrackLyrics(
              widget.submission.entityId,
              TrackLyrics(
                trackId: widget.submission.entityId,
                type: TrackLyricsType.plain,
                languageCode: _lyricsLanguage.text.trim(),
                isVerified: false,
                source: _lyricsSource.text.trim(),
                plainText: _lyrics.text.trim(),
              ),
            );
          }
          break;
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = describeCatalogError(error));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'This field is required.' : null;

  String? _positiveInteger(String? value) {
    final parsed = int.tryParse(value ?? '');
    return parsed == null || parsed <= 0
        ? 'Enter an integer greater than zero.'
        : null;
  }

  String? _nonNegativeInteger(String? value) {
    final parsed = int.tryParse(value ?? '');
    return parsed == null || parsed < 0
        ? 'Enter zero or a positive integer.'
        : null;
  }
}

class _JsonDetails extends StatelessWidget {
  const _JsonDetails({required this.title, required this.value});

  final String title;
  final Map<String, dynamic> value;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(title),
      children: [
        SizedBox(
          width: double.infinity,
          child: SelectableText(
            const JsonEncoder.withIndent('  ').convert(value),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
          ),
        ),
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: ListTile(
        leading: const Icon(Icons.error_outline),
        title: Text(message),
        trailing: TextButton(onPressed: onRetry, child: const Text('Retry')),
      ),
    );
  }
}

List<int> _parseIds(String? value) => (value ?? '')
    .split(',')
    .map((item) => int.tryParse(item.trim()))
    .whereType<int>()
    .where((id) => id > 0)
    .toSet()
    .toList(growable: false);

List<Map<String, dynamic>> _mapList(Object? raw) =>
    (raw as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}
