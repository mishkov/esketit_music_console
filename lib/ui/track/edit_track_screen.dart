import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:equatable/equatable.dart';
import 'package:esketit_music_console/domain/album.dart';
import 'package:esketit_music_console/domain/author.dart';
import 'package:esketit_music_console/domain/track.dart';
import 'package:esketit_music_console/domain/track_info/track_info.dart';
import 'package:esketit_music_console/domain/track_lyrics.dart';
import 'package:esketit_music_console/domain/track_lyrics_import.dart';
import 'package:esketit_music_console/domain/track_metadata_validation.dart';
import 'package:esketit_music_console/domain/track_source_metadata.dart';
import 'package:esketit_music_console/errors/http_app_error.dart';
import 'package:esketit_music_console/firebase/track/storage_file.dart';
import 'package:esketit_music_console/ui/album/album_picker.dart';
import 'package:esketit_music_console/ui/album/albums_support.dart';
import 'package:esketit_music_console/ui/album/edit_album_screen.dart';
import 'package:esketit_music_console/ui/track/track_metadata_editor.dart';
import 'package:esketit_music_console/unassigned_layer/cross_file.dart';
import 'package:esketit_music_console/use_case/track/storage/tracks_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class EditTrackScreen extends StatefulWidget {
  const EditTrackScreen({super.key, required this.trackId});

  final int trackId;

  @override
  State<EditTrackScreen> createState() => _EditTrackScreenState();
}

class _EditTrackScreenState extends State<EditTrackScreen> {
  final _titleController = TextEditingController();
  final _lyricsLanguageCodeController = TextEditingController();
  final _lyricsSourceController = TextEditingController();
  final _lyricsPlainTextController = TextEditingController();
  final List<TrackInfo> _additionalInfos = [];
  final List<TrackSourceMetadata> _sourceMetadata = [];
  final List<Author> _selectedAuthors = [];
  final List<_EditableLyricsLine> _lyricsLines = [];
  List<Author> _availableAuthors = const [];
  List<Album> _availableAlbums = const [];
  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasLyrics = false;
  bool _hasPersistedLyrics = false;
  bool _lyricsIsVerified = false;
  String? _errorMessage;
  int? _selectedAlbumId;
  Track? _track;
  Album? _currentAlbum;
  CrossFile? _replacementFile;
  TrackLyricsType _lyricsType = TrackLyricsType.plain;
  int _nextLyricsLineId = 0;

