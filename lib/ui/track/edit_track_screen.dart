import 'dart:async';

import 'package:cross_file/cross_file.dart';
import 'package:equatable/equatable.dart';
import 'package:esketit_music_console/domain/album.dart';
import 'package:esketit_music_console/domain/author.dart';
import 'package:esketit_music_console/domain/lyrics_search_candidate.dart';
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
import 'package:esketit_music_console/use_case/lyrics/lyrics_search_repository.dart';
import 'package:esketit_music_console/use_case/track/storage/tracks_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

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
  final _syncedLyricsCreatorKey = GlobalKey<_SyncedLyricsCreatorState>();
  final _lyricsSearchAudioController = _TrackMiniPlayerController();
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
  bool _isSyncedLyricsCreatorVisible = false;
  bool _isSearchingLyrics = false;
  String? _errorMessage;
  String? _lyricsSearchError;
  int? _selectedAlbumId;
  Track? _track;
  Album? _currentAlbum;
  CrossFile? _replacementFile;
  TrackLyricsType _lyricsType = TrackLyricsType.plain;
  List<LyricsSearchCandidate>? _lyricsSearchCandidates;
  int _selectedLyricsSearchCandidateIndex = 0;
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
    _lyricsSearchAudioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final track = _track;

    return CallbackShortcuts(
      bindings: _screenShortcutBindings,
      child: Focus(
        autofocus: true,
        child: Scaffold(
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
                      if (_isLoading || _isSaving)
                        const LinearProgressIndicator(),
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
                        onTap: _isLoading || _isSaving
                            ? null
                            : _showAuthorPicker,
                        onRemove: _isLoading || _isSaving
                            ? null
                            : _removeAuthor,
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
                            onPressed: _isLoading || _isSaving
                                ? null
                                : _pickFile,
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
                        onStartSyncedLyricsCreator: _startSyncedLyricsCreator,
                        onLyricsTypeChanged: (type) {
                          setState(() {
                            _lyricsType = type;
                            _isSyncedLyricsCreatorVisible = false;
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
                        onLyricsLineMoveUp: (index) =>
                            _moveLyricsLine(index, -1),
                        onLyricsLineMoveDown: (index) =>
                            _moveLyricsLine(index, 1),
                        onLyricsLineDelete: _removeLyricsLine,
                        onAddLyricsLine: () {
                          setState(() {
                            _lyricsLines.add(_createLyricsLine());
                          });
                        },
                        isSyncedLyricsCreatorVisible:
                            _isSyncedLyricsCreatorVisible,
                        syncedLyricsCreatorKey: _syncedLyricsCreatorKey,
                        trackFile: _replacementFile ?? _track?.file,
                        onCreatedLyricsLineSubmitted: _addCreatedLyricsLine,
                        onCreatedLyricsLineCanceled: _cancelCreatedLyricsLine,
                        onDeleteLyrics: _deleteLyrics,
                        isSearchingLyrics: _isSearchingLyrics,
                        lyricsSearchCandidates: _lyricsSearchCandidates,
                        selectedLyricsSearchCandidateIndex:
                            _selectedLyricsSearchCandidateIndex,
                        lyricsSearchError: _lyricsSearchError,
                        lyricsSearchAudioController:
                            _lyricsSearchAudioController,
                        onSearchLyrics: _searchLyrics,
                        onPreviousLyricsSearchCandidate:
                            _showPreviousLyricsSearchCandidate,
                        onNextLyricsSearchCandidate:
                            _showNextLyricsSearchCandidate,
                        onApplyPlainLyricsSearchCandidate:
                            _applyPlainLyricsSearchCandidate,
                        onSynchronizeLyricsSearchCandidate:
                            _synchronizeLyricsSearchCandidate,
                        onApplySyncedLyricsSearchCandidate:
                            _applySyncedLyricsSearchCandidate,
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
        ),
      ),
    );
  }

  Map<ShortcutActivator, VoidCallback> get _screenShortcutBindings => {
    const SingleActivator(LogicalKeyboardKey.arrowLeft):
        _seekSyncedLyricsCreatorBack,
    const SingleActivator(LogicalKeyboardKey.space):
        _toggleSyncedLyricsCreatorPlayback,
    const SingleActivator(LogicalKeyboardKey.arrowRight):
        _seekSyncedLyricsCreatorForward,
    const SingleActivator(LogicalKeyboardKey.enter):
        _submitSyncedLyricsCreatorLine,
    const SingleActivator(LogicalKeyboardKey.keyZ, control: true):
        _cancelSyncedLyricsCreatorLine,
    const SingleActivator(LogicalKeyboardKey.keyZ, meta: true):
        _cancelSyncedLyricsCreatorLine,
  };

  bool get _canUseSyncedLyricsCreatorShortcuts {
    return _isSyncedLyricsCreatorVisible && !_isSaving && !_isLoading;
  }

  void _seekSyncedLyricsCreatorBack() {
    if (!_canUseSyncedLyricsCreatorShortcuts) {
      return;
    }
    _syncedLyricsCreatorKey.currentState?._seekBackFromShortcut();
  }

  void _seekSyncedLyricsCreatorForward() {
    if (!_canUseSyncedLyricsCreatorShortcuts) {
      return;
    }
    _syncedLyricsCreatorKey.currentState?._seekForwardFromShortcut();
  }

  void _toggleSyncedLyricsCreatorPlayback() {
    if (!_canUseSyncedLyricsCreatorShortcuts) {
      return;
    }
    _syncedLyricsCreatorKey.currentState?._playPauseFromShortcut();
  }

  void _submitSyncedLyricsCreatorLine() {
    if (!_canUseSyncedLyricsCreatorShortcuts) {
      return;
    }
    _syncedLyricsCreatorKey.currentState?._submitNextLine();
  }

  void _cancelSyncedLyricsCreatorLine() {
    if (!_canUseSyncedLyricsCreatorShortcuts) {
      return;
    }
    _syncedLyricsCreatorKey.currentState?._cancelLastLine();
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
    _lyricsSearchCandidates = null;
    _selectedLyricsSearchCandidateIndex = 0;
    _lyricsSearchError = null;

    if (lyrics == null) {
      _hasLyrics = false;
      _hasPersistedLyrics = false;
      _lyricsType = TrackLyricsType.plain;
      _lyricsLanguageCodeController.clear();
      _lyricsSourceController.clear();
      _lyricsIsVerified = false;
      _isSyncedLyricsCreatorVisible = false;
      return;
    }

    _hasLyrics = true;
    _hasPersistedLyrics = true;
    _lyricsType = lyrics.type;
    _lyricsLanguageCodeController.text = lyrics.languageCode;
    _lyricsSourceController.text = lyrics.source;
    _lyricsPlainTextController.text = lyrics.plainText ?? '';
    _lyricsIsVerified = lyrics.isVerified;
    _isSyncedLyricsCreatorVisible = false;
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
      _isSyncedLyricsCreatorVisible = false;
      if (type == TrackLyricsType.synced && _lyricsLines.isEmpty) {
        _lyricsLines.add(_createLyricsLine());
      }
    });
  }

  void _startSyncedLyricsCreator() {
    setState(() {
      _hasLyrics = true;
      _lyricsType = TrackLyricsType.synced;
      _lyricsPlainTextController.clear();
      _removeEmptySyncedLyricsPlaceholder();
      _isSyncedLyricsCreatorVisible = true;
    });
  }

  Future<void> _searchLyrics() async {
    final title = _titleController.text.trim();
    final artistNames = _selectedAuthors
        .map((author) => author.currentName.trim())
        .where((name) => name.isNotEmpty)
        .toList();
    if (title.isEmpty) {
      _showMessage('Track title is required to search for lyrics.');
      return;
    }
    if (artistNames.isEmpty) {
      _showMessage('Select at least one artist before searching for lyrics.');
      return;
    }

    setState(() {
      _isSearchingLyrics = true;
      _lyricsSearchCandidates = null;
      _selectedLyricsSearchCandidateIndex = 0;
      _lyricsSearchError = null;
    });

    try {
      final candidates = await context.read<LyricsSearchRepository>().search(
        trackId: widget.trackId,
        trackName: title,
        artistNames: artistNames,
        albumName: _selectedAlbum?.title ?? '',
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _isSearchingLyrics = false;
        _lyricsSearchCandidates = candidates;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSearchingLyrics = false;
        _lyricsSearchError = _describeError(error);
      });
    }
  }

  void _showPreviousLyricsSearchCandidate() {
    if (_selectedLyricsSearchCandidateIndex <= 0) {
      return;
    }
    setState(() {
      _selectedLyricsSearchCandidateIndex -= 1;
    });
  }

  void _showNextLyricsSearchCandidate() {
    final candidates = _lyricsSearchCandidates;
    if (candidates == null ||
        _selectedLyricsSearchCandidateIndex >= candidates.length - 1) {
      return;
    }
    setState(() {
      _selectedLyricsSearchCandidateIndex += 1;
    });
  }

  Future<void> _applyPlainLyricsSearchCandidate(
    LyricsSearchCandidate candidate,
  ) async {
    final plainText = candidate.plainText?.trim() ?? '';
    if (plainText.isEmpty || !await _confirmLyricsDraftReplacement()) {
      return;
    }
    setState(() {
      _hasLyrics = true;
      _lyricsType = TrackLyricsType.plain;
      _isSyncedLyricsCreatorVisible = false;
      _lyricsPlainTextController.text = plainText;
      _lyricsLines.clear();
      _applyLyricsSearchCandidateMetadata(candidate);
    });
    _showMessage('Plain lyrics applied to the draft.');
  }

  Future<void> _applySyncedLyricsSearchCandidate(
    LyricsSearchCandidate candidate,
  ) async {
    if (candidate.syncedLines.isEmpty ||
        !await _confirmLyricsDraftReplacement()) {
      return;
    }
    setState(() {
      _hasLyrics = true;
      _lyricsType = TrackLyricsType.synced;
      _isSyncedLyricsCreatorVisible = false;
      _lyricsPlainTextController.clear();
      _lyricsLines
        ..clear()
        ..addAll(
          candidate.syncedLines.map(
            (line) => _EditableLyricsLine(
              id: _nextLyricsLineId++,
              startMs: '${line.startMs}',
              endMs: line.endMs?.toString() ?? '',
              text: line.text,
            ),
          ),
        );
      _applyLyricsSearchCandidateMetadata(candidate);
    });
    _showMessage('Synced lyrics applied to the draft.');
  }

  Future<void> _synchronizeLyricsSearchCandidate(
    LyricsSearchCandidate candidate,
  ) async {
    final plainText = candidate.plainText?.trim() ?? '';
    if (plainText.isEmpty || !await _confirmLyricsDraftReplacement()) {
      return;
    }
    setState(() {
      _hasLyrics = true;
      _lyricsType = TrackLyricsType.synced;
      _lyricsPlainTextController.clear();
      _lyricsLines.clear();
      _isSyncedLyricsCreatorVisible = true;
      _applyLyricsSearchCandidateMetadata(candidate);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncedLyricsCreatorKey.currentState?._replacePlainText(plainText);
    });
  }

  void _applyLyricsSearchCandidateMetadata(LyricsSearchCandidate candidate) {
    _lyricsSourceController.text = candidate.source.trim().isEmpty
        ? '${candidate.provider} #${candidate.providerId}'
        : candidate.source;
    _lyricsLanguageCodeController.clear();
    _lyricsIsVerified = false;
  }

  Future<bool> _confirmLyricsDraftReplacement() async {
    if (!_hasMeaningfulLyricsDraft) {
      return true;
    }
    final shouldReplace = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Replace current lyrics?'),
        content: const Text(
          'Applying this search result replaces the current lyrics draft. The change is not saved until you save the track.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Replace'),
          ),
        ],
      ),
    );
    return shouldReplace == true && mounted;
  }

  bool get _hasMeaningfulLyricsDraft {
    if (_hasPersistedLyrics ||
        _lyricsPlainTextController.text.trim().isNotEmpty) {
      return true;
    }
    return _lyricsLines.any(
      (line) =>
          line.text.trim().isNotEmpty ||
          line.startMs.trim() != '0' ||
          line.endMs.trim().isNotEmpty,
    );
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
    _isSyncedLyricsCreatorVisible = false;
  }

  ({TrackLyrics? lyrics, List<String> errors}) _buildLyricsPayload() {
    if (!_hasLyrics) {
      return (lyrics: null, errors: const <String>[]);
    }

    final errors = <String>[];
    final lines = <TrackLyricsLine>[];
    if (_lyricsType == TrackLyricsType.synced) {
      final parsedStartMs = <int?>[];
      for (var index = 0; index < _lyricsLines.length; index++) {
        final line = _lyricsLines[index];
        final lineNumber = index + 1;
        final startMs = int.tryParse(line.startMs.trim());
        parsedStartMs.add(startMs);
        if (startMs == null) {
          errors.add('Line $lineNumber start time must be a valid integer.');
        }
      }

      for (var index = 0; index < _lyricsLines.length; index++) {
        final line = _lyricsLines[index];
        final lineNumber = index + 1;
        final startMs = parsedStartMs[index];
        if (startMs == null) {
          continue;
        }

        final trimmedEndMs = line.endMs.trim();
        final nextStartMs = index + 1 < parsedStartMs.length
            ? parsedStartMs[index + 1]
            : null;
        final endMs = trimmedEndMs.isEmpty
            ? nextStartMs
            : int.tryParse(trimmedEndMs);
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
        _isSyncedLyricsCreatorVisible = false;
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
        _isSyncedLyricsCreatorVisible = false;
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

  void _addCreatedLyricsLine({required int startMs, required String text}) {
    setState(() {
      _lyricsLines.add(
        _EditableLyricsLine(
          id: _nextLyricsLineId++,
          startMs: '$startMs',
          endMs: '',
          text: text,
        ),
      );
    });
  }

  ({int seekMs, String text})? _cancelCreatedLyricsLine() {
    if (_lyricsLines.isEmpty) {
      return null;
    }

    late final _EditableLyricsLine canceledLine;
    late final int seekMs;
    setState(() {
      canceledLine = _lyricsLines.removeLast();
      seekMs = _lyricsLines.isEmpty
          ? 0
          : (_lyricsLines.last.parsedStartMs ?? 0).clamp(0, 1 << 31);
    });

    return (seekMs: seekMs, text: canceledLine.text);
  }

  void _removeEmptySyncedLyricsPlaceholder() {
    if (_lyricsLines.length != 1) {
      return;
    }
    final line = _lyricsLines.single;
    if (line.startMs.trim() == '0' &&
        line.endMs.trim().isEmpty &&
        line.text.trim().isEmpty) {
      _lyricsLines.clear();
    }
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
    required this.onStartSyncedLyricsCreator,
    required this.onLyricsTypeChanged,
    required this.onLyricsVerifiedChanged,
    required this.onLyricsLineChanged,
    required this.onLyricsLineMoveUp,
    required this.onLyricsLineMoveDown,
    required this.onLyricsLineDelete,
    required this.onAddLyricsLine,
    required this.isSyncedLyricsCreatorVisible,
    required this.syncedLyricsCreatorKey,
    required this.trackFile,
    required this.onCreatedLyricsLineSubmitted,
    required this.onCreatedLyricsLineCanceled,
    required this.onDeleteLyrics,
    required this.isSearchingLyrics,
    required this.lyricsSearchCandidates,
    required this.selectedLyricsSearchCandidateIndex,
    required this.lyricsSearchError,
    required this.lyricsSearchAudioController,
    required this.onSearchLyrics,
    required this.onPreviousLyricsSearchCandidate,
    required this.onNextLyricsSearchCandidate,
    required this.onApplyPlainLyricsSearchCandidate,
    required this.onSynchronizeLyricsSearchCandidate,
    required this.onApplySyncedLyricsSearchCandidate,
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
  final VoidCallback onStartSyncedLyricsCreator;
  final ValueChanged<TrackLyricsType> onLyricsTypeChanged;
  final ValueChanged<bool> onLyricsVerifiedChanged;
  final void Function(int index, _EditableLyricsLine updatedLine)
  onLyricsLineChanged;
  final ValueChanged<int> onLyricsLineMoveUp;
  final ValueChanged<int> onLyricsLineMoveDown;
  final ValueChanged<int> onLyricsLineDelete;
  final VoidCallback onAddLyricsLine;
  final bool isSyncedLyricsCreatorVisible;
  final GlobalKey<_SyncedLyricsCreatorState> syncedLyricsCreatorKey;
  final Object? trackFile;
  final void Function({required int startMs, required String text})
  onCreatedLyricsLineSubmitted;
  final ({int seekMs, String text})? Function() onCreatedLyricsLineCanceled;
  final Future<void> Function() onDeleteLyrics;
  final bool isSearchingLyrics;
  final List<LyricsSearchCandidate>? lyricsSearchCandidates;
  final int selectedLyricsSearchCandidateIndex;
  final String? lyricsSearchError;
  final _TrackMiniPlayerController lyricsSearchAudioController;
  final Future<void> Function() onSearchLyrics;
  final VoidCallback onPreviousLyricsSearchCandidate;
  final VoidCallback onNextLyricsSearchCandidate;
  final ValueChanged<LyricsSearchCandidate> onApplyPlainLyricsSearchCandidate;
  final ValueChanged<LyricsSearchCandidate> onSynchronizeLyricsSearchCandidate;
  final ValueChanged<LyricsSearchCandidate> onApplySyncedLyricsSearchCandidate;

  @override
  Widget build(BuildContext context) {
    if (!hasLyrics) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LyricsEmptyState(
            isDisabled: isLoading || isSaving || isSearchingLyrics,
            onStartPlainLyrics: onStartPlainLyrics,
            onStartSyncedLyrics: onStartSyncedLyrics,
            onImportPlainLyrics: onImportPlainLyrics,
            onImportSyncedLyrics: onImportSyncedLyrics,
            onStartSyncedLyricsCreator: onStartSyncedLyricsCreator,
            onSearchLyrics: onSearchLyrics,
          ),
          _LyricsSearchBlock(
            isSearching: isSearchingLyrics,
            candidates: lyricsSearchCandidates,
            selectedIndex: selectedLyricsSearchCandidateIndex,
            errorMessage: lyricsSearchError,
            audioController: lyricsSearchAudioController,
            trackFile: trackFile,
            isDisabled: isSaving,
            showMiniPlayer: true,
            onRetry: onSearchLyrics,
            onPrevious: onPreviousLyricsSearchCandidate,
            onNext: onNextLyricsSearchCandidate,
            onApplyPlain: onApplyPlainLyricsSearchCandidate,
            onSynchronize: onSynchronizeLyricsSearchCandidate,
            onApplySynced: onApplySyncedLyricsSearchCandidate,
          ),
        ],
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
        else if (isSyncedLyricsCreatorVisible)
          _SyncedLyricsCreator(
            key: syncedLyricsCreatorKey,
            lyricsLines: lyricsLines,
            isSaving: isSaving,
            trackFile: trackFile,
            onSubmitLine: onCreatedLyricsLineSubmitted,
            onCancelLastLine: onCreatedLyricsLineCanceled,
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
            if (lyricsType == TrackLyricsType.synced)
              FilledButton.tonalIcon(
                onPressed: isSaving || isSearchingLyrics
                    ? null
                    : onStartSyncedLyricsCreator,
                icon: const Icon(Icons.playlist_play),
                label: const Text('Create synced lyrics'),
              ),
            FilledButton.tonalIcon(
              onPressed: isSaving || isSearchingLyrics ? null : onSearchLyrics,
              icon: const Icon(Icons.search),
              label: const Text('Search lyrics'),
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
        _LyricsSearchBlock(
          isSearching: isSearchingLyrics,
          candidates: lyricsSearchCandidates,
          selectedIndex: selectedLyricsSearchCandidateIndex,
          errorMessage: lyricsSearchError,
          audioController: lyricsSearchAudioController,
          trackFile: trackFile,
          isDisabled: isSaving,
          showMiniPlayer: !isSyncedLyricsCreatorVisible,
          onRetry: onSearchLyrics,
          onPrevious: onPreviousLyricsSearchCandidate,
          onNext: onNextLyricsSearchCandidate,
          onApplyPlain: onApplyPlainLyricsSearchCandidate,
          onSynchronize: onSynchronizeLyricsSearchCandidate,
          onApplySynced: onApplySyncedLyricsSearchCandidate,
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
    required this.onStartSyncedLyricsCreator,
    required this.onSearchLyrics,
  });

  final bool isDisabled;
  final VoidCallback onStartPlainLyrics;
  final VoidCallback onStartSyncedLyrics;
  final Future<void> Function() onImportPlainLyrics;
  final Future<void> Function() onImportSyncedLyrics;
  final VoidCallback onStartSyncedLyricsCreator;
  final Future<void> Function() onSearchLyrics;

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
            FilledButton.tonalIcon(
              onPressed: isDisabled ? null : onStartSyncedLyricsCreator,
              icon: const Icon(Icons.playlist_play),
              label: const Text('Create synced lyrics'),
            ),
            FilledButton.tonalIcon(
              onPressed: isDisabled ? null : onSearchLyrics,
              icon: const Icon(Icons.search),
              label: const Text('Search lyrics'),
            ),
          ],
        ),
      ],
    );
  }
}

