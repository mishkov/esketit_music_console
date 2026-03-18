import 'package:equatable/equatable.dart';

class Author extends Equatable {
  /// Because Author can change their name (for example due to cesonrship).
  final String currentName;

  const Author({required this.currentName});
  
  @override
  List<Object> get props => [currentName];
}
