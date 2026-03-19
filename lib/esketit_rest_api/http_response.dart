import 'package:equatable/equatable.dart';

class HttpResponse extends Equatable {
  const HttpResponse({required this.statusCode, required this.response});

  final int statusCode;
  final Object? response;

  @override
  List<Object?> get props => [statusCode, response];
}

class BinaryHttpResponse extends Equatable {
  const BinaryHttpResponse({
    required this.statusCode,
    required this.bytes,
    this.contentType,
    this.contentDisposition,
  });

  final int statusCode;
  final List<int> bytes;
  final String? contentType;
  final String? contentDisposition;

  @override
  List<Object?> get props => [
    statusCode,
    bytes,
    contentType,
    contentDisposition,
  ];
}
