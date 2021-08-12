class GroupStateTargetException implements Exception {
  const GroupStateTargetException(this.groupId);

  final String groupId;

  @override
  String toString() {
    return 'Group state \'$groupId\' cannot be direct target of transition';
  }
}
