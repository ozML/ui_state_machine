class DuplicateStateException implements Exception {
  const DuplicateStateException(this.stateId);

  final String stateId;

  @override
  String toString() {
    return 'State \'$stateId\' already defined';
  }
}
