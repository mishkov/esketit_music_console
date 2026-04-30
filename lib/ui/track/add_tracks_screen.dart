import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:cross_file/cross_file.dart';
import 'package:esketit_music_console/domain/album.dart';
import 'package:esketit_music_console/domain/author.dart';
import 'package:esketit_music_console/domain/track.dart';
import 'package:esketit_music_console/esketit_rest_api/youtube/youtube_import_models.dart';
import 'package:esketit_music_console/domain/track_info/external_link_track_info.dart';
import 'package:esketit_music_console/domain/track_info/track_info.dart';
import 'package:esketit_music_console/domain/track_metadata_validation.dart';
import 'package:esketit_music_console/domain/track_source_metadata.dart';
import 'package:esketit_music_console/errors/http_app_error.dart';
import 'package:esketit_music_console/esketit_rest_api/telegram/telegram_import_models.dart';
import 'package:esketit_music_console/ui/album/edit_album_screen.dart';
import 'package:esketit_music_console/ui/album/album_picker.dart';
import 'package:esketit_music_console/ui/album/albums_support.dart';
import 'package:esketit_music_console/ui/track/track_metadata_editor.dart';
import 'package:esketit_music_console/unassigned_layer/cross_file.dart';
import 'package:esketit_music_console/unassigned_layer/browser_file_download.dart';
import 'package:esketit_music_console/unassigned_layer/mp3_metadata.dart';
import 'package:esketit_music_console/use_case/auth/bloc/auth_bloc.dart';
import 'package:esketit_music_console/use_case/telegram/telegram_import_repository.dart';
import 'package:esketit_music_console/use_case/track/storage/tracks_storage.dart';
import 'package:esketit_music_console/use_case/track/tracks_list/bloc/track_list_bloc.dart';
import 'package:esketit_music_console/use_case/youtube/youtube_import_repository.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AddTracksScreen extends StatefulWidget {
  const AddTracksScreen({super.key});

  @override
  State<AddTracksScreen> createState() => _AddTracksScreenState();
}

