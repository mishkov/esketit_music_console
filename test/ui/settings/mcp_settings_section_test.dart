import 'package:esketit_music_console/domain/access_control.dart';
import 'package:esketit_music_console/domain/mcp_settings.dart';
import 'package:esketit_music_console/errors/http_app_error.dart';
import 'package:esketit_music_console/ui/settings/mcp_settings_section.dart';
import 'package:esketit_music_console/use_case/access_control/access_control_repository.dart';
import 'package:esketit_music_console/use_case/mcp/mcp_settings_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester tester, _SettingsRepository settings) async {
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<McpSettingsRepository>.value(value: settings),
          RepositoryProvider<AccessControlRepository>.value(value: _Users()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: McpSettingsSection(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('loads guidance, saves edits and can disable acting identity', (
    tester,
  ) async {
    final settings = _SettingsRepository();
    await pump(tester, settings);
    expect(find.text('Current workflow'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'New workflow');
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Disabled — no acting user').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save MCP settings'));
    await tester.tap(find.text('Save MCP settings'));
    await tester.pumpAndSettle();
    expect(settings.userId, isNull);
    expect(settings.workflow, 'New workflow');
    expect(settings.expectedVersion, 2);
    expect(find.text('MCP settings saved.'), findsOneWidget);
  });

  testWidgets('retains unsaved guidance after a version conflict', (
    tester,
  ) async {
    final settings = _SettingsRepository()..conflict = true;
    await pump(tester, settings);
    await tester.enterText(find.byType(TextField).first, 'Unsaved draft');
    await tester.ensureVisible(find.text('Save MCP settings'));
    await tester.tap(find.text('Save MCP settings'));
    await tester.pumpAndSettle();
    expect(find.text('Unsaved draft'), findsOneWidget);
    expect(find.textContaining('Reload'), findsWidgets);
    expect(find.text('MCP settings saved.'), findsNothing);
  });
}

class _SettingsRepository implements McpSettingsRepository {
  bool conflict = false;
  int? userId;
  String? workflow;
  int? expectedVersion;
  @override
  Future<McpSettings> getSettings() async => const McpSettings(
    actingUserId: 7,
    workflowGuidance: 'Current workflow',
    uploadGuidance: 'Current uploads',
    version: 2,
    credentialConfigured: true,
  );
  @override
  Future<McpSettings> saveSettings({
    required int expectedVersion,
    required int? actingUserId,
    required String workflowGuidance,
    required String uploadGuidance,
  }) async {
    this.expectedVersion = expectedVersion;
    if (conflict) {
      throw const HttpAppError(
        message: 'Reload current settings before saving.',
        path: '/mcp/settings',
        statusCode: 409,
      );
    }
    userId = actingUserId;
    workflow = workflowGuidance;
    return McpSettings(
      actingUserId: actingUserId,
      workflowGuidance: workflowGuidance,
      uploadGuidance: uploadGuidance,
      version: 3,
      credentialConfigured: true,
    );
  }
}

class _Users implements AccessControlRepository {
  @override
  Future<List<AccessControlUser>> getUsers() async => [
    AccessControlUser(
      id: 7,
      email: 'agent@example.com',
      createdAt: DateTime.utc(2026),
      roles: const [],
      permissions: const [],
    ),
  ];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
