import 'package:uistate/src/state_management/transition.dart';
import 'package:uistate/src/state_management/uistate.dart';

/// Utility class with some help functions regarding states.
class UIStateUtils {
  UIStateUtils._();

  /// Returns all parent states of the specified state object.
  ///
  /// The returned list of parents is ordered from the nearest to the farest
  /// parent. The order can be changed with [fromTopMost].
  static List<GroupState> parentsOf(
    UIState state, {
    List<GroupState>? parents,
    bool fromTopmost = false,
  }) {
    final _parents = parents ?? [];

    if (state.hasParent) {
      if (fromTopmost) {
        parentsOf(state.parent!, parents: _parents, fromTopmost: fromTopmost);
        _parents.add(state.parent!);
      } else {
        _parents.add(state.parent!);
        parentsOf(state, parents: _parents, fromTopmost: fromTopmost);
      }
    }

    return _parents;
  }

  /// Checks whether the passed parent state lies within the parent
  /// hierarchie of the specified state.
  static bool isParentOf(UIState state, GroupState parent) {
    return parentsOf(state).contains(parent);
  }

  /// Returns all [ActionTransition]'s with a source ID of [sourceId] from the
  /// source list.
  ///
  /// If [targetId] is specified, the result is filtered accordingly.
  static List<ActionTransition> actionTransitionsOf(
    Iterable<Transition> source,
    String sourceId, [
    String? targetId,
  ]) {
    return _transitionsOf<ActionTransition>(source, sourceId, targetId);
  }

  /// Returns all [TriggerTransition]'s with a source ID of [sourceId] from the
  /// source list.
  ///
  /// If [targetId] is specified, the result is filtered accordingly.
  static List<TriggerTransition> triggerTransitionsOf(
    Iterable<Transition> source,
    String sourceId, [
    String? targetId,
  ]) {
    return _transitionsOf<TriggerTransition>(source, sourceId, targetId);
  }

  /// Searches the source for the state with the provided id.
  ///
  /// The function iterates over all states and in case of groups recursively
  /// over all inner states, to find the appropriate target state. If no state
  /// is found null is returned.
  static UIState? tryfindState(String id, Iterable<UIState> source) {
    for (final state in source) {
      if (state.id == id) {
        return state;
      } else if (state is GroupState) {
        final childState = tryfindState(id, state.innerStates);
        if (childState != null) {
          return childState;
        }
      }
    }

    return null;
  }

  static List<T> _transitionsOf<T extends Transition>(
    Iterable<Transition> source,
    String sourceId, [
    String? targetId,
  ]) {
    return source
        .whereType<T>()
        .where(
          (element) =>
              element.sourceIds.contains(sourceId) &&
              (targetId == null || targetId == element.targetId),
        )
        .toList();
  }
}
