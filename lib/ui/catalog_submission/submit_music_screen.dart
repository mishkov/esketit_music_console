import 'dart:convert';

import 'package:esketit_music_console/domain/album.dart';
import 'package:esketit_music_console/domain/author.dart';
import 'package:esketit_music_console/domain/catalog_submission.dart';
import 'package:esketit_music_console/domain/track_lyrics.dart';
import 'package:esketit_music_console/ui/catalog_submission/publication_status_badge.dart';
import 'package:esketit_music_console/ui/catalog_submission/submission_status_badge.dart';
import 'package:esketit_music_console/use_case/auth/bloc/auth_bloc.dart';
import 'package:esketit_music_console/use_case/catalog_submission/catalog_review_controller.dart';
import 'package:esketit_music_console/use_case/catalog_submission/catalog_submission_repository.dart';
import 'package:esketit_music_console/use_case/track/storage/tracks_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SubmitMusicScreen extends StatefulWidget {
  const SubmitMusicScreen({super.key, required this.onSubmissionCreated});

  final VoidCallback onSubmissionCreated;

  @override
  State<SubmitMusicScreen> createState() => _SubmitMusicScreenState();
}

class _SubmitMusicScreenState extends State<SubmitMusicScreen> {
  final _authorName = TextEditingController();
  final _albumTitle = TextEditingController();
  final _albumCover = TextEditingController();
  final _albumReleaseDate = TextEditingController(
    text: DateTime.now().toIso8601String().split('T').first,
  );
  final _trackName = TextEditingController();
  final _albumOrder = TextEditingController(text: '0');
  final _lyrics = TextEditingController();
  final _lyricsLanguage = TextEditingController(text: 'en');
  final _lyricsSource = TextEditingController();
  final _additionalInfo = TextEditingController(text: '[]');
  final _sourceMetadata = TextEditingController(text: '[]');

