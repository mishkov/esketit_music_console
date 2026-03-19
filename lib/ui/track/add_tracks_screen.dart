import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:esketit_music_console/domain/album.dart';
import 'package:esketit_music_console/domain/author.dart';
import 'package:esketit_music_console/domain/track.dart';
import 'package:esketit_music_console/domain/track_info/text_track_info.dart';
import 'package:esketit_music_console/errors/http_app_error.dart';
import 'package:esketit_music_console/esketit_rest_api/telegram/telegram_import_models.dart';
import 'package:esketit_music_console/ui/album/edit_album_screen.dart';
import 'package:esketit_music_console/unassigned_layer/cross_file.dart';
import 'package:esketit_music_console/unassigned_layer/browser_file_download.dart';
import 'package:esketit_music_console/unassigned_layer/mp3_metadata.dart';
import 'package:esketit_music_console/use_case/telegram/telegram_import_repository.dart';
import 'package:esketit_music_console/use_case/track/storage/tracks_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

const _createAlbumOptionValue = -1;

class AddTracksScreen extends StatefulWidget {
  const AddTracksScreen({super.key});

  @override
  State<AddTracksScreen> createState() => _AddTracksScreenState();
}

class _AddTracksScreenState extends State<AddTracksScreen> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Add Tracks'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Upload single file'),
              Tab(text: 'Import from Telegram'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_UploadSingleFileTab(), _TelegramImportTab()],
        ),
      ),
    );
  }
}

class _UploadSingleFileTab extends StatefulWidget {
  const _UploadSingleFileTab();

  @override
  State<_UploadSingleFileTab> createState() => _UploadSingleFileTabState();
}

class _UploadSingleFileTabState extends State<_UploadSingleFileTab> {
  final _titleController = TextEditingController();
  final List<TextTrackInfo> _additionalInfos = [];
  final List<Author> _selectedAuthors = [];
  List<Author> _availableAuthors = const [];
  List<Album> _availableAlbums = const [];
  CrossFile? _pickedFile;
  bool _isSaving = false;
  bool _isLoadingAuthors = true;
  bool _isLoadingAlbums = true;
  int? _selectedAlbumId;

