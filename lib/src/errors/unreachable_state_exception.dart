class UnreachableStateException implements Exception {
  const UnreachableStateException(this.stateId);

  final String stateId;

  @override
  String toString() => 'State \'$stateId\' is unreachable';
}