  List<Author> _authors = const [];
  List<Album> _albums = const [];
  final Set<int> _albumAuthorIds = {};
  final Set<int> _trackAuthorIds = {};
  int? _trackAlbumId;
  CatalogSubmissionUpload? _audioUpload;
  CatalogSubmission? _createdSubmission;
  bool _isPublished = true;
  bool _isLoadingOptions = true;
  bool _isMutating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  @override
  void dispose() {
    for (final controller in [
      _authorName,
      _albumTitle,
      _albumCover,
      _albumReleaseDate,
      _trackName,
      _albumOrder,
      _lyrics,
      _lyricsLanguage,
      _lyricsSource,
      _additionalInfo,
      _sourceMetadata,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  bool _can(String permission) =>
      context.read<AuthBloc>().state.session?.user.hasPermission(permission) ??
      false;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Build a reviewed catalog submission',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        const Text(
          'Reuse published or your own pending catalog records, or create dependencies here before submitting a track.',
        ),
        if (_isLoadingOptions) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: ListTile(
              leading: const Icon(Icons.error_outline),
              title: Text(_error!),
              trailing: TextButton(
                onPressed: _isMutating ? null : _loadOptions,
                child: const Text('Retry'),
              ),
            ),
          ),
        ],
        if (_isMutating) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
        ],
        if (_can(authorsSubmitPermission)) ...[
          const SizedBox(height: 16),
          _SectionCard(
            number: 1,
            title: 'Create a pending author',
            subtitle:
                'Skip this when a suitable published or pending author already exists.',
            child: Column(
              children: [
                TextField(
                  key: const ValueKey('new-author-name'),
                  controller: _authorName,
                  enabled: !_isMutating,
                  decoration: const InputDecoration(
                    labelText: 'Artist name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonal(
                    key: const ValueKey('submit-author'),
                    onPressed: _isMutating ? null : _submitAuthor,
                    child: const Text('Submit author'),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (_can(albumsSubmitPermission)) ...[
          const SizedBox(height: 16),
          _SectionCard(
            number: 2,
            title: 'Create a pending album',
            subtitle:
                'New album submissions always start with an empty track list.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  key: const ValueKey('new-album-title'),
                  controller: _albumTitle,
                  enabled: !_isMutating,
                  decoration: const InputDecoration(
                    labelText: 'Album title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _albumCover,
                  enabled: !_isMutating,
                  decoration: const InputDecoration(
                    labelText: 'Cover image path (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _albumReleaseDate,
                  enabled: !_isMutating,
                  decoration: const InputDecoration(
                    labelText: 'Release date (YYYY-MM-DD)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                _AuthorChoices(
                  authors: _authors,
                  selectedIds: _albumAuthorIds,
                  enabled: !_isMutating,
                  label: 'Album authors',
                  onToggle: (id, selected) => setState(() {
                    selected
                        ? _albumAuthorIds.add(id)
                        : _albumAuthorIds.remove(id);
                  }),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Published on release'),
                  value: _isPublished,
                  onChanged: _isMutating
                      ? null
                      : (value) => setState(() => _isPublished = value),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonal(
                    key: const ValueKey('submit-album'),
                    onPressed: _isMutating ? null : _submitAlbum,
                    child: const Text('Submit album'),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (_can(tracksSubmitPermission)) ...[
          const SizedBox(height: 16),
          _SectionCard(
            number: 3,
            title: 'Stage audio and submit a track',
            subtitle:
                'Audio is staged for review and is not uploaded through the public songs endpoint.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  key: const ValueKey('new-track-name'),
                  controller: _trackName,
                  enabled: !_isMutating,
                  decoration: const InputDecoration(
                    labelText: 'Track name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                _AuthorChoices(
                  authors: _authors,
                  selectedIds: _trackAuthorIds,
                  enabled: !_isMutating,
                  label: 'Track authors',
                  onToggle: (id, selected) => setState(() {
                    selected
                        ? _trackAuthorIds.add(id)
                        : _trackAuthorIds.remove(id);
                  }),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  key: const ValueKey('track-album'),
                  initialValue: _trackAlbumId,
                  decoration: const InputDecoration(
                    labelText: 'Album',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final album in _albums.where(
                      (item) => item.id != null,
                    ))
                      DropdownMenuItem(
                        value: album.id,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(child: Text(album.title)),
                            const SizedBox(width: 8),
                            PublicationStatusBadge(
                              status: album.publicationStatus,
                            ),
                          ],
                        ),
                      ),
                  ],
                  onChanged: _isMutating
                      ? null
                      : (value) => setState(() => _trackAlbumId = value),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _albumOrder,
                  enabled: !_isMutating,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Album order',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilledButton.tonalIcon(
                      key: const ValueKey('stage-audio'),
                      onPressed: _isMutating ? null : _pickAndStageAudio,
                      icon: const Icon(Icons.audio_file),
                      label: Text(
                        _audioUpload == null
                            ? 'Choose and stage audio'
                            : 'Replace staged audio',
                      ),
                    ),
                    if (_audioUpload != null)
                      Text(
                        '${_audioUpload!.originalName} · ${_formatBytes(_audioUpload!.sizeBytes)}',
                      ),
                  ],
                ),
                if (_can(catalogSubmissionsUpdateOwnPermission)) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Optional lyrics',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'A track approved with lyrics receives 5 additional rating points.',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _lyrics,
                    enabled: !_isMutating,
                    minLines: 3,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      labelText: 'Plain lyrics',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _lyricsLanguage,
                          enabled: !_isMutating,
                          decoration: const InputDecoration(
                            labelText: 'Language code',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _lyricsSource,
                          enabled: !_isMutating,
                          decoration: const InputDecoration(
                            labelText: 'Source',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('Advanced metadata'),
                  subtitle: const Text(
                    'Optional JSON arrays for additional info and source metadata.',
                  ),
                  children: [
                    TextField(
                      controller: _additionalInfo,
                      enabled: !_isMutating,
                      minLines: 2,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'Additional info JSON',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _sourceMetadata,
                      enabled: !_isMutating,
                      minLines: 2,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'Source metadata JSON',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    key: const ValueKey('submit-track'),
                    onPressed: _isMutating ? null : _submitTrack,
                    icon: const Icon(Icons.send),
                    label: const Text('Submit track'),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (_createdSubmission != null) ...[
          const SizedBox(height: 16),
          Card(
            key: const ValueKey('created-submission'),
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle_outline),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Submission #${_createdSubmission!.id} created',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      SubmissionStatusBadge(status: _createdSubmission!.status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'The track is already available to you while it awaits review.',
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    key: const ValueKey('open-created-submission'),
                    onPressed: widget.onSubmissionCreated,
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('View submission details'),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 32),
      ],
    );
  }

  Future<void> _loadOptions() async {
    setState(() {
      _isLoadingOptions = true;
      _error = null;
    });
    try {
      final storage = context.read<TracksStorage>();
      final authors = await storage.getAuthors();
      final albums = <Album>[];
      var page = 1;
      do {
        final response = await storage.getAlbumsList(page: page, pageSize: 100);
        albums.addAll(response.albums);
        if (page >= response.totalPages || response.totalPages == 0) break;
        page += 1;
      } while (true);
      authors.sort((a, b) => a.currentName.compareTo(b.currentName));
      albums.sort((a, b) => a.title.compareTo(b.title));
      if (!mounted) return;
      setState(() {
        _authors = authors;
        _albums = albums;
        _isLoadingOptions = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingOptions = false;
        _error = describeCatalogError(error);
      });
    }
  }

  Future<void> _submitAuthor() async {
    if (_authorName.text.trim().isEmpty) {
      return _showValidation('Artist name is required.');
    }
    await _run(() async {
      final created = await context
          .read<CatalogSubmissionRepository>()
          .submitAuthor(AuthorSubmissionRequest(currentName: _authorName.text));
      _authorName.clear();
      _createdSubmission = created;
      await _loadOptions();
    });
  }

  Future<void> _submitAlbum() async {
    final releaseDate = DateTime.tryParse(_albumReleaseDate.text);
    if (_albumTitle.text.trim().isEmpty) {
      return _showValidation('Album title is required.');
    }
    if (_albumAuthorIds.isEmpty) {
      return _showValidation('Select at least one album author.');
    }
    if (releaseDate == null) {
      return _showValidation('Enter a valid release date.');
    }
    await _run(() async {
      final created = await context
          .read<CatalogSubmissionRepository>()
          .submitAlbum(
            AlbumSubmissionRequest(
              title: _albumTitle.text,
              coverImagePath: _albumCover.text,
              authorIds: _albumAuthorIds.toList(growable: false),
              releaseDate: releaseDate,
              isPublished: _isPublished,
              trackIds: const [],
            ),
          );
      _albumTitle.clear();
      _albumCover.clear();
      _albumAuthorIds.clear();
      _createdSubmission = created;
      await _loadOptions();
    });
  }

  Future<void> _pickAndStageAudio() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      withData: true,
    );
    final file = result?.files.single;
    if (file?.bytes == null) return;
    await _run(() async {
      _audioUpload = await context
          .read<CatalogSubmissionRepository>()
          .stageAudio(fileName: file!.name, bytes: file.bytes!);
    });
  }

  Future<void> _submitTrack() async {
    final order = int.tryParse(_albumOrder.text);
    if (_trackName.text.trim().isEmpty) {
      return _showValidation('Track name is required.');
    }
    if (_trackAuthorIds.isEmpty) {
      return _showValidation('Select at least one track author.');
    }
    if (_trackAlbumId == null) return _showValidation('Select an album.');
    if (order == null || order < 0) {
      return _showValidation('Album order must be zero or greater.');
    }
    if (_audioUpload == null) {
      return _showValidation('Stage an audio file first.');
    }

    List<Map<String, dynamic>> additionalInfo;
    List<Map<String, dynamic>> sourceMetadata;
    try {
      additionalInfo = _decodeMapList(_additionalInfo.text);
      sourceMetadata = _decodeMapList(_sourceMetadata.text);
    } catch (error) {
      return _showValidation('$error');
    }

    await _run(() async {
      final repository = context.read<CatalogSubmissionRepository>();
      final created = await repository.submitTrack(
        TrackSubmissionRequest(
          name: _trackName.text,
          authorIds: _trackAuthorIds.toList(growable: false),
          albumId: _trackAlbumId!,
          albumOrder: order,
          audioUploadToken: _audioUpload!.token,
          additionalInfo: additionalInfo,
          sourceMetadata: sourceMetadata,
        ),
      );
      if (_lyrics.text.trim().isNotEmpty &&
          _can(catalogSubmissionsUpdateOwnPermission)) {
        await repository.putTrackLyrics(
          created.entityId,
          TrackLyrics(
            trackId: created.entityId,
            type: TrackLyricsType.plain,
            languageCode: _lyricsLanguage.text.trim(),
            isVerified: false,
            source: _lyricsSource.text.trim(),
            plainText: _lyrics.text.trim(),
          ),
        );
      }
      _createdSubmission = created;
      _trackName.clear();
      _trackAuthorIds.clear();
      _trackAlbumId = null;
      _albumOrder.text = '0';
      _audioUpload = null;
      _lyrics.clear();
      _lyricsSource.clear();
      _additionalInfo.text = '[]';
      _sourceMetadata.text = '[]';
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_isMutating) return;
    setState(() {
      _isMutating = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _error = describeCatalogError(error));
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }

  void _showValidation(String message) {
    setState(() => _error = message);
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final int number;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(radius: 16, child: Text('$number')),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(subtitle),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _AuthorChoices extends StatelessWidget {
  const _AuthorChoices({
    required this.authors,
    required this.selectedIds,
    required this.enabled,
    required this.label,
    required this.onToggle,
  });

  final List<Author> authors;
  final Set<int> selectedIds;
  final bool enabled;
  final String label;
  final void Function(int id, bool selected) onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        if (authors.isEmpty)
          const Text('No reusable authors are available.')
        else
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final author in authors.where((item) => item.id != null))
                FilterChip(
                  selected: selectedIds.contains(author.id),
                  onSelected: enabled
                      ? (value) => onToggle(author.id!, value)
                      : null,
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(author.currentName),
                      const SizedBox(width: 6),
                      PublicationStatusBadge(status: author.publicationStatus),
                    ],
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

List<Map<String, dynamic>> _decodeMapList(String source) {
  final decoded = jsonDecode(source);
  if (decoded is! List) {
    throw const FormatException('Metadata must be a JSON array.');
  }
  if (decoded.any((item) => item is! Map)) {
    throw const FormatException('Every metadata item must be a JSON object.');
  }
  return decoded
      .cast<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
