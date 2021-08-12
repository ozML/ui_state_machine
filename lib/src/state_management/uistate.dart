import 'package:equatable/equatable.dart';
import 'package:ui_state_machine/src/errors/unconditional_state_exception.dart';
import 'package:ui_state_machine/src/state_management/transition.dart';

/// Represents a state in the state based view workflow.
///
/// A state consists of an id and transitions to other states. They can be
/// grouped within [GroupState]'s. In that case a reference to the direct
/// parent group is stored within [parent]. States can also be conditional, in
/// which case the special constructor [State.conditional] must be used.
class UIState with EquatableMixin {
  /// Creates an instance of [UIState] with the default properties set.
  UIState({
    required this.id,
    this.parent,
  })  : condition = null,
        fallbackId = null;

  /// Creates an conditional instance of [UIState].
  ///
  /// The condition is checked before entering the state and also while the
  /// state is active. A failure in the first case blocks the state for
  /// transitions, the latter triggers the fallback transition. If parent
  /// states are also conditional, the evaluation of the conditions is started
  /// from the topmost state.
  UIState.conditional({
    required this.id,
    this.parent,
    required this.condition,
    required this.fallbackId,
  });

  /// An unique identifier.
  final String id;

  /// The parent state associated with this state.
  GroupState? parent;

  /// The entering condition of this state.
  final bool Function()? condition;

  /// The fallback state id which is used if the condition fails.
  final String? fallbackId;

  @override
  List<Object?> get props => [id];

  bool get hasParent => parent != null;
  bool get isConditional => condition != null;

  /// Returns the fallback transition for a conditional state.
  ///
  /// This transition is meant to be triggered, if the condition of the state is
  /// not valid anymore. Therefore the condition of the transition is the exact
  /// negation of the state's condition. The target of the transition is set to
  /// the state identified by [fallbackId].
  ///
  /// Throws an exception for unconditional states. Therefore [isConditional]
  /// should be checked beforehand.
  TriggerTransition get fallbackTransition => _buildFallbackTransition();

  /// Executes the condition if set and returns the result.
  ///
  /// Throws an exception for an unconditional state. Therefore [isConditional]
  /// should be checked beforehand.
  bool check() {
    if (!isConditional) {
      throw UnconditionalStateException(id);
    }

    return condition!.call();
  }

  TriggerTransition _buildFallbackTransition() {
    if (!isConditional) {
      throw UnconditionalStateException(id);
    }

    return TriggerTransition(
      id: "$id.fallback",
      sourceId: this.id,
      targetId: fallbackId!,
      condition: () => !condition!.call(),
    );
  }
}

/// Represents a state that is group to multiple inner states.
///
/// It is basically a [UIState] object extended by the capability to contain
/// multiple inner states. [GroupState]'s cannot be directly targeted by
/// transitions. Instead child states should be targeted.
class GroupState extends UIState {
  /// Creates an instance of [GroupState].
  GroupState({
    required String id,
    GroupState? parent,
    this.innerStates = const {},
  }) : super(id: id, parent: parent) {
    _connectChilds();
  }

  /// Creates a conditional instance of [GroupState].
  ///
  /// For further information, see [State.conditional].
  GroupState.conditional({
    required String id,
    GroupState? parent,
    this.innerStates = const {},
    required bool Function() condition,
    required String fallbackId,
  }) : super.conditional(
          id: id,
          parent: parent,
          condition: condition,
          fallbackId: fallbackId,
        ) {
    _connectChilds();
  }

  /// The child states of thisgroup.
  final Set<UIState> innerStates;

  void _connectChilds() {
    innerStates.forEach((element) {
      element.parent = this;
    });
  }
}

/// Represents the starting point in the state graph.
///
/// Every state graph of a ui state workwflow must contain one instance of this
/// type, to mark the entry point of the workflow.
class StartState extends UIState {
  /// Creates an instance of [StartState].
  StartState({required String id}) : super(id: id);
}