  @override
  void initState() {
    super.initState();
    _loadTrack();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _lyricsLanguageCodeController.dispose();
    _lyricsSourceController.dispose();
    _lyricsPlainTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final track = _track;

    return Scaffold(
      appBar: AppBar(title: const Text('Edit track')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isLoading || _isSaving) const LinearProgressIndicator(),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: _titleController,
                    enabled: !_isLoading && !_isSaving,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  AlbumPickerField(
                    albums: _availableAlbums,
                    selectedAlbum: _selectedAlbum,
                    isLoading: _isLoading,
                    enabled: !_isLoading && !_isSaving && track != null,
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
                    value: _buildAlbumPositionLabel(),
                  ),
                  const SizedBox(height: 16),
                  _AuthorPickerField(
                    authors: _selectedAuthors,
                    isLoading: _isLoading,
                    onTap: _isLoading || _isSaving ? null : _showAuthorPicker,
                    onRemove: _isLoading || _isSaving ? null : _removeAuthor,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Audio file',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  _SelectionSummaryCard(
                    title: _replacementFile == null
                        ? 'Current file'
                        : 'Replacement file',
                    value: _buildFileLabel(),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: _isLoading || _isSaving ? null : _pickFile,
                        icon: const Icon(Icons.upload_file),
                        label: Text(
                          _replacementFile == null
                              ? 'Replace file'
                              : 'Pick another file',
                        ),
                      ),
                      if (_replacementFile != null)
                        TextButton(
                          onPressed: _isSaving
                              ? null
                              : () {
                                  setState(() {
                                    _replacementFile = null;
                                  });
                                },
                          child: const Text('Keep current file'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Lyrics',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  _LyricsSection(
                    hasLyrics: _hasLyrics,
                    hasPersistedLyrics: _hasPersistedLyrics,
                    lyricsType: _lyricsType,
                    languageCodeController: _lyricsLanguageCodeController,
                    sourceController: _lyricsSourceController,
                    plainTextController: _lyricsPlainTextController,
                    lyricsIsVerified: _lyricsIsVerified,
                    lyricsLines: _lyricsLines,
                    isLoading: _isLoading,
                    isSaving: _isSaving,
                    onStartPlainLyrics: () =>
                        _startLyricsDraft(TrackLyricsType.plain),
                    onStartSyncedLyrics: () =>
                        _startLyricsDraft(TrackLyricsType.synced),
                    onImportPlainLyrics: _importPlainLyrics,
                    onImportSyncedLyrics: _importSyncedLyrics,
                    onLyricsTypeChanged: (type) {
                      setState(() {
                        _lyricsType = type;
                        if (_lyricsType == TrackLyricsType.synced &&
                            _lyricsLines.isEmpty) {
                          _lyricsLines.add(_createLyricsLine());
                        }
                      });
                    },
                    onLyricsVerifiedChanged: (value) {
                      setState(() {
                        _lyricsIsVerified = value;
                      });
                    },
                    onLyricsLineChanged: (index, updatedLine) {
                      setState(() {
                        _lyricsLines[index] = updatedLine;
                      });
                    },
                    onLyricsLineMoveUp: (index) => _moveLyricsLine(index, -1),
                    onLyricsLineMoveDown: (index) => _moveLyricsLine(index, 1),
                    onLyricsLineDelete: _removeLyricsLine,
                    onAddLyricsLine: () {
                      setState(() {
                        _lyricsLines.add(_createLyricsLine());
                      });
                    },
                    onDeleteLyrics: _deleteLyrics,
                  ),
                  const SizedBox(height: 24),
                  TrackMetadataEditor(
                    additionalInfo: _additionalInfos,
                    sourceMetadata: _sourceMetadata,
                    enabled: !_isLoading && !_isSaving,
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
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: _isLoading || _isSaving || track == null
                            ? null
                            : _deleteTrack,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete track'),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: _isLoading || _isSaving || track == null
                            ? null
                            : _saveTrack,
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _loadTrack() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final storage = context.read<TracksStorage>();
      final track = await storage.getTrack(widget.trackId);
      final authorsFuture = storage.getAuthors();
      final albumsFuture = loadAllAlbums(storage);
      final currentAlbumFuture = storage.getAlbum(track.albumId);
      final lyricsFuture = storage.getTrackLyrics(widget.trackId);

      final authors = await authorsFuture;
      final albums = await albumsFuture;
      final currentAlbum = await currentAlbumFuture;
      final lyrics = await lyricsFuture;

      if (!mounted) {
        return;
      }

      authors.sort(
        (left, right) => left.currentName.toLowerCase().compareTo(
          right.currentName.toLowerCase(),
        ),
      );
      albums.sort(
        (left, right) =>
            left.title.toLowerCase().compareTo(right.title.toLowerCase()),
      );

      setState(() {
        _track = track;
        _currentAlbum = currentAlbum;
        _availableAuthors = authors;
        _availableAlbums = albums;
        _selectedAlbumId = track.albumId;
        _titleController.text = track.name;
        _selectedAuthors
          ..clear()
          ..addAll(track.authors);
        _additionalInfos
          ..clear()
          ..addAll(track.additionalInfo);
        _sourceMetadata
          ..clear()
          ..addAll(track.sourceMetadata);
        _replacementFile = null;
        _applyLyricsState(lyrics);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = _describeError(error);
      });
    }
  }

  void _applyLyricsState(TrackLyrics? lyrics) {
    _lyricsLines.clear();
    _lyricsPlainTextController.clear();

    if (lyrics == null) {
      _hasLyrics = false;
      _hasPersistedLyrics = false;
      _lyricsType = TrackLyricsType.plain;
      _lyricsLanguageCodeController.clear();
      _lyricsSourceController.clear();
      _lyricsIsVerified = false;
      return;
    }

    _hasLyrics = true;
    _hasPersistedLyrics = true;
    _lyricsType = lyrics.type;
    _lyricsLanguageCodeController.text = lyrics.languageCode;
    _lyricsSourceController.text = lyrics.source;
    _lyricsPlainTextController.text = lyrics.plainText ?? '';
    _lyricsIsVerified = lyrics.isVerified;
    _lyricsLines.addAll(
      lyrics.lines.map(
        (line) => _EditableLyricsLine(
          id: _nextLyricsLineId++,
          startMs: '${line.startMs}',
          endMs: line.endMs?.toString() ?? '',
          text: line.text,
        ),
      ),
    );
  }

  void _startLyricsDraft(TrackLyricsType type) {
    setState(() {
      _hasLyrics = true;
      _lyricsType = type;
      if (type == TrackLyricsType.synced && _lyricsLines.isEmpty) {
        _lyricsLines.add(_createLyricsLine());
      }
    });
  }

  _EditableLyricsLine _createLyricsLine() {
    final previousLine = _lyricsLines.isEmpty ? null : _lyricsLines.last;
    final suggestedStart =
        previousLine?.parsedEndMs ?? previousLine?.parsedStartMs ?? 0;
    return _EditableLyricsLine(
      id: _nextLyricsLineId++,
      startMs: '$suggestedStart',
      endMs: '',
      text: '',
    );
  }

  Future<void> _deleteLyrics() async {
    final trackId = _track?.id;
    if (trackId == null) {
      return;
    }

    if (!_hasPersistedLyrics) {
      setState(() {
        _clearLyricsDraft();
      });
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete lyrics?'),
          content: const Text(
            'This removes the lyrics for this track. This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true || !mounted) {
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await context.read<TracksStorage>().deleteTrackLyrics(trackId);
      if (!mounted) {
        return;
      }
      setState(() {
        _clearLyricsDraft();
        _isSaving = false;
      });
      _showMessage('Lyrics deleted.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
        _errorMessage = _describeError(error);
      });
    }
  }

  void _clearLyricsDraft() {
    _hasLyrics = false;
    _hasPersistedLyrics = false;
    _lyricsType = TrackLyricsType.plain;
    _lyricsLanguageCodeController.clear();
    _lyricsSourceController.clear();
    _lyricsPlainTextController.clear();
    _lyricsLines.clear();
    _lyricsIsVerified = false;
  }

  ({TrackLyrics? lyrics, List<String> errors}) _buildLyricsPayload() {
    if (!_hasLyrics) {
      return (lyrics: null, errors: const <String>[]);
    }

    final errors = <String>[];
    final lines = <TrackLyricsLine>[];
    if (_lyricsType == TrackLyricsType.synced) {
      for (var index = 0; index < _lyricsLines.length; index++) {
        final line = _lyricsLines[index];
        final lineNumber = index + 1;
        final startMs = int.tryParse(line.startMs.trim());
        if (startMs == null) {
          errors.add('Line $lineNumber start time must be a valid integer.');
          continue;
        }

        final trimmedEndMs = line.endMs.trim();
        final endMs = trimmedEndMs.isEmpty ? null : int.tryParse(trimmedEndMs);
        if (trimmedEndMs.isNotEmpty && endMs == null) {
          errors.add('Line $lineNumber end time must be a valid integer.');
          continue;
        }

        lines.add(
          TrackLyricsLine(startMs: startMs, endMs: endMs, text: line.text),
        );
      }
    }

    final lyrics = TrackLyrics(
      trackId: widget.trackId,
      type: _lyricsType,
      languageCode: _lyricsLanguageCodeController.text,
      isVerified: _lyricsIsVerified,
      source: _lyricsSourceController.text,
      plainText: _lyricsType == TrackLyricsType.plain
          ? _lyricsPlainTextController.text
          : null,
      lines: _lyricsType == TrackLyricsType.synced ? lines : const [],
    );

    return (
      lyrics: lyrics,
      errors: [...errors, ...validateTrackLyrics(lyrics)],
    );
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

    setState(() {
      _replacementFile = CrossFile(file: xFile);
    });
  }

  Future<void> _openCreateAlbumScreen() async {
    final savedAlbum = await Navigator.of(
      context,
    ).push<Album>(MaterialPageRoute(builder: (_) => const EditAlbumScreen()));

    if (savedAlbum?.id == null || !mounted) {
      return;
    }

    await _reloadAlbums();
    if (!mounted) {
      return;
    }

    setState(() {
      _selectedAlbumId = savedAlbum!.id;
    });
  }

  Future<void> _reloadAlbums() async {
    final albums = await loadAllAlbums(context.read<TracksStorage>());
    albums.sort(
      (left, right) =>
          left.title.toLowerCase().compareTo(right.title.toLowerCase()),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _availableAlbums = albums;
      if (!_availableAlbums.any((album) => album.id == _selectedAlbumId)) {
        _selectedAlbumId = albums.isEmpty ? null : albums.first.id;
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
    final track = _track;
    final selectedAlbum = _selectedAlbum;
    final title = _titleController.text.trim();
    final lyricsPayload = _buildLyricsPayload();
    final additionalInfoErrors = validateTrackAdditionalInfo(_additionalInfos);
    final sourceMetadataErrors = validateTrackSourceMetadata(_sourceMetadata);

    if (track == null) {
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
    if (lyricsPayload.errors.isNotEmpty) {
      _showMessage(lyricsPayload.errors.first);
      return;
    }
    if (additionalInfoErrors.isNotEmpty) {
      _showMessage(additionalInfoErrors.first);
      return;
    }
    if (sourceMetadataErrors.isNotEmpty) {
      _showMessage(sourceMetadataErrors.first);
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final storage = context.read<TracksStorage>();
      final albumOrder = await _resolveAlbumOrder(selectedAlbum!);
      final updatedTrack = await storage.updateTrack(
        Track(
          id: track.id,
          name: title,
          authors: List<Author>.from(_selectedAuthors),
          albumId: selectedAlbum.id!,
          albumOrder: albumOrder,
          additionalInfo: List<TrackInfo>.from(_additionalInfos),
          sourceMetadata: List<TrackSourceMetadata>.from(_sourceMetadata),
          file: _replacementFile ?? track.file,
        ),
      );
      final lyrics = lyricsPayload.lyrics;
      if (lyrics != null) {
        await storage.putTrackLyrics(lyrics);
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _track = updatedTrack;
        _selectedAlbumId = updatedTrack.albumId;
        _replacementFile = null;
        _hasPersistedLyrics = lyrics != null;
        _isSaving = false;
      });
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
        _errorMessage = _describeError(error);
      });
    }
  }

  Future<int> _resolveAlbumOrder(Album selectedAlbum) async {
    final track = _track;
    if (track?.id == null) {
      return 0;
    }

    if (selectedAlbum.id == _currentAlbum?.id) {
      final currentTrackIds = _currentAlbum?.trackIds ?? const <int>[];
      final currentIndex = currentTrackIds.indexOf(track!.id!);
      if (currentIndex >= 0) {
        return currentIndex;
      }
    }

    final album = await context.read<TracksStorage>().getAlbum(
      selectedAlbum.id!,
    );
    return album.trackIds.length;
  }

  Future<void> _deleteTrack() async {
    final track = _track;
    if (track?.id == null) {
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete track?'),
          content: Text(
            'Delete "${_titleController.text.trim()}" from the database? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true || !mounted) {
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await context.read<TracksStorage>().deleteTrack(track!.id!);
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
        _errorMessage = _describeError(error);
      });
    }
  }

  void _moveLyricsLine(int index, int offset) {
    final targetIndex = index + offset;
    if (targetIndex < 0 || targetIndex >= _lyricsLines.length) {
      return;
    }
    setState(() {
      final line = _lyricsLines.removeAt(index);
      _lyricsLines.insert(targetIndex, line);
    });
  }

  void _removeLyricsLine(int index) {
    setState(() {
      _lyricsLines.removeAt(index);
    });
  }

  Future<void> _importPlainLyrics() async {
    final bytes = await _pickLyricsFile(allowedExtensions: const ['txt']);
    if (bytes == null || !mounted) {
      return;
    }

    try {
      final plainText = parsePlainLyricsFile(bytes);
      if (plainText.isEmpty) {
        throw const FormatException('The selected TXT file is empty.');
      }
      setState(() {
        _hasLyrics = true;
        _lyricsType = TrackLyricsType.plain;
        _lyricsPlainTextController.text = plainText;
        _lyricsLines.clear();
      });
      _showMessage('Plain lyrics imported.');
    } catch (error) {
      _showMessage('Failed to import TXT lyrics: $error');
    }
  }

  Future<void> _importSyncedLyrics() async {
    final bytes = await _pickLyricsFile(allowedExtensions: const ['lrc']);
    if (bytes == null || !mounted) {
      return;
    }

    try {
      final lines = parseLrcLyricsFile(bytes);
      setState(() {
        _hasLyrics = true;
        _lyricsType = TrackLyricsType.synced;
        _lyricsPlainTextController.clear();
        _lyricsLines
          ..clear()
          ..addAll(
            lines.map(
              (line) => _EditableLyricsLine(
                id: _nextLyricsLineId++,
                startMs: '${line.startMs}',
                endMs: line.endMs?.toString() ?? '',
                text: line.text,
              ),
            ),
          );
      });
      _showMessage('Synced lyrics imported.');
    } catch (error) {
      _showMessage('Failed to import LRC lyrics: $error');
    }
  }

  Future<Uint8List?> _pickLyricsFile({
    required List<String> allowedExtensions,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
    );
    return result?.files.single.bytes;
  }

  void _removeAuthor(Author author) {
    setState(() {
      _selectedAuthors.remove(author);
    });
  }

  Album? get _selectedAlbum {
    for (final album in _availableAlbums) {
      if (album.id == _selectedAlbumId) {
        return album;
      }
    }
    return null;
  }

  String _buildAlbumPositionLabel() {
    final selectedAlbum = _selectedAlbum;
    final track = _track;
    if (selectedAlbum == null || track?.id == null) {
      return 'Select an album';
    }
    if (selectedAlbum.id == _currentAlbum?.id) {
      final currentIndex = _currentAlbum?.trackIds.indexOf(track!.id!);
      if (currentIndex != null && currentIndex >= 0) {
        return 'Current position: ${currentIndex + 1}';
      }
    }
    return 'Track will be moved to position ${selectedAlbum.trackIds.length + 1}';
  }

  String _buildFileLabel() {
    final file = (_replacementFile ?? _track?.file);
    if (file == null) {
      return 'No file selected';
    }
    if (file is CrossFile) {
      return '${file.name} (local file selected)';
    }
    if (file is StorageFile) {
      return '${file.name}\n${file.downloadUrl}';
    }
    return 'Unsupported file type: ${file.runtimeType}';
  }

  String _describeError(Object error) {
    if (error is HttpAppError) {
      final responseBody = error.responseBody;
      if (responseBody is String && responseBody.trim().isNotEmpty) {
        return responseBody.trim();
      }
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

class _LyricsSection extends StatelessWidget {
  const _LyricsSection({
    required this.hasLyrics,
    required this.hasPersistedLyrics,
    required this.lyricsType,
    required this.languageCodeController,
    required this.sourceController,
    required this.plainTextController,
    required this.lyricsIsVerified,
    required this.lyricsLines,
    required this.isLoading,
    required this.isSaving,
    required this.onStartPlainLyrics,
    required this.onStartSyncedLyrics,
    required this.onImportPlainLyrics,
    required this.onImportSyncedLyrics,
    required this.onLyricsTypeChanged,
    required this.onLyricsVerifiedChanged,
    required this.onLyricsLineChanged,
    required this.onLyricsLineMoveUp,
    required this.onLyricsLineMoveDown,
    required this.onLyricsLineDelete,
    required this.onAddLyricsLine,
    required this.onDeleteLyrics,
  });

  final bool hasLyrics;
  final bool hasPersistedLyrics;
  final TrackLyricsType lyricsType;
  final TextEditingController languageCodeController;
  final TextEditingController sourceController;
  final TextEditingController plainTextController;
  final bool lyricsIsVerified;
  final List<_EditableLyricsLine> lyricsLines;
  final bool isLoading;
  final bool isSaving;
  final VoidCallback onStartPlainLyrics;
  final VoidCallback onStartSyncedLyrics;
  final Future<void> Function() onImportPlainLyrics;
  final Future<void> Function() onImportSyncedLyrics;
  final ValueChanged<TrackLyricsType> onLyricsTypeChanged;
  final ValueChanged<bool> onLyricsVerifiedChanged;
  final void Function(int index, _EditableLyricsLine updatedLine)
  onLyricsLineChanged;
  final ValueChanged<int> onLyricsLineMoveUp;
  final ValueChanged<int> onLyricsLineMoveDown;
  final ValueChanged<int> onLyricsLineDelete;
  final VoidCallback onAddLyricsLine;
  final Future<void> Function() onDeleteLyrics;

  @override
  Widget build(BuildContext context) {
    if (!hasLyrics) {
      return _LyricsEmptyState(
        isDisabled: isLoading || isSaving,
        onStartPlainLyrics: onStartPlainLyrics,
        onStartSyncedLyrics: onStartSyncedLyrics,
        onImportPlainLyrics: onImportPlainLyrics,
        onImportSyncedLyrics: onImportSyncedLyrics,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<TrackLyricsType>(
          segments: const [
            ButtonSegment(
              value: TrackLyricsType.plain,
              icon: Icon(Icons.notes),
              label: Text('Plain'),
            ),
            ButtonSegment(
              value: TrackLyricsType.synced,
              icon: Icon(Icons.av_timer),
              label: Text('Synced'),
            ),
          ],
          selected: {lyricsType},
          onSelectionChanged: isSaving
              ? null
              : (selection) => onLyricsTypeChanged(selection.first),
        ),
        const SizedBox(height: 16),
        _LyricsMetadataFields(
          languageCodeController: languageCodeController,
          sourceController: sourceController,
          lyricsIsVerified: lyricsIsVerified,
          isSaving: isSaving,
          onLyricsVerifiedChanged: onLyricsVerifiedChanged,
        ),
        const SizedBox(height: 12),
        if (lyricsType == TrackLyricsType.plain)
          TextField(
            controller: plainTextController,
            enabled: !isSaving,
            minLines: 8,
            maxLines: 16,
            decoration: const InputDecoration(
              labelText: 'Lyrics text',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          )
        else
          _SyncedLyricsEditor(
            lyricsLines: lyricsLines,
            isSaving: isSaving,
            onLyricsLineChanged: onLyricsLineChanged,
            onLyricsLineMoveUp: onLyricsLineMoveUp,
            onLyricsLineMoveDown: onLyricsLineMoveDown,
            onLyricsLineDelete: onLyricsLineDelete,
            onAddLyricsLine: onAddLyricsLine,
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.tonalIcon(
              onPressed: isSaving
                  ? null
                  : lyricsType == TrackLyricsType.plain
                  ? onImportPlainLyrics
                  : onImportSyncedLyrics,
              icon: const Icon(Icons.upload_file),
              label: Text(
                lyricsType == TrackLyricsType.plain
                    ? 'Import .txt'
                    : 'Import .lrc',
              ),
            ),
            TextButton.icon(
              onPressed: isSaving ? null : onDeleteLyrics,
              icon: const Icon(Icons.delete_outline),
              label: Text(
                hasPersistedLyrics ? 'Delete lyrics' : 'Remove lyrics draft',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LyricsEmptyState extends StatelessWidget {
  const _LyricsEmptyState({
    required this.isDisabled,
    required this.onStartPlainLyrics,
    required this.onStartSyncedLyrics,
    required this.onImportPlainLyrics,
    required this.onImportSyncedLyrics,
  });

  final bool isDisabled;
  final VoidCallback onStartPlainLyrics;
  final VoidCallback onStartSyncedLyrics;
  final Future<void> Function() onImportPlainLyrics;
  final Future<void> Function() onImportSyncedLyrics;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _EmptyStateCard(message: 'This track has no lyrics yet.'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.tonalIcon(
              onPressed: isDisabled ? null : onStartPlainLyrics,
              icon: const Icon(Icons.notes),
              label: const Text('Add plain lyrics'),
            ),
            FilledButton.tonalIcon(
              onPressed: isDisabled ? null : onImportPlainLyrics,
              icon: const Icon(Icons.upload_file),
              label: const Text('Import .txt'),
            ),
            FilledButton.tonalIcon(
              onPressed: isDisabled ? null : onStartSyncedLyrics,
              icon: const Icon(Icons.av_timer),
              label: const Text('Add synced lyrics'),
            ),
            FilledButton.tonalIcon(
              onPressed: isDisabled ? null : onImportSyncedLyrics,
              icon: const Icon(Icons.upload_file),
              label: const Text('Import .lrc'),
            ),
          ],
        ),
      ],
    );
  }
}

class _LyricsMetadataFields extends StatelessWidget {
  const _LyricsMetadataFields({
    required this.languageCodeController,
    required this.sourceController,
    required this.lyricsIsVerified,
    required this.isSaving,
    required this.onLyricsVerifiedChanged,
  });

  final TextEditingController languageCodeController;
  final TextEditingController sourceController;
  final bool lyricsIsVerified;
  final bool isSaving;
  final ValueChanged<bool> onLyricsVerifiedChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: languageCodeController,
                enabled: !isSaving,
                decoration: const InputDecoration(
                  labelText: 'Language code',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: sourceController,
                enabled: !isSaving,
                decoration: const InputDecoration(
                  labelText: 'Source',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          value: lyricsIsVerified,
          onChanged: isSaving ? null : onLyricsVerifiedChanged,
          contentPadding: EdgeInsets.zero,
          title: const Text('Verified lyrics'),
        ),
      ],
    );
  }
}

class _SyncedLyricsEditor extends StatelessWidget {
  const _SyncedLyricsEditor({
    required this.lyricsLines,
    required this.isSaving,
    required this.onLyricsLineChanged,
    required this.onLyricsLineMoveUp,
    required this.onLyricsLineMoveDown,
    required this.onLyricsLineDelete,
    required this.onAddLyricsLine,
  });

  final List<_EditableLyricsLine> lyricsLines;
  final bool isSaving;
  final void Function(int index, _EditableLyricsLine updatedLine)
  onLyricsLineChanged;
  final ValueChanged<int> onLyricsLineMoveUp;
  final ValueChanged<int> onLyricsLineMoveDown;
  final ValueChanged<int> onLyricsLineDelete;
  final VoidCallback onAddLyricsLine;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (lyricsLines.isEmpty)
          const _EmptyStateCard(message: 'No synced lyric lines yet.')
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: lyricsLines.length,
            itemBuilder: (context, index) {
              final line = lyricsLines[index];
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == lyricsLines.length - 1 ? 0 : 12,
                ),
                child: _SyncedLyricsLineCard(
                  key: ValueKey(line.id),
                  index: index,
                  line: line,
                  isSaving: isSaving,
                  onChanged: (updatedLine) =>
                      onLyricsLineChanged(index, updatedLine),
                  onMoveUp: index == 0 ? null : () => onLyricsLineMoveUp(index),
                  onMoveDown: index == lyricsLines.length - 1
                      ? null
                      : () => onLyricsLineMoveDown(index),
                  onDelete: () => onLyricsLineDelete(index),
                ),
              );
            },
          ),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: isSaving ? null : onAddLyricsLine,
          icon: const Icon(Icons.add),
          label: const Text('Add line'),
        ),
      ],
    );
  }
}

