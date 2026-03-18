import 'package:equatable/equatable.dart';

class HttpResponse extends Equatable {
  const HttpResponse({required this.statusCode, required this.response});

  final int statusCode;
  final Object? response;

  @override
  List<Object?> get props => [statusCode, response];
}
