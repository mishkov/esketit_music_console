import 'package:esketit_music_console/errors/app_error.dart';

class HttpAppError extends AppError {
  const HttpAppError({
    required String message,
    required this.path,
    required this.statusCode,
    this.responseBody,
    super.cause,
    super.stackTrace,
  }) : super(message);

  final String path;
  final int statusCode;
  final Object? responseBody;

  @override
  String toString() => '$message ($statusCode $path)';
}

class UnauthorizedAppError extends HttpAppError {
  UnauthorizedAppError({
    required super.path,
    super.responseBody,
    super.cause,
    super.stackTrace,
  }) : super(message: 'Unauthorized request', statusCode: 401);
}

class ForbiddenAppError extends HttpAppError {
  ForbiddenAppError({
    required super.path,
    super.responseBody,
    super.cause,
    super.stackTrace,
  }) : super(message: 'Forbidden request', statusCode: 403);
}
