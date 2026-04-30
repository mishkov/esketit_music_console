import 'dart:typed_data';

import 'package:esketit_music_console/domain/auth/app_user.dart';
import 'package:esketit_music_console/domain/auth/auth_session.dart';
import 'package:esketit_music_console/errors/http_app_error.dart';
import 'package:esketit_music_console/esketit_rest_api/telegram/telegram_import_models.dart';
import 'package:esketit_music_console/esketit_rest_api/youtube/youtube_cookies_models.dart';
import 'package:esketit_music_console/ui/settings/settings_screen.dart';
import 'package:esketit_music_console/use_case/auth/bloc/auth_bloc.dart';
import 'package:esketit_music_console/use_case/auth/auth_repository.dart';
import 'package:esketit_music_console/use_case/telegram/telegram_import_repository.dart';
import 'package:esketit_music_console/use_case/youtube/youtube_cookies_repository.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  FilePicker? originalFilePicker;

  setUp(() {
    try {
      originalFilePicker = FilePicker.platform;
    } catch (_) {
      originalFilePicker = null;
    }
  });

  tearDown(() {
    final filePicker = originalFilePicker;
    if (filePicker != null) {
      FilePicker.platform = filePicker;
    }
  });

  testWidgets('renders configured false state clearly for admins', (
    tester,
  ) async {
    final youtubeRepository = _FakeYouTubeCookiesRepository(
      currentStatus: const YouTubeCookiesStatus(
        configured: false,
        filePresent: false,
      ),
    );

    await _pumpScreen(
      tester,
      authRepository: _FakeAuthRepository(role: AppUserRole.admin),
      youtubeRepository: youtubeRepository,
    );

    expect(find.text('YouTube Cookies'), findsOneWidget);
    expect(
      find.textContaining('Cookie storage is not configured'),
      findsOneWidget,
    );
    expect(find.text('Upload'), findsNothing);
  });

  testWidgets('uploads cookies file and refreshes status', (tester) async {
    FilePicker.platform = _FakeFilePicker(
      result: FilePickerResult([
        PlatformFile(
          name: 'youtube-cookies.txt',
          size: 3,
          bytes: Uint8List.fromList(const [1, 2, 3]),
        ),
      ]),
    );
    final youtubeRepository = _FakeYouTubeCookiesRepository(
      currentStatus: const YouTubeCookiesStatus(
        configured: true,
        filePresent: false,
      ),
      uploadedStatus: YouTubeCookiesStatus(
        configured: true,
        filePresent: true,
        lastModified: DateTime.utc(2026, 4, 29, 12),
      ),
    );

    await _pumpScreen(
      tester,
      authRepository: _FakeAuthRepository(role: AppUserRole.admin),
      youtubeRepository: youtubeRepository,
    );

    await _tapVisible(
      tester,
      find.widgetWithText(FilledButton, 'Pick cookies file'),
    );
    await _tapVisible(tester, find.widgetWithText(FilledButton, 'Upload'));

    expect(youtubeRepository.lastUploadFileName, 'youtube-cookies.txt');
    expect(youtubeRepository.lastUploadBytes, [1, 2, 3]);
    expect(find.text('YouTube cookies file uploaded.'), findsOneWidget);
    expect(find.text('File present: Yes'), findsOneWidget);
  });

  testWidgets('deletes the stored cookies file', (tester) async {
    final youtubeRepository = _FakeYouTubeCookiesRepository(
      currentStatus: YouTubeCookiesStatus(
        configured: true,
        filePresent: true,
        lastModified: DateTime.utc(2026, 4, 29, 12),
      ),
      deletedStatus: const YouTubeCookiesStatus(
        configured: true,
        filePresent: false,
      ),
    );

    await _pumpScreen(
      tester,
      authRepository: _FakeAuthRepository(role: AppUserRole.admin),
      youtubeRepository: youtubeRepository,
    );

    await _tapVisible(tester, find.widgetWithText(TextButton, 'Remove file'));

    expect(youtubeRepository.deleteCount, 1);
    expect(find.text('YouTube cookies file removed.'), findsOneWidget);
    expect(find.text('File present: No'), findsOneWidget);
  });

  testWidgets('shows admin-facing upload errors', (tester) async {
    FilePicker.platform = _FakeFilePicker(
      result: FilePickerResult([
        PlatformFile(
          name: 'youtube-cookies.txt',
          size: 3,
          bytes: Uint8List.fromList(const [1, 2, 3]),
        ),
      ]),
    );
    final youtubeRepository = _FakeYouTubeCookiesRepository(
      currentStatus: const YouTubeCookiesStatus(
        configured: true,
        filePresent: false,
      ),
      uploadError: const HttpAppError(
        message: 'Cookies file is invalid',
        path: '/youtube/cookies',
        statusCode: 400,
      ),
    );

    await _pumpScreen(
      tester,
      authRepository: _FakeAuthRepository(role: AppUserRole.admin),
      youtubeRepository: youtubeRepository,
    );

    await _tapVisible(
      tester,
      find.widgetWithText(FilledButton, 'Pick cookies file'),
    );
    await _tapVisible(tester, find.widgetWithText(FilledButton, 'Upload'));

    expect(find.text('Cookies file is invalid'), findsOneWidget);
  });

  testWidgets('hides the YouTube cookies section for listeners', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      authRepository: _FakeAuthRepository(role: AppUserRole.listener),
      youtubeRepository: _FakeYouTubeCookiesRepository(
        currentStatus: const YouTubeCookiesStatus(
          configured: true,
          filePresent: true,
        ),
      ),
    );

    expect(find.text('YouTube Cookies'), findsNothing);
  });
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required _FakeAuthRepository authRepository,
  required _FakeYouTubeCookiesRepository youtubeRepository,
}) async {
  final authBloc = AuthBloc(authRepository: authRepository)
    ..add(const AuthSessionRestoreRequested());

  await tester.pumpWidget(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<TelegramImportRepository>(
          create: (_) => _FakeTelegramImportRepository(),
        ),
        RepositoryProvider<YouTubeCookiesRepository>.value(
          value: youtubeRepository,
        ),
      ],
      child: MultiBlocProvider(
        providers: [BlocProvider<AuthBloc>.value(value: authBloc)],
        child: const MaterialApp(home: Scaffold(body: SettingsScreen())),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

class _FakeAuthRepository implements AuthRepository {
  const _FakeAuthRepository({required this.role});

  final AppUserRole role;

  AuthSession get _session => AuthSession(
    user: AppUser(
      id: 1,
      email: 'admin@example.com',
      role: role,
      createdAt: DateTime.utc(2026, 1, 1),
    ),
    accessToken: 'token',
    accessTokenExpiresAt: DateTime.utc(2099, 1, 1),
    refreshToken: 'refresh',
    refreshTokenExpiresAt: DateTime.utc(2099, 1, 2),
  );

  @override
  Future<AuthSession?> restoreSession() async => _session;

  @override
  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async => _session;

  @override
  Future<void> signOut() async {}

  @override
  Future<AuthSession?> refreshSession({bool forceRefresh = false}) async =>
      _session;
}

class _FakeTelegramImportRepository implements TelegramImportRepository {
  @override
  Future<TelegramStatus> getStatus() async => const TelegramStatus(
    configured: true,
    authorized: true,
    passwordRequired: false,
  );

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeYouTubeCookiesRepository implements YouTubeCookiesRepository {
  _FakeYouTubeCookiesRepository({
    required this.currentStatus,
    this.uploadedStatus,
    this.deletedStatus,
    this.uploadError,
  });

  YouTubeCookiesStatus currentStatus;
  final YouTubeCookiesStatus? uploadedStatus;
  final YouTubeCookiesStatus? deletedStatus;
  final Object? uploadError;

  String? lastUploadFileName;
  List<int>? lastUploadBytes;
  int deleteCount = 0;

  @override
  Future<YouTubeCookiesStatus> getStatus() async => currentStatus;

  @override
  Future<YouTubeCookiesStatus> uploadCookies({
    required String fileName,
    required List<int> bytes,
  }) async {
    lastUploadFileName = fileName;
    lastUploadBytes = bytes;
    if (uploadError != null) {
      throw uploadError!;
    }
    currentStatus = uploadedStatus ?? currentStatus;
    return currentStatus;
  }

  @override
  Future<void> deleteCookies() async {
    deleteCount += 1;
    currentStatus = deletedStatus ?? currentStatus;
  }
}

class _FakeFilePicker extends FilePicker {
  _FakeFilePicker({this.result});

  final FilePickerResult? result;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    return result;
  }
}
