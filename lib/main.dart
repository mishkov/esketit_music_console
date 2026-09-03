import 'package:esketit_music_console/domain/album.dart';
import 'package:esketit_music_console/domain/author.dart';
import 'package:esketit_music_console/esketit_rest_api/auth/authenticated_http_client_proxy.dart';
import 'package:esketit_music_console/esketit_rest_api/auth/esketit_rest_api_auth_repository.dart';
import 'package:esketit_music_console/esketit_rest_api/lyrics/esketit_rest_api_lyrics_search_repository.dart';
import 'package:esketit_music_console/esketit_rest_api/telegram/esketit_rest_api_telegram_import_repository.dart';
import 'package:esketit_music_console/esketit_rest_api/track/esketit_rest_api_tracks_storage.dart';
import 'package:esketit_music_console/esketit_rest_api/youtube/esketit_rest_api_youtube_cookies_repository.dart';
import 'package:esketit_music_console/esketit_rest_api/youtube/esketit_rest_api_youtube_import_repository.dart';
import 'package:esketit_music_console/observability/sentry_import_repositories.dart';
import 'package:esketit_music_console/ui/album/albums_list_screen.dart';
import 'package:esketit_music_console/ui/album/albums_support.dart';
import 'package:esketit_music_console/ui/album/edit_album_screen.dart';
import 'package:esketit_music_console/ui/auth/sign_in_screen.dart';
import 'package:esketit_music_console/ui/author/authors_list_screen.dart';
import 'package:esketit_music_console/ui/settings/settings_screen.dart';
import 'package:esketit_music_console/ui/track/add_tracks_screen.dart';
import 'package:esketit_music_console/ui/track/edit_track_screen.dart';
import 'package:esketit_music_console/ui/utilities/utilities_screen.dart';
import 'package:esketit_music_console/unassigned_layer/http_package_http_client.dart';
import 'package:esketit_music_console/unassigned_layer/shared_preferences_auth_session_storage.dart';
import 'package:esketit_music_console/use_case/auth/bloc/auth_bloc.dart';
import 'package:esketit_music_console/use_case/lyrics/lyrics_search_repository.dart';
import 'package:esketit_music_console/use_case/settings/app_theme_mode_cubit.dart';
import 'package:esketit_music_console/use_case/telegram/telegram_import_repository.dart';
import 'package:esketit_music_console/use_case/track/storage/tracks_storage.dart';
import 'package:esketit_music_console/use_case/track/tracks_list/bloc/track_list_bloc.dart';
import 'package:esketit_music_console/use_case/youtube/youtube_cookies_repository.dart';
import 'package:esketit_music_console/use_case/youtube/youtube_import_repository.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

const _sentryDsn = String.fromEnvironment(
  'SENTRY_DSN',
  defaultValue:
      'https://58c2b3d1c61cb0eb6d388eee78610233@o4504197551554560.ingest.us.sentry.io/4512018545049600',
);
const _sentryEnvironment = String.fromEnvironment('SENTRY_ENVIRONMENT');
const _sentryTracesSampleRateValue = String.fromEnvironment(
  'SENTRY_TRACES_SAMPLE_RATE',
  defaultValue: '1.0',
);

final _sentryNavigatorObserver = SentryNavigatorObserver();

