import 'package:esketit_music_console/domain/album.dart';
import 'package:esketit_music_console/domain/author.dart';
import 'package:esketit_music_console/esketit_rest_api/auth/authenticated_http_client_proxy.dart';
import 'package:esketit_music_console/esketit_rest_api/auth/esketit_rest_api_auth_repository.dart';
import 'package:esketit_music_console/esketit_rest_api/telegram/esketit_rest_api_telegram_import_repository.dart';
import 'package:esketit_music_console/esketit_rest_api/track/esketit_rest_api_tracks_storage.dart';
import 'package:esketit_music_console/firebase/track/storage_file.dart';
import 'package:esketit_music_console/ui/album/albums_list_screen.dart';
import 'package:esketit_music_console/ui/album/edit_album_screen.dart';
import 'package:esketit_music_console/ui/auth/sign_in_screen.dart';
import 'package:esketit_music_console/ui/author/authors_list_screen.dart';
import 'package:esketit_music_console/ui/settings/settings_screen.dart';
import 'package:esketit_music_console/ui/track/add_tracks_screen.dart';
import 'package:esketit_music_console/ui/track/edit_track_screen.dart';
import 'package:esketit_music_console/unassigned_layer/cross_file.dart';
import 'package:esketit_music_console/unassigned_layer/http_package_http_client.dart';
import 'package:esketit_music_console/unassigned_layer/shared_preferences_auth_session_storage.dart';
import 'package:esketit_music_console/use_case/auth/bloc/auth_bloc.dart';
import 'package:esketit_music_console/use_case/telegram/telegram_import_repository.dart';
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
        // DO NOT REMOVE ANY COMMENDTED LINES HERE BECAUSE THEY ARE USED TO QUICKLY SWITCH SERVER.
        defaultValue: 'http://localhost:8080',
        // defaultValue: 'http://46.101.162.92:8080',
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
        RepositoryProvider<TelegramImportRepository>(
          create: (_) => EsketitRestApiTelegramImportRepository(
            httpClient: authenticatedHttpClient,
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

enum _MainDestination { tracks, albums, authors, settings }

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  _MainDestination _destination = _MainDestination.tracks;
  int _albumsSectionVersion = 0;

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
      floatingActionButton: switch (_destination) {
        _MainDestination.tracks => FloatingActionButton.extended(
          onPressed: _openAddTrackScreen,
          icon: const Icon(Icons.library_add),
          label: const Text('Add track'),
        ),
        _MainDestination.albums => FloatingActionButton.extended(
          onPressed: _openCreateAlbumScreen,
          icon: const Icon(Icons.album_outlined),
          label: const Text('Create album'),
        ),
        _MainDestination.authors || _MainDestination.settings => null,
      },
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
                icon: Icon(Icons.album_outlined),
                selectedIcon: Icon(Icons.album),
                label: Text('Albums'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people),
                label: Text('Authors'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: Text('Settings'),
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
                _MainDestination.albums => AlbumsListScreen(
                  key: ValueKey('albums-$_albumsSectionVersion'),
                ),
                _MainDestination.authors => const AuthorsListScreen(
                  key: ValueKey('authors'),
                ),
                _MainDestination.settings => const SettingsScreen(
                  key: ValueKey('settings'),
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

  Future<void> _openCreateAlbumScreen() async {
    final didSave = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const EditAlbumScreen()));

    if (didSave == true && mounted) {
      setState(() {
        _albumsSectionVersion += 1;
        _destination = _MainDestination.albums;
      });
    }
  }
}

class TracksSection extends StatefulWidget {
  const TracksSection({super.key});

  @override
  State<TracksSection> createState() => _TracksSectionState();
}

class _TracksSectionState extends State<TracksSection> {
  static const List<int> _pageSizeOptions = [20, 50, 100];
  static const int _filterOptionsPageSize = 100;

  late final TextEditingController _queryController;
  List<Author> _authors = const [];
  List<Album> _albums = const [];
  int? _selectedAuthorId;
  int? _selectedAlbumId;
  bool _isLoadingFilterOptions = true;
  String? _filterOptionsError;

  @override
  void initState() {
    super.initState();
    final state = context.read<TrackListBloc>().state;
    _queryController = TextEditingController(text: state.query ?? '');
    _selectedAuthorId = state.authorId;
    _selectedAlbumId = state.albumId;
    _loadFilterOptions();
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TrackListBloc, TrackListState>(
      builder: (context, state) {
        return Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.only(top: 16),
                color: Theme.of(context).scaffoldBackgroundColor,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
                          onPressed: () => context.read<TrackListBloc>().add(
                            const LoadTracks(),
                          ),
                          tooltip: 'Reload tracks',
                          icon: const Icon(Icons.refresh),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: 280,
                          child: TextField(
                            controller: _queryController,
                            textInputAction: TextInputAction.search,
                            onSubmitted: (_) => _applyFilters(),
                            decoration: const InputDecoration(
                              labelText: 'Search by track name',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.search),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 240,
                          child: NotificationListener<ScrollNotification>(
                            onNotification: (notification) {
                              return true;
                            },
                            child: DropdownMenu<int>(
                              key: ValueKey(_selectedAuthorId),
                              width: 240,
                              initialSelection: _selectedAuthorId,
                              enableFilter: true,
                              enableSearch: true,
                              requestFocusOnTap: true,
                              menuStyle: _filterMenuStyle,
                              onSelected: state.isLoading
                                  ? null
                                  : (value) {
                                      setState(() {
                                        _selectedAuthorId = value;
                                      });
                                    },
                              dropdownMenuEntries: _authorEntries,
                              label: Text(
                                _isLoadingFilterOptions
                                    ? 'Loading authors...'
                                    : 'Author',
                              ),
                              hintText: _isLoadingFilterOptions
                                  ? 'Loading authors...'
                                  : 'All authors',
                              inputDecorationTheme: const InputDecorationTheme(
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 280,
                          child: NotificationListener<ScrollNotification>(
                            onNotification: (notification) {
                              return true;
                            },
                            child: DropdownMenu<int>(
                              key: ValueKey(_selectedAlbumId),
                              width: 280,
                              initialSelection: _selectedAlbumId,
                              enableFilter: true,
                              enableSearch: true,
                              requestFocusOnTap: true,
                              menuStyle: _filterMenuStyle,
                              onSelected: state.isLoading
                                  ? null
                                  : (value) {
                                      setState(() {
                                        _selectedAlbumId = value;
                                      });
                                    },
                              dropdownMenuEntries: _albumEntries,
                              label: Text(
                                _isLoadingFilterOptions
                                    ? 'Loading albums...'
                                    : 'Album',
                              ),
                              hintText: _isLoadingFilterOptions
                                  ? 'Loading albums...'
                                  : 'All albums',
                              inputDecorationTheme: const InputDecorationTheme(
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: state.isLoading ? null : _applyFilters,
                          icon: const Icon(Icons.filter_alt),
                          label: const Text('Apply'),
                        ),
                        TextButton(
                          onPressed: state.isLoading ? null : _clearFilters,
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (state.errorMessage != null) ...[
                      Text(
                        state.errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_filterOptionsError != null) ...[
                      Text(
                        _filterOptionsError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (state.isLoading) const LinearProgressIndicator(),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 16,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Page ${state.page} of ${state.totalPages == 0 ? 1 : state.totalPages}',
                        ),
                        Text('Items: ${state.totalItems}'),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Page size: '),
                            DropdownButton<int>(
                              value: _pageSizeOptions.contains(state.pageSize)
                                  ? state.pageSize
                                  : _pageSizeOptions.first,
                              items: _pageSizeOptions
                                  .map(
                                    (value) => DropdownMenuItem<int>(
                                      value: value,
                                      child: Text('$value'),
                                    ),
                                  )
                                  .toList(),
                              onChanged: state.isLoading
                                  ? null
                                  : (value) {
                                      if (value == null) {
                                        return;
                                      }
                                      context.read<TrackListBloc>().add(
                                        LoadTracks(pageSize: value),
                                      );
                                    },
                            ),
                          ],
                        ),
                        OutlinedButton.icon(
                          onPressed: state.isLoading || state.page <= 1
                              ? null
                              : () => context.read<TrackListBloc>().add(
                                  LoadTracks(page: state.page - 1),
                                ),
                          icon: const Icon(Icons.chevron_left),
                          label: const Text('Previous'),
                        ),
                        OutlinedButton.icon(
                          onPressed:
                              state.isLoading ||
                                  state.totalPages == 0 ||
                                  state.page >= state.totalPages
                              ? null
                              : () => context.read<TrackListBloc>().add(
                                  LoadTracks(page: state.page + 1),
                                ),
                          icon: const Icon(Icons.chevron_right),
                          label: const Text('Next'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
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
                            onTap: () =>
                                _openEditTrackScreen(context, track.id),
                            title: Text(track.name),
                            subtitle: Text(
                              [
                                'Authors: ${track.authors.map((author) => author.currentName).join(', ')}',
                                _fileLabel(track.file),
                              ].join('\n'),
                            ),
                            isThreeLine: true,
                            trailing: const Icon(Icons.chevron_right),
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

  void _applyFilters() {
    context.read<TrackListBloc>().add(
      LoadTracks(
        page: 1,
        query: _queryController.text,
        authorId: _selectedAuthorId,
        albumId: _selectedAlbumId,
      ),
    );
  }

  void _clearFilters() {
    _queryController.clear();
    setState(() {
      _selectedAuthorId = null;
      _selectedAlbumId = null;
    });
    context.read<TrackListBloc>().add(
      const LoadTracks(
        page: 1,
        clearQuery: true,
        clearAuthorId: true,
        clearAlbumId: true,
      ),
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

  Future<void> _openEditTrackScreen(BuildContext context, int? trackId) async {
    if (trackId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Track ID is missing.')));
      return;
    }

    final didSave = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EditTrackScreen(trackId: trackId)),
    );

    if (didSave == true && context.mounted) {
      context.read<TrackListBloc>().add(const LoadTracks());
    }
  }

  List<DropdownMenuEntry<int>> get _authorEntries => _authors
      .where((author) => author.id != null)
      .map(
        (author) => DropdownMenuEntry<int>(
          value: author.id!,
          label: '${author.currentName} (#${author.id})',
        ),
      )
      .toList();

  List<DropdownMenuEntry<int>> get _albumEntries => _albums
      .where((album) => album.id != null)
      .map(
        (album) => DropdownMenuEntry<int>(
          value: album.id!,
          label: '${album.title} (#${album.id})',
        ),
      )
      .toList();

  MenuStyle get _filterMenuStyle => const MenuStyle(
    alignment: AlignmentDirectional.bottomStart,
    maximumSize: WidgetStatePropertyAll(Size.fromHeight(400)),
  );

  Future<void> _loadFilterOptions() async {
    setState(() {
      _isLoadingFilterOptions = true;
      _filterOptionsError = null;
    });

    try {
      final storage = context.read<TracksStorage>();
      final authors = await storage.getAuthors();
      final albums = await _loadAllAlbums(storage);
      authors.sort(
        (left, right) => left.currentName.toLowerCase().compareTo(
          right.currentName.toLowerCase(),
        ),
      );
      albums.sort(
        (left, right) =>
            left.title.toLowerCase().compareTo(right.title.toLowerCase()),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _authors = authors;
        _albums = albums;
        _isLoadingFilterOptions = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingFilterOptions = false;
        _filterOptionsError = 'Failed to load author/album filters: $error';
      });
    }
  }

  Future<List<Album>> _loadAllAlbums(TracksStorage storage) async {
    final albums = <Album>[];
    var page = 1;

    while (true) {
      final chunk = await storage.getAlbums(
        page: page,
        pageSize: _filterOptionsPageSize,
      );
      albums.addAll(chunk);
      if (chunk.length < _filterOptionsPageSize) {
        return albums;
      }
      page += 1;
    }
  }
}
