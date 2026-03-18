import 'package:esketit_music_console/esketit_rest_api/auth/authenticated_http_client_proxy.dart';
import 'package:esketit_music_console/esketit_rest_api/auth/esketit_rest_api_auth_repository.dart';
import 'package:esketit_music_console/esketit_rest_api/track/esketit_rest_api_tracks_storage.dart';
import 'package:esketit_music_console/firebase/track/storage_file.dart';
import 'package:esketit_music_console/ui/auth/sign_in_screen.dart';
import 'package:esketit_music_console/ui/author/authors_list_screen.dart';
import 'package:esketit_music_console/ui/track/add_tracks_screen.dart';
import 'package:esketit_music_console/unassigned_layer/cross_file.dart';
import 'package:esketit_music_console/unassigned_layer/http_package_http_client.dart';
import 'package:esketit_music_console/unassigned_layer/shared_preferences_auth_session_storage.dart';
import 'package:esketit_music_console/use_case/auth/bloc/auth_bloc.dart';
import 'package:esketit_music_console/use_case/track/storage/tracks_storage.dart';
import 'package:esketit_music_console/use_case/track/tracks_list/bloc/track_list_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AppRoot());
}

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    final baseUri = Uri.parse(
      const String.fromEnvironment(
        'ESKETIT_API_BASE_URL',
        defaultValue: 'http://localhost:8080',
      ),
    );
    final unauthenticatedHttpClient = HttpPackageHttpClient(baseUri: baseUri);
    late final EsketitRestApiAuthRepository authRepository;
    final authenticatedHttpClient = AuthenticatedHttpClientProxy(
      httpClient: unauthenticatedHttpClient,
      refreshSession: ({forceRefresh = false}) =>
          authRepository.refreshSession(forceRefresh: forceRefresh),
    );
    authRepository = EsketitRestApiAuthRepository(
      unauthenticatedHttpClient: unauthenticatedHttpClient,
      authenticatedHttpClient: authenticatedHttpClient,
      sessionStorage: SharedPreferencesAuthSessionStorage(),
    );

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<TracksStorage>(
          create: (_) => EsketitRestApiTracksStorage(
            authenticatedHttpClient: authenticatedHttpClient,
            baseUri: baseUri,
          ),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) =>
                AuthBloc(authRepository: authRepository)
                  ..add(const AuthSessionRestoreRequested()),
          ),
          BlocProvider(
            create: (context) => TrackListBloc(
              const TrackListState(tracks: []),
              storage: context.read<TracksStorage>(),
            ),
          ),
        ],
        child: const MainApp(),
      ),
    );
  }
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Esketit Music',
      theme: ThemeData(colorSchemeSeed: Colors.green, useMaterial3: true),
      home: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          switch (state.status) {
            case AuthStatus.restoring:
              return const _RestoringSessionScreen();
            case AuthStatus.unauthenticated:
              return const SignInScreen();
            case AuthStatus.authenticated:
              return const MainShell();
          }
        },
      ),
    );
  }
}

class _RestoringSessionScreen extends StatelessWidget {
  const _RestoringSessionScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Restoring session...'),
          ],
        ),
      ),
    );
  }
}

enum _MainDestination { tracks, authors }

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  _MainDestination _destination = _MainDestination.tracks;

  @override
  void initState() {
    super.initState();
    context.read<TrackListBloc>().add(const LoadTracks());
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthBloc bloc) => bloc.state.session?.user);

    return Scaffold(
      appBar: AppBar(
        title: Text('Esketit Music'),
        actions: [
          if (user != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(child: Text(user.email)),
            ),
          TextButton(
            onPressed: () =>
                context.read<AuthBloc>().add(const AuthSignOutRequested()),
            child: const Text('Sign out'),
          ),
        ],
      ),
      floatingActionButton: _destination == _MainDestination.tracks
          ? FloatingActionButton.extended(
              onPressed: _openAddTrackScreen,
              icon: const Icon(Icons.library_add),
              label: const Text('Add track'),
            )
          : null,
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _destination.index,
            onDestinationSelected: (index) {
              setState(() {
                _destination = _MainDestination.values[index];
              });
            },
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.music_note_outlined),
                selectedIcon: Icon(Icons.music_note),
                label: Text('Tracks'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people),
                label: Text('Authors'),
              ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: switch (_destination) {
                _MainDestination.tracks => const TracksSection(
                  key: ValueKey('tracks'),
                ),
                _MainDestination.authors => const AuthorsListScreen(
                  key: ValueKey('authors'),
                ),
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openAddTrackScreen() async {
    final didSave = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const AddTracksScreen()));

    if (didSave == true && mounted) {
      context.read<TrackListBloc>().add(const LoadTracks());
    }
  }
}

class TracksSection extends StatelessWidget {
  const TracksSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TrackListBloc, TrackListState>(
      builder: (context, state) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Tracks',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () =>
                        context.read<TrackListBloc>().add(const LoadTracks()),
                    tooltip: 'Reload tracks',
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (state.errorMessage != null) ...[
                Text(
                  state.errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 12),
              ],
              if (state.isLoading) const LinearProgressIndicator(),
              const SizedBox(height: 12),
              Expanded(
                child: state.tracks.isEmpty && !state.isLoading
                    ? const Center(
                        child: Text(
                          'No tracks yet. Use "Add track" to create one.',
                        ),
                      )
                    : ListView.separated(
                        itemCount: state.tracks.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 24),
                        itemBuilder: (context, index) {
                          final track = state.tracks[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            title: Text(track.name),
                            subtitle: Text(
                              [
                                'Authors: ${track.authors.map((author) => author.currentName).join(', ')}',
                                _fileLabel(track.file),
                              ].join('\n'),
                            ),
                            isThreeLine: true,
                            tileColor: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerLowest,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _fileLabel(Object file) {
    if (file is StorageFile) {
      return 'File: ${file.name} (${file.downloadUrl})';
    }
    if (file is CrossFile) {
      return 'File: ${file.name} (local)';
    }
    return 'File: unknown';
  }
}