class _EditableLyricsLine extends Equatable {
  const _EditableLyricsLine({
    required this.id,
    required this.startMs,
    required this.endMs,
    required this.text,
  });

  final int id;
  final String startMs;
  final String endMs;
  final String text;

  int? get parsedStartMs => int.tryParse(startMs.trim());
  int? get parsedEndMs =>
      endMs.trim().isEmpty ? null : int.tryParse(endMs.trim());

  _EditableLyricsLine copyWith({String? startMs, String? endMs, String? text}) {
    return _EditableLyricsLine(
      id: id,
      startMs: startMs ?? this.startMs,
      endMs: endMs ?? this.endMs,
      text: text ?? this.text,
    );
  }

  @override
  List<Object?> get props => [id, startMs, endMs, text];
}

class _SyncedLyricsLineCard extends StatelessWidget {
  const _SyncedLyricsLineCard({
    super.key,
    required this.index,
    required this.line,
    required this.isSaving,
    required this.onChanged,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final int index;
  final _EditableLyricsLine line;
  final bool isSaving;
  final ValueChanged<_EditableLyricsLine> onChanged;
  final VoidCallback onDelete;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Line ${index + 1}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                IconButton(
                  onPressed: isSaving ? null : onMoveUp,
                  icon: const Icon(Icons.arrow_upward),
                  tooltip: 'Move up',
                ),
                IconButton(
                  onPressed: isSaving ? null : onMoveDown,
                  icon: const Icon(Icons.arrow_downward),
                  tooltip: 'Move down',
                ),
                IconButton(
                  onPressed: isSaving ? null : onDelete,
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Remove',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 140,
                  child: TextFormField(
                    enabled: !isSaving,
                    initialValue: line.startMs,
                    decoration: const InputDecoration(
                      labelText: 'Start ms',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      onChanged(line.copyWith(startMs: value));
                    },
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 140,
                  child: TextFormField(
                    enabled: !isSaving,
                    initialValue: line.endMs,
                    decoration: const InputDecoration(
                      labelText: 'End ms',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      onChanged(line.copyWith(endMs: value));
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    enabled: !isSaving,
                    initialValue: line.text,
                    decoration: const InputDecoration(
                      labelText: 'Text',
                      border: OutlineInputBorder(),
                    ),
                    minLines: 1,
                    maxLines: 3,
                    onChanged: (value) {
                      onChanged(line.copyWith(text: value));
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({required this.message});

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
