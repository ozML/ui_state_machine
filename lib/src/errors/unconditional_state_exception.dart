class UnconditionalStateException implements Exception {
  const UnconditionalStateException(this.stateId);

  final String stateId;

  @override
  String toString() => 'State \'$stateId\' is not conditional';
}