Future<void> main() async {
  final configuredTracesSampleRate = double.tryParse(
    _sentryTracesSampleRateValue,
  );
  final tracesSampleRate =
      configuredTracesSampleRate != null &&
          configuredTracesSampleRate >= 0 &&
          configuredTracesSampleRate <= 1
      ? configuredTracesSampleRate
      : 1.0;

  await SentryFlutter.init((options) {
    options
      ..dsn = _sentryDsn
      ..tracesSampleRate = tracesSampleRate
      ..enableLogs = true
      ..sendDefaultPii = false;
    if (_sentryEnvironment.isNotEmpty) {
      options.environment = _sentryEnvironment;
    }
    options.addInAppInclude('esketit_music_console');
  }, appRunner: () => runApp(SentryWidget(child: const AppRoot())));
}

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    final baseUri = Uri.parse(
      const String.fromEnvironment(
        'ESKETIT_API_BASE_URL',
        // DO NOT REMOVE ANY COMMENDTED LINES HERE BECAUSE THEY ARE USED TO QUICKLY SWITCH SERVER.
        // defaultValue: 'http://localhost:8080/api/',
        defaultValue: 'https://esketitmusic.online/api/',
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
        RepositoryProvider<LyricsSearchRepository>(
          create: (_) => EsketitRestApiLyricsSearchRepository(
            httpClient: authenticatedHttpClient,
          ),
        ),
        RepositoryProvider<TelegramImportRepository>(
          create: (_) => SentryTelegramImportRepository(
            delegate: EsketitRestApiTelegramImportRepository(
              httpClient: authenticatedHttpClient,
            ),
          ),
        ),
        RepositoryProvider<YouTubeImportRepository>(
          create: (_) => SentryYouTubeImportRepository(
            delegate: EsketitRestApiYouTubeImportRepository(
              httpClient: authenticatedHttpClient,
              baseUri: baseUri,
            ),
          ),
        ),
        RepositoryProvider<YouTubeCookiesRepository>(
          create: (_) => EsketitRestApiYouTubeCookiesRepository(
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
          BlocProvider(create: (_) => AppThemeModeCubit()..load()),
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
    return BlocBuilder<AppThemeModeCubit, AppThemeModePreference>(
      builder: (context, themePreference) {
        return MaterialApp(
          title: 'Esketit Music',
          navigatorObservers: [_sentryNavigatorObserver],
          theme: ThemeData(colorSchemeSeed: Colors.green, useMaterial3: true),
          darkTheme: ThemeData(
            colorSchemeSeed: Colors.green,
            brightness: Brightness.dark,
            useMaterial3: true,
          ),
          themeMode: themePreference.themeMode,
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
      },
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

enum _MainDestination { tracks, albums, authors, utilities, settings }

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  static const double _navigationDrawerBreakpoint = 600;
  static const int _filterOptionsPageSize = 100;

  _MainDestination _destination = _MainDestination.tracks;
  int _albumsSectionVersion = 0;
  late final TextEditingController _trackQueryController;
  List<Author> _trackFilterAuthors = const [];
  List<Album> _trackFilterAlbums = const [];
  int? _selectedTrackAuthorId;
  int? _selectedTrackAlbumId;
  bool _isLoadingTrackFilterOptions = true;
  bool _showFoundItemsAfterLoad = false;
  String? _trackFilterOptionsError;

  @override
  void initState() {
    super.initState();
    final trackListState = context.read<TrackListBloc>().state;
    _trackQueryController = TextEditingController(
      text: trackListState.query ?? '',
    );
    _selectedTrackAuthorId = trackListState.authorId;
    _selectedTrackAlbumId = trackListState.albumId;
    _loadTrackFilterOptions();
    context.read<TrackListBloc>().add(const LoadTracks());
  }

  @override
  void dispose() {
    _trackQueryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final useNavigationDrawer =
        MediaQuery.sizeOf(context).width < _navigationDrawerBreakpoint;
    final userEmail = context.select(
      (AuthBloc bloc) => bloc.state.session?.user.email,
    );
    final tracksStorage = context.read<TracksStorage>();
    final trackAlbumCoverUrls = <int, String>{};
    for (final album in _trackFilterAlbums) {
      final albumId = album.id;
      if (albumId != null) {
        trackAlbumCoverUrls[albumId] = tracksStorage.resolveAlbumCoverUrl(
          album.coverImagePath,
        );
      }
    }

    return BlocListener<TrackListBloc, TrackListState>(
      listener: _handleTrackListState,
      child: Scaffold(
        appBar: _buildAppBar(),
        drawer: useNavigationDrawer
            ? _buildNavigationDrawer(context, userEmail)
            : null,
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
          _MainDestination.authors ||
          _MainDestination.utilities ||
          _MainDestination.settings => null,
        },
        body: Row(
          children: [
            if (!useNavigationDrawer) ...[
              _buildNavigationRail(context),
              const VerticalDivider(width: 1),
            ],
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: switch (_destination) {
                  _MainDestination.tracks => TracksSection(
                    key: const ValueKey('tracks'),
                    albumCoverUrlsById: trackAlbumCoverUrls,
                  ),
                  _MainDestination.albums => AlbumsListScreen(
                    key: ValueKey('albums-$_albumsSectionVersion'),
                  ),
                  _MainDestination.authors => const AuthorsListScreen(
                    key: ValueKey('authors'),
                  ),
                  _MainDestination.utilities => const UtilitiesScreen(
                    key: ValueKey('utilities'),
                  ),
                  _MainDestination.settings => const SettingsScreen(
                    key: ValueKey('settings'),
                  ),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    if (_destination != _MainDestination.tracks) {
      return AppBar(title: const Text('Esketit Music'));
    }

    final hasAppliedFilters =
        _selectedTrackAuthorId != null || _selectedTrackAlbumId != null;

    return AppBar(
      centerTitle: true,
      title: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SizedBox(
          height: 44,
          child: Row(
            spacing: 8,
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('track-search-field'),
                  controller: _trackQueryController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _applyTrackSearch(),
                  decoration: InputDecoration(
                    hintText: 'Search by track name',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              Badge(
                key: const ValueKey('track-filter-badge'),
                isLabelVisible: hasAppliedFilters,
                smallSize: 8,
                child: IconButton(
                  onPressed: _isLoadingTrackFilterOptions
                      ? null
                      : _openTrackFilters,
                  tooltip: _isLoadingTrackFilterOptions
                      ? 'Loading filters'
                      : 'Filter tracks',
                  icon: Icon(
                    hasAppliedFilters
                        ? Icons.filter_alt
                        : Icons.filter_alt_outlined,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleTrackListState(BuildContext context, TrackListState state) {
    if (!_showFoundItemsAfterLoad || state.isLoading || state.isLoadingMore) {
      return;
    }

    _showFoundItemsAfterLoad = false;
    if (state.errorMessage == null) {
      _showFoundItemsSnackbar(context, state.totalItems);
    }
  }

  void _applyTrackSearch() {
    _showFoundItemsAfterLoad = true;
    context.read<TrackListBloc>().add(
      LoadTracks(query: _trackQueryController.text),
    );
  }

  Future<void> _openTrackFilters() async {
    FocusScope.of(context).unfocus();
    final initialFilters = _TrackFilterSelection(
      authorId: _selectedTrackAuthorId,
      albumId: _selectedTrackAlbumId,
    );
    final useBottomSheet =
        MediaQuery.sizeOf(context).width < _navigationDrawerBreakpoint;

    final _TrackFilterSelection? filters;
    if (useBottomSheet) {
      filters = await showModalBottomSheet<_TrackFilterSelection>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (sheetContext) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            20,
            16,
            16 + MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: SingleChildScrollView(
            child: _TrackFiltersForm(
              initialFilters: initialFilters,
              authors: _trackFilterAuthors,
              albums: _trackFilterAlbums,
              errorMessage: _trackFilterOptionsError,
            ),
          ),
        ),
      );
    } else {
      filters = await showDialog<_TrackFilterSelection>(
        context: context,
        builder: (dialogContext) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _TrackFiltersForm(
                initialFilters: initialFilters,
                authors: _trackFilterAuthors,
                albums: _trackFilterAlbums,
                errorMessage: _trackFilterOptionsError,
              ),
            ),
          ),
        ),
      );
    }

    if (filters == null || !mounted) {
      return;
    }

    final authorId = filters.authorId;
    final albumId = filters.albumId;
    setState(() {
      _selectedTrackAuthorId = authorId;
      _selectedTrackAlbumId = albumId;
    });
    _showFoundItemsAfterLoad = true;
    context.read<TrackListBloc>().add(
      LoadTracks(
        authorId: authorId,
        albumId: albumId,
        clearAuthorId: authorId == null,
        clearAlbumId: albumId == null,
      ),
    );
  }

  void _showFoundItemsSnackbar(BuildContext context, int itemCount) {
    final itemLabel = itemCount == 1 ? 'item' : 'items';
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Found $itemCount $itemLabel')));
  }

  Future<void> _loadTrackFilterOptions() async {
    try {
      final storage = context.read<TracksStorage>();
      final authors = await storage.getAuthors();
      final albums = await loadAllAlbums(
        storage,
        pageSize: _filterOptionsPageSize,
      );
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
        _trackFilterAuthors = authors;
        _trackFilterAlbums = albums;
        _isLoadingTrackFilterOptions = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingTrackFilterOptions = false;
        _trackFilterOptionsError =
            'Failed to load author/album filters: $error';
      });
    }
  }

  Widget _buildNavigationRail(BuildContext context) {
    return NavigationRail(
      selectedIndex: _destination.index,
      onDestinationSelected: (index) {
        if (index == _MainDestination.values.length) {
          _confirmSignOut();
          return;
        }
        _selectDestination(index);
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
          icon: Icon(Icons.build_outlined),
          selectedIcon: Icon(Icons.build),
          label: Text('Utilities'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: Text('Settings'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.logout),
          label: Text('Sign out'),
        ),
      ],
    );
  }

  Widget _buildNavigationDrawer(BuildContext context, String? userEmail) {
    return NavigationDrawer(
      selectedIndex: _destination.index,
      onDestinationSelected: (index) {
        Navigator.of(context).pop();
        _selectDestination(index);
      },
      children: [
        if (userEmail != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
            child: Row(
              children: [
                const Icon(Icons.account_circle_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    userEmail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
          ),
        const Divider(indent: 12, endIndent: 12),
        const NavigationDrawerDestination(
          icon: Icon(Icons.music_note_outlined),
          selectedIcon: Icon(Icons.music_note),
          label: Text('Tracks'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.album_outlined),
          selectedIcon: Icon(Icons.album),
          label: Text('Albums'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.people_outline),
          selectedIcon: Icon(Icons.people),
          label: Text('Authors'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.build_outlined),
          selectedIcon: Icon(Icons.build),
          label: Text('Utilities'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: Text('Settings'),
        ),
        const Divider(indent: 12, endIndent: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign out'),
            onTap: _confirmSignOut,
          ),
        ),
      ],
    );
  }

  void _selectDestination(int index) {
    setState(() {
      _destination = _MainDestination.values[index];
    });
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      context.read<AuthBloc>().add(const AuthSignOutRequested());
    }
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
    final savedAlbum = await Navigator.of(
      context,
    ).push<Album>(MaterialPageRoute(builder: (_) => const EditAlbumScreen()));

    if (savedAlbum != null && mounted) {
      setState(() {
        _albumsSectionVersion += 1;
        _destination = _MainDestination.albums;
      });
    }
  }
}

class _TrackFilterSelection {
  const _TrackFilterSelection({this.authorId, this.albumId});

  final int? authorId;
  final int? albumId;
}

class _TrackFiltersForm extends StatefulWidget {
  const _TrackFiltersForm({
    required this.initialFilters,
    required this.authors,
    required this.albums,
    this.errorMessage,
  });

  final _TrackFilterSelection initialFilters;
  final List<Author> authors;
  final List<Album> albums;
  final String? errorMessage;

  @override
  State<_TrackFiltersForm> createState() => _TrackFiltersFormState();
}

class _TrackFiltersFormState extends State<_TrackFiltersForm> {
  static const int _allItemsValue = -1;

  late int? _authorId;
  late int? _albumId;

  @override
  void initState() {
    super.initState();
    _authorId = widget.initialFilters.authorId;
    _albumId = widget.initialFilters.albumId;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Filter tracks', style: Theme.of(context).textTheme.headlineSmall),
        if (widget.errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            widget.errorMessage!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) => DropdownMenu<int>(
            key: const ValueKey('track-author-filter'),
            width: constraints.maxWidth,
            initialSelection: _authorId ?? _allItemsValue,
            enableFilter: true,
            enableSearch: true,
            requestFocusOnTap: true,
            menuStyle: _filterMenuStyle,
            onSelected: (value) {
              setState(() {
                _authorId = value == _allItemsValue ? null : value;
              });
            },
            dropdownMenuEntries: [
              const DropdownMenuEntry<int>(
                value: _allItemsValue,
                label: 'All authors',
              ),
              ...widget.authors
                  .where((author) => author.id != null)
                  .map(
                    (author) => DropdownMenuEntry<int>(
                      value: author.id!,
                      label: '${author.currentName} (#${author.id})',
                    ),
                  ),
            ],
            label: const Text('Author'),
            inputDecorationTheme: const InputDecorationTheme(
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) => DropdownMenu<int>(
            key: const ValueKey('track-album-filter'),
            width: constraints.maxWidth,
            initialSelection: _albumId ?? _allItemsValue,
            enableFilter: true,
            enableSearch: true,
            requestFocusOnTap: true,
            menuStyle: _filterMenuStyle,
            onSelected: (value) {
              setState(() {
                _albumId = value == _allItemsValue ? null : value;
              });
            },
            dropdownMenuEntries: [
              const DropdownMenuEntry<int>(
                value: _allItemsValue,
                label: 'All albums',
              ),
              ...widget.albums
                  .where((album) => album.id != null)
                  .map(
                    (album) => DropdownMenuEntry<int>(
                      value: album.id!,
                      label: '${album.title} (#${album.id})',
                    ),
                  ),
            ],
            label: const Text('Album'),
            inputDecorationTheme: const InputDecorationTheme(
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(const _TrackFilterSelection()),
              child: const Text('Clear'),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(
                _TrackFilterSelection(authorId: _authorId, albumId: _albumId),
              ),
              child: const Text('Apply'),
            ),
          ],
        ),
      ],
    );
  }

  MenuStyle get _filterMenuStyle => const MenuStyle(
    alignment: AlignmentDirectional.bottomStart,
    maximumSize: WidgetStatePropertyAll(Size.fromHeight(400)),
  );
}

class TracksSection extends StatefulWidget {
  const TracksSection({super.key, required this.albumCoverUrlsById});

  final Map<int, String> albumCoverUrlsById;

  @override
  State<TracksSection> createState() => _TracksSectionState();
}

class _TracksSectionState extends State<TracksSection> {
  static const double _loadMoreThreshold = 400;

  late final ScrollController _scrollController;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_loadMoreIfNeeded);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadMoreIfNeeded();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TrackListBloc, TrackListState>(
      listener: (context, state) {
        if (state.isLoading) {
          _resetScrollPosition();
        }
        if (!state.isLoading &&
            !state.isLoadingMore &&
            state.errorMessage == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _loadMoreIfNeeded();
            }
          });
        }
      },
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (state.errorMessage != null) ...[
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  state.errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (state.isLoading && !_isRefreshing) ...[
              Padding(
                padding: const EdgeInsets.all(16),
                child: const LinearProgressIndicator(),
              ),
              const SizedBox(height: 12),
            ],
            Expanded(
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  dragDevices: {
                    ...ScrollConfiguration.of(context).dragDevices,
                    PointerDeviceKind.mouse,
                  },
                ),
                child: RefreshIndicator.adaptive(
                  key: const ValueKey('track-refresh-indicator'),
                  onRefresh: _refreshTracks,
                  child: state.tracks.isEmpty && !state.isLoading
                      ? LayoutBuilder(
                          builder: (context, constraints) => ListView(
                            controller: _scrollController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            children: [
                              SizedBox(
                                height: constraints.maxHeight,
                                child: const Center(
                                  child: Text(
                                    'No tracks yet. Use "Add track" to create one.',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          itemCount:
                              state.tracks.length +
                              (state.isLoadingMore ? 1 : 0),
                          separatorBuilder: (context, index) =>
                              index == state.tracks.length - 1
                              ? const SizedBox(height: 12)
                              : const Divider(height: 24),
                          itemBuilder: (context, index) {
                            if (index == state.tracks.length) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Center(
                                  child: SizedBox.square(
                                    dimension: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                    ),
                                  ),
                                ),
                              );
                            }

                            final track = state.tracks[index];
                            final authorNames = track.authors
                                .map((author) => author.currentName.trim())
                                .where((name) => name.isNotEmpty)
                                .join(', ');
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              onTap: () =>
                                  _openEditTrackScreen(context, track.id),
                              leading: _TrackAlbumCover(
                                imageUrl:
                                    widget.albumCoverUrlsById[track.albumId] ??
                                    '',
                              ),
                              title: Text(track.name),
                              subtitle: authorNames.isEmpty
                                  ? null
                                  : Text(authorNames),
                              trailing: const Icon(Icons.chevron_right),

                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _refreshTracks() async {
    final bloc = context.read<TrackListBloc>();
    if (_isRefreshing || bloc.state.isLoading) {
      return;
    }

    setState(() {
      _isRefreshing = true;
    });
    final refreshFinished = bloc.stream.firstWhere(
      (state) => !state.isLoading && !state.isLoadingMore,
    );
    bloc.add(const LoadTracks());

    try {
      await refreshFinished;
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  void _loadMoreIfNeeded() {
    if (!_scrollController.hasClients ||
        _scrollController.position.extentAfter > _loadMoreThreshold) {
      return;
    }

    final bloc = context.read<TrackListBloc>();
    final state = bloc.state;
    if (state.isLoading ||
        state.isLoadingMore ||
        state.totalPages == 0 ||
        state.page >= state.totalPages) {
      return;
    }

    bloc.add(const LoadMoreTracks());
  }

  void _resetScrollPosition() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
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
}

class _TrackAlbumCover extends StatelessWidget {
  const _TrackAlbumCover({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final placeholder = ColoredBox(
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.album_rounded,
          size: 28,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: AspectRatio(
        aspectRatio: 1,
        child: imageUrl.isEmpty
            ? placeholder
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => placeholder,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) {
                    return child;
                  }
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      placeholder,
                      const Center(
                        child: SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}
