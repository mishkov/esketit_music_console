import 'package:equatable/equatable.dart';
import 'package:esketit_music_console/domain/auth/auth_session.dart';
import 'package:esketit_music_console/errors/app_error.dart';
import 'package:esketit_music_console/use_case/auth/auth_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum AuthStatus { restoring, authenticated, unauthenticated }

sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthSessionRestoreRequested extends AuthEvent {
  const AuthSessionRestoreRequested();
}

class AuthSignInRequested extends AuthEvent {
  const AuthSignInRequested({required this.email, required this.password});

  final String email;
  final String password;

  @override
  List<Object?> get props => [email, password];
}

class AuthSignOutRequested extends AuthEvent {
  const AuthSignOutRequested();
}

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({required AuthRepository authRepository})
    : _authRepository = authRepository,
      super(const AuthState.initial()) {
    on<AuthSessionRestoreRequested>(_onRestoreRequested);
    on<AuthSignInRequested>(_onSignInRequested);
    on<AuthSignOutRequested>(_onSignOutRequested);
  }

  final AuthRepository _authRepository;

  Future<void> _onRestoreRequested(
    AuthSessionRestoreRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(
      state.copyWith(
        status: AuthStatus.restoring,
        isSubmitting: false,
        clearFailure: true,
      ),
    );

    try {
      final session = await _authRepository.restoreSession();
      if (session == null) {
        emit(
          state.copyWith(
            status: AuthStatus.unauthenticated,
            clearSession: true,
            clearFailure: true,
          ),
        );
        return;
      }

      emit(
        state.copyWith(
          status: AuthStatus.authenticated,
          session: session,
          clearFailure: true,
        ),
      );
    } catch (error, stackTrace) {
      emit(
        state.copyWith(
          status: AuthStatus.unauthenticated,
          clearSession: true,
          isSubmitting: false,
          failure: _toFailure(error, stackTrace),
        ),
      );
    }
  }

  Future<void> _onSignInRequested(
    AuthSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true, clearFailure: true));

    try {
      final session = await _authRepository.signIn(
        email: event.email,
        password: event.password,
      );
      emit(
        state.copyWith(
          status: AuthStatus.authenticated,
          session: session,
          isSubmitting: false,
          clearFailure: true,
        ),
      );
    } catch (error, stackTrace) {
      emit(
        state.copyWith(
          status: AuthStatus.unauthenticated,
          clearSession: true,
          isSubmitting: false,
          failure: _toFailure(error, stackTrace),
        ),
      );
    }
  }

  Future<void> _onSignOutRequested(
    AuthSignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true, clearFailure: true));

    try {
      await _authRepository.signOut();
      emit(
        state.copyWith(
          status: AuthStatus.unauthenticated,
          clearSession: true,
          isSubmitting: false,
          clearFailure: true,
        ),
      );
    } catch (error, stackTrace) {
      emit(
        state.copyWith(
          status: AuthStatus.unauthenticated,
          clearSession: true,
          isSubmitting: false,
          failure: _toFailure(error, stackTrace),
        ),
      );
    }
  }

  AppError _toFailure(Object error, StackTrace stackTrace) {
    if (error is AppError) {
      return error;
    }
    return AppError(
      'Authentication failed',
      cause: error,
      stackTrace: stackTrace,
    );
  }
}

class AuthState extends Equatable {
  const AuthState({
    required this.status,
    required this.isSubmitting,
    this.session,
    this.failure,
  });

  const AuthState.initial()
    : this(status: AuthStatus.restoring, isSubmitting: false);

  final AuthStatus status;
  final AuthSession? session;
  final bool isSubmitting;
  final AppError? failure;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  AuthState copyWith({
    AuthStatus? status,
    AuthSession? session,
    bool clearSession = false,
    bool? isSubmitting,
    AppError? failure,
    bool clearFailure = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      session: clearSession ? null : (session ?? this.session),
      isSubmitting: isSubmitting ?? this.isSubmitting,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props => [status, session, isSubmitting, failure];
}
