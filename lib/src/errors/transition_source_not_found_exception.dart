class TransitionSourceNotFoundException implements Exception {
  const TransitionSourceNotFoundException(this.transitionId, this.sourceId);

  final String transitionId;
  final String sourceId;

  @override
  String toString() {
    return 'Source \'$sourceId\' of transition \'$transitionId\' not found';
  }
}
