import 'package:esketit_music_console/domain/access_control.dart';
import 'package:esketit_music_console/domain/mcp_settings.dart';
import 'package:esketit_music_console/use_case/access_control/access_control_repository.dart';
import 'package:esketit_music_console/use_case/mcp/mcp_settings_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class McpSettingsSection extends StatefulWidget {
  const McpSettingsSection({super.key});

  @override
  State<McpSettingsSection> createState() => _McpSettingsSectionState();
}

class _McpSettingsSectionState extends State<McpSettingsSection> {
  final _workflow = TextEditingController();
  final _uploads = TextEditingController();
  McpSettings? _settings;
  List<AccessControlUser> _users = const [];
  int? _actingUserId;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _savedMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _workflow.dispose();
    _uploads.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _savedMessage = null;
    });
    try {
      final results = await Future.wait<Object>([
        context.read<McpSettingsRepository>().getSettings(),
        context.read<AccessControlRepository>().getUsers(),
      ]);
      if (!mounted) return;
      final settings = results[0] as McpSettings;
      setState(() {
        _settings = settings;
        _users = results[1] as List<AccessControlUser>;
        _actingUserId = settings.actingUserId;
        _workflow.text = settings.workflowGuidance;
        _uploads.text = settings.uploadGuidance;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _save() async {
    final settings = _settings;
    if (settings == null) return;
    setState(() {
      _saving = true;
      _error = null;
      _savedMessage = null;
    });
    try {
      final saved = await context.read<McpSettingsRepository>().saveSettings(
        expectedVersion: settings.version,
        actingUserId: _actingUserId,
        workflowGuidance: _workflow.text,
        uploadGuidance: _uploads.text,
      );
      if (!mounted) return;
      setState(() {
        _settings = saved;
        _savedMessage = 'MCP settings saved.';
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _loading || _saving;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Connected AI agents submit and address feedback as the selected user, using that user’s permissions.',
        ),
        const SizedBox(height: 12),
        if (_loading) const LinearProgressIndicator(),
        if (_error != null) ...[
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 12),
        ],
        if (_settings != null) ...[
          if (!_settings!.credentialConfigured) ...[
            const Text(
              'The MCP connection credential still needs to be configured on the server.',
            ),
            const SizedBox(height: 12),
          ],
          DropdownButtonFormField<int>(
            key: ValueKey(_settings!.version),
            initialValue: _actingUserId ?? 0,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Agent acting user',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(
                value: 0,
                child: Text('Disabled — no acting user'),
              ),
              ..._users.map(
                (user) =>
                    DropdownMenuItem(value: user.id, child: Text(user.email)),
              ),
            ],
            onChanged: busy
                ? null
                : (value) => setState(() {
                    _actingUserId = value == 0 ? null : value;
                    _savedMessage = null;
                  }),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _workflow,
            enabled: !busy,
            minLines: 4,
            maxLines: 12,
            decoration: const InputDecoration(
              labelText: 'Workflow guidance',
              helperText:
                  'Submission standards, source preferences, and how to address feedback.',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {
              _savedMessage = null;
            }),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _uploads,
            enabled: !busy,
            minLines: 3,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Upload guidance',
              helperText:
                  'Additional media preparation instructions. Server upload limits and permissions are enforced separately.',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {
              _savedMessage = null;
            }),
          ),
          const SizedBox(height: 16),
        ],
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            FilledButton(
              onPressed: busy || _settings == null ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Save MCP settings'),
            ),
            OutlinedButton(
              onPressed: busy ? null : _load,
              child: const Text('Reload MCP settings'),
            ),
          ],
        ),
        if (_savedMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_savedMessage!),
          ),
      ],
    );
  }
}
