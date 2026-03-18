import 'package:esketit_music_console/domain/auth/auth_session.dart';

abstract class AuthRepository {
  Future<AuthSession?> restoreSession();

  Future<AuthSession> signIn({required String email, required String password});

  Future<void> signOut();

  Future<AuthSession?> refreshSession({bool forceRefresh = false});
}