  @override
  void initState() {
    super.initState();
    _loadAuthors();
    _loadAlbums();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isLoadingAuthors || _isLoadingAlbums)
                  const LinearProgressIndicator(),
                FilledButton.icon(
                  onPressed: _isSaving ? null : _pickFile,
                  icon: const Icon(Icons.upload_file),
                  label: Text(
                    _pickedFile == null ? 'Pick file' : 'Replace file',
                  ),
                ),
                const SizedBox(height: 12),
                _SelectionSummaryCard(
                  title: 'Selected file',
                  value: _pickedFile?.name ?? 'No file selected',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _titleController,
                  enabled: !_isSaving,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  key: ValueKey(
                    'album-${_selectedAlbumId ?? 'none'}-${_availableAlbums.length}',
                  ),
                  initialValue: _selectedAlbumId,
                  items: [
                    ..._availableAlbums.map(
                      (album) => DropdownMenuItem<int>(
                        value: album.id,
                        child: Text(album.title),
                      ),
                    ),
                    const DropdownMenuItem<int>(
                      value: _createAlbumOptionValue,
                      child: Text('Create new album...'),
                    ),
                  ],
                  onChanged: _isSaving || _isLoadingAlbums
                      ? null
                      : _onAlbumChanged,
                  decoration: const InputDecoration(
                    labelText: 'Album',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                _SelectionSummaryCard(
                  title: 'Album position',
                  value: _selectedAlbum == null
                      ? 'Select an album'
                      : 'Track will be added as item ${_selectedAlbum!.trackIds.length + 1}',
                ),
                const SizedBox(height: 16),
                _AuthorPickerField(
                  authors: _selectedAuthors,
                  isLoading: _isLoadingAuthors,
                  onTap: _isSaving ? null : _showAuthorPicker,
                  onRemove: _isSaving ? null : _removeAuthor,
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                Text(
                  'Additional infos',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                if (_additionalInfos.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'No additional infos yet.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                else
                  ..._additionalInfos.asMap().entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _AdditionalInfoCard(
                        info: entry.value,
                        onDelete: _isSaving
                            ? null
                            : () => _removeAdditionalInfo(entry.key),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                MenuAnchor(
                  menuChildren: [
                    MenuItemButton(
                      onPressed: _showAddTextInfoDialog,
                      child: const Text('Text info'),
                    ),
                  ],
                  builder: (context, controller, child) {
                    return FilledButton.tonalIcon(
                      onPressed: _isSaving
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
                if (_isSaving) const LinearProgressIndicator(),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FilledButton(
                      onPressed: _isSaving ? null : _saveTrack,
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _loadAuthors() async {
    try {
      final authors = await context.read<TracksStorage>().getAuthors();
      if (!mounted) {
        return;
      }
      authors.sort(
        (left, right) => left.currentName.toLowerCase().compareTo(
          right.currentName.toLowerCase(),
        ),
      );
      setState(() {
        _availableAuthors = authors;
        _isLoadingAuthors = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingAuthors = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load authors: $error')));
    }
  }

  Future<void> _loadAlbums() async {
    try {
      final albums = await context.read<TracksStorage>().getAlbums();
      if (!mounted) {
        return;
      }
      albums.sort(
        (left, right) =>
            left.title.toLowerCase().compareTo(right.title.toLowerCase()),
      );
      setState(() {
        _availableAlbums = albums;
        if (!_availableAlbums.any((album) => album.id == _selectedAlbumId)) {
          _selectedAlbumId = albums.isEmpty ? null : albums.first.id;
        }
        _isLoadingAlbums = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingAlbums = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load albums: $error')));
    }
  }

  Future<void> _onAlbumChanged(int? value) async {
    if (value == _createAlbumOptionValue) {
      await _openCreateAlbumScreen();
      return;
    }

    setState(() {
      _selectedAlbumId = value;
    });
  }

  Future<void> _openCreateAlbumScreen() async {
    final previousAlbumIds = _availableAlbums.map((album) => album.id).toSet();
    final didSave = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const EditAlbumScreen()));

    if (didSave != true || !mounted) {
      return;
    }

    await _loadAlbums();
    if (!mounted) {
      return;
    }

    Album? newAlbum;
    for (final album in _availableAlbums) {
      if (album.id != null && !previousAlbumIds.contains(album.id)) {
        newAlbum = album;
        break;
      }
    }
    newAlbum ??= _availableAlbums.isEmpty ? null : _availableAlbums.last;

    if (newAlbum?.id != null) {
      setState(() {
        _selectedAlbumId = newAlbum!.id;
      });
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    final file = result?.files.single;
    if (file == null || file.bytes == null) {
      return;
    }

    final xFile = XFile.fromData(
      file.bytes!,
      name: file.name,
      mimeType: file.extension == null ? null : 'audio/${file.extension}',
    );
    final metadata = parseMp3Metadata(file.bytes!);

    setState(() {
      _pickedFile = CrossFile(file: xFile);
      if ((metadata.title?.isNotEmpty ?? false)) {
        _titleController.text = metadata.title!;
      }
    });

    await _applyMetadataAuthors(metadata.authors);
  }

  Future<void> _applyMetadataAuthors(List<String> metadataAuthors) async {
    if (metadataAuthors.isEmpty) {
      return;
    }

    final knownAuthors = <Author>[];
    final newAuthors = <String>[];

    for (final authorName in metadataAuthors) {
      final existingAuthor = _findAvailableAuthor(authorName);
      if (existingAuthor != null) {
        knownAuthors.add(existingAuthor);
      } else {
        newAuthors.add(authorName);
      }
    }

    if (knownAuthors.isNotEmpty) {
      setState(() {
        for (final author in knownAuthors) {
          _addSelectedAuthor(author);
        }
      });
    }

    if (newAuthors.isEmpty || !mounted) {
      return;
    }

    final shouldAdd = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add new authors to database?'),
          content: Text(
            'The MP3 metadata contains authors that are not in the database yet:\n\n${newAuthors.join(', ')}\n\nDo you want to add them?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );

    if (shouldAdd != true || !mounted) {
      return;
    }

    setState(() {
      for (final authorName in newAuthors) {
        _addSelectedAuthor(Author(currentName: authorName));
      }
    });
  }

  Future<void> _showAuthorPicker() async {
    final pickedAuthors = await showDialog<List<Author>>(
      context: context,
      builder: (context) => _AuthorPickerDialog(
        availableAuthors: _availableAuthors,
        initiallySelectedAuthors: _selectedAuthors,
      ),
    );

    if (pickedAuthors == null || !mounted) {
      return;
    }

    setState(() {
      _selectedAuthors
        ..clear()
        ..addAll(pickedAuthors);
    });
  }

  Future<void> _showAddTextInfoDialog() async {
    final titleController = TextEditingController();
    final textController = TextEditingController();

    final info = await showDialog<TextTrackInfo>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add text info'),
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
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    titleController.dispose();
    textController.dispose();

    if (info == null || !mounted) {
      return;
    }

    setState(() {
      _additionalInfos.add(info);
    });
  }

  Future<void> _saveTrack() async {
    if (_pickedFile == null || _titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File and title are required.')),
      );
      return;
    }
    final selectedAlbum = _selectedAlbum;
    if (selectedAlbum?.id == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select an album first.')));
      return;
    }
    if (_selectedAuthors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one author.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await context.read<TracksStorage>().putTrack(
        Track(
          name: _titleController.text.trim(),
          authors: List<Author>.from(_selectedAuthors),
          albumId: selectedAlbum!.id!,
          albumOrder: selectedAlbum.trackIds.length,
          additionalInfo: List<TextTrackInfo>.from(_additionalInfos),
          file: _pickedFile!,
        ),
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save track: $error')));
    }
  }

  void _removeAuthor(Author author) {
    setState(() {
      _selectedAuthors.remove(author);
    });
  }

  void _removeAdditionalInfo(int index) {
    setState(() {
      _additionalInfos.removeAt(index);
    });
  }

  void _addSelectedAuthor(Author author) {
    final exists = _selectedAuthors.any(
      (selected) =>
          selected.currentName.toLowerCase() ==
          author.currentName.toLowerCase(),
    );
    if (!exists) {
      _selectedAuthors.add(author);
    }
  }

  Author? _findAvailableAuthor(String authorName) {
    for (final author in _availableAuthors) {
      if (author.currentName.toLowerCase() == authorName.toLowerCase()) {
        return author;
      }
    }
    return null;
  }

  Album? get _selectedAlbum {
    for (final album in _availableAlbums) {
      if (album.id == _selectedAlbumId) {
        return album;
      }
    }
    return null;
  }
}

class _TelegramImportTab extends StatefulWidget {
  const _TelegramImportTab();

  @override
  State<_TelegramImportTab> createState() => _TelegramImportTabState();
}

class _TelegramImportTabState extends State<_TelegramImportTab> {
  final _channelUsernameController = TextEditingController();
  final _titleController = TextEditingController();
  final List<TextTrackInfo> _additionalInfos = [];
  final List<Author> _selectedAuthors = [];
  List<Author> _availableAuthors = const [];
  List<Album> _availableAlbums = const [];

  TelegramStatus? _telegramStatus;
  TelegramImportSession? _session;
  Uint8List? _currentAudioBytes;
  String? _audioErrorMessage;
  int? _loadedTrackMessageId;
  bool _isLoadingState = true;
  bool _isLoadingAuthors = true;
  bool _isLoadingAlbums = true;
  bool _isStartingSession = false;
  bool _isSaving = false;
  bool _isSkipping = false;
  bool _isCancelling = false;
  bool _isDownloadingReport = false;
  int? _selectedAlbumId;

  @override
  void initState() {
    super.initState();
    _loadInitialState();
  }

  @override
  void dispose() {
    _channelUsernameController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = _telegramStatus;
    final session = _session;
    final currentTrack = session?.currentTrack;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isLoadingState || _isLoadingAuthors || _isLoadingAlbums)
                  const LinearProgressIndicator(),
                if (_telegramStatus == null && !_isLoadingState)
                  _TelegramInfoBanner(
                    message: 'Failed to load Telegram integration status.',
                  )
                else if (status != null && !status.configured)
                  _TelegramInfoBanner(
                    message:
                        'Telegram integration is not configured on the backend. Open Settings to configure TELEGRAM_API_ID and TELEGRAM_API_HASH.',
                    actionLabel: 'Open Settings',
                    onAction: () => Navigator.of(context).pop(),
                  )
                else if (status != null && !status.authorized)
                  const _TelegramInfoBanner(
                    message:
                        'Telegram integration is configured but not authorized. Finish Telegram login in Settings before starting an import session.',
                  )
                else if (session == null)
                  _buildSessionStarter(context)
                else if (session.isCompleted)
                  _buildCompletedState(context, session)
                else if (currentTrack != null)
                  _buildTrackReview(context, session, currentTrack)
                else
                  _TelegramInfoBanner(
                    message:
                        'Telegram import session is active but no current track is available.',
                    actionLabel: 'Reload session',
                    onAction: _refreshTelegramState,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSessionStarter(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Start Telegram import',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            const Text(
              'Paste a public Telegram channel username. The backend will scan audio tracks and open them one by one for review.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _channelUsernameController,
              enabled: !_isStartingSession,
              decoration: const InputDecoration(
                labelText: 'Channel username',
                hintText: 'channel_name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: _isStartingSession ? null : _startSession,
                  icon: const Icon(Icons.cloud_download_outlined),
                  label: Text(
                    _isStartingSession ? 'Starting...' : 'Start import',
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: _isLoadingState ? null : _refreshTelegramState,
                  child: const Text('Refresh'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedState(
    BuildContext context,
    TelegramImportSession session,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Import completed',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text('Channel: @${session.channelUsername}'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _SelectionSummaryCard(
                  title: 'Saved',
                  value: '${session.progress.saved}',
                ),
                _SelectionSummaryCard(
                  title: 'Skipped',
                  value: '${session.progress.skipped}',
                ),
                _SelectionSummaryCard(
                  title: 'Processed',
                  value:
                      '${session.progress.processed}/${session.progress.total}',
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: _isDownloadingReport
                      ? null
                      : _downloadSkippedReport,
                  icon: const Icon(Icons.download),
                  label: Text(
                    _isDownloadingReport
                        ? 'Preparing report...'
                        : 'Download skipped CSV',
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: _isCancelling ? null : _clearCompletedSession,
                  child: Text(_isCancelling ? 'Clearing...' : 'Clear session'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackReview(
    BuildContext context,
    TelegramImportSession session,
    TelegramImportTrack currentTrack,
  ) {
    final selectedAlbum = _selectedAlbum;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Telegram track',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _SelectionSummaryCard(
                      title: 'Channel',
                      value: '@${session.channelUsername}',
                    ),
                    _SelectionSummaryCard(
                      title: 'Progress',
                      value:
                          '${session.progress.processed}/${session.progress.total}',
                    ),
                    _SelectionSummaryCard(
                      title: 'Remaining',
                      value: '${session.progress.remaining}',
                    ),
                    _SelectionSummaryCard(
                      title: 'Skipped',
                      value: '${session.progress.skipped}',
                    ),
                    _SelectionSummaryCard(
                      title: 'Saved',
                      value: '${session.progress.saved}',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SelectionSummaryCard(
                  title: 'Telegram message',
                  value: currentTrack.telegramMessageLink,
                ),
                const SizedBox(height: 12),
                _SelectionSummaryCard(
                  title: 'Audio file',
                  value:
                      '${currentTrack.fileName}\n${currentTrack.mimeType} • ${_formatBytes(currentTrack.sizeBytes)}',
                ),
                if (_audioErrorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _audioErrorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _currentAudioBytes == null
                          ? null
                          : _downloadCurrentAudio,
                      icon: const Icon(Icons.audio_file),
                      label: const Text('Download audio'),
                    ),
                    TextButton(
                      onPressed: _refreshCurrentAudio,
                      child: const Text('Reload audio metadata'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _titleController,
          enabled: !_isSaving && !_isSkipping && !_isCancelling,
          decoration: const InputDecoration(
            labelText: 'Title',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<int>(
          key: ValueKey(
            'telegram-album-${_selectedAlbumId ?? 'none'}-${_availableAlbums.length}',
          ),
          initialValue: _selectedAlbumId,
          items: [
            ..._availableAlbums.map(
              (album) => DropdownMenuItem<int>(
                value: album.id,
                child: Text(album.title),
              ),
            ),
            const DropdownMenuItem<int>(
              value: _createAlbumOptionValue,
              child: Text('Create new album...'),
            ),
          ],
          onChanged:
              _isSaving || _isSkipping || _isCancelling || _isLoadingAlbums
              ? null
              : _onAlbumChanged,
          decoration: const InputDecoration(
            labelText: 'Album',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        _SelectionSummaryCard(
          title: 'Album position',
          value: selectedAlbum == null
              ? 'Select an album'
              : 'Track will be added as item ${selectedAlbum.trackIds.length + 1}',
        ),
        const SizedBox(height: 16),
        _AuthorPickerField(
          authors: _selectedAuthors,
          isLoading: _isLoadingAuthors,
          onTap: _isSaving || _isSkipping || _isCancelling
              ? null
              : _showAuthorPicker,
          onRemove: _isSaving || _isSkipping || _isCancelling
              ? null
              : _removeAuthor,
        ),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 12),
        Text(
          'Additional infos',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        if (_additionalInfos.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'No additional infos yet.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          )
        else
          ..._additionalInfos.asMap().entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _AdditionalInfoCard(
                info: entry.value,
                onDelete: _isSaving || _isSkipping || _isCancelling
                    ? null
                    : () => _removeAdditionalInfo(entry.key),
              ),
            ),
          ),
        const SizedBox(height: 12),
        MenuAnchor(
          menuChildren: [
            MenuItemButton(
              onPressed: _showAddTextInfoDialog,
              child: const Text('Text info'),
            ),
          ],
          builder: (context, controller, child) {
            return FilledButton.tonalIcon(
              onPressed: _isSaving || _isSkipping || _isCancelling
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
        if (_isSaving || _isSkipping || _isCancelling)
          const LinearProgressIndicator(),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: _isSaving || _isSkipping || _isCancelling
                  ? null
                  : _cancelSession,
              child: const Text('Cancel session'),
            ),
            const SizedBox(width: 12),
            FilledButton.tonal(
              onPressed: _isSaving || _isSkipping || _isCancelling
                  ? null
                  : _skipAndNext,
              child: const Text('Skip and next'),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: _isSaving || _isSkipping || _isCancelling
                  ? null
                  : _saveAndNext,
              child: const Text('Save and next'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _loadInitialState() async {
    await _loadAuthors();
    await _loadAlbums();
    await _refreshTelegramState();
  }

  Future<void> _refreshTelegramState() async {
    setState(() {
      _isLoadingState = true;
    });

    try {
      final repository = context.read<TelegramImportRepository>();
      final status = await repository.getStatus();
      TelegramImportSession? session;
      if (status.configured && status.authorized) {
        session = await repository.getCurrentSession();
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _telegramStatus = status;
        _session = session;
        _isLoadingState = false;
      });
      await _syncTrackStateWithSession(session);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _telegramStatus = null;
        _session = null;
        _isLoadingState = false;
      });
      _showMessage(_errorMessageFrom(error));
    }
  }

  Future<void> _loadAuthors() async {
    try {
      final authors = await context.read<TracksStorage>().getAuthors();
      if (!mounted) {
        return;
      }
      authors.sort(
        (left, right) => left.currentName.toLowerCase().compareTo(
          right.currentName.toLowerCase(),
        ),
      );
      setState(() {
        _availableAuthors = authors;
        _isLoadingAuthors = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingAuthors = false;
      });
      _showMessage('Failed to load authors: $error');
    }
  }

  Future<void> _loadAlbums() async {
    try {
      final albums = await context.read<TracksStorage>().getAlbums();
      if (!mounted) {
        return;
      }
      albums.sort(
        (left, right) =>
            left.title.toLowerCase().compareTo(right.title.toLowerCase()),
      );
      setState(() {
        _availableAlbums = albums;
        if (!_availableAlbums.any((album) => album.id == _selectedAlbumId)) {
          _selectedAlbumId = albums.isEmpty ? null : albums.first.id;
        }
        _isLoadingAlbums = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingAlbums = false;
      });
      _showMessage('Failed to load albums: $error');
    }
  }

  Future<void> _onAlbumChanged(int? value) async {
    if (value == _createAlbumOptionValue) {
      await _openCreateAlbumScreen();
      return;
    }

    setState(() {
      _selectedAlbumId = value;
    });
  }

  Future<void> _openCreateAlbumScreen() async {
    final previousAlbumIds = _availableAlbums.map((album) => album.id).toSet();
    final didSave = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const EditAlbumScreen()));

    if (didSave != true || !mounted) {
      return;
    }

    await _loadAlbums();
    if (!mounted) {
      return;
    }

    Album? newAlbum;
    for (final album in _availableAlbums) {
      if (album.id != null && !previousAlbumIds.contains(album.id)) {
        newAlbum = album;
        break;
      }
    }
    newAlbum ??= _availableAlbums.isEmpty ? null : _availableAlbums.last;

    if (newAlbum?.id != null) {
      setState(() {
        _selectedAlbumId = newAlbum!.id;
      });
    }
  }

  Future<void> _startSession() async {
    final channelUsername = _normalizeChannelUsername(
      _channelUsernameController.text,
    );
    if (channelUsername.isEmpty) {
      _showMessage('Channel username is required.');
      return;
    }

    setState(() {
      _isStartingSession = true;
    });

    final repository = context.read<TelegramImportRepository>();

    try {
      final session = await repository.startSession(
        channelUsername: channelUsername,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _session = session;
        _isStartingSession = false;
      });
      await _syncTrackStateWithSession(session);
    } on HttpAppError catch (error) {
      if (error.statusCode == 409 &&
          error.message == 'telegram import session is already active') {
        if (!mounted) {
          return;
        }
        final shouldReplace = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Replace active import session?'),
              content: const Text(
                'There is already an active Telegram import session. Start a new one and replace it?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('No'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Replace'),
                ),
              ],
            );
          },
        );

        if (shouldReplace == true) {
          try {
            final session = await repository.startSession(
              channelUsername: channelUsername,
              replaceExisting: true,
            );
            if (!mounted) {
              return;
            }
            setState(() {
              _session = session;
              _isStartingSession = false;
            });
            await _syncTrackStateWithSession(session);
            return;
          } catch (replaceError) {
            if (!mounted) {
              return;
            }
            setState(() {
              _isStartingSession = false;
            });
            _showMessage(_errorMessageFrom(replaceError));
            return;
          }
        }
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _isStartingSession = false;
      });
      _showMessage(error.message);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isStartingSession = false;
      });
      _showMessage(_errorMessageFrom(error));
    }
  }

  Future<void> _syncTrackStateWithSession(
    TelegramImportSession? session,
  ) async {
    final track = session?.currentTrack;
    if (track == null) {
      setState(() {
        _currentAudioBytes = null;
        _audioErrorMessage = null;
        _loadedTrackMessageId = null;
        _titleController.clear();
        _additionalInfos.clear();
        _selectedAuthors.clear();
      });
      return;
    }

    if (_loadedTrackMessageId == track.messageId) {
      return;
    }

    setState(() {
      _loadedTrackMessageId = track.messageId;
      _currentAudioBytes = null;
      _audioErrorMessage = null;
      _titleController.text = track.parsedTitle;
      _additionalInfos.clear();
      _selectedAuthors.clear();
      if (!_availableAlbums.any((album) => album.id == _selectedAlbumId)) {
        _selectedAlbumId = _availableAlbums.isEmpty
            ? null
            : _availableAlbums.first.id;
      }
    });

    await _refreshCurrentAudio();
  }

  Future<void> _refreshCurrentAudio() async {
    final currentTrack = _session?.currentTrack;
    if (currentTrack == null) {
      return;
    }

    try {
      final downloaded = await context
          .read<TelegramImportRepository>()
          .downloadCurrentAudio();
      final metadata = parseMp3Metadata(downloaded.bytes);

      if (!mounted) {
        return;
      }

      setState(() {
        _currentAudioBytes = downloaded.bytes;
        _audioErrorMessage = null;
        if ((metadata.title?.isNotEmpty ?? false)) {
          _titleController.text = metadata.title!;
        } else if (_titleController.text.trim().isEmpty) {
          _titleController.text = currentTrack.parsedTitle;
        }
      });
      await _applyMetadataAuthors(metadata.authors);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _currentAudioBytes = null;
        _audioErrorMessage = _errorMessageFrom(error);
      });
    }
  }

  Future<void> _applyMetadataAuthors(List<String> metadataAuthors) async {
    if (metadataAuthors.isEmpty) {
      return;
    }

    final knownAuthors = <Author>[];
    final newAuthors = <String>[];

    for (final authorName in metadataAuthors) {
      final existingAuthor = _findAvailableAuthor(authorName);
      if (existingAuthor != null) {
        knownAuthors.add(existingAuthor);
      } else {
        newAuthors.add(authorName);
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      for (final author in knownAuthors) {
        _addSelectedAuthor(author);
      }
      for (final authorName in newAuthors) {
        _addSelectedAuthor(Author(currentName: authorName));
      }
    });
  }

  Future<void> _showAuthorPicker() async {
    final pickedAuthors = await showDialog<List<Author>>(
      context: context,
      builder: (context) => _AuthorPickerDialog(
        availableAuthors: _availableAuthors,
        initiallySelectedAuthors: _selectedAuthors,
      ),
    );

    if (pickedAuthors == null || !mounted) {
      return;
    }

    setState(() {
      _selectedAuthors
        ..clear()
        ..addAll(pickedAuthors);
    });
  }

  Future<void> _showAddTextInfoDialog() async {
    final titleController = TextEditingController();
    final textController = TextEditingController();

    final info = await showDialog<TextTrackInfo>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add text info'),
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
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    titleController.dispose();
    textController.dispose();

    if (info == null || !mounted) {
      return;
    }

    setState(() {
      _additionalInfos.add(info);
    });
  }

  Future<void> _saveAndNext() async {
    final title = _titleController.text.trim();
    final selectedAlbum = _selectedAlbum;
    final session = _session;

    if (session?.currentTrack == null) {
      _showMessage('No Telegram track is loaded.');
      return;
    }
    if (title.isEmpty) {
      _showMessage('Title is required.');
      return;
    }
    if (selectedAlbum?.id == null) {
      _showMessage('Select an album first.');
      return;
    }
    if (_selectedAuthors.isEmpty) {
      _showMessage('Select at least one author.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final repository = context.read<TelegramImportRepository>();

    try {
      final authorIds = await _resolveAuthorIds();
      final updatedSession = await repository.saveCurrent(
        name: title,
        authorIds: authorIds,
        albumId: selectedAlbum!.id!,
        albumOrder: selectedAlbum.trackIds.length,
        additionalInfo: List<TextTrackInfo>.from(_additionalInfos),
      );

      await _loadAlbums();

      if (!mounted) {
        return;
      }

      setState(() {
        _session = updatedSession;
        _isSaving = false;
      });
      await _syncTrackStateWithSession(updatedSession);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
      });
      _showMessage(_errorMessageFrom(error));
    }
  }

  Future<void> _skipAndNext() async {
    setState(() {
      _isSkipping = true;
    });

    try {
      final updatedSession = await context
          .read<TelegramImportRepository>()
          .skipCurrent();
      if (!mounted) {
        return;
      }
      setState(() {
        _session = updatedSession;
        _isSkipping = false;
      });
      await _syncTrackStateWithSession(updatedSession);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSkipping = false;
      });
      _showMessage(_errorMessageFrom(error));
    }
  }

  Future<void> _cancelSession() async {
    final repository = context.read<TelegramImportRepository>();
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cancel Telegram import session?'),
          content: const Text(
            'This will stop the current Telegram import session and clear its temporary files on the backend.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Cancel session'),
            ),
          ],
        );
      },
    );

    if (shouldCancel != true) {
      return;
    }

    setState(() {
      _isCancelling = true;
    });

    try {
      await repository.cancelCurrentSession();
      if (!mounted) {
        return;
      }
      setState(() {
        _session = null;
        _currentAudioBytes = null;
        _audioErrorMessage = null;
        _loadedTrackMessageId = null;
        _isCancelling = false;
      });
      _titleController.clear();
      _additionalInfos.clear();
      _selectedAuthors.clear();
      _showMessage('Telegram import session cancelled.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isCancelling = false;
      });
      _showMessage(_errorMessageFrom(error));
    }
  }

  Future<void> _clearCompletedSession() async {
    await _cancelSession();
  }

  Future<void> _downloadSkippedReport() async {
    setState(() {
      _isDownloadingReport = true;
    });

    try {
      final file = await context
          .read<TelegramImportRepository>()
          .downloadSkippedReport();
      saveBytesAsFile(
        bytes: file.bytes,
        fileName: file.fileName,
        contentType: file.contentType,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _isDownloadingReport = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isDownloadingReport = false;
      });
      _showMessage(_errorMessageFrom(error));
    }
  }

  void _downloadCurrentAudio() {
    final currentTrack = _session?.currentTrack;
    final bytes = _currentAudioBytes;
    if (currentTrack == null || bytes == null) {
      return;
    }

    saveBytesAsFile(
      bytes: bytes,
      fileName: currentTrack.fileName,
      contentType: currentTrack.mimeType,
    );
  }

  Future<List<int>> _resolveAuthorIds() async {
    final storage = context.read<TracksStorage>();
    final resolvedAuthorIds = <int>[];
    final createdAuthors = <Author>[];

    for (final author in _selectedAuthors) {
      final existingId = author.id;
      if (existingId != null) {
        resolvedAuthorIds.add(existingId);
        continue;
      }

      final createdAuthor = await storage.createAuthor(author);
      resolvedAuthorIds.add(createdAuthor.id!);
      createdAuthors.add(createdAuthor);
    }

    if (createdAuthors.isNotEmpty && mounted) {
      setState(() {
        final authorIdsByName = {
          for (final author in _availableAuthors)
            author.currentName.toLowerCase(): author,
          for (final author in createdAuthors)
            author.currentName.toLowerCase(): author,
        };
        _availableAuthors = authorIdsByName.values.toList()
          ..sort(
            (left, right) => left.currentName.toLowerCase().compareTo(
              right.currentName.toLowerCase(),
            ),
          );
        for (var i = 0; i < _selectedAuthors.length; i++) {
          final replacement = createdAuthors.where(
            (author) =>
                author.currentName.toLowerCase() ==
                _selectedAuthors[i].currentName.toLowerCase(),
          );
          if (replacement.isNotEmpty) {
            _selectedAuthors[i] = replacement.first;
          }
        }
      });
    }

    return resolvedAuthorIds;
  }

  void _removeAuthor(Author author) {
    setState(() {
      _selectedAuthors.remove(author);
    });
  }

  void _removeAdditionalInfo(int index) {
    setState(() {
      _additionalInfos.removeAt(index);
    });
  }

  void _addSelectedAuthor(Author author) {
    final exists = _selectedAuthors.any(
      (selected) =>
          selected.currentName.toLowerCase() ==
          author.currentName.toLowerCase(),
    );
    if (!exists) {
      _selectedAuthors.add(author);
    }
  }

  Author? _findAvailableAuthor(String authorName) {
    for (final author in _availableAuthors) {
      if (author.currentName.toLowerCase() == authorName.toLowerCase()) {
        return author;
      }
    }
    return null;
  }

  Album? get _selectedAlbum {
    for (final album in _availableAlbums) {
      if (album.id == _selectedAlbumId) {
        return album;
      }
    }
    return null;
  }

  String _normalizeChannelUsername(String value) {
    final trimmed = value.trim();
    if (trimmed.startsWith('@')) {
      return trimmed.substring(1);
    }
    return trimmed;
  }

  String _errorMessageFrom(Object error) {
    if (error is HttpAppError) {
      return error.message;
    }
    return error.toString();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _TelegramInfoBanner extends StatelessWidget {
  const _TelegramInfoBanner({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

class _SelectionSummaryCard extends StatelessWidget {
  const _SelectionSummaryCard({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}

class _AuthorPickerField extends StatelessWidget {
  const _AuthorPickerField({
    required this.authors,
    required this.isLoading,
    required this.onTap,
    required this.onRemove,
  });

  final List<Author> authors;
  final bool isLoading;
  final VoidCallback? onTap;
  final ValueChanged<Author>? onRemove;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Authors',
          border: OutlineInputBorder(),
          suffixIcon: Icon(Icons.arrow_drop_down),
        ),
        child: isLoading
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Text('Loading authors...'),
              )
            : authors.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Text('Select authors'),
              )
            : Wrap(
                spacing: 8,
                runSpacing: 8,
                children: authors
                    .map(
                      (author) => InputChip(
                        label: Text(author.currentName),
                        onDeleted: onRemove == null
                            ? null
                            : () => onRemove!(author),
                      ),
                    )
                    .toList(),
              ),
      ),
    );
  }
}

class _AuthorPickerDialog extends StatefulWidget {
  const _AuthorPickerDialog({
    required this.availableAuthors,
    required this.initiallySelectedAuthors,
  });

  final List<Author> availableAuthors;
  final List<Author> initiallySelectedAuthors;

  @override
  State<_AuthorPickerDialog> createState() => _AuthorPickerDialogState();
}

class _AuthorPickerDialogState extends State<_AuthorPickerDialog> {
  late final Map<String, Author> _selectedAuthorsByKey = {
    for (final author in widget.availableAuthors)
      if (widget.initiallySelectedAuthors.any(
        (selected) =>
            selected.currentName.toLowerCase() ==
            author.currentName.toLowerCase(),
      ))
        author.currentName.toLowerCase(): author,
    for (final author in widget.initiallySelectedAuthors)
      if (!widget.availableAuthors.any(
        (availableAuthor) =>
            availableAuthor.currentName.toLowerCase() ==
            author.currentName.toLowerCase(),
      ))
        author.currentName.toLowerCase(): author,
  };
  final _customAuthorController = TextEditingController();

  @override
  void dispose() {
    _customAuthorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select authors'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_customSelectedAuthors.isNotEmpty) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Selected custom authors',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _customSelectedAuthors
                        .map(
                          (author) => InputChip(
                            label: Text(author.currentName),
                            onDeleted: () {
                              setState(() {
                                _selectedAuthorsByKey.remove(
                                  author.currentName.toLowerCase(),
                                );
                              });
                            },
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (widget.availableAuthors.isEmpty)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('No authors in database yet.'),
                )
              else
                ...widget.availableAuthors.map(
                  (author) => CheckboxListTile(
                    value: _selectedAuthorsByKey.containsKey(
                      author.currentName.toLowerCase(),
                    ),
                    contentPadding: EdgeInsets.zero,
                    title: Text(author.currentName),
                    onChanged: (value) {
                      setState(() {
                        final key = author.currentName.toLowerCase();
                        if (value == true) {
                          _selectedAuthorsByKey[key] = author;
                        } else {
                          _selectedAuthorsByKey.remove(key);
                        }
                      });
                    },
                  ),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _customAuthorController,
                decoration: const InputDecoration(
                  labelText: 'Add custom author',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _addCustomAuthor(),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _addCustomAuthor,
                  icon: const Icon(Icons.add),
                  label: const Text('Add custom author'),
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
            final authors = _selectedAuthorsByKey.values.toList();

            authors.sort(
              (left, right) => left.currentName.toLowerCase().compareTo(
                right.currentName.toLowerCase(),
              ),
            );
            Navigator.of(context).pop(authors);
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }

  void _addCustomAuthor() {
    final authorName = _customAuthorController.text.trim();
    if (authorName.isEmpty) {
      return;
    }
    setState(() {
      _selectedAuthorsByKey[authorName.toLowerCase()] = Author(
        currentName: authorName,
      );
    });
    _customAuthorController.clear();
  }

  List<Author> get _customSelectedAuthors {
    return _selectedAuthorsByKey.values
        .where(
          (selectedAuthor) => !widget.availableAuthors.any(
            (availableAuthor) =>
                availableAuthor.currentName.toLowerCase() ==
                selectedAuthor.currentName.toLowerCase(),
          ),
        )
        .toList()
      ..sort(
        (left, right) => left.currentName.toLowerCase().compareTo(
          right.currentName.toLowerCase(),
        ),
      );
  }
}

class _AdditionalInfoCard extends StatelessWidget {
  const _AdditionalInfoCard({required this.info, required this.onDelete});

  final TextTrackInfo info;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        title: Text(info.title.isEmpty ? 'Untitled info' : info.title),
        subtitle: info.text.isEmpty ? null : Text(info.text),
        trailing: IconButton(
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Remove',
        ),
      ),
    );
  }
}