class _LyricsSearchBlock extends StatelessWidget {
  const _LyricsSearchBlock({
    required this.isSearching,
    required this.candidates,
    required this.selectedIndex,
    required this.errorMessage,
    required this.audioController,
    required this.trackFile,
    required this.isDisabled,
    required this.showMiniPlayer,
    required this.onRetry,
    required this.onPrevious,
    required this.onNext,
    required this.onApplyPlain,
    required this.onSynchronize,
    required this.onApplySynced,
  });

  final bool isSearching;
  final List<LyricsSearchCandidate>? candidates;
  final int selectedIndex;
  final String? errorMessage;
  final _TrackMiniPlayerController audioController;
  final Object? trackFile;
  final bool isDisabled;
  final bool showMiniPlayer;
  final Future<void> Function() onRetry;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<LyricsSearchCandidate> onApplyPlain;
  final ValueChanged<LyricsSearchCandidate> onSynchronize;
  final ValueChanged<LyricsSearchCandidate> onApplySynced;

  @override
  Widget build(BuildContext context) {
    if (!isSearching && candidates == null && errorMessage == null) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Material(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          child: _buildContent(context),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (isSearching) {
      return const Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Searching LRCLIB…'),
                SizedBox(height: 2),
                Text('Looking for the best matching lyrics.'),
              ],
            ),
          ),
        ],
      );
    }

    if (errorMessage != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Could not search LRCLIB',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          Text(errorMessage!),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      );
    }

    final items = candidates ?? const <LyricsSearchCandidate>[];
    if (items.isEmpty) {
      return const Text('No lyrics found');
    }

    final safeIndex = selectedIndex.clamp(0, items.length - 1);
    final candidate = items[safeIndex];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (items.length > 1) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  'Select the correct lyrics',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Text('${safeIndex + 1} of ${items.length}'),
            ],
          ),
          const SizedBox(height: 12),
        ],
        if (showMiniPlayer) ...[
          _TrackMiniPlayer(
            key: const ValueKey('lyrics-search-mini-player'),
            controller: audioController,
            trackFile: trackFile,
            isDisabled: isDisabled,
          ),
          const SizedBox(height: 12),
        ],
        if (items.length > 1)
          Row(
            children: [
              IconButton.filledTonal(
                onPressed: safeIndex == 0 ? null : onPrevious,
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Previous lyrics',
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _candidateTitle(candidate),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: safeIndex == items.length - 1 ? null : onNext,
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Next lyrics',
              ),
            ],
          )
        else
          Text(
            _candidateTitle(candidate),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        const SizedBox(height: 6),
        Text(
          _candidateDetails(candidate),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Text(
          _resultLabel(candidate),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 12),
        _LyricsCandidatePreview(
          candidate: candidate,
          positionMs: audioController.positionListenable,
        ),
        if (candidate.hasSyncedLyrics) ...[
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => onApplySynced(candidate),
            icon: const Icon(Icons.check),
            label: const Text('Apply synced lyrics'),
          ),
        ] else if (candidate.hasPlainLyrics) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: () => onApplyPlain(candidate),
                icon: const Icon(Icons.check),
                label: const Text('Apply as plain lyrics'),
              ),
              OutlinedButton.icon(
                onPressed: () => onSynchronize(candidate),
                icon: const Icon(Icons.playlist_play),
                label: const Text('Synchronize manually'),
              ),
            ],
          ),
        ],
      ],
    );
  }

  String _candidateTitle(LyricsSearchCandidate candidate) {
    final artist = candidate.artistName.trim();
    return artist.isEmpty
        ? candidate.trackName
        : '${candidate.trackName} — $artist';
  }

  String _candidateDetails(LyricsSearchCandidate candidate) {
    final details = <String>[];
    if (candidate.albumName.trim().isNotEmpty) {
      details.add(candidate.albumName.trim());
    }
    if (candidate.durationMs > 0) {
      details.add(_formatSearchDuration(candidate.durationMs));
    }
    details.add(candidate.source);
    return details.join(' • ');
  }

  String _resultLabel(LyricsSearchCandidate candidate) {
    if (candidate.hasSyncedLyrics) {
      return 'Synced lyrics found';
    }
    if (candidate.hasPlainLyrics) {
      return 'Plain lyrics found';
    }
    if (candidate.instrumental) {
      return 'LRCLIB marks this track as instrumental';
    }
    return 'No lyrics found in this result';
  }

  String _formatSearchDuration(int durationMs) {
    final duration = Duration(milliseconds: durationMs);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _LyricsCandidatePreview extends StatelessWidget {
  const _LyricsCandidatePreview({
    required this.candidate,
    required this.positionMs,
  });

  final LyricsSearchCandidate candidate;
  final ValueListenable<int> positionMs;

  @override
  Widget build(BuildContext context) {
    if (candidate.hasSyncedLyrics) {
      return ValueListenableBuilder<int>(
        valueListenable: positionMs,
        builder: (context, currentPositionMs, _) {
          final activeIndex = _activeLineIndex(currentPositionMs);
          return ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 500),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: candidate.syncedLines.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final line = candidate.syncedLines[index];
                final isHighlighted = index == activeIndex;
                return _LyricsPreviewLine(
                  key: isHighlighted
                      ? ValueKey('current-lyrics-line-$index')
                      : ValueKey('lyrics-line-$index'),
                  startMs: line.startMs,
                  text: line.text,
                  isHighlighted: isHighlighted,
                );
              },
            ),
          );
        },
      );
    }
    if (candidate.hasPlainLyrics) {
      return Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxHeight: 500),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: SingleChildScrollView(
          child: SelectionArea(child: Text(candidate.plainText!.trim())),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  int _activeLineIndex(int positionMs) {
    for (var index = 0; index < candidate.syncedLines.length; index++) {
      final line = candidate.syncedLines[index];
      final nextLine = index + 1 < candidate.syncedLines.length
          ? candidate.syncedLines[index + 1]
          : null;
      final endMs = line.endMs ?? nextLine?.startMs;
      if (positionMs >= line.startMs && (endMs == null || positionMs < endMs)) {
        return index;
      }
    }
    return -1;
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

class _SyncedLyricsCreator extends StatefulWidget {
  const _SyncedLyricsCreator({
    super.key,
    required this.lyricsLines,
    required this.isSaving,
    required this.trackFile,
    required this.onSubmitLine,
    required this.onCancelLastLine,
  });

  final List<_EditableLyricsLine> lyricsLines;
  final bool isSaving;
  final Object? trackFile;
  final void Function({required int startMs, required String text})
  onSubmitLine;
  final ({int seekMs, String text})? Function() onCancelLastLine;

  @override
  State<_SyncedLyricsCreator> createState() => _SyncedLyricsCreatorState();
}

class _SyncedLyricsCreatorState extends State<_SyncedLyricsCreator> {
  final _audioController = _TrackMiniPlayerController();
  final TextEditingController _plainTextController = TextEditingController();
  final FocusNode _panelFocusNode = FocusNode();
  final FocusNode _plainTextFocusNode = FocusNode();
  final ScrollController _submittedLinesScrollController = ScrollController();
  int _delayMs = 200;
  late int _submittedLineCount;

  static const List<int> _delayOptions = [
    0,
    100,
    200,
    300,
    500,
    750,
    1000,
    1500,
    2000,
  ];

  @override
  void initState() {
    super.initState();
    _submittedLineCount = widget.lyricsLines.length;
  }

  @override
  void didUpdateWidget(covariant _SyncedLyricsCreator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.lyricsLines.length != _submittedLineCount) {
      _submittedLineCount = widget.lyricsLines.length;
      _scrollSubmittedLinesToBottom();
    }
  }

  @override
  void dispose() {
    _audioController.dispose();
    _plainTextController.dispose();
    _panelFocusNode.dispose();
    _plainTextFocusNode.dispose();
    _submittedLinesScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: _shortcutBindings,
      child: Focus(
        focusNode: _panelFocusNode,
        autofocus: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TrackMiniPlayer(
              key: const ValueKey('synced-lyrics-creator-mini-player'),
              controller: _audioController,
              trackFile: widget.trackFile,
              isDisabled: widget.isSaving,
              trailing: SizedBox(
                width: 180,
                child: DropdownButtonFormField<int>(
                  initialValue: _delayMs,
                  decoration: const InputDecoration(
                    labelText: 'Delay',
                    border: OutlineInputBorder(),
                  ),
                  items: _delayOptions
                      .map(
                        (delay) => DropdownMenuItem<int>(
                          value: delay,
                          child: Text('$delay ms'),
                        ),
                      )
                      .toList(),
                  onChanged: widget.isSaving
                      ? null
                      : (value) {
                          if (value == null) {
                            return;
                          }
                          setState(() {
                            _delayMs = value;
                          });
                        },
                ),
              ),
            ),
            const SizedBox(height: 12),
            _SubmittedSyncedLyricsBlock(
              lines: widget.lyricsLines,
              scrollController: _submittedLinesScrollController,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: widget.isSaving || widget.lyricsLines.isEmpty
                  ? null
                  : _cancelLastLine,
              icon: const Icon(Icons.undo),
              label: const Text('Cancel last line (Ctrl/Cmd+Z)'),
            ),
            const SizedBox(height: 12),
            CallbackShortcuts(
              bindings: _shortcutBindings,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 500),
                child: TextField(
                  controller: _plainTextController,
                  focusNode: _plainTextFocusNode,
                  enabled: !widget.isSaving,
                  keyboardType: TextInputType.multiline,
                  minLines: 8,
                  maxLines: null,
                  decoration: const InputDecoration(
                    labelText: 'Plain text lyrics',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<ShortcutActivator, VoidCallback> get _shortcutBindings => {
    const SingleActivator(LogicalKeyboardKey.arrowLeft): _seekBackFromShortcut,
    const SingleActivator(LogicalKeyboardKey.space): _playPauseFromShortcut,
    const SingleActivator(LogicalKeyboardKey.arrowRight):
        _seekForwardFromShortcut,
    const SingleActivator(LogicalKeyboardKey.enter): _submitNextLine,
    const SingleActivator(LogicalKeyboardKey.keyZ, control: true):
        _cancelLastLine,
    const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): _cancelLastLine,
  };

  void _seekBackFromShortcut() {
    if (widget.isSaving) {
      return;
    }
    _audioController.seekBy(-5000);
  }

  void _seekForwardFromShortcut() {
    if (widget.isSaving) {
      return;
    }
    _audioController.seekBy(5000);
  }

  void _playPauseFromShortcut() {
    if (widget.isSaving) {
      return;
    }
    _audioController.togglePlayPause();
  }

  void _submitNextLine() {
    if (widget.isSaving) {
      return;
    }
    final remainingLines = _plainTextController.text
        .split(RegExp(r'\r\n|\n|\r'))
        .toList();
    while (remainingLines.isNotEmpty && remainingLines.first.trim().isEmpty) {
      remainingLines.removeAt(0);
    }
    if (remainingLines.isEmpty) {
      _plainTextController.clear();
      return;
    }

    final lineText = remainingLines.removeAt(0).trim();
    if (lineText.isEmpty) {
      return;
    }
    final startMs = (_audioController.positionMs - _delayMs)
        .clamp(0, 1 << 31)
        .toInt();

    widget.onSubmitLine(startMs: startMs, text: lineText);
    _plainTextController.text = remainingLines.join('\n');
    _plainTextController.selection = TextSelection.collapsed(
      offset: _plainTextController.text.length,
    );
  }

  void _cancelLastLine() {
    if (widget.isSaving) {
      return;
    }
    final canceledLine = widget.onCancelLastLine();
    if (canceledLine == null) {
      return;
    }

    final currentText = _plainTextController.text;
    _plainTextController.text = currentText.trim().isEmpty
        ? canceledLine.text
        : '${canceledLine.text}\n$currentText';
    _plainTextController.selection = TextSelection.collapsed(
      offset: _plainTextController.text.length,
    );
    _audioController.seekToMs(canceledLine.seekMs);
  }

  void _replacePlainText(String text) {
    _plainTextController.text = text;
    _plainTextController.selection = TextSelection.collapsed(
      offset: _plainTextController.text.length,
    );
    _plainTextFocusNode.requestFocus();
  }

  void _scrollSubmittedLinesToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_submittedLinesScrollController.hasClients) {
        return;
      }
      _submittedLinesScrollController.animateTo(
        _submittedLinesScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }
}

class _TrackMiniPlayerController {
  _TrackMiniPlayerState? _state;
  final ValueNotifier<int> _positionMs = ValueNotifier(0);

  int get positionMs => _positionMs.value;
  ValueListenable<int> get positionListenable => _positionMs;

  Future<void> togglePlayPause() async {
    await _state?._togglePlayPause();
  }

  Future<void> seekBy(int offsetMs) async {
    await _state?._seekBy(offsetMs);
  }

  Future<void> seekToMs(int milliseconds) async {
    await _state?._seekToMs(milliseconds);
  }

  void _attach(_TrackMiniPlayerState state) {
    _state = state;
    _updatePosition(state._position);
  }

  void _detach(_TrackMiniPlayerState state) {
    if (identical(_state, state)) {
      _state = null;
    }
  }

  void _updatePosition(Duration position) {
    final milliseconds = position.inMilliseconds;
    if (_positionMs.value != milliseconds) {
      _positionMs.value = milliseconds;
    }
  }

  void dispose() {
    _state = null;
    _positionMs.dispose();
  }
}

class _TrackMiniPlayer extends StatefulWidget {
  const _TrackMiniPlayer({
    super.key,
    this.controller,
    required this.trackFile,
    required this.isDisabled,
    this.trailing,
  });

  final _TrackMiniPlayerController? controller;
  final Object? trackFile;
  final bool isDisabled;
  final Widget? trailing;

  @override
  State<_TrackMiniPlayer> createState() => _TrackMiniPlayerState();
}

class _TrackMiniPlayerState extends State<_TrackMiniPlayer> {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isLoadingAudio = false;
  String? _loadedSourceKey;
  String? _audioErrorMessage;

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
    _positionSubscription = _player.positionStream.listen((position) {
      if (mounted) {
        widget.controller?._updatePosition(position);
        setState(() {
          _position = position;
        });
      }
    });
    _durationSubscription = _player.durationStream.listen((duration) {
      if (mounted) {
        setState(() {
          _duration = duration ?? Duration.zero;
        });
      }
    });
    _playerStateSubscription = _player.playerStateStream.listen((state) {
      if (!mounted) {
        return;
      }
      if (state.processingState == ProcessingState.completed) {
        _player.seek(Duration.zero);
        _player.pause();
      }
      setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant _TrackMiniPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.controller, oldWidget.controller)) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
    if (_sourceKeyFor(widget.trackFile) != _sourceKeyFor(oldWidget.trackFile)) {
      _resetAudio();
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasAudioSource = _sourceKeyFor(widget.trackFile) != null;
    final maxMs = _duration.inMilliseconds <= 0 ? 1 : _duration.inMilliseconds;
    final currentMs = _position.inMilliseconds.clamp(0, maxMs).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _player.playing
                          ? Icons.graphic_eq
                          : Icons.audio_file_outlined,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _sourceLabelFor(widget.trackFile),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Slider(
                  value: currentMs,
                  max: maxMs.toDouble(),
                  onChanged:
                      !widget.isDisabled &&
                          hasAudioSource &&
                          _duration > Duration.zero
                      ? (value) => _seekToMs(value.round())
                      : null,
                ),
                Row(
                  children: [
                    Text(_formatAudioDuration(_position)),
                    const Spacer(),
                    if (_isLoadingAudio)
                      Text(
                        'Loading...',
                        style: Theme.of(context).textTheme.bodySmall,
                      )
                    else if (_audioErrorMessage != null)
                      Flexible(
                        child: Text(
                          _audioErrorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colorScheme.error),
                        ),
                      ),
                    const Spacer(),
                    Text(_formatAudioDuration(_duration)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            IconButton.filledTonal(
              onPressed: widget.isDisabled ? null : () => _seekBy(-5000),
              icon: const Icon(Icons.replay_5),
              tooltip: 'Back 5 seconds',
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: widget.isDisabled || _isLoadingAudio || !hasAudioSource
                  ? null
                  : _togglePlayPause,
              icon: Icon(_player.playing ? Icons.pause : Icons.play_arrow),
              tooltip: _player.playing ? 'Pause' : 'Play',
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              onPressed: widget.isDisabled ? null : () => _seekBy(5000),
              icon: const Icon(Icons.forward_5),
              tooltip: 'Forward 5 seconds',
            ),
            if (widget.trailing != null) ...[const Spacer(), widget.trailing!],
          ],
        ),
      ],
    );
  }

  Future<void> _togglePlayPause() async {
    if (widget.isDisabled) {
      return;
    }
    if (_player.playing) {
      await _player.pause();
      return;
    }
    if (_loadedSourceKey != _sourceKeyFor(widget.trackFile)) {
      await _loadAudioSource();
      if (_loadedSourceKey == null) {
        return;
      }
    }
    await _player.play();
  }

  Future<void> _loadAudioSource() async {
    final sourceKey = _sourceKeyFor(widget.trackFile);
    if (sourceKey == null) {
      setState(() {
        _audioErrorMessage = 'Audio source is unavailable.';
      });
      return;
    }

    setState(() {
      _isLoadingAudio = true;
      _audioErrorMessage = null;
    });
    try {
      final trackFile = widget.trackFile;
      if (trackFile is StorageFile) {
        await _player.setUrl(trackFile.downloadUrl);
      } else if (trackFile is CrossFile) {
        await _player.setFilePath(trackFile.file.path);
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _loadedSourceKey = sourceKey;
        _isLoadingAudio = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadedSourceKey = null;
        _isLoadingAudio = false;
        _audioErrorMessage = 'Failed to load audio: $error';
      });
    }
  }

  Future<void> _seekBy(int offsetMs) async {
    await _seekToMs(_position.inMilliseconds + offsetMs);
  }

  Future<void> _seekToMs(int milliseconds) async {
    var clampedMs = milliseconds < 0 ? 0 : milliseconds;
    if (_duration > Duration.zero) {
      clampedMs = clampedMs.clamp(0, _duration.inMilliseconds).toInt();
    }
    final position = Duration(milliseconds: clampedMs);
    await _player.seek(position);
    if (mounted) {
      widget.controller?._updatePosition(position);
      setState(() {
        _position = position;
      });
    }
  }

  void _resetAudio() {
    _player.stop();
    widget.controller?._updatePosition(Duration.zero);
    setState(() {
      _loadedSourceKey = null;
      _audioErrorMessage = null;
      _isLoadingAudio = false;
      _position = Duration.zero;
      _duration = Duration.zero;
    });
  }

  String? _sourceKeyFor(Object? trackFile) {
    if (trackFile is StorageFile && trackFile.downloadUrl.trim().isNotEmpty) {
      return 'url:${trackFile.downloadUrl}';
    }
    if (trackFile is CrossFile && trackFile.file.path.trim().isNotEmpty) {
      return 'file:${trackFile.file.path}';
    }
    return null;
  }

  String _sourceLabelFor(Object? trackFile) {
    if (trackFile is StorageFile) {
      return trackFile.name;
    }
    if (trackFile is CrossFile) {
      return trackFile.name;
    }
    return 'No playable audio file';
  }
}

