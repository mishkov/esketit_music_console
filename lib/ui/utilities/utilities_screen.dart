import 'dart:async';

import 'package:esketit_music_console/domain/file/media_file_info.dart';
import 'package:esketit_music_console/use_case/track/storage/tracks_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';

class UtilitiesScreen extends StatefulWidget {
  const UtilitiesScreen({super.key});

  @override
  State<UtilitiesScreen> createState() => _UtilitiesScreenState();
}

class _UtilitiesScreenState extends State<UtilitiesScreen> {
  final AudioPlayer _player = AudioPlayer();

  List<MediaFileInfo> _unusedSongs = const [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _loadingSongUrl;
  String? _currentSongUrl;
  String? _deletingSongPath;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<PlayerState>? _playerStateSubscription;

  @override
  void initState() {
    super.initState();
    _positionSubscription = _player.positionStream.listen((position) {
      if (!mounted) {
        return;
      }
      setState(() {
        _position = position;
      });
    });
    _durationSubscription = _player.durationStream.listen((duration) {
      if (!mounted) {
        return;
      }
      setState(() {
        _duration = duration ?? Duration.zero;
      });
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
    _loadUnusedSongs();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    setState(() {
      
    });
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Utilities',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const Spacer(),
              IconButton(
                onPressed: _isLoading ? null : _loadUnusedSongs,
                tooltip: 'Reload unused songs',
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Unused MP3 files',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'These files exist in `/songs` and are not referenced by any track.',
            style: Theme.of(context).textTheme.bodyMedium,
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
          Expanded(
            child: _unusedSongs.isEmpty && !_isLoading
                ? const Center(child: Text('No unused MP3 files found.'))
                : ListView.separated(
                    itemCount: _unusedSongs.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final file = _unusedSongs[index];
                      final isCurrent = _currentSongUrl == file.url;
                      final isLoadingCurrent = _loadingSongUrl == file.url;
                      final isDeleting = _deletingSongPath == file.path;

                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      file.name,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  FilledButton.tonalIcon(
                                    onPressed: isDeleting
                                        ? null
                                        : () => _togglePlayback(file),
                                    icon: Icon(
                                      _playbackIcon(
                                        isCurrent: isCurrent,
                                        isLoadingCurrent: isLoadingCurrent,
                                      ),
                                    ),
                                    label: Text(
                                      _playbackLabel(
                                        isCurrent: isCurrent,
                                        isLoadingCurrent: isLoadingCurrent,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  FilledButton.icon(
                                    onPressed: isDeleting
                                        ? null
                                        : () => _deleteSong(file),
                                    icon: isDeleting
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.delete_outline),
                                    label: const Text('Delete'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              SelectableText(
                                [
                                  'Path: ${file.path}',
                                  'URL: ${file.url}',
                                  'Size: ${_formatBytes(file.sizeBytes)}',
                                  'Modified: ${_formatDateTime(file.lastModified)}',
                                ].join('\n'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),
          _PlayerPanel(
            currentSong: _currentSong,
            isBuffering: _loadingSongUrl != null,
            isPlaying: _player.playing,
            position: _position,
            duration: _duration,
            onSeek: _seekTo,
            onPlayPause: _toggleCurrentPlayback,
            onStop: _stopPlayback,
          ),
        ],
      ),
    );
  }

  MediaFileInfo? get _currentSong {
    final url = _currentSongUrl;
    if (url == null) {
      return null;
    }
    for (final song in _unusedSongs) {
      if (song.url == url) {
        return song;
      }
    }
    return null;
  }

  Future<void> _loadUnusedSongs() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final files = await context.read<TracksStorage>().getUnusedSongs();
      if (!mounted) {
        return;
      }
      setState(() {
        _unusedSongs = files;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load unused MP3 files: $error';
      });
    }
  }

  Future<void> _togglePlayback(MediaFileInfo file) async {
    if (_currentSongUrl == file.url) {
      await _toggleCurrentPlayback();
      return;
    }

    setState(() {
      _loadingSongUrl = file.url;
      _errorMessage = null;
    });

    try {
      await _player.setUrl(file.url);
      await _player.play();
      if (!mounted) {
        return;
      }
      setState(() {
        _currentSongUrl = file.url;
        _loadingSongUrl = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingSongUrl = null;
        _errorMessage = 'Failed to play ${file.name}: $error';
      });
    }
  }

  Future<void> _toggleCurrentPlayback() async {
    if (_currentSongUrl == null) {
      return;
    }
    if (_player.playing) {
      await _player.pause();
      return;
    }
    await _player.play();
  }

  Future<void> _stopPlayback() async {
    await _player.stop();
    if (!mounted) {
      return;
    }
    setState(() {
      _currentSongUrl = null;
      _loadingSongUrl = null;
      _position = Duration.zero;
      _duration = Duration.zero;
    });
  }

  Future<void> _deleteSong(MediaFileInfo file) async {
    final storage = context.read<TracksStorage>();
    setState(() {
      _deletingSongPath = file.path;
      _errorMessage = null;
    });

    final wasCurrent = _currentSongUrl == file.url;
    try {
      if (wasCurrent) {
        await _stopPlayback();
      }

      await storage.deleteSongFile(file.path);
      if (!mounted) {
        return;
      }
      setState(() {
        _unusedSongs = _unusedSongs
            .where((song) => song.path != file.path)
            .toList(growable: false);
        _deletingSongPath = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _deletingSongPath = null;
        _errorMessage = 'Failed to delete ${file.name}: $error';
      });
    }
  }

  Future<void> _seekTo(double seconds) async {
    final clamped = seconds.clamp(0, _duration.inMilliseconds / 1000);
    await _player.seek(Duration(milliseconds: (clamped * 1000).round()));
  }

  IconData _playbackIcon({
    required bool isCurrent,
    required bool isLoadingCurrent,
  }) {
    if (isLoadingCurrent) {
      return Icons.hourglass_top;
    }
    if (isCurrent && _player.playing) {
      return Icons.pause;
    }
    return Icons.play_arrow;
  }

  String _playbackLabel({
    required bool isCurrent,
    required bool isLoadingCurrent,
  }) {
    if (isLoadingCurrent) {
      return 'Loading';
    }
    if (isCurrent && _player.playing) {
      return 'Pause';
    }
    if (isCurrent) {
      return 'Resume';
    }
    return 'Play';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    final kib = bytes / 1024;
    if (kib < 1024) {
      return '${kib.toStringAsFixed(1)} KB';
    }
    final mib = kib / 1024;
    if (mib < 1024) {
      return '${mib.toStringAsFixed(1)} MB';
    }
    final gib = mib / 1024;
    return '${gib.toStringAsFixed(1)} GB';
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    final twoDigitMonth = local.month.toString().padLeft(2, '0');
    final twoDigitDay = local.day.toString().padLeft(2, '0');
    final twoDigitHour = local.hour.toString().padLeft(2, '0');
    final twoDigitMinute = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$twoDigitMonth-$twoDigitDay $twoDigitHour:$twoDigitMinute';
  }
}

class _PlayerPanel extends StatelessWidget {
  const _PlayerPanel({
    required this.currentSong,
    required this.isBuffering,
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.onSeek,
    required this.onPlayPause,
    required this.onStop,
  });

  final MediaFileInfo? currentSong;
  final bool isBuffering;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final ValueChanged<double> onSeek;
  final Future<void> Function() onPlayPause;
  final Future<void> Function() onStop;

  @override
  Widget build(BuildContext context) {
    final hasSong = currentSong != null;
    final maxSeconds = duration.inMilliseconds <= 0
        ? 1.0
        : duration.inMilliseconds / 1000;
    final currentSeconds = position.inMilliseconds <= 0
        ? 0.0
        : position.inMilliseconds / 1000;

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(isPlaying ? Icons.graphic_eq : Icons.audio_file_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    currentSong?.name ?? 'No file selected',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  onPressed: hasSong && !isBuffering
                      ? () => onPlayPause()
                      : null,
                  icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                  tooltip: isPlaying ? 'Pause' : 'Play',
                ),
                IconButton(
                  onPressed: hasSong ? () => onStop() : null,
                  icon: const Icon(Icons.stop),
                  tooltip: 'Stop',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Slider(
              value: currentSeconds.clamp(0, maxSeconds),
              max: maxSeconds,
              onChanged: hasSong && duration > Duration.zero ? onSeek : null,
            ),
            Row(
              children: [
                Text(_formatDuration(position)),
                const Spacer(),
                if (isBuffering)
                  Text(
                    'Buffering...',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                const Spacer(),
                Text(_formatDuration(duration)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDuration(Duration value) {
    final totalSeconds = value.inSeconds;
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
