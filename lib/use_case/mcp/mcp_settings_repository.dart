import 'package:esketit_music_console/domain/mcp_settings.dart';

abstract class McpSettingsRepository {
  Future<McpSettings> getSettings();
  Future<McpSettings> saveSettings({
    required int expectedVersion,
    required int? actingUserId,
    required String workflowGuidance,
    required String uploadGuidance,
  });
}
