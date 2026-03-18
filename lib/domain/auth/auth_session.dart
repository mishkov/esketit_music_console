import 'package:equatable/equatable.dart';
import 'package:esketit_music_console/domain/auth/app_user.dart';

class AuthSession extends Equatable {
  const AuthSession({
    required this.user,
    required this.accessToken,
    required this.accessTokenExpiresAt,
    required this.refreshToken,
    required this.refreshTokenExpiresAt,
  });

  final AppUser user;
  final String accessToken;
  final DateTime accessTokenExpiresAt;
  final String refreshToken;
  final DateTime refreshTokenExpiresAt;

  bool get isAccessTokenExpired =>
      !DateTime.now().toUtc().isBefore(accessTokenExpiresAt.toUtc());

  bool get isRefreshTokenExpired =>
      !DateTime.now().toUtc().isBefore(refreshTokenExpiresAt.toUtc());

  AuthSession copyWith({
    AppUser? user,
    String? accessToken,
    DateTime? accessTokenExpiresAt,
    String? refreshToken,
    DateTime? refreshTokenExpiresAt,
  }) {
    return AuthSession(
      user: user ?? this.user,
      accessToken: accessToken ?? this.accessToken,
      accessTokenExpiresAt: accessTokenExpiresAt ?? this.accessTokenExpiresAt,
      refreshToken: refreshToken ?? this.refreshToken,
      refreshTokenExpiresAt:
          refreshTokenExpiresAt ?? this.refreshTokenExpiresAt,
    );
  }

  @override
  List<Object?> get props => [
    user,
    accessToken,
    accessTokenExpiresAt,
    refreshToken,
    refreshTokenExpiresAt,
  ];
}
