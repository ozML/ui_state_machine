import 'package:flutter/foundation.dart';
import 'package:ui_state_machine/src/errors/circular_state_traversal_exception.dart';
import 'package:ui_state_machine/src/errors/duplicate_state_exception.dart';
import 'package:ui_state_machine/src/errors/duplicate_transition_exception.dart';
import 'package:ui_state_machine/src/errors/group_state_target_exception.dart';
import 'package:ui_state_machine/src/errors/multiple_start_states_exception.dart';
import 'package:ui_state_machine/src/errors/no_start_state_exception.dart';
import 'package:ui_state_machine/src/errors/state_manager_invalid_exception.dart';
import 'package:ui_state_machine/src/errors/state_manager_not_initialized_exception.dart';
import 'package:ui_state_machine/src/errors/state_manager_not_validated_exception.dart';
import 'package:ui_state_machine/src/errors/state_not_found_exception.dart';
import 'package:ui_state_machine/src/errors/transition_source_not_found_exception.dart';
import 'package:ui_state_machine/src/errors/transition_target_not_found_exception.dart';
import 'package:ui_state_machine/src/errors/unreachable_state_exception.dart';
import 'package:ui_state_machine/src/state_management/transition.dart';
import 'package:ui_state_machine/src/state_management/uistate.dart';
import 'package:ui_state_machine/src/state_management/uistate_manager_factory.dart';
import 'package:ui_state_machine/src/utils/uistate_utils.dart';

/// The Statemanager class provides a workflow for state based view management.
///
/// This class is the core component of the ui state workflow and manages the
/// validation of conditions and transitions between states. If the class is
/// initialized with use of the constructor, all states and transitions must be
/// defined at once. It can additionally instantiated by using the helper class
/// [UIStateManagerFactory].
class UIStateManager extends ChangeNotifier {
  /// Creates an instance of [UIStateManager].
  UIStateManager({
    required Set<UIState> states,
    required Set<Transition> transitions,
  })  : _states = states,
        _transitions = transitions;

  /// Creates an instance of [UIStateManager] and validates it upon creation.
  factory UIStateManager.validated({
    required Set<UIState> states,
    required Set<Transition> transitions,
  }) {
    final manager = UIStateManager(states: states, transitions: transitions);
    manager.validate();

    return manager;
  }

  /// Creates an instance of [UIStateManager] and initializes it upon creation.
  factory UIStateManager.initialized({
    required Set<UIState> states,
    required Set<Transition> transitions,
  }) {
    final manager = UIStateManager(states: states, transitions: transitions);
    manager.initialize();

    return manager;
  }

  /// Set of all states of this manager.
  final Set<UIState> _states;

  /// Set of all transitions of this manager.
  final Set<Transition> _transitions;

  /// The initialization state of this manager.
  bool _isInitialized = false;

  /// The validation state of this manager.
  bool? _isValid;

  /// The start state of this manager.
  UIState? _startState;

  /// The current state of this manager.
  UIState? _currentState;

  /// Indicates whether the triggers are currently processed.
  bool _isProcessingTriggers = false;

  bool get isInitialized => _isInitialized;
  bool get isValid => _isValid ?? false;
  Set<UIState> get states => Set.unmodifiable(_states);
  Set<Transition> get transitions => Set.unmodifiable(_transitions);
  UIState? get currentState => _currentState;
  bool get isProcessingTriggers => _isProcessingTriggers;

