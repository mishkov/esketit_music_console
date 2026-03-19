import 'package:esketit_music_console/errors/http_app_error.dart';
import 'package:esketit_music_console/esketit_rest_api/telegram/telegram_import_models.dart';
import 'package:esketit_music_console/use_case/telegram/telegram_import_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();

  TelegramStatus? _status;
  bool _isLoading = true;
  bool _isRequestingCode = false;
  bool _isConfirmingCode = false;
  bool _isConfirmingPassword = false;
  String? _errorMessage;
  bool _codeRequested = false;

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
                      title: 'Telegram Integration',
                      child: _buildTelegramSection(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTelegramSection(BuildContext context) {
    final status = _status;
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

  Future<void> _loadStatus() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final status = await context.read<TelegramImportRepository>().getStatus();
      if (!mounted) {
        return;
      }
      setState(() {
        _status = status;
        _isLoading = false;
        _isConfirmingCode = false;
        _isConfirmingPassword = false;
        if (status.authorized) {
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
        _status = TelegramStatus(
          configured: _status?.configured ?? true,
          authorized: false,
          passwordRequired: false,
          accountIdentifier: _status?.accountIdentifier,
          importTempDir: _status?.importTempDir,
          sessionStorageFile: _status?.sessionStorageFile,
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
        _status = status;
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
        _status = status;
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

  String _errorMessageFrom(Object error) {
    if (error is HttpAppError) {
      return error.message;
    }
    return error.toString();
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
