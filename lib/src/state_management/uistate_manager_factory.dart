import 'package:ui_state_machine/src/state_management/transition.dart';
import 'package:ui_state_machine/src/state_management/uistate.dart';
import 'package:ui_state_machine/src/state_management/uistate_manager.dart';

/// This factory class can be usde to assemble a [UIStateManager] instance with
/// all states and transitions.
class UIStateManagerFactory {
  Set<UIState> _states = {};
  Set<Transition> _transitions = {};

  /// Add a state to the factory.
  ///
  /// In case of a group state, the inner states can are also included.
  UIStateManagerFactory addState(UIState state) {
    _states.add(state);
    return this;
  }

  /// Adds multiple states to the factory.
  ///
  /// In case of a group state, the inner states can are also included.
  UIStateManagerFactory addStates(Set<UIState> states) {
    for (final state in states) {
      _states.add(state);
    }
    return this;
  }

  /// Adds a transition to the factory.
  UIStateManagerFactory addTransition(Transition transition) {
    _transitions.add(transition);
    return this;
  }

  /// Adds multiple transitions to the factory.
  UIStateManagerFactory addTransitions(Set<Transition> transitions) {
    for (final transition in transitions) {
      addTransition(transition);
    }
    return this;
  }

  /// Creates a [ActionTransition] and adds it to the factory.
  UIStateManagerFactory createActionTransition(
    String id,
    Set<String> sourceIds,
    String targetId,
  ) {
    _transitions.add(
      ActionTransition(
        id: id,
        sourceIds: sourceIds,
        targetId: targetId,
      ),
    );
    return this;
  }

  /// Creates a [TriggerTransition] and adds it to the factory.
  UIStateManagerFactory createTriggerTransition(
    String id,
    String sourceId,
    String targetId,
    bool Function() condition,
  ) {
    _transitions.add(
      TriggerTransition(
        id: id,
        sourceId: sourceId,
        targetId: targetId,
        condition: condition,
      ),
    );
    return this;
  }

  /// Builds a [UIStateManager] instance wih the included data and returns it.
  ///
  /// The resulting state manager is automatically validated before returning
  /// it. This default behavior can be tweaked by passing [validate].
  UIStateManager build({bool validate = true}) {
    final manager = UIStateManager(
      states: _states,
      transitions: _transitions,
    );

    if (validate) {
      manager.validate();
    }

    return manager;
  }
}
