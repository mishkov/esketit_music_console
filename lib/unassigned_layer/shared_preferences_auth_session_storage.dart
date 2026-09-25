import 'dart:convert';

import 'package:esketit_music_console/domain/auth/app_user.dart';
import 'package:esketit_music_console/domain/auth/auth_session.dart';
import 'package:esketit_music_console/domain/access_control.dart';
import 'package:esketit_music_console/use_case/auth/auth_session_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesAuthSessionStorage implements AuthSessionStorage {
  static const _sessionKey = 'auth_session_v1';

  @override
  Future<AuthSession?> read() async {
    final preferences = await SharedPreferences.getInstance();
    final rawSession = preferences.getString(_sessionKey);
    if (rawSession == null || rawSession.isEmpty) {
      return null;
    }

    final decoded = jsonDecode(rawSession);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    final userJson = decoded['user'];
    if (userJson is! Map<String, dynamic>) {
      return null;
    }

    return AuthSession(
      user: AppUser(
        id: (userJson['id'] as num).toInt(),
        email: userJson['email'] as String,
        createdAt: DateTime.parse(userJson['createdAt'] as String),
        roles: (userJson['roles'] as List)
            .map(
              (item) =>
                  AccessRole.fromJson(Map<String, dynamic>.from(item as Map)),
            )
            .toList(growable: false),
        permissions: (userJson['permissions'] as List)
            .map(
              (item) => AccessPermission.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList(growable: false),
      ),
      accessToken: decoded['accessToken'] as String,
      accessTokenExpiresAt: DateTime.parse(
        decoded['accessTokenExpiresAt'] as String,
      ),
      refreshToken: decoded['refreshToken'] as String,
      refreshTokenExpiresAt: DateTime.parse(
        decoded['refreshTokenExpiresAt'] as String,
      ),
    );
  }

  @override
  Future<void> write(AuthSession session) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _sessionKey,
      jsonEncode({
        'user': {
          'id': session.user.id,
          'email': session.user.email,
          'createdAt': session.user.createdAt.toIso8601String(),
          'roles': session.user.roles.map((role) => role.toJson()).toList(),
          'permissions': session.user.permissions
              .map((permission) => permission.toJson())
              .toList(),
        },
        'accessToken': session.accessToken,
        'accessTokenExpiresAt': session.accessTokenExpiresAt.toIso8601String(),
        'refreshToken': session.refreshToken,
        'refreshTokenExpiresAt': session.refreshTokenExpiresAt
            .toIso8601String(),
      }),
    );
  }

  @override
  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_sessionKey);
  }
}