class _AddTracksScreenState extends State<AddTracksScreen> {
  @override
  Widget build(BuildContext context) {
    final isAdmin =
        context.select((AuthBloc bloc) => bloc.state.session?.user.isAdmin) ??
        false;
    final tabs = [
      const Tab(text: 'Upload single file'),
      const Tab(text: 'Import from ZIP'),
      const Tab(text: 'Import from Telegram'),
      if (isAdmin) const Tab(text: 'Import from YouTube'),
    ];
    final views = [
      const _UploadSingleFileTab(),
      const _ZipImportTab(),
      const _TelegramImportTab(),
      if (isAdmin) const _YouTubeImportTab(),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Add Tracks'),
          bottom: TabBar(isScrollable: true, tabs: tabs),
        ),
        body: TabBarView(children: views),
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
  final List<TrackInfo> _additionalInfos = [];
  final List<TrackSourceMetadata> _sourceMetadata = [];
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
                AlbumPickerField(
                  albums: _availableAlbums,
                  selectedAlbum: _selectedAlbum,
                  isLoading: _isLoadingAlbums,
                  enabled: !_isSaving,
                  onSelected: (album) {
                    setState(() {
                      _selectedAlbumId = album.id;
                    });
                  },
                  onCreateNew: _openCreateAlbumScreen,
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
                TrackMetadataEditor(
                  additionalInfo: _additionalInfos,
                  sourceMetadata: _sourceMetadata,
                  enabled: !_isSaving,
                  onAdditionalInfoChanged: (items) {
                    setState(() {
                      _additionalInfos
                        ..clear()
                        ..addAll(items);
                    });
                  },
                  onSourceMetadataChanged: (items) {
                    setState(() {
                      _sourceMetadata
                        ..clear()
                        ..addAll(items);
                    });
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
      final albums = await loadAllAlbums(context.read<TracksStorage>());
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

  Future<void> _openCreateAlbumScreen({
    String? initialTitle,
    DateTime? initialReleaseDate,
  }) async {
    final savedAlbum = await Navigator.of(context).push<Album>(
      MaterialPageRoute(
        builder: (_) => EditAlbumScreen(
          initialTitle: initialTitle,
          initialReleaseDate: initialReleaseDate,
        ),
      ),
    );

    if (savedAlbum?.id == null || !mounted) {
      return;
    }

    await _loadAlbums();
    if (!mounted) {
      return;
    }

    setState(() {
      _selectedAlbumId = savedAlbum!.id;
    });
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

    await _applyMetadataAlbum(
      metadata.album,
      metadataReleaseDate: metadata.releaseDate,
    );
    await _applyMetadataAuthors(metadata.authors);
  }

  Future<void> _applyMetadataAlbum(
    String? metadataAlbum, {
    DateTime? metadataReleaseDate,
  }) async {
    final albumTitle = metadataAlbum?.trim();
    if (albumTitle == null || albumTitle.isEmpty) {
      return;
    }

    final matchingAlbum = findBestMatchingAlbum(_availableAlbums, albumTitle);
    if (matchingAlbum?.id != null) {
      setState(() {
        _selectedAlbumId = matchingAlbum!.id;
      });
      return;
    }

    final result = await showAlbumPickerDialog(
      context,
      availableAlbums: _availableAlbums,
      selectedAlbumId: _selectedAlbumId,
      metadataAlbumTitle: albumTitle,
      onCreateNew: () => _openCreateAlbumScreen(
        initialTitle: albumTitle,
        initialReleaseDate: metadataReleaseDate,
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    if (result case AlbumPickerDialogSelection(album: final album)) {
      setState(() {
        _selectedAlbumId = album.id;
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
    final additionalInfoErrors = validateTrackAdditionalInfo(_additionalInfos);
    if (additionalInfoErrors.isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(additionalInfoErrors.first)));
      return;
    }
    final sourceMetadataErrors = validateTrackSourceMetadata(_sourceMetadata);
    if (sourceMetadataErrors.isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(sourceMetadataErrors.first)));
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
          additionalInfo: List<TrackInfo>.from(_additionalInfos),
          sourceMetadata: List<TrackSourceMetadata>.from(_sourceMetadata),
          file: _pickedFile!,
        ),
      );
      if (!mounted) {
        return;
      }
      context.read<TrackListBloc>().add(const LoadTracks());
      await _loadAlbums();
      if (!mounted) {
        return;
      }
      _resetForm();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Track successfully added.')),
      );
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

  void _resetForm() {
    setState(() {
      _isSaving = false;
      _pickedFile = null;
      _titleController.clear();
      _additionalInfos.clear();
      _sourceMetadata.clear();
      _selectedAuthors.clear();
      _selectedAlbumId = _availableAlbums.isEmpty
          ? null
          : _availableAlbums.first.id;
    });
  }
}

class _ZipImportEntry {
  const _ZipImportEntry({
    required this.fileName,
    required this.bytes,
    required this.metadata,
  });

  final String fileName;
  final Uint8List bytes;
  final Mp3Metadata metadata;

  String get mimeType => 'audio/mpeg';
}

class _ZipImportSession {
  const _ZipImportSession({
    required this.zipFileName,
    required this.entries,
    this.currentIndex = 0,
    this.savedCount = 0,
    this.skippedCount = 0,
  });

  final String zipFileName;
  final List<_ZipImportEntry> entries;
  final int currentIndex;
  final int savedCount;
  final int skippedCount;

  _ZipImportEntry? get currentEntry =>
      currentIndex >= 0 && currentIndex < entries.length
      ? entries[currentIndex]
      : null;

  bool get isCompleted => currentIndex >= entries.length;

  int get processedCount => savedCount + skippedCount;

  int get totalCount => entries.length;

  int get remainingCount => totalCount - processedCount;

  _ZipImportSession nextAfterSave() {
    return _ZipImportSession(
      zipFileName: zipFileName,
      entries: entries,
      currentIndex: currentIndex + 1,
      savedCount: savedCount + 1,
      skippedCount: skippedCount,
    );
  }

  _ZipImportSession nextAfterSkip() {
    return _ZipImportSession(
      zipFileName: zipFileName,
      entries: entries,
      currentIndex: currentIndex + 1,
      savedCount: savedCount,
      skippedCount: skippedCount + 1,
    );
  }
}

class _ZipImportTab extends StatefulWidget {
  const _ZipImportTab();

  @override
  State<_ZipImportTab> createState() => _ZipImportTabState();
}

class _ZipImportTabState extends State<_ZipImportTab> {
  final _titleController = TextEditingController();
  final List<TrackInfo> _additionalInfos = [];
  final List<TrackSourceMetadata> _sourceMetadata = [];
  final List<Author> _selectedAuthors = [];
  List<Author> _availableAuthors = const [];
  List<Album> _availableAlbums = const [];

  _ZipImportSession? _session;
  int? _selectedAlbumId;
  bool _isLoadingAuthors = true;
  bool _isLoadingAlbums = true;
  bool _isStartingImport = false;
  bool _isSaving = false;
  bool _isSkipping = false;
  bool _isCancelling = false;

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
    final session = _session;
    final currentEntry = session?.currentEntry;
    final selectedAlbum = _selectedAlbum;

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
                if (session == null)
                  _buildSessionStarter(context)
                else if (session.isCompleted)
                  _buildCompletedState(context, session)
                else if (currentEntry != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Current ZIP track',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  _SelectionSummaryCard(
                                    title: 'ZIP file',
                                    value: session.zipFileName,
                                  ),
                                  _SelectionSummaryCard(
                                    title: 'Progress',
                                    value:
                                        '${session.processedCount}/${session.totalCount}',
                                  ),
                                  _SelectionSummaryCard(
                                    title: 'Remaining',
                                    value: '${session.remainingCount}',
                                  ),
                                  _SelectionSummaryCard(
                                    title: 'Skipped',
                                    value: '${session.skippedCount}',
                                  ),
                                  _SelectionSummaryCard(
                                    title: 'Saved',
                                    value: '${session.savedCount}',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _SelectionSummaryCard(
                                title: 'Audio file',
                                value:
                                    '${currentEntry.fileName}\n${currentEntry.mimeType} • ${_formatBytes(currentEntry.bytes.length)}',
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
                      AlbumPickerField(
                        albums: _availableAlbums,
                        selectedAlbum: _selectedAlbum,
                        isLoading: _isLoadingAlbums,
                        enabled: !_isSaving && !_isSkipping && !_isCancelling,
                        onSelected: (album) {
                          setState(() {
                            _selectedAlbumId = album.id;
                          });
                        },
                        onCreateNew: _openCreateAlbumScreen,
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
                      TrackMetadataEditor(
                        additionalInfo: _additionalInfos,
                        sourceMetadata: _sourceMetadata,
                        enabled: !_isSaving && !_isSkipping && !_isCancelling,
                        onAdditionalInfoChanged: (items) {
                          setState(() {
                            _additionalInfos
                              ..clear()
                              ..addAll(items);
                          });
                        },
                        onSourceMetadataChanged: (items) {
                          setState(() {
                            _sourceMetadata
                              ..clear()
                              ..addAll(items);
                          });
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
                  )
                else
                  _TelegramInfoBanner(
                    message:
                        'ZIP import session is active but no current track is available.',
                    actionLabel: 'Cancel session',
                    onAction: _cancelSession,
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
              'Start ZIP import',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            const Text(
              'Pick a ZIP archive that contains MP3 files. The browser will unpack it locally and open tracks one by one for review.',
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _isStartingImport ? null : _startSession,
              icon: const Icon(Icons.folder_zip_outlined),
              label: Text(
                _isStartingImport ? 'Opening ZIP...' : 'Pick ZIP file',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedState(BuildContext context, _ZipImportSession session) {
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
            Text('ZIP file: ${session.zipFileName}'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _SelectionSummaryCard(
                  title: 'Saved',
                  value: '${session.savedCount}',
                ),
                _SelectionSummaryCard(
                  title: 'Skipped',
                  value: '${session.skippedCount}',
                ),
                _SelectionSummaryCard(
                  title: 'Processed',
                  value: '${session.processedCount}/${session.totalCount}',
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: _isCancelling ? null : _clearCompletedSession,
              child: Text(_isCancelling ? 'Clearing...' : 'Clear session'),
            ),
          ],
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
      _showMessage('Failed to load authors: $error');
    }
  }

  Future<void> _loadAlbums() async {
    try {
      final albums = await loadAllAlbums(context.read<TracksStorage>());
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

  Future<void> _startSession() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['zip'],
    );
    final file = result?.files.single;
    if (file == null || file.bytes == null) {
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _isStartingImport = true;
    });

    try {
      final archive = ZipDecoder().decodeBytes(file.bytes!);
      final mp3Entries = archive.files
          .where((entry) => entry.isFile)
          .where((entry) => entry.name.toLowerCase().endsWith('.mp3'))
          .map((entry) {
            final bytes = _archiveEntryBytes(entry);
            return _ZipImportEntry(
              fileName: entry.name.split('/').last,
              bytes: bytes,
              metadata: parseMp3Metadata(bytes),
            );
          })
          .toList();

      if (mp3Entries.isEmpty) {
        throw const FormatException(
          'The selected ZIP does not contain MP3 files.',
        );
      }

      final session = _ZipImportSession(
        zipFileName: file.name,
        entries: mp3Entries,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _session = session;
        _isStartingImport = false;
      });
      await _syncTrackStateWithSession(session);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isStartingImport = false;
      });
      _showMessage(_errorMessageFrom(error));
    }
  }

  Future<void> _syncTrackStateWithSession(_ZipImportSession? session) async {
    if (!mounted) {
      return;
    }

    final entry = session?.currentEntry;
    if (entry == null) {
      setState(() {
        _titleController.clear();
        _additionalInfos.clear();
        _sourceMetadata.clear();
        _selectedAuthors.clear();
      });
      return;
    }

    setState(() {
      _titleController.text = (entry.metadata.title?.trim().isNotEmpty ?? false)
          ? entry.metadata.title!
          : _titleFromFileName(entry.fileName);
      _additionalInfos.clear();
      _sourceMetadata.clear();
      _selectedAuthors.clear();
      if (!_availableAlbums.any((album) => album.id == _selectedAlbumId)) {
        _selectedAlbumId = _availableAlbums.isEmpty
            ? null
            : _availableAlbums.first.id;
      }
    });

    await _applyMetadataAlbum(
      entry.metadata.album,
      metadataReleaseDate: entry.metadata.releaseDate,
    );
    await _applyMetadataAuthors(entry.metadata.authors);
  }

  Future<void> _openCreateAlbumScreen({
    String? initialTitle,
    DateTime? initialReleaseDate,
  }) async {
    final savedAlbum = await Navigator.of(context).push<Album>(
      MaterialPageRoute(
        builder: (_) => EditAlbumScreen(
          initialTitle: initialTitle,
          initialReleaseDate: initialReleaseDate,
        ),
      ),
    );

    if (savedAlbum?.id == null || !mounted) {
      return;
    }

    await _loadAlbums();
    if (!mounted) {
      return;
    }

    setState(() {
      _selectedAlbumId = savedAlbum!.id;
    });
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

  Future<void> _applyMetadataAlbum(
    String? metadataAlbum, {
    DateTime? metadataReleaseDate,
  }) async {
    if (!mounted) {
      return;
    }
    final albumTitle = metadataAlbum?.trim();
    if (albumTitle == null || albumTitle.isEmpty) {
      return;
    }

    final matchingAlbum = findBestMatchingAlbum(_availableAlbums, albumTitle);
    if (matchingAlbum?.id != null) {
      setState(() {
        _selectedAlbumId = matchingAlbum!.id;
      });
      return;
    }

    final result = await showAlbumPickerDialog(
      context,
      availableAlbums: _availableAlbums,
      selectedAlbumId: _selectedAlbumId,
      metadataAlbumTitle: albumTitle,
      onCreateNew: () => _openCreateAlbumScreen(
        initialTitle: albumTitle,
        initialReleaseDate: metadataReleaseDate,
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    if (result case AlbumPickerDialogSelection(album: final album)) {
      setState(() {
        _selectedAlbumId = album.id;
      });
    }
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

  Future<void> _saveAndNext() async {
    final session = _session;
    final entry = session?.currentEntry;
    final title = _titleController.text.trim();
    final selectedAlbum = _selectedAlbum;

    if (entry == null) {
      _showMessage('No ZIP track is loaded.');
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
    final additionalInfoErrors = validateTrackAdditionalInfo(_additionalInfos);
    if (additionalInfoErrors.isNotEmpty) {
      _showMessage(additionalInfoErrors.first);
      return;
    }
    final sourceMetadataErrors = validateTrackSourceMetadata(_sourceMetadata);
    if (sourceMetadataErrors.isNotEmpty) {
      _showMessage(sourceMetadataErrors.first);
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _isSaving = true;
    });

    try {
      final xFile = XFile.fromData(
        entry.bytes,
        name: entry.fileName,
        mimeType: entry.mimeType,
      );
      await context.read<TracksStorage>().putTrack(
        Track(
          name: title,
          authors: List<Author>.from(_selectedAuthors),
          albumId: selectedAlbum!.id!,
          albumOrder: selectedAlbum.trackIds.length,
          additionalInfo: List<TrackInfo>.from(_additionalInfos),
          sourceMetadata: List<TrackSourceMetadata>.from(_sourceMetadata),
          file: CrossFile(file: xFile),
        ),
      );
      await _loadAlbums();
      if (!mounted) {
        return;
      }

      final updatedSession = session!.nextAfterSave();
      setState(() {
        _session = updatedSession;
        _isSaving = false;
      });
      context.read<TrackListBloc>().add(const LoadTracks());
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
    final session = _session;
    if (session == null) {
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _isSkipping = true;
    });

    final updatedSession = session.nextAfterSkip();
    setState(() {
      _session = updatedSession;
      _isSkipping = false;
    });
    await _syncTrackStateWithSession(updatedSession);
  }

  Future<void> _cancelSession() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _isCancelling = true;
    });

    setState(() {
      _session = null;
      _titleController.clear();
      _additionalInfos.clear();
      _sourceMetadata.clear();
      _selectedAuthors.clear();
      _isCancelling = false;
    });
  }

  Future<void> _clearCompletedSession() async {
    await _cancelSession();
  }

  void _removeAuthor(Author author) {
    setState(() {
      _selectedAuthors.remove(author);
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

  String _titleFromFileName(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    final nameWithoutExtension = dotIndex > 0
        ? fileName.substring(0, dotIndex)
        : fileName;
    return nameWithoutExtension.replaceAll('_', ' ').trim();
  }

  Uint8List _archiveEntryBytes(ArchiveFile entry) {
    return Uint8List.fromList(entry.content as List<int>);
  }

  String _errorMessageFrom(Object error) {
    if (error is HttpAppError) {
      return error.message;
    }
    if (error is FormatException) {
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

class _TelegramImportTab extends StatefulWidget {
  const _TelegramImportTab();

  @override
  State<_TelegramImportTab> createState() => _TelegramImportTabState();
}

class _TelegramImportTabState extends State<_TelegramImportTab> {
  final _channelUsernameController = TextEditingController();
  final _startMessageIdController = TextEditingController();
  final _titleController = TextEditingController();
  final List<TrackInfo> _additionalInfos = [];
  final List<TrackSourceMetadata> _sourceMetadata = [];
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
    _startMessageIdController.dispose();
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
                    actionLabel: _isCancelling
                        ? 'Stopping...'
                        : 'Stop current import session',
                    onAction: _isCancelling ? null : _cancelSession,
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
            TextField(
              controller: _startMessageIdController,
              enabled: !_isStartingSession,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Start from message ID',
                helperText:
                    'Optional. Inclusive: the import starts from this Telegram message ID.',
                hintText: '12345',
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
        AlbumPickerField(
          albums: _availableAlbums,
          selectedAlbum: _selectedAlbum,
          isLoading: _isLoadingAlbums,
          enabled: !_isSaving && !_isSkipping && !_isCancelling,
          onSelected: (album) {
            setState(() {
              _selectedAlbumId = album.id;
            });
          },
          onCreateNew: _openCreateAlbumScreen,
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
        TrackMetadataEditor(
          additionalInfo: _additionalInfos,
          sourceMetadata: _sourceMetadata,
          enabled: !_isSaving && !_isSkipping && !_isCancelling,
          onAdditionalInfoChanged: (items) {
            setState(() {
              _additionalInfos
                ..clear()
                ..addAll(items);
            });
          },
          onSourceMetadataChanged: (items) {
            setState(() {
              _sourceMetadata
                ..clear()
                ..addAll(items);
            });
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
    if (!mounted) {
      return;
    }
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
      final albums = await loadAllAlbums(context.read<TracksStorage>());
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

  Future<void> _openCreateAlbumScreen({
    String? initialTitle,
    DateTime? initialReleaseDate,
  }) async {
    final savedAlbum = await Navigator.of(context).push<Album>(
      MaterialPageRoute(
        builder: (_) => EditAlbumScreen(
          initialTitle: initialTitle,
          initialReleaseDate: initialReleaseDate,
        ),
      ),
    );

    if (savedAlbum?.id == null || !mounted) {
      return;
    }

    await _loadAlbums();
    if (!mounted) {
      return;
    }

    setState(() {
      _selectedAlbumId = savedAlbum!.id;
    });
  }

  Future<void> _startSession() async {
    final channelUsername = _normalizeChannelUsername(
      _channelUsernameController.text,
    );
    final startMessageIdResult = _parseStartMessageId(
      _startMessageIdController.text,
    );
    if (channelUsername.isEmpty) {
      _showMessage('Channel username is required.');
      return;
    }
    if (startMessageIdResult.errorMessage != null) {
      _showMessage(startMessageIdResult.errorMessage!);
      return;
    }
    final startMessageId = startMessageIdResult.value;

    if (!mounted) {
      return;
    }
    setState(() {
      _isStartingSession = true;
    });

    final repository = context.read<TelegramImportRepository>();

    try {
      final session = await repository.startSession(
        channelUsername: channelUsername,
        startMessageId: startMessageId,
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
              startMessageId: startMessageId,
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
    if (!mounted) {
      return;
    }
    final track = session?.currentTrack;
    if (track == null) {
      setState(() {
        _currentAudioBytes = null;
        _audioErrorMessage = null;
        _loadedTrackMessageId = null;
        _titleController.clear();
        _additionalInfos.clear();
        _sourceMetadata.clear();
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
      _additionalInfos
        ..clear()
        ..addAll(_defaultTelegramAdditionalInfo(track));
      _sourceMetadata
        ..clear()
        ..addAll(_defaultTelegramSourceMetadata(session, track));
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
      await _applyMetadataAlbum(
        metadata.album,
        metadataReleaseDate: metadata.releaseDate,
      );
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

  Future<void> _applyMetadataAlbum(
    String? metadataAlbum, {
    DateTime? metadataReleaseDate,
  }) async {
    if (!mounted) {
      return;
    }
    final albumTitle = metadataAlbum?.trim();
    if (albumTitle == null || albumTitle.isEmpty) {
      return;
    }

    final matchingAlbum = findBestMatchingAlbum(_availableAlbums, albumTitle);
    if (matchingAlbum?.id != null) {
      setState(() {
        _selectedAlbumId = matchingAlbum!.id;
      });
      return;
    }

    final result = await showAlbumPickerDialog(
      context,
      availableAlbums: _availableAlbums,
      selectedAlbumId: _selectedAlbumId,
      metadataAlbumTitle: albumTitle,
      onCreateNew: () => _openCreateAlbumScreen(
        initialTitle: albumTitle,
        initialReleaseDate: metadataReleaseDate,
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    if (result case AlbumPickerDialogSelection(album: final album)) {
      setState(() {
        _selectedAlbumId = album.id;
      });
    }
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
    final additionalInfoErrors = validateTrackAdditionalInfo(_additionalInfos);
    if (additionalInfoErrors.isNotEmpty) {
      _showMessage(additionalInfoErrors.first);
      return;
    }
    final sourceMetadataErrors = validateTrackSourceMetadata(_sourceMetadata);
    if (sourceMetadataErrors.isNotEmpty) {
      _showMessage(sourceMetadataErrors.first);
      return;
    }

    if (!mounted) {
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
        additionalInfo: List<TrackInfo>.from(_additionalInfos),
        sourceMetadata: List<TrackSourceMetadata>.from(_sourceMetadata),
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
    if (!mounted) {
      return;
    }
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

    if (!mounted) {
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
      _sourceMetadata.clear();
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
    if (!mounted) {
      return;
    }
    setState(() {
      _isDownloadingReport = true;
    });

    try {
      final file = await context
          .read<TelegramImportRepository>()
          .downloadSkippedReport();
      await saveBytesAsFile(
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

  Future<void> _downloadCurrentAudio() async {
    final currentTrack = _session?.currentTrack;
    final bytes = _currentAudioBytes;
    if (currentTrack == null || bytes == null) {
      return;
    }

    try {
      await saveBytesAsFile(
        bytes: bytes,
        fileName: currentTrack.fileName,
        contentType: currentTrack.mimeType,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(_errorMessageFrom(error));
    }
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

  _StartMessageIdParseResult _parseStartMessageId(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return const _StartMessageIdParseResult();
    }

    final parsed = int.tryParse(trimmed);
    if (parsed == null || parsed < 0) {
      return const _StartMessageIdParseResult(
        errorMessage:
            'Start message ID must be an integer greater than or equal to 0.',
      );
    }

    return _StartMessageIdParseResult(value: parsed);
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

  List<TrackInfo> _defaultTelegramAdditionalInfo(TelegramImportTrack track) {
    final link = track.telegramMessageLink.trim();
    if (link.isEmpty) {
      return const [];
    }
    return [
      ExternalLinkTrackInfo(
        provider: 'telegram',
        title: 'Telegram message',
        url: link,
      ),
    ];
  }

  List<TrackSourceMetadata> _defaultTelegramSourceMetadata(
    TelegramImportSession? session,
    TelegramImportTrack track,
  ) {
    if (track.messageId <= 0) {
      return const [];
    }
    return [
      TrackSourceMetadata(
        provider: 'telegram',
        kind: 'message',
        identity: {
          if (session?.channelUsername.trim().isNotEmpty ?? false)
            'chatId': session!.channelUsername.trim(),
          'messageId': '${track.messageId}',
        },
        url: track.telegramMessageLink.trim().isEmpty
            ? null
            : track.telegramMessageLink.trim(),
      ),
    ];
  }
}

class _YouTubeImportTab extends StatefulWidget {
  const _YouTubeImportTab();

  @override
  State<_YouTubeImportTab> createState() => _YouTubeImportTabState();
}

class _YouTubeImportTabState extends State<_YouTubeImportTab> {
  final _urlController = TextEditingController();
  final _titleController = TextEditingController();
  final List<Author> _selectedAuthors = [];
  final Map<int, Track> _suggestedTracksById = {};
  List<Author> _availableAuthors = const [];
  List<Album> _availableAlbums = const [];

  YouTubeImportSession? _session;
  DateTime? _releaseDateCutoff;
  bool _replaceExisting = false;
  bool _isLoadingState = true;
  bool _isLoadingAuthors = true;
  bool _isLoadingAlbums = true;
  bool _isStartingSession = false;
  bool _isCreating = false;
  bool _isAttaching = false;
  bool _isSkipping = false;
  bool _isCancelling = false;
  int? _selectedAlbumId;
  int? _selectedTrackId;
  String? _loadedItemKey;

  @override
  void initState() {
    super.initState();
    _loadInitialState();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final currentItem = session?.currentItem;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isLoadingState || _isLoadingAuthors || _isLoadingAlbums)
                  const LinearProgressIndicator(),
                if (session == null)
                  _buildSessionStarter(context)
                else if (session.isCompleted)
                  _buildCompletedState(context, session)
                else if (currentItem != null)
                  _buildCurrentItemReview(context, session, currentItem)
                else
                  _TelegramInfoBanner(
                    message:
                        'YouTube import session is active but no current item is available.',
                    actionLabel: 'Reload session',
                    onAction: _refreshSession,
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
              'Start YouTube import',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            const Text(
              'Paste a YouTube or YouTube Music URL. The backend will resolve it into a one-by-one review session.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _urlController,
              enabled: !_isStartingSession,
              decoration: const InputDecoration(
                labelText: 'YouTube URL',
                hintText: 'https://music.youtube.com/...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            _SelectionSummaryCard(
              title: 'Release date cutoff',
              value: _releaseDateCutoff == null
                  ? 'No cutoff'
                  : _formatDateOnly(_releaseDateCutoff!),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton.icon(
                  onPressed: _isStartingSession ? null : _pickReleaseDateCutoff,
                  icon: const Icon(Icons.event_outlined),
                  label: Text(
                    _releaseDateCutoff == null
                        ? 'Pick cutoff'
                        : 'Change cutoff',
                  ),
                ),
                if (_releaseDateCutoff != null)
                  TextButton(
                    onPressed: _isStartingSession
                        ? null
                        : () {
                            setState(() {
                              _releaseDateCutoff = null;
                            });
                          },
                    child: const Text('Clear cutoff'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _replaceExisting,
              onChanged: _isStartingSession
                  ? null
                  : (value) {
                      setState(() {
                        _replaceExisting = value;
                      });
                    },
              title: const Text('Replace active session'),
              subtitle: const Text(
                'If a YouTube import session is already active, replace it immediately.',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: _isStartingSession ? null : _startSession,
                  icon: const Icon(Icons.ondemand_video),
                  label: Text(
                    _isStartingSession ? 'Starting...' : 'Start import',
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: _isLoadingState ? null : _refreshSession,
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
    YouTubeImportSession session,
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
            _SelectionSummaryCard(
              title: 'Source',
              value:
                  '${_humanizeSourceType(session.sourceType)}\n${session.sourceUrl}',
            ),
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
            TextButton(
              onPressed: _isCancelling ? null : _clearCompletedSession,
              child: Text(_isCancelling ? 'Clearing...' : 'Clear session'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentItemReview(
    BuildContext context,
    YouTubeImportSession session,
    YouTubeCurrentImportItem item,
  ) {
    final selectedAlbum = _selectedAlbum;
    final exactSuggestion = _findExactSuggestion(item);
    final selectedTrack = _selectedTrack;

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
                  'Current YouTube item',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _SelectionSummaryCard(
                      title: 'Source type',
                      value: _humanizeSourceType(item.sourceType),
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
                      title: 'Saved',
                      value: '${session.progress.saved}',
                    ),
                    _SelectionSummaryCard(
                      title: 'Skipped',
                      value: '${session.progress.skipped}',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (exactSuggestion != null) ...[
                  _buildExactMatchBanner(context, exactSuggestion),
                  const SizedBox(height: 16),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SelectionSummaryCard(
                            title: 'Source URL',
                            value: item.sourceUrl,
                          ),
                          const SizedBox(height: 12),
                          _SelectionSummaryCard(
                            title: 'Original URL',
                            value: item.originalSourceUrl,
                          ),
                          const SizedBox(height: 12),
                          _SelectionSummaryCard(
                            title: 'Parsed title',
                            value: item.parsedTitle,
                          ),
                          const SizedBox(height: 12),
                          _SelectionSummaryCard(
                            title: 'Parsed authors',
                            value: item.parsedAuthorNames.isEmpty
                                ? 'No parsed authors'
                                : item.parsedAuthorNames.join(', '),
                          ),
                          const SizedBox(height: 12),
                          _SelectionSummaryCard(
                            title: 'Parsed album',
                            value: item.parsedAlbumTitle ?? 'No parsed album',
                          ),
                          const SizedBox(height: 12),
                          _SelectionSummaryCard(
                            title: 'Parsed release date',
                            value: item.parsedReleaseDate == null
                                ? 'No parsed release date'
                                : _formatDateTime(item.parsedReleaseDate!),
                          ),
                        ],
                      ),
                    ),
                    if (item.coverImageUrl != null) ...[
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 220,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cover image',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: Image.network(
                                  item.coverImageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.surfaceContainerHighest,
                                        alignment: Alignment.center,
                                        child: const Text(
                                          'Failed to load cover',
                                        ),
                                      ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                if (item.durationSeconds != null) ...[
                  const SizedBox(height: 12),
                  Text('Duration: ${_formatDuration(item.durationSeconds!)}'),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildSuggestionsSection(context, item),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add as new',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _titleController,
                  enabled: !_isBusy,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                AlbumPickerField(
                  albums: _availableAlbums,
                  selectedAlbum: selectedAlbum,
                  isLoading: _isLoadingAlbums,
                  enabled: !_isBusy,
                  onSelected: (album) {
                    setState(() {
                      _selectedAlbumId = album.id;
                    });
                  },
                  onCreateNew: () => _openCreateAlbumScreen(
                    initialTitle: item.parsedAlbumTitle,
                    initialReleaseDate: item.parsedReleaseDate,
                  ),
                ),
                if (item.parsedAlbumTitle != null &&
                    item.parsedAlbumTitle!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      Text(
                        'Parsed album: ${item.parsedAlbumTitle!}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      TextButton(
                        onPressed: _isBusy
                            ? null
                            : () => _searchParsedAlbum(item),
                        child: const Text('Search parsed album'),
                      ),
                    ],
                  ),
                ],
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
                  onTap: _isBusy ? null : _showAuthorPicker,
                  onRemove: _isBusy ? null : _removeAuthor,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _isBusy ? null : _addAsNew,
                  child: Text(_isCreating ? 'Adding...' : 'Add as new'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Attach to existing',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                _SelectionSummaryCard(
                  title: 'Selected local track',
                  value: selectedTrack == null
                      ? 'No track selected'
                      : _trackSummary(selectedTrack),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.tonal(
                      onPressed: _isBusy ? null : _selectExistingTrack,
                      child: const Text('Select existing track'),
                    ),
                    if (selectedTrack != null)
                      TextButton(
                        onPressed: _isBusy
                            ? null
                            : () {
                                setState(() {
                                  _selectedTrackId = null;
                                });
                              },
                        child: const Text('Clear selection'),
                      ),
                    FilledButton(
                      onPressed: _isBusy || selectedTrack == null
                          ? null
                          : _attachSelectedTrack,
                      child: Text(_isAttaching ? 'Attaching...' : 'Attach'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (_isBusy) const LinearProgressIndicator(),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: _isBusy ? null : _cancelSession,
              child: const Text('Cancel session'),
            ),
            const SizedBox(width: 12),
            FilledButton.tonal(
              onPressed: _isBusy ? null : _skipAndNext,
              child: const Text('Skip'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildExactMatchBanner(
    BuildContext context,
    YouTubeImportSuggestion suggestion,
  ) {
    final matchedTrack = _suggestedTracksById[suggestion.trackId];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Exact source match found',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            matchedTrack == null
                ? 'Track #${suggestion.trackId} already has this source.'
                : _trackSummary(matchedTrack),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _isBusy
                ? null
                : () => _attachToTrackId(suggestion.trackId),
            child: const Text('Attach exact source match'),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsSection(
    BuildContext context,
    YouTubeCurrentImportItem item,
  ) {
    final suggestions = [...item.suggestions]
      ..sort((left, right) {
        if (left.isExactSourceMatch == right.isExactSourceMatch) {
          return right.confidence.compareTo(left.confidence);
        }
        return left.isExactSourceMatch ? -1 : 1;
      });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Suggestions', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (suggestions.isEmpty)
              const Text('No suggestions for this item.')
            else
              Column(
                children: suggestions
                    .map(
                      (suggestion) => _buildSuggestionTile(context, suggestion),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionTile(
    BuildContext context,
    YouTubeImportSuggestion suggestion,
  ) {
    final track = _suggestedTracksById[suggestion.trackId];
    final confidencePercent = (suggestion.confidence * 100).toStringAsFixed(0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Chip(
                label: Text(
                  suggestion.isExactSourceMatch
                      ? 'Exact source match'
                      : 'Possible track match',
                ),
              ),
              Text('Track #${suggestion.trackId}'),
              Text('Confidence $confidencePercent%'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            track == null ? 'Loading track details...' : _trackSummary(track),
          ),
          if (suggestion.metadata.isNotEmpty) ...[
            const SizedBox(height: 8),
            SelectableText(formatJsonObject(suggestion.metadata)),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.tonal(
                onPressed: _isBusy
                    ? null
                    : () => _attachToTrackId(suggestion.trackId),
                child: const Text('Use suggestion'),
              ),
              TextButton(
                onPressed: _isBusy
                    ? null
                    : () {
                        setState(() {
                          _selectedTrackId = suggestion.trackId;
                        });
                      },
                child: const Text('Select for attach'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool get _isBusy =>
      _isStartingSession ||
      _isCreating ||
      _isAttaching ||
      _isSkipping ||
      _isCancelling;

  Future<void> _loadInitialState() async {
    await _loadAuthors();
    await _loadAlbums();
    await _refreshSession();
  }

  Future<void> _refreshSession() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _isLoadingState = true;
    });

    try {
      final session = await context
          .read<YouTubeImportRepository>()
          .getCurrentSession();
      if (!mounted) {
        return;
      }
      setState(() {
        _session = session;
        _isLoadingState = false;
      });
      await _syncStateWithSession(session);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
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
      final albums = await loadAllAlbums(context.read<TracksStorage>());
      if (!mounted) {
        return;
      }
      albums.sort(
        (left, right) =>
            left.title.toLowerCase().compareTo(right.title.toLowerCase()),
      );
      setState(() {
        _availableAlbums = albums;
        if (_selectedAlbumId != null &&
            !_availableAlbums.any((album) => album.id == _selectedAlbumId)) {
          _selectedAlbumId = null;
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

  Future<void> _pickReleaseDateCutoff() async {
    final now = DateTime.now();
    final initialDate = _releaseDateCutoff ?? now;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1970),
      lastDate: DateTime(now.year + 20),
    );
    if (pickedDate == null || !mounted) {
      return;
    }

    setState(() {
      _releaseDateCutoff = DateTime.utc(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        23,
        59,
        59,
        999,
      );
    });
  }

  Future<void> _openCreateAlbumScreen({
    String? initialTitle,
    DateTime? initialReleaseDate,
  }) async {
    final savedAlbum = await Navigator.of(context).push<Album>(
      MaterialPageRoute(
        builder: (_) => EditAlbumScreen(
          initialTitle: initialTitle,
          initialReleaseDate: initialReleaseDate,
        ),
      ),
    );

    if (savedAlbum?.id == null || !mounted) {
      return;
    }

    await _loadAlbums();
    if (!mounted) {
      return;
    }

    setState(() {
      _selectedAlbumId = savedAlbum!.id;
    });
  }

  Future<void> _startSession() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      _showMessage('YouTube URL is required.');
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _isStartingSession = true;
    });

    final repository = context.read<YouTubeImportRepository>();

    try {
      final session = await repository.startSession(
        url: url,
        releaseDateCutoff: _releaseDateCutoff,
        replaceExisting: _replaceExisting,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _session = session;
        _isStartingSession = false;
      });
      await _syncStateWithSession(session);
    } on HttpAppError catch (error) {
      if (error.statusCode == 409 && !_replaceExisting) {
        if (!mounted) {
          return;
        }
        final shouldReplace = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Replace active import session?'),
              content: Text(
                error.message.isEmpty
                    ? 'There is already an active YouTube import session. Start a new one and replace it?'
                    : error.message,
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
              url: url,
              releaseDateCutoff: _releaseDateCutoff,
              replaceExisting: true,
            );
            if (!mounted) {
              return;
            }
            setState(() {
              _replaceExisting = true;
              _session = session;
              _isStartingSession = false;
            });
            await _syncStateWithSession(session);
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

  Future<void> _syncStateWithSession(YouTubeImportSession? session) async {
    if (!mounted) {
      return;
    }

    final item = session?.currentItem;
    if (item == null) {
      setState(() {
        _loadedItemKey = null;
        _titleController.clear();
        _selectedTrackId = null;
        _selectedAlbumId = null;
        _selectedAuthors.clear();
        _suggestedTracksById.clear();
      });
      return;
    }

    final itemKey = '${item.videoId}:${item.sourceUrl}';
    if (_loadedItemKey == itemKey) {
      return;
    }

    final matchedAlbum = item.parsedAlbumTitle == null
        ? null
        : findBestMatchingAlbum(_availableAlbums, item.parsedAlbumTitle!);
    final selectedAuthors = _resolveParsedAuthors(item.parsedAuthorNames);

    setState(() {
      _loadedItemKey = itemKey;
      _titleController.text = item.parsedTitle;
      _selectedTrackId = null;
      _selectedAlbumId = matchedAlbum?.id;
      _selectedAuthors
        ..clear()
        ..addAll(selectedAuthors);
      _suggestedTracksById.clear();
    });

    await _loadSuggestionTracks(item.suggestions);
  }

  List<Author> _resolveParsedAuthors(List<String> parsedAuthorNames) {
    final matches = <Author>[];
    final seen = <String>{};

    for (final rawName in parsedAuthorNames) {
      final normalized = _normalizeName(rawName);
      if (normalized.isEmpty || seen.contains(normalized)) {
        continue;
      }
      seen.add(normalized);
      final existing = _findAvailableAuthorByNormalizedName(normalized);
      matches.add(existing ?? Author(currentName: rawName.trim()));
    }

    return matches;
  }

  Future<void> _loadSuggestionTracks(
    List<YouTubeImportSuggestion> suggestions,
  ) async {
    final trackIds = suggestions
        .map((suggestion) => suggestion.trackId)
        .toSet();
    final storage = context.read<TracksStorage>();
    final loaded = <int, Track>{};

    for (final trackId in trackIds) {
      if (trackId <= 0) {
        continue;
      }
      try {
        loaded[trackId] = await storage.getTrack(trackId);
      } catch (_) {}
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _suggestedTracksById
        ..clear()
        ..addAll(loaded);
    });
  }

  Future<void> _searchParsedAlbum(YouTubeCurrentImportItem item) async {
    final parsedAlbumTitle = item.parsedAlbumTitle;
    if (parsedAlbumTitle == null || parsedAlbumTitle.isEmpty) {
      return;
    }

    final result = await showAlbumPickerDialog(
      context,
      availableAlbums: _availableAlbums,
      selectedAlbumId: _selectedAlbumId,
      metadataAlbumTitle: parsedAlbumTitle,
      onCreateNew: () => _openCreateAlbumScreen(
        initialTitle: parsedAlbumTitle,
        initialReleaseDate: item.parsedReleaseDate,
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    if (result case AlbumPickerDialogSelection(album: final album)) {
      setState(() {
        _selectedAlbumId = album.id;
      });
    }
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

  Future<void> _selectExistingTrack() async {
    final selectedTrack = await showDialog<Track>(
      context: context,
      builder: (context) => const _TrackPickerDialog(),
    );

    if (selectedTrack?.id == null || !mounted) {
      return;
    }

    setState(() {
      _selectedTrackId = selectedTrack!.id;
      _suggestedTracksById[selectedTrack.id!] = selectedTrack;
    });
  }

  Future<void> _addAsNew() async {
    final currentItem = _session?.currentItem;
    final selectedAlbum = _selectedAlbum;
    final title = _titleController.text.trim();

    if (currentItem == null) {
      _showMessage('No YouTube item is loaded.');
      return;
    }
    if (title.isEmpty) {
      _showMessage('Name is required.');
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

    if (!mounted) {
      return;
    }
    setState(() {
      _isCreating = true;
    });

    final repository = context.read<YouTubeImportRepository>();

    try {
      final authorIds = await _resolveAuthorIds();
      final response = await repository.addCurrentAsNew(
        name: title,
        authorIds: authorIds,
        albumId: selectedAlbum!.id!,
        albumOrder: selectedAlbum.trackIds.length,
      );

      await _loadAlbums();

      if (!mounted) {
        return;
      }

      context.read<TrackListBloc>().add(const LoadTracks());
      setState(() {
        _session = response.session;
        _isCreating = false;
      });
      await _syncStateWithSession(response.session);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isCreating = false;
      });
      _showMessage(_errorMessageFrom(error));
    }
  }

  Future<void> _attachSelectedTrack() async {
    final trackId = _selectedTrackId;
    if (trackId == null || trackId <= 0) {
      _showMessage('Select a local track first.');
      return;
    }
    await _attachToTrackId(trackId);
  }

  Future<void> _attachToTrackId(int trackId) async {
    if (!mounted) {
      return;
    }
    setState(() {
      _isAttaching = true;
      _selectedTrackId = trackId;
    });

    try {
      final response = await context
          .read<YouTubeImportRepository>()
          .attachCurrent(trackId: trackId);
      if (!mounted) {
        return;
      }
      context.read<TrackListBloc>().add(const LoadTracks());
      setState(() {
        _session = response.session;
        _isAttaching = false;
      });
      await _syncStateWithSession(response.session);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isAttaching = false;
      });
      _showMessage(_errorMessageFrom(error));
    }
  }

  Future<void> _skipAndNext() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _isSkipping = true;
    });

    try {
      final updatedSession = await context
          .read<YouTubeImportRepository>()
          .skipCurrent();
      if (!mounted) {
        return;
      }
      setState(() {
        _session = updatedSession;
        _isSkipping = false;
      });
      await _syncStateWithSession(updatedSession);
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
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cancel YouTube import session?'),
          content: const Text(
            'This will stop the current YouTube import session on the backend.',
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

    if (shouldCancel != true || !mounted) {
      return;
    }

    setState(() {
      _isCancelling = true;
    });

    try {
      await context.read<YouTubeImportRepository>().cancelCurrentSession();
      if (!mounted) {
        return;
      }
      setState(() {
        _session = null;
        _loadedItemKey = null;
        _titleController.clear();
        _selectedTrackId = null;
        _selectedAlbumId = null;
        _selectedAuthors.clear();
        _suggestedTracksById.clear();
        _isCancelling = false;
      });
      _showMessage('YouTube import session cancelled.');
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
            _normalizeName(author.currentName): author,
          for (final author in createdAuthors)
            _normalizeName(author.currentName): author,
        };
        _availableAuthors = authorIdsByName.values.toList()
          ..sort(
            (left, right) => left.currentName.toLowerCase().compareTo(
              right.currentName.toLowerCase(),
            ),
          );
        for (var index = 0; index < _selectedAuthors.length; index++) {
          final normalized = _normalizeName(
            _selectedAuthors[index].currentName,
          );
          final replacement = authorIdsByName[normalized];
          if (replacement != null) {
            _selectedAuthors[index] = replacement;
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

  String _normalizeName(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  Author? _findAvailableAuthorByNormalizedName(String normalizedName) {
    for (final author in _availableAuthors) {
      if (_normalizeName(author.currentName) == normalizedName) {
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

  Track? get _selectedTrack {
    final trackId = _selectedTrackId;
    if (trackId == null) {
      return null;
    }
    return _suggestedTracksById[trackId];
  }

  YouTubeImportSuggestion? _findExactSuggestion(YouTubeCurrentImportItem item) {
    for (final suggestion in item.suggestions) {
      if (suggestion.isExactSourceMatch) {
        return suggestion;
      }
    }
    return null;
  }

  String _trackSummary(Track track) {
    final authors = track.authors
        .map((author) => author.currentName)
        .join(', ');
    return [
      '#${track.id ?? 'unknown'} ${track.name}',
      if (authors.isNotEmpty) 'Authors: $authors',
      'Album #${track.albumId}',
    ].join('\n');
  }

  String _humanizeSourceType(String sourceType) {
    switch (sourceType) {
      case 'track':
        return 'Track';
      case 'playlist':
        return 'Playlist';
      case 'artist':
        return 'Artist';
      default:
        return sourceType;
    }
  }

  String _errorMessageFrom(Object error) {
    if (error is HttpAppError) {
      return error.message;
    }
    if (error is FormatException) {
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

class _StartMessageIdParseResult {
  const _StartMessageIdParseResult({this.value, this.errorMessage});

  final int? value;
  final String? errorMessage;
}

class _TrackPickerDialog extends StatefulWidget {
  const _TrackPickerDialog();

  @override
  State<_TrackPickerDialog> createState() => _TrackPickerDialogState();
}

class _TrackPickerDialogState extends State<_TrackPickerDialog> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<Track> _tracks = const [];
  bool _isLoading = true;
  String? _errorMessage;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
    _loadTracks();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select local track'),
      content: SizedBox(
        width: 640,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: const InputDecoration(
                labelText: 'Search tracks',
                hintText: 'Title or ID',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => _loadTracks(),
            ),
            const SizedBox(height: 12),
            if (_errorMessage != null) ...[
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 12),
            ],
            if (_isLoading) const LinearProgressIndicator(),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: _tracks.isEmpty && !_isLoading
                  ? const Center(child: Text('No tracks match the search.'))
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: _tracks.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final track = _tracks[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(track.name),
                          subtitle: Text(
                            [
                              '#${track.id ?? 'unknown'}',
                              if (track.authors.isNotEmpty)
                                track.authors
                                    .map((author) => author.currentName)
                                    .join(', '),
                              'Album #${track.albumId}',
                            ].join('  •  '),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: track.id == null
                              ? null
                              : () => Navigator.of(context).pop(track),
                        );
                      },
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
      ],
    );
  }

  Future<void> _loadTracks() async {
    final requestId = ++_requestId;
    final query = _searchController.text.trim();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await context.read<TracksStorage>().getTracks(
        page: 1,
        pageSize: 20,
        query: query.isEmpty ? null : query,
      );
      if (!mounted || requestId != _requestId) {
        return;
      }
      setState(() {
        _tracks = result.tracks;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted || requestId != _requestId) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load tracks: $error';
      });
    }
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

String _formatDateOnly(DateTime date) {
  final normalized = date.toUtc();
  return '${normalized.year.toString().padLeft(4, '0')}-${normalized.month.toString().padLeft(2, '0')}-${normalized.day.toString().padLeft(2, '0')}';
}

String _formatDateTime(DateTime dateTime) {
  final normalized = dateTime.toUtc();
  return '${_formatDateOnly(normalized)} ${normalized.hour.toString().padLeft(2, '0')}:${normalized.minute.toString().padLeft(2, '0')} UTC';
}

String _formatDuration(int durationSeconds) {
  final minutes = durationSeconds ~/ 60;
  final seconds = durationSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
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
  static const _recentAuthorNamesStorageKey = 'recent_author_picker_names_v1';

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
  late final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final List<String> _selectionOrderKeys = [];
  List<String> _recentAuthorKeys = const [];
  late String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectionOrderKeys.addAll(_selectedAuthorsByKey.keys);
    _loadRecentAuthors();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recentAuthors = _recentAuthors;
    final filteredAuthors = _filteredAuthors;
    final trimmedSearchText = _searchController.text.trim();

    return AlertDialog(
      title: const Text('Select authors'),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: const InputDecoration(
                labelText: 'Search authors',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.trim().toLowerCase();
                });
              },
              onSubmitted: (_) => _addCustomAuthor(),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: trimmedSearchText.isEmpty ? null : _addCustomAuthor,
                icon: const Icon(Icons.add),
                label: Text(
                  trimmedSearchText.isEmpty
                      ? 'Add author'
                      : 'Add author $trimmedSearchText',
                ),
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                    if (recentAuthors.isNotEmpty) ...[
                      Text(
                        'Last selected authors',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      ...recentAuthors.map(_buildAuthorTile),
                      const SizedBox(height: 12),
                    ],
                    Text(
                      'All authors',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    if (widget.availableAuthors.isEmpty)
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('No authors in database yet.'),
                      )
                    else if (filteredAuthors.isEmpty)
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('No authors match the search.'),
                      )
                    else
                      ...filteredAuthors.map(_buildAuthorTile),
                  ],
                ),
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
          onPressed: () async {
            final authors = _selectedAuthorsByKey.values.toList();

            authors.sort(
              (left, right) => left.currentName.toLowerCase().compareTo(
                right.currentName.toLowerCase(),
              ),
            );
            await _saveRecentAuthors();
            if (!context.mounted) {
              return;
            }
            Navigator.of(context).pop(authors);
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }

  void _addCustomAuthor() {
    final authorName = _searchController.text.trim();
    if (authorName.isEmpty) {
      return;
    }

    setState(() {
      final key = authorName.toLowerCase();
      _selectedAuthorsByKey[key] = Author(currentName: authorName);
      _markAuthorAsRecentlySelected(key);
    });
    _searchController.clear();
    _searchQuery = '';
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

  List<Author> get _filteredAuthors {
    if (_searchQuery.isEmpty) {
      return widget.availableAuthors;
    }

    return widget.availableAuthors.where((author) {
      final name = author.currentName.toLowerCase();
      final id = author.id?.toString() ?? '';
      return name.contains(_searchQuery) || id.contains(_searchQuery);
    }).toList();
  }

  List<Author> get _recentAuthors {
    if (_recentAuthorKeys.isEmpty) {
      return const [];
    }

    final authorsByKey = {
      for (final author in widget.availableAuthors)
        author.currentName.toLowerCase(): author,
    };

    final filteredRecentAuthors = <Author>[];
    for (final authorKey in _recentAuthorKeys) {
      final author = authorsByKey[authorKey];
      if (author == null) {
        continue;
      }
      if (_searchQuery.isNotEmpty &&
          !author.currentName.toLowerCase().contains(_searchQuery) &&
          !(author.id?.toString().contains(_searchQuery) ?? false)) {
        continue;
      }
      filteredRecentAuthors.add(author);
    }
    return filteredRecentAuthors;
  }

  Widget _buildAuthorTile(Author author) {
    return CheckboxListTile(
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
            _markAuthorAsRecentlySelected(key);
          } else {
            _selectedAuthorsByKey.remove(key);
          }
        });
      },
    );
  }

  void _markAuthorAsRecentlySelected(String key) {
    _selectionOrderKeys.remove(key);
    _selectionOrderKeys.add(key);
  }

  Future<void> _loadRecentAuthors() async {
    final preferences = await SharedPreferences.getInstance();
    final storedRecentNames =
        preferences.getStringList(_recentAuthorNamesStorageKey) ?? const [];
    if (!mounted) {
      return;
    }

    setState(() {
      _recentAuthorKeys = storedRecentNames
          .map((name) => name.toLowerCase())
          .where((name) => name.isNotEmpty)
          .toList();
    });
  }

  Future<void> _saveRecentAuthors() async {
    final availableAuthorKeys = {
      for (final author in widget.availableAuthors)
        author.currentName.toLowerCase(),
    };
    final mergedRecentNames = <String>[];

    for (final authorKey in _selectionOrderKeys.reversed) {
      if (!_selectedAuthorsByKey.containsKey(authorKey)) {
        continue;
      }
      if (!availableAuthorKeys.contains(authorKey)) {
        continue;
      }
      mergedRecentNames.add(authorKey);
      if (mergedRecentNames.length == 5) {
        break;
      }
    }

    if (mergedRecentNames.length < 5) {
      for (final authorKey in _recentAuthorKeys) {
        if (!availableAuthorKeys.contains(authorKey)) {
          continue;
        }
        if (mergedRecentNames.contains(authorKey)) {
          continue;
        }
        mergedRecentNames.add(authorKey);
        if (mergedRecentNames.length == 5) {
          break;
        }
      }
    }

    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _recentAuthorNamesStorageKey,
      mergedRecentNames,
    );
    _recentAuthorKeys = mergedRecentNames;
  }
}