  /// Initiates this state manager.
  ///
  /// This method must be invoked before working with the manager, otherwise an
  /// exception is thrown. Upon execution a validity check is performed and the
  /// start state is hooked.
  ///
  /// For further information on the validation process see [validate].
  void initialize() {
    if (!isValid) {
      validate();
    }

    if (isValid && !isInitialized) {
      _changeCurrentState(_startState!);
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Validates the state manager and the associated data.
  ///
  /// If the validity check suceeds, [isValid] is set to true. Different points
  /// that are checked are following:
  ///
  /// * Presence of exactly one start state in the form of [StartState].
  /// * Uniqueness of state and transition IDs.
  /// * Existence of sources and targets of [Transition]'s.
  /// * [GroupState] not set as target of transitions.
  /// * No unreachable states
  ///
  /// The method is called inside of [initialize] anyway, so it has not be
  /// called additionally.
  void validate() {
    if (!isValid) {
      final stateMap = _collectStates();
      final transitionMap = _collectTransitions();
      final fallbackTransitions = _extractTransitions(stateMap.values);

      _mergeTransitions(fallbackTransitions, transitionMap);
      _checkTransitionStates(transitionMap.values, stateMap);
      _checkStartState(stateMap.values);
      _checkForLostStates(stateMap.values, transitionMap.values);

      _startState = stateMap.values.whereType<StartState>().first;

      _isValid = true;
      notifyListeners();
    }
  }

  /// Tries to make a transition from the current state to the state specified
  /// by [id].
  ///
  /// For further information see [goToState].
  void goTo(String id) {
    _checkManagerValidity();

    //At first check triggers of current state
    if (applyTriggers()) {
      return;
    }

    _goToFrom(id, _currentState!);
  }

  /// Tries to make a transition from the current state to the specified target
  /// [state].
  ///
  /// To make the transition a valid [Transition] which connects the two states
  /// is searched. If none is found the parents are also searched for a
  /// possibility. For conditional target states the condition is also checked
  /// before making the transition. They are also checked for conditional
  /// parents if the parent of the current state and the target state differ.
  /// In the process the triggers of involved states are also checked. For
  /// further information regarding the general trigger evaluation see
  /// [applyTriggers].
  void goToState(UIState state) {
    _checkManagerValidity();

    //At first check triggers of current state
    if (applyTriggers()) {
      return;
    }

    _goToFrom(state.id, _currentState!);
  }

  /// Searches for a valid state by traversing available trigger transitions.
  ///
  /// If a valid state is found, it is automatically set as current state.
  /// If no sourceState parameter is defined, the process will start from the
  /// current set state. The valid state is determined by passing following
  /// steps:
  ///
  /// * Check triggers on parent states starting from the topmost.
  ///   * If state found, it may be returned.
  /// * If source state is conditional, the condition is checked.
  ///   * If condition fails, the fallback state may be returned.
  /// * Check all available trigger transitions of the source state in order.
  /// * If a target state is conditional a traversal is only considered, if the
  ///   condition is met.
  /// * Check the condition of trigger transition.
  ///   * If condition is met, the target may be returned.
  ///
  /// All triggers and parent triggers are additional checked for each
  /// potential new step.
  ///
  /// Returns true if any trigger was applied.
  bool applyTriggers() {
    bool result = false;

    try {
      _changeIsProcessingTriggers(true);
      result = _applyTriggers();
    } finally {
      _changeIsProcessingTriggers(false);
    }

    return result;
  }

  bool _applyTriggers([UIState? sourceState]) {
    _checkManagerValidity();

    if (_currentState != null || sourceState != null) {
      final startState = sourceState ?? _currentState!;
      var resultState = _traverseTriggers(startState);

      if (resultState != null) {
        if (resultState != startState) {
          _currentState = resultState;
          notifyListeners();
        }

        return true;
      }
    }

    return false;
  }

  /// Makes the transition from source to target state, if possible.
  void _goToFrom(String targetId, UIState sourceState) {
    final transitions = UIStateUtils.actionTransitionsOf(
        _transitions, sourceState.id, targetId);

    if (transitions.isEmpty && sourceState.hasParent) {
      // If no transition to target found, also check for all parent states
      // starting from the direct parent
      _goToFrom(targetId, sourceState.parent!);
      return;
    } else if (transitions.isEmpty && !sourceState.hasParent) {
      return;
    }

    final transition = transitions.first;
    final targetState = _findState(transition.targetId);

    if (targetState.isConditional && !targetState.check()) {
      return;
    }

    if (targetState.parent != _currentState?.parent) {
      final hierarchy = UIStateUtils.parentsOf(targetState, fromTopmost: true);
      for (final state in hierarchy) {
        if (state.isConditional && !state.check()) {
          return;
        }
      }
    }

    UIState? resultState = _traverseTriggers(targetState) ?? targetState;

    _changeCurrentState(resultState);
    notifyListeners();
  }

  /// Traverses all available triggered transisitions recursively, starting
  /// from the given state to find a valid target state.
  UIState? _traverseTriggers(UIState sourceState, {UIState? originalSource}) {
    if (originalSource != null && originalSource.id == sourceState.id) {
      throw CircularStateTraversalException();
    }
    final startState = originalSource ?? sourceState;

    // First check all triggers of parents, starting from the topmost
    if (sourceState.hasParent) {
      final target = _traverseTriggers(
        sourceState.parent!,
        originalSource: originalSource ?? sourceState,
      );

      if (target != null) {
        return target;
      }
    }

    // Check whether state condition fails
    if (sourceState.isConditional && !sourceState.check()) {
      final target = _findState(sourceState.fallbackTransition.targetId);
      final distantTarget = _traverseTriggers(
        target,
        originalSource: startState,
      );

      return distantTarget ?? target;
    }

    final transitions =
        UIStateUtils.triggerTransitionsOf(_transitions, sourceState.id);
    for (final transition in transitions) {
      final UIState currentTarget = _findState(transition.targetId);
      final isValid = !currentTarget.isConditional || currentTarget.check();

      if (isValid && transition.trigger()) {
        // Finally check the triggers of target state on valid transition
        final distantTarget = _traverseTriggers(
          currentTarget,
          originalSource: startState,
        );

        final resultState = distantTarget ?? currentTarget;

        return resultState;
      }
    }

    return null;
  }

  void _changeCurrentState(UIState value) {
    if (value != _currentState) {
      _currentState = value;
      notifyListeners();
    }
  }

  void _changeIsProcessingTriggers(bool value) {
    if (value != _isProcessingTriggers) {
      _isProcessingTriggers = value;
      notifyListeners();
    }
  }

  UIState _findState(String id) {
    final result = UIStateUtils.tryfindState(id, _states);
    if (result == null) {
      throw StateNotFoundException(id);
    }

    return result;
  }

  void _checkManagerValidity() {
    if (_isValid == null) {
      throw StateManagerNotValidatedException();
    } else if (_isValid == false) {
      throw StateManagerInvalidException();
    } else if (!_isInitialized) {
      throw StateManagerNotInitializedException();
    }
  }

  Map<String, Transition> _collectTransitions() {
    Map<String, Transition> map = {};
    for (final transition in _transitions) {
      map[transition.id] = transition;
    }

    return map;
  }

  Map<String, UIState> _collectStates([
    Iterable<UIState>? source,
    Map<String, UIState>? map,
  ]) {
    final _map = map ?? {};

    for (final state in (source ?? _states)) {
      if (_map.containsKey(state.id)) {
        throw DuplicateStateException(state.id);
      }
      _map[state.id] = state;

      if (state is GroupState) {
        _collectStates(state.innerStates, _map);
      }
    }

    return _map;
  }

  Set<Transition> _extractTransitions(Iterable<UIState> sourceSet) {
    final Set<Transition> transitions = {};
    for (final state in sourceSet) {
      if (state.isConditional) {
        transitions.add(state.fallbackTransition);
      }
    }

    return transitions;
  }

  void _mergeTransitions(
      Iterable<Transition> source, Map<String, Transition> targetMap) {
    for (final transition in source) {
      if (targetMap.containsKey(transition.id)) {
        throw DuplicateTransitionException(transition.id);
      }
      targetMap[transition.id] = transition;
    }
  }

  void _checkTransitionStates(
      Iterable<Transition> source, Map<String, UIState> stateMap) {
    for (final transition in source) {
      for (final sourceId in transition.sourceIds) {
        if (!stateMap.containsKey(sourceId)) {
          throw TransitionSourceNotFoundException(transition.id, sourceId);
        }
      }

      if (!stateMap.containsKey(transition.targetId)) {
        throw TransitionTargetNotFoundException(
            transition.id, transition.targetId);
      }

      if (stateMap[transition.targetId] is GroupState) {
        throw GroupStateTargetException(stateMap[transition.targetId]!.id);
      }
    }
  }

  void _checkStartState(Iterable<UIState> source) {
    final starters = source.whereType<StartState>();
    if (starters.isEmpty) {
      throw NoStartStateException();
    } else if (starters.length > 1) {
      throw MultipleStartStatesException();
    }
  }

  void _checkForLostStates(
    Iterable<UIState> source,
    Iterable<Transition> transitions,
  ) {
    for (final state in source) {
      if (state is GroupState || state is StartState) {
        continue;
      }

      if (!transitions.any((element) => element.targetId == state.id)) {
        throw UnreachableStateException(state.id);
      }
    }
  }
}
