import 'package:firebase_core/firebase_core.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cross_file/cross_file.dart';
import 'package:esketit_music_console/domain/author.dart';
import 'package:esketit_music_console/domain/track.dart';
import 'package:esketit_music_console/domain/track_info/text_track_info.dart';
import 'package:esketit_music_console/firebase/track/firebase_track_storage.dart';
import 'package:esketit_music_console/firebase/track/storage_file.dart';
import 'package:esketit_music_console/firebase_options.dart';
import 'package:esketit_music_console/unassigned_layer/cross_file.dart';
import 'package:esketit_music_console/use_case/track/storage/tracks_storage.dart';
import 'package:esketit_music_console/use_case/track/tracks_list/bloc/track_list_bloc.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const AppRoot());
}

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<TracksStorage>(
      create: (_) => FirebaseTrackStorage(),
      child: BlocProvider(
        create: (context) => TrackListBloc(
          const TrackListState(tracks: []),
          storage: context.read<TracksStorage>(),
        )..add(const LoadTracks()),
        child: const MainApp(),
      ),
    );
  }
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: TracksDebugPage());
  }
}

class TracksDebugPage extends StatefulWidget {
  const TracksDebugPage({super.key});

  @override
  State<TracksDebugPage> createState() => _TracksDebugPageState();
}

class _TracksDebugPageState extends State<TracksDebugPage> {
  final _nameController = TextEditingController();
  final _authorsController = TextEditingController();
  final _infoTitleController = TextEditingController();
  final _infoTextController = TextEditingController();
  CrossFile? _pickedFile;

  @override
  void dispose() {
    _nameController.dispose();
    _authorsController.dispose();
    _infoTitleController.dispose();
    _infoTextController.dispose();
    super.dispose();
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
      _pickedFile = CrossFile(file: xFile);
    });
  }

  void _addTrack() {
    if (_pickedFile == null || _nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Track name and file are required')),
      );
      return;
    }

    final authors = _authorsController.text
        .split(',')
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .map((name) => Author(currentName: name))
        .toList();

    final info = <TextTrackInfo>[];
    if (_infoTitleController.text.trim().isNotEmpty ||
        _infoTextController.text.trim().isNotEmpty) {
      info.add(
        TextTrackInfo(
          title: _infoTitleController.text.trim(),
          text: _infoTextController.text.trim(),
        ),
      );
    }

    context.read<TrackListBloc>().add(
      AddTrack(
        track: Track(
          name: _nameController.text.trim(),
          authors: authors,
          addionalInfo: info,
          file: _pickedFile!,
        ),
      ),
    );

    _nameController.clear();
    _authorsController.clear();
    _infoTitleController.clear();
    _infoTextController.clear();
    setState(() {
      _pickedFile = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tracks Firebase Test UI')),
      body: BlocBuilder<TrackListBloc, TrackListState>(
        builder: (context, state) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: 300,
                      child: TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Track name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 300,
                      child: TextField(
                        controller: _authorsController,
                        decoration: const InputDecoration(
                          labelText: 'Authors (comma separated)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 300,
                      child: TextField(
                        controller: _infoTitleController,
                        decoration: const InputDecoration(
                          labelText: 'Info title',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 300,
                      child: TextField(
                        controller: _infoTextController,
                        decoration: const InputDecoration(
                          labelText: 'Info text',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  children: [
                    FilledButton(
                      onPressed: state.isLoading ? null : _pickFile,
                      child: const Text('Pick File'),
                    ),
                    FilledButton(
                      onPressed: state.isLoading ? null : _addTrack,
                      child: const Text('Add Track'),
                    ),
                    FilledButton.tonal(
                      onPressed: state.isLoading
                          ? null
                          : () => context.read<TrackListBloc>().add(
                              const LoadTracks(),
                            ),
                      child: const Text('Reload'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _pickedFile == null
                      ? 'No file selected'
                      : 'Selected file: ${_pickedFile!.name}',
                ),
                if (state.errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    state.errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
                const SizedBox(height: 12),
                if (state.isLoading) const LinearProgressIndicator(),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    itemCount: state.tracks.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 24),
                    itemBuilder: (context, index) {
                      final track = state.tracks[index];
                      return ListTile(
                        title: Text(track.name),
                        subtitle: Text(
                          [
                            'Authors: ${track.authors.map((author) => author.currentName).join(', ')}',
                            _fileLabel(track),
                          ].join('\n'),
                        ),
                        isThreeLine: true,
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _fileLabel(Track track) {
    if (track.file is StorageFile) {
      final file = track.file as StorageFile;
      return 'File: ${file.name} (${file.downloadUrl})';
    }
    if (track.file is CrossFile) {
      final file = track.file as CrossFile;
      return 'File: ${file.name} (local)';
    }
    return 'File: unknown';
  }
}
