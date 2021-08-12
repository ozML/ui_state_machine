class DuplicateTransitionException implements Exception {
  const DuplicateTransitionException(this.transitionId);

  final String transitionId;

  @override
  String toString() {
    return 'Transition \'$transitionId\' already defined';
  }
}