String _formatAudioDuration(Duration value) {
  final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  final milliseconds = value.inMilliseconds
      .remainder(1000)
      .toString()
      .padLeft(3, '0');
  return '$minutes:$seconds.$milliseconds';
}

class _SubmittedSyncedLyricsBlock extends StatelessWidget {
  const _SubmittedSyncedLyricsBlock({
    required this.lines,
    required this.scrollController,
  });

  final List<_EditableLyricsLine> lines;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) {
      return const _EmptyStateCard(message: 'No submitted lyric lines yet.');
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 400),
      child: ListView.separated(
        controller: scrollController,
        shrinkWrap: true,
        itemCount: lines.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final line = lines[index];
          return _LyricsPreviewLine(
            startMs: line.parsedStartMs ?? 0,
            text: line.text,
          );
        },
      ),
    );
  }
}

class _LyricsPreviewLine extends StatelessWidget {
  const _LyricsPreviewLine({
    super.key,
    required this.startMs,
    required this.text,
    this.isHighlighted = false,
  });

  final int startMs;
  final String text;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: double.infinity,
      padding: EdgeInsets.all(isHighlighted ? 8 : 0),
      decoration: BoxDecoration(
        color: isHighlighted ? colorScheme.secondaryContainer : null,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isHighlighted
                  ? colorScheme.primary
                  : colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              _formatAudioDuration(Duration(milliseconds: startMs)),
              style: TextStyle(
                color: isHighlighted
                    ? colorScheme.onPrimary
                    : colorScheme.onPrimaryContainer,
                fontWeight: isHighlighted ? FontWeight.w600 : null,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: isHighlighted ? colorScheme.onSecondaryContainer : null,
                fontWeight: isHighlighted ? FontWeight.w600 : null,
              ),
            ),
          ),
        ],
      ),
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
