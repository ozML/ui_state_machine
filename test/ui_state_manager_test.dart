import 'package:flutter_test/flutter_test.dart';
import 'package:ui_state_machine/src/errors/circular_state_traversal_exception.dart';
import 'package:ui_state_machine/src/errors/duplicate_state_exception.dart';
import 'package:ui_state_machine/src/errors/duplicate_transition_exception.dart';
import 'package:ui_state_machine/src/errors/group_state_target_exception.dart';
import 'package:ui_state_machine/src/errors/multiple_start_states_exception.dart';
import 'package:ui_state_machine/src/errors/no_start_state_exception.dart';
import 'package:ui_state_machine/src/errors/transition_source_not_found_exception.dart';
import 'package:ui_state_machine/src/errors/transition_target_not_found_exception.dart';
import 'package:ui_state_machine/src/errors/unreachable_state_exception.dart';
import 'package:ui_state_machine/src/state_management/transition.dart';
import 'package:ui_state_machine/src/state_management/uistate.dart';
import 'package:ui_state_machine/src/state_management/uistate_manager.dart';
import 'package:ui_state_machine/src/state_management/uistate_manager_factory.dart';

void main() {
  group('Test validation', () {
    group('Test start state', () {
      test('Test empty state manager', () {
        expect(
          () => UIStateManager.validated(
            states: {},
            transitions: {},
          ),
          throwsA(isA<NoStartStateException>()),
        );
      });

      test('Test multiple start states', () {
        expect(
          () => UIStateManager.validated(
            states: {StartState(id: '0'), StartState(id: '1')},
            transitions: {},
          ),
          throwsA(isA<MultipleStartStatesException>()),
        );
      });

      test('Test multiple start states including nested inner state', () {
        expect(
          () => UIStateManager.validated(
            states: {
              StartState(id: '0'),
              GroupState(
                id: '1',
                innerStates: {
                  StartState(id: '1.0'),
                },
              )
            },
            transitions: {},
          ),
          throwsA(isA<MultipleStartStatesException>()),
        );
      });

      test('Test state manager with only start state', () {
        expect(
          () => UIStateManager.validated(
            states: {StartState(id: '0')},
            transitions: {},
          ),
          returnsNormally,
        );
      });
    });

    group('Test duplicate ID', () {
      test('Test duplicate state ID', () {
        expect(
          () => UIStateManager.validated(
            states: {StartState(id: '0'), UIState(id: '0')},
            transitions: {},
          ),
          throwsA(isA<DuplicateStateException>()),
        );
      });

      test('Test duplicate state ID including nested inner state', () {
        expect(
          () => UIStateManager.validated(
            states: {
              StartState(id: '0'),
              GroupState(id: '1', innerStates: {UIState(id: '1')})
            },
            transitions: {},
          ),
          throwsA(isA<DuplicateStateException>()),
        );
      });

      test('Test duplicate transition ID', () {
        expect(
          () => UIStateManager.validated(
            states: {StartState(id: '0'), UIState(id: '1')},
            transitions: {
              ActionTransition.singleSource(
                id: '0:1',
                sourceId: '0',
                targetId: '1',
              ),
              ActionTransition.singleSource(
                id: '0:1',
                sourceId: '0',
                targetId: '1',
              ),
            },
          ),
          returnsNormally,
        );
      });

      test('Test duplicate transition ID including fallback transition', () {
        expect(
          () => UIStateManager.validated(
            states: {
              StartState(id: '0'),
              UIState.conditional(
                  id: '1', condition: () => true, fallbackId: '0')
            },
            transitions: {
              ActionTransition.singleSource(
                id: '1.fallback',
                sourceId: '0',
                targetId: '1',
              ),
            },
          ),
          throwsA(isA<DuplicateTransitionException>()),
        );
      });
    });

    test('Test transition with group state target', () {
      expect(
        () => UIStateManager.validated(
          states: {
            StartState(id: '0'),
            GroupState(id: '1', innerStates: {UIState(id: '1.0')})
          },
          transitions: {
            ActionTransition.singleSource(
                id: '0:1', sourceId: '0', targetId: '1')
          },
        ),
        throwsA(isA<GroupStateTargetException>()),
      );
    });

    test('Test unknown transition source state', () {
      expect(
        () => UIStateManager.validated(
          states: {
            StartState(id: '0'),
            GroupState(id: '1', innerStates: {UIState(id: '1.0')})
          },
          transitions: {
            ActionTransition.singleSource(
                id: '0:1', sourceId: '2', targetId: '1')
          },
        ),
        throwsA(isA<TransitionSourceNotFoundException>()),
      );
    });

    test('Test unknown transition target state', () {
      expect(
        () => UIStateManager.validated(
          states: {
            StartState(id: '0'),
            GroupState(id: '1', innerStates: {UIState(id: '1.0')})
          },
          transitions: {
            ActionTransition.singleSource(
                id: '0:1', sourceId: '0', targetId: '2')
          },
        ),
        throwsA(isA<TransitionTargetNotFoundException>()),
      );
    });

    test('Test unreachable state', () {
      expect(
        () => UIStateManager.validated(
          states: {StartState(id: '0'), UIState(id: '1')},
          transitions: {
            TriggerTransition(
              id: '1:0',
              sourceId: '1',
              targetId: '0',
              condition: () => true,
            )
          },
        ),
        throwsA(isA<UnreachableStateException>()),
      );
    });
  });

  group('Test workflow', () {
    bool isSignedIn = false;
    bool isAdmin = false;
    late UIStateManager manager;

    setUp(() {
      final factory = UIStateManagerFactory()
          .addState(StartState(id: 'login'))
          .addState(GroupState.conditional(
            id: 'logged_in',
            innerStates: {
              UIState(id: 'dashboard'),
              UIState(id: 'userview'),
              GroupState.conditional(
                id: 'admin_area',
                innerStates: {UIState(id: 'settings')},
                condition: () => isAdmin == true,
                fallbackId: 'dashboard',
              ),
            },
            condition: () => isSignedIn == true,
            fallbackId: 'login',
          ))
          .addTransition(TriggerTransition(
            id: 't|login:dashboard',
            sourceId: 'login',
            targetId: 'dashboard',
            condition: () => isSignedIn == true,
          ))
          .addTransition(ActionTransition(
            id: '+:userview',
            sourceIds: {'dashboard', 'admin_area'},
            targetId: 'userview',
          ))
          .addTransition(ActionTransition(
            id: '+:settings',
            sourceIds: {'dashboard', 'userview'},
            targetId: 'settings',
          ));

      manager = factory.build(validate: false);
    });

    test('Test initialization', () {
      expect(() => manager.initialize(), returnsNormally);
    });

    test('Test go to dashboard although signed out', () {
      manager.initialize();
      manager.goTo('dashboard');
      expect(
        isCurrentState(manager, 'login'),
        isTrue,
      );
    });

    test('Test go to dashboard while signed in', () {
      isSignedIn = true;
      manager.initialize();
      manager.goTo('dashboard');
      expect(
        isCurrentState(manager, 'dashboard'),
        isTrue,
      );
    });

    test('Test trigger transition to dashboard', () {
      manager.initialize();
      isSignedIn = true;
      manager.applyTriggers();
      expect(
        isCurrentState(manager, 'dashboard'),
        isTrue,
      );
    });

    test('Test go to settings while unauthorized', () {
      manager.initialize();
      isSignedIn = true;
      manager.applyTriggers();
      manager.goTo('settings');
      expect(
        isCurrentState(manager, 'dashboard'),
        isTrue,
      );
    });

    test('Test go to settings while authorized', () {
      manager.initialize();
      isSignedIn = true;
      isAdmin = true;
      manager.applyTriggers();
      manager.goTo('settings');
      expect(
        isCurrentState(manager, 'settings'),
        isTrue,
      );
    });

    test('Test fallback transition from settings', () {
      manager.initialize();
      isSignedIn = true;
      isAdmin = true;
      manager.applyTriggers();
      manager.goTo('settings');
      isAdmin = false;
      manager.applyTriggers();

      expect(
        isCurrentState(manager, 'dashboard'),
        isTrue,
      );
    });

    test('Test fallback transition from logged_in', () {
      manager.initialize();
      isSignedIn = true;
      isAdmin = true;
      manager.applyTriggers();
      manager.goTo('settings');
      isSignedIn = false;
      manager.applyTriggers();

      expect(
        isCurrentState(manager, 'login'),
        isTrue,
      );
    });

    tearDown(() {});
  });

  group('Test single workflow cases', () {
    test('Test circular traversal', () {
      final manager = UIStateManager.initialized(
        states: {StartState(id: '0'), UIState(id: '1')},
        transitions: {
          TriggerTransition(
            id: '1:0',
            sourceId: '1',
            targetId: '0',
            condition: () => true,
          ),
          TriggerTransition(
            id: '0:1',
            sourceId: '0',
            targetId: '1',
            condition: () => true,
          )
        },
      );

      expect(
        () => manager.applyTriggers(),
        throwsA(isA<CircularStateTraversalException>()),
      );
    });
  });
}

bool isCurrentState(UIStateManager manager, String id) {
  return manager.currentState?.id == id;
}
