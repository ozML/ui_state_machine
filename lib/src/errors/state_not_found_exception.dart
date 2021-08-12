class StateNotFoundException implements Exception {
  const StateNotFoundException(this.stateId);

  final String stateId;

  @override
  String toString() => 'State with id \'$stateId\' not found';
}
