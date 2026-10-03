import 'package:esketit_music_console/ui/settings/mcp_settings_section.dart';
import 'dart:typed_data';

import 'package:esketit_music_console/esketit_rest_api/youtube/youtube_cookies_models.dart';
import 'package:esketit_music_console/errors/http_app_error.dart';
import 'package:esketit_music_console/esketit_rest_api/telegram/telegram_import_models.dart';
import 'package:esketit_music_console/use_case/auth/bloc/auth_bloc.dart';
import 'package:esketit_music_console/use_case/settings/app_theme_mode_cubit.dart';
import 'package:esketit_music_console/use_case/telegram/telegram_import_repository.dart';
import 'package:esketit_music_console/use_case/youtube/youtube_cookies_repository.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

const _enableSentryVerification = bool.fromEnvironment('SENTRY_VERIFY_SETUP');

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();

  TelegramStatus? _telegramStatus;
  YouTubeCookiesStatus? _youTubeCookiesStatus;
  bool _isLoading = true;
  bool _isRequestingCode = false;
  bool _isConfirmingCode = false;
  bool _isConfirmingPassword = false;
  bool _isUploadingYouTubeCookies = false;
  bool _isDeletingYouTubeCookies = false;
  String? _errorMessage;
  bool _codeRequested = false;
  String? _selectedYouTubeCookiesFileName;
  Uint8List? _selectedYouTubeCookiesBytes;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canManageYouTube = context.select(
      (AuthBloc bloc) =>
          bloc.state.session?.user.hasPermission(
            'integrations.youtube.manage',
          ) ??
          false,
    );

    final canManageMcp = context.select(
      (AuthBloc bloc) =>
          bloc.state.session?.user.hasPermission('access_control.manage') ??
          false,
    );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Settings',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _isLoading ? null : _loadStatus,
                    tooltip: 'Reload settings',
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_isLoading) const LinearProgressIndicator(),
              if (_errorMessage != null) ...[
                Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 16),
              ],
              Expanded(
                child: ListView(
                  children: [
                    _SettingsCard(
                      title: 'Appearance',
                      child: _buildAppearanceSection(context),
                    ),
                    const SizedBox(height: 16),
                    _SettingsCard(
                      title: 'Telegram Integration',
                      child: _buildTelegramSection(context),
                    ),
                    if (canManageYouTube) ...[
                      const SizedBox(height: 16),
                      _SettingsCard(
                        title: 'YouTube Cookies',
                        child: _buildYouTubeCookiesSection(context),
                      ),
                    ],
                    if (canManageMcp) ...[
                      const SizedBox(height: 16),
                      const _SettingsCard(
                        title: 'AI Agent / MCP',
                        child: McpSettingsSection(),
                      ),
                    ],
                    if (_enableSentryVerification) ...[
                      const SizedBox(height: 16),
                      _SettingsCard(
                        title: 'Sentry',
                        child: FilledButton(
                          onPressed: () {
                            throw StateError('Sentry setup verification');
                          },
                          child: const Text('Verify Sentry setup'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppearanceSection(BuildContext context) {
    final themePreference = context.select(
      (AppThemeModeCubit cubit) => cubit.state,
    );

    return SizedBox(
      width: 240,
      child: DropdownMenu<AppThemeModePreference>(
        key: ValueKey(themePreference),
        width: 240,
        initialSelection: themePreference,
        label: const Text('Theme'),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
        dropdownMenuEntries: AppThemeModePreference.values
            .map(
              (preference) => DropdownMenuEntry<AppThemeModePreference>(
                value: preference,
                label: preference.label,
              ),
            )
            .toList(),
        onSelected: (preference) {
          if (preference == null) {
            return;
          }
          context.read<AppThemeModeCubit>().setThemeMode(preference);
        },
      ),
    );
  }

  Widget _buildTelegramSection(BuildContext context) {
    final status = _telegramStatus;
    if (status == null) {
      return const Text('Loading Telegram integration status...');
    }

    if (!status.configured) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Telegram integration is not configured on the backend. Add TELEGRAM_API_ID and TELEGRAM_API_HASH to backend env before using Telegram import.',
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatusRow(label: 'Configured', value: 'Yes'),
        _StatusRow(
          label: 'Authorized',
          value: status.authorized ? 'Yes' : 'No',
        ),
        _StatusRow(
          label: 'Password required',
          value: status.passwordRequired ? 'Yes' : 'No',
        ),
        if ((status.accountIdentifier ?? '').isNotEmpty)
          _StatusRow(label: 'Account', value: status.accountIdentifier!),
        if ((status.importTempDir ?? '').isNotEmpty)
          _StatusRow(label: 'Import temp dir', value: status.importTempDir!),
        if ((status.sessionStorageFile ?? '').isNotEmpty)
          _StatusRow(label: 'Session file', value: status.sessionStorageFile!),
        if (!status.authorized) ...[
          const SizedBox(height: 20),
          Text(
            'Authorize Telegram account',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            enabled:
                !_isRequestingCode &&
                !_isConfirmingCode &&
                !_isConfirmingPassword,
            decoration: const InputDecoration(
              labelText: 'Phone number',
              hintText: '+1234567890',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton(
                onPressed:
                    _isRequestingCode ||
                        _isConfirmingCode ||
                        _isConfirmingPassword
                    ? null
                    : _requestCode,
                child: Text(
                  _isRequestingCode ? 'Sending code...' : 'Send code',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _codeController,
            enabled:
                _codeRequested &&
                !status.passwordRequired &&
                !_isRequestingCode &&
                !_isConfirmingCode &&
                !_isConfirmingPassword,
            decoration: const InputDecoration(
              labelText: 'Login code',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton.tonal(
                onPressed:
                    !_codeRequested ||
                        status.passwordRequired ||
                        _isRequestingCode ||
                        _isConfirmingCode ||
                        _isConfirmingPassword
                    ? null
                    : _confirmCode,
                child: Text(
                  _isConfirmingCode ? 'Confirming...' : 'Confirm login',
                ),
              ),
            ],
          ),
          if (status.passwordRequired) ...[
            const SizedBox(height: 20),
            Text(
              'Telegram cloud password required',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              enabled:
                  !_isRequestingCode &&
                  !_isConfirmingCode &&
                  !_isConfirmingPassword,
              decoration: const InputDecoration(
                labelText: 'Cloud password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton.tonal(
                  onPressed:
                      _isRequestingCode ||
                          _isConfirmingCode ||
                          _isConfirmingPassword
                      ? null
                      : _confirmPassword,
                  child: Text(
                    _isConfirmingPassword
                        ? 'Confirming password...'
                        : 'Confirm password',
                  ),
                ),
              ],
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildYouTubeCookiesSection(BuildContext context) {
    final status = _youTubeCookiesStatus;
    if (status == null) {
      return const Text('Loading YouTube cookies status...');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'This file is used by the server for YouTube/YouTube Music downloads that require login, including age-restricted tracks.',
        ),
        const SizedBox(height: 8),
        const Text(
          'The file should be a browser-exported YouTube cookies file.',
        ),
        const SizedBox(height: 8),
        const Text(
          'The file is sensitive and should only be uploaded by an admin.',
        ),
        const SizedBox(height: 8),
        const Text(
          'If downloads start failing again, re-upload a fresh cookies file.',
        ),
        const SizedBox(height: 16),
        _StatusRow(
          label: 'Configured',
          value: status.configured ? 'Yes' : 'No',
        ),
        _StatusRow(
          label: 'File present',
          value: status.filePresent ? 'Yes' : 'No',
        ),
        _StatusRow(
          label: 'Last updated',
          value: status.lastModified == null
              ? 'Unknown'
              : _formatDateTime(status.lastModified!),
        ),
        if (!status.configured) ...[
          const SizedBox(height: 12),
          Text(
            'Cookie storage is not configured on the backend. Upload is unavailable until the server is configured.',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ] else ...[
          const SizedBox(height: 16),
          _StatusRow(
            label: 'Selected file',
            value: _selectedYouTubeCookiesFileName ?? 'No file selected',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.tonalIcon(
                onPressed:
                    _isUploadingYouTubeCookies || _isDeletingYouTubeCookies
                    ? null
                    : _pickYouTubeCookiesFile,
                icon: const Icon(Icons.upload_file),
                label: Text(
                  _selectedYouTubeCookiesFileName == null
                      ? 'Pick cookies file'
                      : 'Replace file',
                ),
              ),
              FilledButton(
                onPressed:
                    _selectedYouTubeCookiesBytes == null ||
                        _isUploadingYouTubeCookies ||
                        _isDeletingYouTubeCookies
                    ? null
                    : _uploadYouTubeCookiesFile,
                child: Text(
                  _isUploadingYouTubeCookies ? 'Uploading...' : 'Upload',
                ),
              ),
              if (status.filePresent)
                TextButton(
                  onPressed:
                      _isUploadingYouTubeCookies || _isDeletingYouTubeCookies
                      ? null
                      : _deleteYouTubeCookiesFile,
                  child: Text(
                    _isDeletingYouTubeCookies ? 'Removing...' : 'Remove file',
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _loadStatus() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final telegramRepository = context.read<TelegramImportRepository>();
    final youTubeCookiesRepository = context.read<YouTubeCookiesRepository>();

    try {
      final telegramStatus = await telegramRepository.getStatus();
      final youTubeCookiesStatus = await youTubeCookiesRepository.getStatus();
      if (!mounted) {
        return;
      }
      setState(() {
        _telegramStatus = telegramStatus;
        _youTubeCookiesStatus = youTubeCookiesStatus;
        _isLoading = false;
        _isConfirmingCode = false;
        _isConfirmingPassword = false;
        if (telegramStatus.authorized) {
          _codeRequested = false;
          _codeController.clear();
          _passwordController.clear();
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = _errorMessageFrom(error);
      });
    }
  }

  Future<void> _requestCode() async {
    final phoneNumber = _phoneController.text.trim();
    if (phoneNumber.isEmpty) {
      _showMessage('Phone number is required.');
      return;
    }

    setState(() {
      _isRequestingCode = true;
    });

    try {
      await context.read<TelegramImportRepository>().requestAuthCode(
        phoneNumber: phoneNumber,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _codeRequested = true;
        _isRequestingCode = false;
        _telegramStatus = TelegramStatus(
          configured: _telegramStatus?.configured ?? true,
          authorized: false,
          passwordRequired: false,
          accountIdentifier: _telegramStatus?.accountIdentifier,
          importTempDir: _telegramStatus?.importTempDir,
          sessionStorageFile: _telegramStatus?.sessionStorageFile,
        );
      });
      _showMessage('Telegram login code requested.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isRequestingCode = false;
      });
      _showMessage(_errorMessageFrom(error));
    }
  }

  Future<void> _confirmCode() async {
    final phoneNumber = _phoneController.text.trim();
    final code = _codeController.text.trim();
    if (phoneNumber.isEmpty || code.isEmpty) {
      _showMessage('Phone number and code are required.');
      return;
    }

    setState(() {
      _isConfirmingCode = true;
    });

    try {
      final status = await context
          .read<TelegramImportRepository>()
          .confirmAuthCode(phoneNumber: phoneNumber, code: code);
      if (!mounted) {
        return;
      }
      setState(() {
        _telegramStatus = status;
        _isConfirmingCode = false;
        _codeRequested = true;
      });
      if (status.authorized) {
        _codeController.clear();
        _passwordController.clear();
        _showMessage('Telegram account authorized.');
        await _loadStatus();
        return;
      }
      if (status.passwordRequired) {
        _showMessage('Telegram cloud password is required.');
        return;
      }
      _showMessage('Telegram login was not completed.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isConfirmingCode = false;
      });
      _showMessage(_errorMessageFrom(error));
    }
  }

  Future<void> _confirmPassword() async {
    final password = _passwordController.text.trim();
    if (password.isEmpty) {
      _showMessage('Cloud password is required.');
      return;
    }

    setState(() {
      _isConfirmingPassword = true;
    });

    try {
      final status = await context
          .read<TelegramImportRepository>()
          .confirmPassword(password: password);
      if (!mounted) {
        return;
      }
      setState(() {
        _telegramStatus = status;
        _isConfirmingPassword = false;
      });
      if (status.authorized) {
        _codeRequested = false;
        _codeController.clear();
        _passwordController.clear();
        _showMessage('Telegram account authorized.');
        await _loadStatus();
        return;
      }
      _showMessage(
        'Telegram password was accepted but authorization is incomplete.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isConfirmingPassword = false;
      });
      _showMessage(_errorMessageFrom(error));
    }
  }

  Future<void> _pickYouTubeCookiesFile() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    final file = result?.files.single;
    if (file == null || file.bytes == null) {
      return;
    }

    setState(() {
      _selectedYouTubeCookiesFileName = file.name;
      _selectedYouTubeCookiesBytes = file.bytes;
    });
  }

  Future<void> _uploadYouTubeCookiesFile() async {
    final fileName = _selectedYouTubeCookiesFileName;
    final bytes = _selectedYouTubeCookiesBytes;
    if (fileName == null || bytes == null) {
      _showMessage('Pick a cookies file first.');
      return;
    }

    setState(() {
      _isUploadingYouTubeCookies = true;
    });

    try {
      final status = await context
          .read<YouTubeCookiesRepository>()
          .uploadCookies(fileName: fileName, bytes: bytes);
      if (!mounted) {
        return;
      }
      setState(() {
        _isUploadingYouTubeCookies = false;
        _selectedYouTubeCookiesFileName = null;
        _selectedYouTubeCookiesBytes = null;
        _youTubeCookiesStatus = status;
      });
      _showMessage('YouTube cookies file uploaded.');
      await _refreshYouTubeCookiesStatus();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isUploadingYouTubeCookies = false;
      });
      _showMessage(_errorMessageFrom(error));
    }
  }

  Future<void> _deleteYouTubeCookiesFile() async {
    setState(() {
      _isDeletingYouTubeCookies = true;
    });

    try {
      await context.read<YouTubeCookiesRepository>().deleteCookies();
      if (!mounted) {
        return;
      }
      setState(() {
        _isDeletingYouTubeCookies = false;
      });
      _showMessage('YouTube cookies file removed.');
      await _refreshYouTubeCookiesStatus();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isDeletingYouTubeCookies = false;
      });
      _showMessage(_errorMessageFrom(error));
    }
  }

  Future<void> _refreshYouTubeCookiesStatus() async {
    try {
      final status = await context.read<YouTubeCookiesRepository>().getStatus();
      if (!mounted) {
        return;
      }
      setState(() {
        _youTubeCookiesStatus = status;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(_errorMessageFrom(error));
    }
  }

  String _errorMessageFrom(Object error) {
    if (error is HttpAppError) {
      return error.message;
    }
    return error.toString();
  }

  String _formatDateTime(DateTime dateTime) {
    final normalized = dateTime.toUtc();
    final date =
        '${normalized.year.toString().padLeft(4, '0')}-${normalized.month.toString().padLeft(2, '0')}-${normalized.day.toString().padLeft(2, '0')}';
    final time =
        '${normalized.hour.toString().padLeft(2, '0')}:${normalized.minute.toString().padLeft(2, '0')}';
    return '$date $time UTC';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SelectableText('$label: $value'),
    );
  }
}
