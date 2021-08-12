Presents the UI view workflow in the manner of  a state machine.

Views are presented in states and possible ransitions inbetween as well as corresponding conditions must be defined in a workflow graph. This way view relations and logic can be further separated.

Usage
--

It is quite easy to get the workflow running by using the `UIStateWorkflow` widget. You only have to provide `managerFactory` and `pageSelector` builder functions as well as a list of value providers. Everything else is assembled by the widget.

Finally the `builder` function is used to construct a routing component (`Router`) and pass the information parser and delegate with the `WorkflowContext.informationParser` and `WorkflowContext.routerDelegate` accessors into it.

### Navigation

The workflow widget can be accessed via the static method `UIStateWorkflow.of` by providing a `BuildContext`. To trigger a transition to a target state use the `UIStateWorkflow.goToState` instance method. It is not guaranteed, that the desired state will actually be set as the next state, as existing conditions and triggers will be evaluated first. 

The _uistate_workflow_ library comes also with an extension for `BuildContext`, which enables the usage of the shortcut `context.goToState`.

__Do not use Router methods to navigate, as changes will not be tracked by the workflow engine__

Components
--

### States

The states are associated with specific views in the app.

This are the usable types of states:

* `UIState`

	The base state class, all other classes inherit from it. It consist of an ID and can have an entering condition.

* `StartState`

	The special start state which represents the entry point of the workflow. Therefore there must be exactly obe defined in any valid workflow. It cannot be part of a group.

* `GroupState`

	Consists of a set of inner states, which can also contain other group states. As a restriction groups cannot be directly targeted by a transition, but can indeed be a source.


### Transitions

Transitions are the connection between different states. There should be no state without transition, as it would be unreachable. The transitions must be defined once, but there is no need to call them manually, as this is automatically handled by the workflow engine.

This are the usable types of transitions:

- `ActionTransition`

	Normal connection between states. As it would be cumbersome to define really each transition between two states, it is possible to combine multiple sources for one target state.

- `TriggerTransition`

	Automatically triggered connection between exactly two states, depending on a set condition.

### State manager

The class `UIStateManager` represents the UI workflow engine. It handles the transitions between states and checks the related conditions. All available states and transitions of the workflow are defined during the creation by passing them to its constructor.

```dart
UIStateManager(
  states: {
    StartState(id: 'start'),
    GroupState(
      id: 'g0',
      innerStates: {
        UIState(id: 'g0.s0'),
        UIState(id: 'g0.s1'),
      },
    ),
  },
  transitions: {
    TriggerTransition(
      id: 't0',
      sourceId: 'start',
      targetId: 'g0.s0',
      condition: () => true
    ),
    ActionTransition.singleSource(
      id: 't1',
      sourceId: 'g0.s0',
      targetId: 'g0.s1',
    ),
    ActionTransition.singleSource(
      id: 't2',
      sourceIds: 'g0.s1',
      targetId: 'g0.s0',
    ),
  },
)
```
In this example, the workflow will begin with the state _start_, immediately jumping to _g0.s0_, as the auto transition _t0_ has a condition of `true`. Thereafter _start_ cannot be entered again, but transitions between _g0.s0_ and _g0.s1_ remains possible.

An additional way to create a state manager is by using the `UIStateManagerFactory` helper class.

### Workflow widget

The `UIStateWorkflow` helper widget glues all components together. It should be used for easy usage and more pre-build helper functionality. The `builder` method can then be used to initialize the routing widget. Workflow specific instances of `RouteInformationParser` and `RouterDelegate` are automatically created and passed into the `builder` through `WorkflowContext`.

```dart
Widget build(BuildContext context) {
  final appModel = AppModel();

  return ChangeNotifierProvider.value(
    value: appModel,
    child: UIStateWorkflow(
      managerFactory: _managerFactory,
      pageSelector: (config) =>
          DynamicAppView(config: config ?? PageConfiguration.empty()),
      valueProviders: {appModel},
      builder: (context, wfContext) {
        return MaterialApp.router(
          routeInformationParser: wfContext.informationParser,
          routerDelegate: wfContext.routerDelegate,
        );
      },
    ),
  );
}
```

The parameters `managerFactory`, `pageSelector` and `valueProviders` are mandatory to the constructor and provide relevant initialization and working data to the workflow. <br/>They have the following roles:

- `managerFactory`

	A contruction method, which is used to build the `UIStateManager` for the widget. A instance of `ProviderContext`, which consists of the value providers, defined with `valueProviders` is passed into the method, to provide access to needed data fields for state and trigger conditions.

- `pageSelector`

	This method is responsible for the state dependend view selection logic. It therefore creates the association between state and view\page configuration. Whenever the current state of the workflow changes, the method is called to determine the right view for it.


- `valueProviders`

	The list of value classes which exposes data for access within the workflow. They are automatically listened on for changes to reevaluate workflow conditions. Therefore this must be instances of `ChangeNotifier` or other classes which inherit from `Listenable`. The providers can be accessed from the `managerFactory` and `builder` methods through `ProviderContext` or `WorkflowContext`.

Workflow logic
--
The workflow engine will evaluate the next valid state every time a value provider notifies about a change and if the user manually calls `UIStateWorkflow.goToState` to trigger a transition. The following steps are __recursively__ traversed by the `UIStateManager`:

* Check triggers on parent states starting from the topmost.
	* If state found, it may be returned.
* If source state is conditional, the condition is checked.
	* If condition fails, the fallback state may be returned.
* Check all available trigger transitions of the source state in order.
* If a target state is conditional a traversal is only considered, if the condition is met.
* Check the condition of trigger transition.
	* If condition is met, the target may be returned.

If no other valid state is found in course of the evaluation process and the target state is either conditional with the condition met, or unconditional, it will be selected as the next state.

