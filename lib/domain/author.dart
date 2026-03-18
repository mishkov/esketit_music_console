import 'package:equatable/equatable.dart';

class Author extends Equatable {
  /// Because Author can change their name (for example due to cesonrship).
  final int? id;
  final String currentName;
  final List<String> photos;

  const Author({this.id, required this.currentName, this.photos = const []});

  @override
  List<Object?> get props => [id, currentName, photos];
}
