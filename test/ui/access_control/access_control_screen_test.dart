import 'package:esketit_music_console/domain/access_control.dart';
import 'package:esketit_music_console/domain/auth/app_user.dart';
import 'package:esketit_music_console/domain/auth/auth_session.dart';
import 'package:esketit_music_console/errors/http_app_error.dart';
import 'package:esketit_music_console/ui/access_control/access_control_screen.dart';
import 'package:esketit_music_console/use_case/access_control/access_control_repository.dart';
import 'package:esketit_music_console/use_case/auth/auth_repository.dart';
import 'package:esketit_music_console/use_case/auth/bloc/auth_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('protects direct navigation without permission', (tester) async {
    final accessRepository = _FakeAccessControlRepository();

    await _pumpRoute(
      tester,
      authRepository: _FakeAuthRepository(session: _session(canManage: false)),
      accessRepository: accessRepository,
    );

    expect(find.text('Access denied'), findsOneWidget);
    expect(find.text('Access Control'), findsNothing);
    expect(accessRepository.usersReadCount, 0);
  });

  testWidgets('renders multiple assigned roles and effective permissions', (
    tester,
  ) async {
    await _pumpRoute(
      tester,
      authRepository: _FakeAuthRepository(session: _session()),
      accessRepository: _FakeAccessControlRepository(),
    );

    expect(find.text('admin, editor'), findsOneWidget);
    expect(find.text('access_control.manage, tracks.create'), findsOneWidget);
    expect(find.text('Effective permissions (derived)'), findsOneWidget);
  });

  testWidgets('disables horizontal swipe tab switching', (tester) async {
    await _pumpRoute(
      tester,
      authRepository: _FakeAuthRepository(session: _session()),
      accessRepository: _FakeAccessControlRepository(),
    );

    final tabBarView = tester.widget<TabBarView>(find.byType(TabBarView));
    expect(tabBarView.physics, isA<NeverScrollableScrollPhysics>());
  });

  testWidgets('grows user rows to show long permission lists', (tester) async {
    final permissionCodes = List.generate(
      16,
      (index) => 'catalog.permission_${index + 1}',
    );
    final accessRepository = _FakeAccessControlRepository();
    accessRepository.users = [
      AccessControlUser(
        id: 7,
        email: 'admin@example.com',
        createdAt: DateTime.utc(2026, 1, 3),
        roles: [_adminRole],
        permissions: [
          for (var index = 0; index < permissionCodes.length; index++)
            AccessPermission(
              id: index + 10,
              code: permissionCodes[index],
              description: '',
              createdAt: DateTime.utc(2026, 1, 1),
            ),
        ],
      ),
    ];

    await _pumpRoute(
      tester,
      authRepository: _FakeAuthRepository(session: _session()),
      accessRepository: accessRepository,
    );

    final permissionsText = find.text(permissionCodes.join(', '));
    expect(permissionsText, findsOneWidget);
    expect(tester.getSize(permissionsText).height, greaterThan(48));
  });

  testWidgets('replaces the complete user role set and refreshes auth', (
    tester,
  ) async {
    final authRepository = _FakeAuthRepository(session: _session());
    final accessRepository = _FakeAccessControlRepository();
    await _pumpRoute(
      tester,
      authRepository: authRepository,
      accessRepository: accessRepository,
    );

    await _tapVisible(tester, find.byKey(const ValueKey('edit-user-roles-7')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('user-role-option-1')));
    await tester.tap(find.byKey(const ValueKey('save-user-roles')));
    await tester.pumpAndSettle();

    expect(accessRepository.lastUserId, 7);
    expect(accessRepository.lastRoleIds, [2]);
    expect(accessRepository.usersReadCount, 2);
    expect(authRepository.currentUserRefreshCount, 1);
    expect(find.text('Role assignments updated.'), findsOneWidget);
  });

  testWidgets('creates, updates, and deletes a custom role', (tester) async {
    final authRepository = _FakeAuthRepository(session: _session());
    final accessRepository = _FakeAccessControlRepository();
    await _pumpRoute(
      tester,
      authRepository: authRepository,
      accessRepository: accessRepository,
    );
    await tester.tap(find.text('Roles'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('create-role')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('role-name-field')),
      'importer',
    );
    await tester.enterText(
      find.byKey(const ValueKey('role-description-field')),
      'Imports music',
    );
    await tester.tap(find.byKey(const ValueKey('save-role')));
    await tester.pumpAndSettle();

    expect(accessRepository.createdRoleName, 'importer');
    expect(accessRepository.createdRoleDescription, 'Imports music');

    await _tapVisible(tester, find.byKey(const ValueKey('role-edit-2')));
    await tester.enterText(
      find.byKey(const ValueKey('role-name-field')),
      'catalog-editor',
    );
    await tester.tap(find.byKey(const ValueKey('save-role')));
    await tester.pumpAndSettle();

    expect(accessRepository.updatedRoleId, 2);
    expect(accessRepository.updatedRoleName, 'catalog-editor');

    await _tapVisible(tester, find.byKey(const ValueKey('role-delete-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(accessRepository.deletedRoleId, 2);
    expect(authRepository.currentUserRefreshCount, 3);
  });

  testWidgets('prevents system role rename and delete in the UI', (
    tester,
  ) async {
    await _pumpRoute(
      tester,
      authRepository: _FakeAuthRepository(session: _session()),
      accessRepository: _FakeAccessControlRepository(),
    );
    await tester.tap(find.text('Roles'));
    await tester.pumpAndSettle();

    final deleteButton = tester.widget<IconButton>(
      find.byKey(const ValueKey('role-delete-1')),
    );
    expect(deleteButton.onPressed, isNull);

    await _tapVisible(tester, find.byKey(const ValueKey('role-edit-1')));
    final nameField = tester.widget<TextFormField>(
      find.byKey(const ValueKey('role-name-field')),
    );
    expect(nameField.enabled, isFalse);
    expect(find.text('System role names cannot be changed.'), findsOneWidget);
  });

  testWidgets('replaces a role complete permission set', (tester) async {
    final accessRepository = _FakeAccessControlRepository();
    await _pumpRoute(
      tester,
      authRepository: _FakeAuthRepository(session: _session()),
      accessRepository: accessRepository,
    );
    await tester.tap(find.text('Roles'));
    await tester.pumpAndSettle();

    await _tapVisible(tester, find.byKey(const ValueKey('role-permissions-2')));
    await tester.tap(find.byKey(const ValueKey('role-permission-option-2')));
    await tester.tap(find.byKey(const ValueKey('role-permission-option-1')));
    await tester.tap(find.byKey(const ValueKey('save-role-permissions')));
    await tester.pumpAndSettle();

    expect(accessRepository.permissionsRoleId, 2);
    expect(accessRepository.lastPermissionIds, [1]);
  });

  testWidgets('permission registry is read-only and searchable', (
    tester,
  ) async {
    await _pumpRoute(
      tester,
      authRepository: _FakeAuthRepository(session: _session()),
      accessRepository: _FakeAccessControlRepository(),
    );
    await tester.tap(find.text('Permissions'));
    await tester.pumpAndSettle();

    expect(find.text('access_control.manage'), findsOneWidget);
    expect(find.text('tracks.create'), findsOneWidget);
    expect(find.textContaining('Create permission'), findsNothing);
    expect(find.textContaining('Delete permission'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('permission-search')),
      'tracks',
    );
    await tester.pump();
    expect(find.text('tracks.create'), findsOneWidget);
    expect(find.text('access_control.manage'), findsNothing);
  });

  testWidgets('displays known and unknown audit values', (tester) async {
    await _pumpRoute(
      tester,
      authRepository: _FakeAuthRepository(session: _session()),
      accessRepository: _FakeAccessControlRepository(),
    );
    await tester.tap(find.text('Audit log'));
    await tester.pumpAndSettle();

    expect(find.text('future.action.value'), findsOneWidget);
    expect(find.text('admin@example.com (#7)'), findsOneWidget);
    expect(find.text('Role #999'), findsOneWidget);
    expect(find.text('{"source":"test"}'), findsOneWidget);
  });

  testWidgets('shows the backend final-manager conflict message', (
    tester,
  ) async {
    final accessRepository = _FakeAccessControlRepository(
      replaceUserRolesError: const HttpAppError(
        message:
            'at least one user must retain access-control management permission',
        path: '/access-control/users/7/roles',
        statusCode: 409,
      ),
    );
    await _pumpRoute(
      tester,
      authRepository: _FakeAuthRepository(session: _session()),
      accessRepository: accessRepository,
    );

    await _tapVisible(tester, find.byKey(const ValueKey('edit-user-roles-7')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear all'));
    await tester.tap(find.byKey(const ValueKey('save-user-roles')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'at least one user must retain access-control management permission',
      ),
      findsWidgets,
    );
  });

  testWidgets('refreshes auth on 403 and handles 500 visibly', (tester) async {
    final authRepository = _FakeAuthRepository(session: _session());
    final accessRepository = _FakeAccessControlRepository(
      usersReadErrors: [ForbiddenAppError(path: '/access-control/users')],
    );
    await _pumpRoute(
      tester,
      authRepository: authRepository,
      accessRepository: accessRepository,
    );

    expect(authRepository.currentUserRefreshCount, 1);
    expect(find.textContaining('Permission denied'), findsOneWidget);

    accessRepository.usersReadErrors.add(
      const HttpAppError(
        message: 'Request failed',
        path: '/access-control/users',
        statusCode: 500,
      ),
    );
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(
      find.text('The server could not complete the request. Try again.'),
      findsOneWidget,
    );
  });

  testWidgets('handles 401 through the session-expiration flow', (
    tester,
  ) async {
    final authRepository = _FakeAuthRepository(
      session: _session(),
      expireOnSecondRestore: true,
    );
    await _pumpRoute(
      tester,
      authRepository: authRepository,
      accessRepository: _FakeAccessControlRepository(
        usersReadErrors: [UnauthorizedAppError(path: '/access-control/users')],
      ),
    );

    expect(authRepository.restoreCount, 2);
    expect(find.text('Access denied'), findsOneWidget);
  });

  testWidgets('refreshes stale lists after a mutation 404', (tester) async {
    final accessRepository = _FakeAccessControlRepository(
      replaceUserRolesError: const HttpAppError(
        message: 'user not found',
        path: '/access-control/users/7/roles',
        statusCode: 404,
      ),
    );
    await _pumpRoute(
      tester,
      authRepository: _FakeAuthRepository(session: _session()),
      accessRepository: accessRepository,
    );
    await _tapVisible(tester, find.byKey(const ValueKey('edit-user-roles-7')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-user-roles')));
    await tester.pumpAndSettle();

    expect(accessRepository.usersReadCount, 2);
    expect(accessRepository.rolesReadCount, 2);
    expect(find.textContaining('no longer exists'), findsWidgets);
  });

  testWidgets('leaves the restricted route after self-revocation', (
    tester,
  ) async {
    final authRepository = _FakeAuthRepository(
      session: _session(),
      refreshedSession: _session(canManage: false),
    );
    await _pumpRoute(
      tester,
      authRepository: authRepository,
      accessRepository: _FakeAccessControlRepository(),
      withSafeRoute: true,
    );

    await _tapVisible(tester, find.byKey(const ValueKey('edit-user-roles-7')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-user-roles')));
    await tester.pumpAndSettle();

    expect(find.text('Safe page'), findsOneWidget);
    expect(find.text('Access Control'), findsNothing);
  });
}

Future<void> _pumpRoute(
  WidgetTester tester, {
  required _FakeAuthRepository authRepository,
  required _FakeAccessControlRepository accessRepository,
  bool withSafeRoute = false,
}) async {
  tester.view.physicalSize = const Size(1500, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final authBloc = AuthBloc(authRepository: authRepository)
    ..add(const AuthSessionRestoreRequested());
  addTearDown(authBloc.close);

  await tester.pumpWidget(
    RepositoryProvider<AccessControlRepository>.value(
      value: accessRepository,
      child: BlocProvider<AuthBloc>.value(
        value: authBloc,
        child: withSafeRoute
            ? MaterialApp(
                initialRoute: AccessControlRoute.routeName,
                routes: {
                  '/': (_) => const Scaffold(body: Text('Safe page')),
                  AccessControlRoute.routeName: (_) =>
                      const AccessControlRoute(),
                },
              )
            : const MaterialApp(home: AccessControlRoute()),
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

AuthSession _session({bool canManage = true}) {
  return AuthSession(
    user: AppUser(
      id: 7,
      email: 'admin@example.com',
      createdAt: DateTime.utc(2026, 1, 1),
      roles: const [],
      permissions: canManage ? [_managePermission] : const [],
    ),
    accessToken: 'token',
    accessTokenExpiresAt: DateTime.utc(2099, 1, 1),
    refreshToken: 'refresh',
    refreshTokenExpiresAt: DateTime.utc(2099, 1, 2),
  );
}

final _managePermission = AccessPermission(
  id: 1,
  code: accessControlManagePermission,
  description: 'Manage access control',
  createdAt: DateTime.utc(2026, 1, 1),
);

final _tracksPermission = AccessPermission(
  id: 2,
  code: 'tracks.create',
  description: 'Create tracks',
  createdAt: DateTime.utc(2026, 1, 1),
);

final _adminRole = AccessRole(
  id: 1,
  name: 'admin',
  description: 'Full administration',
  system: true,
  createdAt: DateTime.utc(2026, 1, 1),
  permissions: [_managePermission, _tracksPermission],
);

final _editorRole = AccessRole(
  id: 2,
  name: 'editor',
  description: 'Edits the catalog',
  system: false,
  createdAt: DateTime.utc(2026, 1, 2),
  permissions: [_tracksPermission],
);

final _accessUser = AccessControlUser(
  id: 7,
  email: 'admin@example.com',
  createdAt: DateTime.utc(2026, 1, 3),
  roles: [_adminRole, _editorRole],
  permissions: [_managePermission, _tracksPermission],
);

final _auditEvent = AccessControlAuditEvent(
  id: 5,
  actorUserId: 7,
  action: 'future.action.value',
  targetRoleId: 999,
  details: const {'source': 'test'},
  createdAt: DateTime.utc(2026, 1, 4),
);

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({
    required this.session,
    this.refreshedSession,
    this.expireOnSecondRestore = false,
  });

  final AuthSession session;
  final AuthSession? refreshedSession;
  final bool expireOnSecondRestore;
  int restoreCount = 0;
  int currentUserRefreshCount = 0;

  @override
  Future<AuthSession?> restoreSession() async {
    restoreCount += 1;
    if (expireOnSecondRestore && restoreCount > 1) {
      return null;
    }
    return session;
  }

  @override
  Future<AuthSession?> refreshCurrentUser() async {
    currentUserRefreshCount += 1;
    return refreshedSession ?? session;
  }

  @override
  Future<AuthSession?> refreshSession({bool forceRefresh = false}) async =>
      session;

  @override
  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async => session;

  @override
  Future<void> signOut() async {}
}

class _FakeAccessControlRepository implements AccessControlRepository {
  _FakeAccessControlRepository({
    this.replaceUserRolesError,
    List<Object>? usersReadErrors,
  }) : usersReadErrors = usersReadErrors ?? [];

  final Object? replaceUserRolesError;
  final List<Object> usersReadErrors;
  List<AccessControlUser> users = [_accessUser];
  List<AccessRole> roles = [_adminRole, _editorRole];
  final List<AccessPermission> permissions = [
    _managePermission,
    _tracksPermission,
  ];
  final List<AccessControlAuditEvent> events = [_auditEvent];
  int usersReadCount = 0;
  int rolesReadCount = 0;
  int? lastUserId;
  List<int>? lastRoleIds;
  String? createdRoleName;
  String? createdRoleDescription;
  int? updatedRoleId;
  String? updatedRoleName;
  int? deletedRoleId;
  int? permissionsRoleId;
  List<int>? lastPermissionIds;

  @override
  Future<List<AccessControlUser>> getUsers() async {
    usersReadCount += 1;
    if (usersReadErrors.isNotEmpty) {
      throw usersReadErrors.removeAt(0);
    }
    return List.from(users);
  }

  @override
  Future<List<AccessRole>> getRoles() async {
    rolesReadCount += 1;
    return List.from(roles);
  }

  @override
  Future<List<AccessPermission>> getPermissions() async =>
      List.from(permissions);

  @override
  Future<List<AccessControlAuditEvent>> getAuditEvents({
    int limit = 100,
  }) async => List.from(events);

  @override
  Future<UserAccessProfile> replaceUserRoles(
    int userId,
    List<int> roleIds,
  ) async {
    lastUserId = userId;
    lastRoleIds = List.from(roleIds);
    if (replaceUserRolesError != null) {
      throw replaceUserRolesError!;
    }
    final selectedRoles = roles
        .where((role) => roleIds.contains(role.id))
        .toList();
    final selectedPermissions = {
      for (final role in selectedRoles)
        for (final permission in role.permissions) permission.id: permission,
    }.values.toList();
    users = users
        .map(
          (user) => user.id == userId
              ? AccessControlUser(
                  id: user.id,
                  email: user.email,
                  createdAt: user.createdAt,
                  roles: selectedRoles,
                  permissions: selectedPermissions,
                )
              : user,
        )
        .toList();
    return UserAccessProfile(
      roles: selectedRoles,
      permissions: selectedPermissions,
    );
  }

  @override
  Future<AccessRole> createRole({
    required String name,
    required String description,
  }) async {
    createdRoleName = name;
    createdRoleDescription = description;
    final role = AccessRole(
      id: 3,
      name: name,
      description: description,
      system: false,
      createdAt: DateTime.utc(2026, 2, 1),
      permissions: const [],
    );
    roles = [...roles, role];
    return role;
  }

  @override
  Future<AccessRole> updateRole(
    int roleId, {
    required String name,
    required String description,
  }) async {
    updatedRoleId = roleId;
    updatedRoleName = name;
    final previous = roles.singleWhere((role) => role.id == roleId);
    final updated = AccessRole(
      id: roleId,
      name: name,
      description: description,
      system: previous.system,
      createdAt: previous.createdAt,
      permissions: previous.permissions,
    );
    roles = roles.map((role) => role.id == roleId ? updated : role).toList();
    return updated;
  }

  @override
  Future<void> deleteRole(int roleId) async {
    deletedRoleId = roleId;
    roles = roles.where((role) => role.id != roleId).toList();
  }

  @override
  Future<AccessRole> replaceRolePermissions(
    int roleId,
    List<int> permissionIds,
  ) async {
    permissionsRoleId = roleId;
    lastPermissionIds = List.from(permissionIds);
    final previous = roles.singleWhere((role) => role.id == roleId);
    final updated = AccessRole(
      id: previous.id,
      name: previous.name,
      description: previous.description,
      system: previous.system,
      createdAt: previous.createdAt,
      permissions: permissions
          .where((permission) => permissionIds.contains(permission.id))
          .toList(),
    );
    roles = roles.map((role) => role.id == roleId ? updated : role).toList();
    return updated;
  }
}
