class NoStartStateException implements Exception {
  @override
  String toString() => 'One start state must be defined';
}
