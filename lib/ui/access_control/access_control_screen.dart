import 'dart:convert';

import 'package:esketit_music_console/domain/access_control.dart';
import 'package:esketit_music_console/errors/http_app_error.dart';
import 'package:esketit_music_console/use_case/access_control/access_control_repository.dart';
import 'package:esketit_music_console/use_case/auth/bloc/auth_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

const accessControlManagePermission = 'access_control.manage';

class AccessControlRoute extends StatelessWidget {
  const AccessControlRoute({super.key});

  static const routeName = '/access-control';

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (previous, current) =>
          previous.session?.user.permissions !=
          current.session?.user.permissions,
      listener: (context, state) {
        if (!_canManageAccessControl(state)) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      },
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          if (!_canManageAccessControl(state)) {
            return const ForbiddenScreen();
          }
          return const AccessControlScreen();
        },
      ),
    );
  }
}

class ForbiddenScreen extends StatelessWidget {
  const ForbiddenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Access denied')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline,
                size: 56,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'You do not have permission to manage access control.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                },
                child: const Text('Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

bool _canManageAccessControl(AuthState state) =>
    state.session?.user.hasPermission(accessControlManagePermission) ?? false;

class AccessControlScreen extends StatefulWidget {
  const AccessControlScreen({super.key});

  @override
  State<AccessControlScreen> createState() => _AccessControlScreenState();
}

class _AccessControlScreenState extends State<AccessControlScreen> {
  final _permissionSearchController = TextEditingController();
  List<AccessControlUser> _users = const [];
  List<AccessRole> _roles = const [];
  List<AccessPermission> _permissions = const [];
  List<AccessControlAuditEvent> _auditEvents = const [];
  bool _isLoading = true;
  bool _isMutating = false;
  String? _errorMessage;
  String _permissionQuery = '';

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _permissionSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Access Control'),
          actions: [
            IconButton(
              onPressed: _isLoading || _isMutating ? null : _loadAll,
              tooltip: 'Reload access control',
              icon: const Icon(Icons.refresh),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(key: ValueKey('access-control-users-tab'), text: 'Users'),
              Tab(key: ValueKey('access-control-roles-tab'), text: 'Roles'),
              Tab(
                key: ValueKey('access-control-permissions-tab'),
                text: 'Permissions',
              ),
              Tab(key: ValueKey('access-control-audit-tab'), text: 'Audit log'),
            ],
          ),
        ),
        body: Column(
          children: [
            if (_isLoading || _isMutating) const LinearProgressIndicator(),
            if (_errorMessage != null)
              MaterialBanner(
                content: Text(_errorMessage!),
                actions: [
                  TextButton(onPressed: _loadAll, child: const Text('Retry')),
                ],
              ),
            Expanded(
              child: _isLoading && _users.isEmpty && _roles.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildUsersTab(),
                        _buildRolesTab(),
                        _buildPermissionsTab(),
                        _buildAuditTab(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersTab() {
    if (_users.isEmpty) {
      return const _EmptyState(
        icon: Icons.people_outline,
        message: 'No users found.',
      );
    }

    return _TableViewport(
      child: DataTable(
        dataRowMaxHeight: double.infinity,
        columns: const [
          DataColumn(label: Text('Email')),
          DataColumn(label: Text('Assigned roles')),
          DataColumn(label: Text('Effective permissions (derived)')),
          DataColumn(label: Text('Created')),
          DataColumn(label: Text('Actions')),
        ],
        rows: _users.map((user) {
          return DataRow(
            key: ValueKey('access-control-user-${user.id}'),
            cells: [
              DataCell(SelectableText(user.email)),
              DataCell(
                _ValuesCell(
                  values: user.roles.map((role) => role.name).toList(),
                  emptyLabel: 'No roles',
                ),
              ),
              DataCell(
                _ValuesCell(
                  values: user.permissions
                      .map((permission) => permission.code)
                      .toList(),
                  emptyLabel: 'No effective permissions',
                ),
              ),
              DataCell(Text(_formatDate(user.createdAt))),
              DataCell(
                IconButton(
                  key: ValueKey('edit-user-roles-${user.id}'),
                  onPressed: _isMutating ? null : () => _editUserRoles(user),
                  tooltip: 'Edit role assignments',
                  icon: const Icon(Icons.manage_accounts_outlined),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRolesTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              key: const ValueKey('create-role'),
              onPressed: _isMutating ? null : () => _editRole(),
              icon: const Icon(Icons.add),
              label: const Text('Create role'),
            ),
          ),
        ),
        Expanded(
          child: _roles.isEmpty
              ? const _EmptyState(
                  icon: Icons.shield_outlined,
                  message: 'No roles found.',
                )
              : _TableViewport(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Role')),
                      DataColumn(label: Text('Description')),
                      DataColumn(label: Text('Permissions')),
                      DataColumn(label: Text('Created')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: _roles.map((role) {
                      return DataRow(
                        key: ValueKey('access-role-${role.id}'),
                        cells: [
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SelectableText(role.name),
                                if (role.system) ...[
                                  const SizedBox(width: 8),
                                  const Chip(
                                    label: Text('System'),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          DataCell(
                            SizedBox(
                              width: 280,
                              child: Text(
                                role.description.isEmpty
                                    ? 'No description'
                                    : role.description,
                              ),
                            ),
                          ),
                          DataCell(Text('${role.permissions.length}')),
                          DataCell(Text(_formatDate(role.createdAt))),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  key: ValueKey('role-permissions-${role.id}'),
                                  onPressed: _isMutating
                                      ? null
                                      : () => _editRolePermissions(role),
                                  tooltip: 'Edit permissions',
                                  icon: const Icon(Icons.key_outlined),
                                ),
                                IconButton(
                                  key: ValueKey('role-edit-${role.id}'),
                                  onPressed: _isMutating
                                      ? null
                                      : () => _editRole(role: role),
                                  tooltip: role.system
                                      ? 'Edit system role description'
                                      : 'Edit role',
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                                IconButton(
                                  key: ValueKey('role-delete-${role.id}'),
                                  onPressed: role.system || _isMutating
                                      ? null
                                      : () => _deleteRole(role),
                                  tooltip: role.system
                                      ? 'System roles cannot be deleted'
                                      : 'Delete role',
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildPermissionsTab() {
    final query = _permissionQuery.trim().toLowerCase();
    final filtered = _permissions.where((permission) {
      return query.isEmpty ||
          permission.code.toLowerCase().contains(query) ||
          permission.description.toLowerCase().contains(query);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            key: const ValueKey('permission-search'),
            controller: _permissionSearchController,
            decoration: const InputDecoration(
              labelText: 'Search permissions',
              hintText: 'Code or description',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => setState(() => _permissionQuery = value),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const _EmptyState(
                  icon: Icons.key_off_outlined,
                  message: 'No permissions found.',
                )
              : _TableViewport(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Code')),
                      DataColumn(label: Text('Description')),
                      DataColumn(label: Text('Created')),
                    ],
                    rows: filtered
                        .map(
                          (permission) => DataRow(
                            key: ValueKey('permission-${permission.id}'),
                            cells: [
                              DataCell(SelectableText(permission.code)),
                              DataCell(
                                SizedBox(
                                  width: 380,
                                  child: Text(permission.description),
                                ),
                              ),
                              DataCell(Text(_formatDate(permission.createdAt))),
                            ],
                          ),
                        )
                        .toList(),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildAuditTab() {
    if (_auditEvents.isEmpty) {
      return const _EmptyState(
        icon: Icons.history,
        message: 'No audit events found.',
      );
    }

    return _TableViewport(
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Timestamp')),
          DataColumn(label: Text('Action')),
          DataColumn(label: Text('Actor')),
          DataColumn(label: Text('Target')),
          DataColumn(label: Text('Details')),
        ],
        rows: _auditEvents.map((event) {
          return DataRow(
            key: ValueKey('audit-event-${event.id}'),
            cells: [
              DataCell(Text(_formatDate(event.createdAt))),
              DataCell(SelectableText(event.action)),
              DataCell(Text(_userLabel(event.actorUserId))),
              DataCell(Text(_targetLabel(event))),
              DataCell(
                SizedBox(
                  width: 320,
                  child: SelectableText(
                    event.details.isEmpty ? '—' : jsonEncode(event.details),
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Future<void> _loadAll() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final repository = context.read<AccessControlRepository>();
      final results = await Future.wait<Object>([
        repository.getUsers(),
        repository.getRoles(),
        repository.getPermissions(),
        repository.getAuditEvents(),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _users = results[0] as List<AccessControlUser>;
        _roles = results[1] as List<AccessRole>;
        _permissions = results[2] as List<AccessPermission>;
        _auditEvents = results[3] as List<AccessControlAuditEvent>;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = _messageFor(error);
      });
      await _handleAuthOrStaleResourceError(error);
    }
  }

  Future<void> _editUserRoles(AccessControlUser user) async {
    final roleIds = await showDialog<Set<int>>(
      context: context,
      builder: (context) => _RoleSelectionDialog(user: user, roles: _roles),
    );
    if (roleIds == null || !mounted) {
      return;
    }

    await _runMutation('Role assignments updated.', () async {
      final profile = await context
          .read<AccessControlRepository>()
          .replaceUserRoles(user.id, roleIds.toList()..sort());
      if (mounted) {
        setState(() {
          _users = _users
              .map(
                (item) => item.id == user.id
                    ? AccessControlUser(
                        id: item.id,
                        email: item.email,
                        createdAt: item.createdAt,
                        roles: profile.roles,
                        permissions: profile.permissions,
                      )
                    : item,
              )
              .toList(growable: false);
        });
      }
    });
  }

  Future<void> _editRole({AccessRole? role}) async {
    final input = await showDialog<_RoleInput>(
      context: context,
      builder: (context) => _RoleEditorDialog(role: role),
    );
    if (input == null || !mounted) {
      return;
    }

    await _runMutation(role == null ? 'Role created.' : 'Role updated.', () {
      final repository = context.read<AccessControlRepository>();
      if (role == null) {
        return repository.createRole(
          name: input.name,
          description: input.description,
        );
      }
      return repository.updateRole(
        role.id,
        name: role.system ? role.name : input.name,
        description: input.description,
      );
    });
  }

  Future<void> _deleteRole(AccessRole role) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete role?'),
        content: Text(
          'Delete “${role.name}”? Users assigned only this role may lose access.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await _runMutation(
      'Role deleted.',
      () => context.read<AccessControlRepository>().deleteRole(role.id),
    );
  }

  Future<void> _editRolePermissions(AccessRole role) async {
    final permissionIds = await showDialog<Set<int>>(
      context: context,
      builder: (context) =>
          _PermissionSelectionDialog(role: role, permissions: _permissions),
    );
    if (permissionIds == null || !mounted) {
      return;
    }
    await _runMutation(
      'Role permissions updated.',
      () => context.read<AccessControlRepository>().replaceRolePermissions(
        role.id,
        permissionIds.toList()..sort(),
      ),
    );
  }

  Future<void> _runMutation(
    String successMessage,
    Future<void> Function() mutation,
  ) async {
    if (_isMutating) {
      return;
    }
    setState(() {
      _isMutating = true;
      _errorMessage = null;
    });
    try {
      await mutation();
      await _refreshDataAfterMutation();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = _messageFor(error);
      setState(() => _errorMessage = message);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      await _handleAuthOrStaleResourceError(error);
    } finally {
      if (mounted) {
        setState(() => _isMutating = false);
      }
    }
  }

  Future<void> _refreshDataAfterMutation() async {
    final repository = context.read<AccessControlRepository>();
    try {
      final results = await Future.wait<Object>([
        repository.getUsers(),
        repository.getRoles(),
        repository.getPermissions(),
        repository.getAuditEvents(),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _users = results[0] as List<AccessControlUser>;
        _roles = results[1] as List<AccessRole>;
        _permissions = results[2] as List<AccessPermission>;
        _auditEvents = results[3] as List<AccessControlAuditEvent>;
      });
    } finally {
      if (mounted) {
        await _refreshAuthorizationAfterMutation();
      }
    }
  }

  Future<void> _refreshAuthorizationAfterMutation() async {
    final session = await context.read<AuthBloc>().refreshCurrentUser();
    if (!mounted) {
      return;
    }
    if (!(session?.user.hasPermission(accessControlManagePermission) ??
        false)) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<void> _handleAuthOrStaleResourceError(Object error) async {
    if (error is UnauthorizedAppError) {
      context.read<AuthBloc>().add(const AuthSessionRestoreRequested());
      return;
    }
    if (error is ForbiddenAppError) {
      await context.read<AuthBloc>().refreshCurrentUser();
      return;
    }
    if (error is HttpAppError && error.statusCode == 404) {
      await _reloadListsAfterNotFound();
    }
  }

  Future<void> _reloadListsAfterNotFound() async {
    try {
      final repository = context.read<AccessControlRepository>();
      final results = await Future.wait<Object>([
        repository.getUsers(),
        repository.getRoles(),
      ]);
      if (mounted) {
        setState(() {
          _users = results[0] as List<AccessControlUser>;
          _roles = results[1] as List<AccessRole>;
        });
      }
    } catch (_) {
      // Preserve the original actionable error; Retry remains available.
    }
  }

  String _messageFor(Object error) {
    if (error is HttpAppError) {
      if (error.statusCode == 409) {
        return error.message == 'Request failed'
            ? 'The change conflicts with access-control rules. At least one user must retain access-control management permission.'
            : error.message;
      }
      return switch (error.statusCode) {
        400 =>
          error.message == 'Request failed'
              ? 'The server rejected the invalid access-control data.'
              : error.message,
        401 => 'Your session expired. Sign in again.',
        403 => 'Permission denied. Your access profile has been refreshed.',
        404 => 'The user or role no longer exists. The lists were refreshed.',
        500 => 'The server could not complete the request. Try again.',
        _ => error.message,
      };
    }
    return 'Unable to complete the access-control request: $error';
  }

  String _userLabel(int? id) {
    if (id == null) {
      return 'Unknown actor';
    }
    for (final user in _users) {
      if (user.id == id) {
        return '${user.email} (#$id)';
      }
    }
    return 'User #$id';
  }

  String _targetLabel(AccessControlAuditEvent event) {
    final parts = <String>[];
    final userId = event.targetUserId;
    if (userId != null) {
      parts.add(_userLabel(userId));
    }
    final roleId = event.targetRoleId;
    if (roleId != null) {
      final role = _findRole(roleId);
      parts.add(role == null ? 'Role #$roleId' : '${role.name} (#$roleId)');
    }
    final permissionId = event.targetPermissionId;
    if (permissionId != null) {
      final permission = _findPermission(permissionId);
      parts.add(
        permission == null
            ? 'Permission #$permissionId'
            : '${permission.code} (#$permissionId)',
      );
    }
    return parts.isEmpty ? '—' : parts.join(', ');
  }

  AccessRole? _findRole(int id) {
    for (final role in _roles) {
      if (role.id == id) {
        return role;
      }
    }
    return null;
  }

  AccessPermission? _findPermission(int id) {
    for (final permission in _permissions) {
      if (permission.id == id) {
        return permission;
      }
    }
    return null;
  }
}

class _RoleSelectionDialog extends StatefulWidget {
  const _RoleSelectionDialog({required this.user, required this.roles});

  final AccessControlUser user;
  final List<AccessRole> roles;

  @override
  State<_RoleSelectionDialog> createState() => _RoleSelectionDialogState();
}

class _RoleSelectionDialogState extends State<_RoleSelectionDialog> {
  late final Set<int> _selectedIds = widget.user.roles
      .map((role) => role.id)
      .toSet();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Roles for ${widget.user.email}'),
      content: SizedBox(
        width: 480,
        child: widget.roles.isEmpty
            ? const Text('No roles are available. Saving will assign no roles.')
            : ListView(
                shrinkWrap: true,
                children: widget.roles
                    .map(
                      (role) => CheckboxListTile(
                        key: ValueKey('user-role-option-${role.id}'),
                        value: _selectedIds.contains(role.id),
                        title: Text(role.name),
                        subtitle: role.description.isEmpty
                            ? null
                            : Text(role.description),
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: (selected) {
                          setState(() {
                            if (selected ?? false) {
                              _selectedIds.add(role.id);
                            } else {
                              _selectedIds.remove(role.id);
                            }
                          });
                        },
                      ),
                    )
                    .toList(),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => setState(_selectedIds.clear),
          child: const Text('Clear all'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('save-user-roles'),
          onPressed: () => Navigator.of(context).pop(_selectedIds),
          child: const Text('Save roles'),
        ),
      ],
    );
  }
}

class _RoleEditorDialog extends StatefulWidget {
  const _RoleEditorDialog({this.role});

  final AccessRole? role;

  @override
  State<_RoleEditorDialog> createState() => _RoleEditorDialogState();
}

class _RoleEditorDialogState extends State<_RoleEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController = TextEditingController(
    text: widget.role?.name ?? '',
  );
  late final TextEditingController _descriptionController =
      TextEditingController(text: widget.role?.description ?? '');

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.role;
    return AlertDialog(
      title: Text(role == null ? 'Create role' : 'Edit role'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const ValueKey('role-name-field'),
                controller: _nameController,
                enabled: !(role?.system ?? false),
                autofocus: role == null,
                maxLength: 100,
                decoration: InputDecoration(
                  labelText: 'Name',
                  helperText: role?.system ?? false
                      ? 'System role names cannot be changed.'
                      : null,
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Role name is required.'
                    : null,
              ),
              TextFormField(
                key: const ValueKey('role-description-field'),
                controller: _descriptionController,
                maxLength: 500,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('save-role'),
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) {
              return;
            }
            Navigator.of(context).pop(
              _RoleInput(
                name: _nameController.text.trim(),
                description: _descriptionController.text.trim(),
              ),
            );
          },
          child: Text(role == null ? 'Create' : 'Save'),
        ),
      ],
    );
  }
}

class _RoleInput {
  const _RoleInput({required this.name, required this.description});

  final String name;
  final String description;
}

class _PermissionSelectionDialog extends StatefulWidget {
  const _PermissionSelectionDialog({
    required this.role,
    required this.permissions,
  });

  final AccessRole role;
  final List<AccessPermission> permissions;

  @override
  State<_PermissionSelectionDialog> createState() =>
      _PermissionSelectionDialogState();
}

class _PermissionSelectionDialogState
    extends State<_PermissionSelectionDialog> {
  late final Set<int> _selectedIds = widget.role.permissions
      .map((permission) => permission.id)
      .toSet();

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<AccessPermission>>{};
    for (final permission in widget.permissions) {
      final prefix = permission.code.split('.').first;
      groups.putIfAbsent(prefix, () => []).add(permission);
    }
    final groupNames = groups.keys.toList()..sort();

    return AlertDialog(
      title: Text('Permissions for ${widget.role.name}'),
      content: SizedBox(
        width: 620,
        height: 520,
        child: widget.permissions.isEmpty
            ? const Center(child: Text('No permissions are available.'))
            : ListView(
                children: [
                  for (final groupName in groupNames) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Text(
                        groupName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    for (final permission in groups[groupName]!)
                      CheckboxListTile(
                        key: ValueKey(
                          'role-permission-option-${permission.id}',
                        ),
                        value: _selectedIds.contains(permission.id),
                        title: Text(permission.code),
                        subtitle: Text(permission.description),
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: (selected) {
                          setState(() {
                            if (selected ?? false) {
                              _selectedIds.add(permission.id);
                            } else {
                              _selectedIds.remove(permission.id);
                            }
                          });
                        },
                      ),
                  ],
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => setState(_selectedIds.clear),
          child: const Text('Clear all'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('save-role-permissions'),
          onPressed: () => Navigator.of(context).pop(_selectedIds),
          child: const Text('Save permissions'),
        ),
      ],
    );
  }
}

class _TableViewport extends StatelessWidget {
  const _TableViewport({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      child: SingleChildScrollView(
        padding: padding,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: child,
        ),
      ),
    );
  }
}

class _ValuesCell extends StatelessWidget {
  const _ValuesCell({required this.values, required this.emptyLabel});

  final List<String> values;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      child: Text(values.isEmpty ? emptyLabel : values.join(', ')),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48),
          const SizedBox(height: 12),
          Text(message),
        ],
      ),
    );
  }
}

String _formatDate(DateTime value) {
  final local = value.toLocal().toIso8601String();
  return local.length >= 16
      ? local.substring(0, 16).replaceFirst('T', ' ')
      : local;
}
