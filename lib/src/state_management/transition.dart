import 'package:equatable/equatable.dart';

/// Represents a transition in a state based view workflow.
///
/// The transition connects the two [State]'s identified by their IDs, allowing
/// a unidirectional traversial from source to target state. To simplify the
/// definition of transitions, it is possible to summarize multiple transitions
/// to one target. This type cannot be instantiated, instead the sub types
/// [ActionTransition] and [TriggerTransition] should be used.
abstract class Transition with EquatableMixin {
  /// Creates an instance of [Transition].
  const Transition({
    required this.id,
    required this.sourceIds,
    required this.targetId,
  });

  /// Creates an instance of [Transition] with a single source.
  Transition.singleSource({
    required this.id,
    required String sourceId,
    required this.targetId,
  }) : this.sourceIds = {sourceId};

  /// An unique identifier.
  final String id;

  /// The IDs of all source states.
  final Set<String> sourceIds;

  /// The ID of the target state.
  final String targetId;

  @override
  List<Object?> get props => [id];
}

/// Represents a transition in a state based view workflow.
///
/// This type inherits all properties of [Transition], but can be instantiated.
/// It connects one ore more source states with a target state and is used
/// for a direct unidirectional traversal between them.
class ActionTransition extends Transition {
  /// Creates an instance of [ActionTransition].
  const ActionTransition({
    required String id,
    required Set<String> sourceIds,
    required String targetId,
  }) : super(
          id: id,
          sourceIds: sourceIds,
          targetId: targetId,
        );

  /// Creates an instance of [ActionTransition] with a single source.
  ActionTransition.singleSource({
    required String id,
    required String sourceId,
    required String targetId,
  }) : super.singleSource(
          id: id,
          sourceId: sourceId,
          targetId: targetId,
        );
}

/// A transition, that triggers automatically on met condition.
///
/// This transition sub type can not be actively traversed, but will be
/// triggered by the workflow engine if the set condition is met. This type can
/// also not be summarized, each transition must be defined individually.
class TriggerTransition extends Transition {
  /// Creates an instance of [TriggerTransition].
  TriggerTransition({
    required String id,
    required String sourceId,
    required String targetId,
    required this.condition,
  }) : super.singleSource(
          id: id,
          sourceId: sourceId,
          targetId: targetId,
        );

  final bool Function() condition;

  String get source => sourceIds.first;

  bool trigger() {
    return condition.call();
  }
}
