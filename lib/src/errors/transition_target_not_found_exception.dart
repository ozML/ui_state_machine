class TransitionTargetNotFoundException implements Exception {
  const TransitionTargetNotFoundException(this.transitionId, this.targetId);

  final String transitionId;
  final String targetId;

  @override
  String toString() {
    return 'Target \'$targetId\' of transition \'$transitionId\' not found';
  }
}
