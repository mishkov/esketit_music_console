import 'dart:convert';

import 'package:esketit_music_console/domain/access_control.dart';
import 'package:esketit_music_console/domain/auth/app_user.dart';
import 'package:esketit_music_console/domain/auth/auth_session.dart';
import 'package:esketit_music_console/unassigned_layer/shared_preferences_auth_session_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'persists roles and permissions without a singular role field',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = SharedPreferencesAuthSessionStorage();
      final session = AuthSession(
        user: AppUser(
          id: 7,
          email: 'admin@example.com',
          createdAt: DateTime.utc(2026, 1, 1),
          roles: [_role],
          permissions: [_permission],
        ),
        accessToken: 'access',
        accessTokenExpiresAt: DateTime.utc(2099, 1, 1),
        refreshToken: 'refresh',
        refreshTokenExpiresAt: DateTime.utc(2099, 2, 1),
      );

      await storage.write(session);

      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString('auth_session_v1');
      final json = jsonDecode(raw!) as Map<String, dynamic>;
      final userJson = json['user'] as Map<String, dynamic>;
      expect(userJson.containsKey('role'), isFalse);
      expect(userJson['roles'], hasLength(1));
      expect(userJson['permissions'], hasLength(1));

      final restored = await storage.read();
      expect(restored, session);
      expect(restored?.user.hasPermission('access_control.manage'), isTrue);
    },
  );
}

final _permission = AccessPermission(
  id: 1,
  code: 'access_control.manage',
  description: 'Manage access control',
  createdAt: DateTime.utc(2026, 1, 1),
);

final _role = AccessRole(
  id: 1,
  name: 'admin',
  description: 'Full administration',
  system: true,
  createdAt: DateTime.utc(2026, 1, 1),
  permissions: [_permission],
);
