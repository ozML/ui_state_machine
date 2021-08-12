import 'dart:collection';

import 'package:flutter/widgets.dart';
import 'package:ui_state_machine/src/state_management/uistate_manager.dart';
import 'package:ui_state_machine/src/workflow/routing.dart';
import 'package:ui_state_machine/src/workflow/uistate_page.dart';

/// Widget which encapsulates all relevant information for ui state workflow.
///
/// This widget should be wrapped around a [Router] or [MaterialApp], which can
/// then be created within the [UIStateWorkflow.builder] method in the
/// constructor. The [UIStateWorkflow] instance passed to the method provides
/// access to the the [RouteInformationParser] an [RouterDelegate] instance
/// specific to the workflow, which should be used in the routing class, to
/// enable tthe full capacity of the workflow engine.
///
/// ___Example:___
/// ```dart
///  Widget build(BuildContext context) {
///    final loginState = LoginState();
///    final rolesState = RolesState();
///
///    return MultiProvider(
///      providers: [
///        ChangeNotifierProvider.value(value: loginState),
///        ChangeNotifierProvider.value(value: rolesState)
///      ],
///      child: UIStateWorkflow(
///        managerFactory: _managerFactory,
///        pageSelector: _pageSelector,
///        valueProviders: {loginState, rolesState},
///        enableLocations: false,
///        useFullLocations: false,
///        builder: (context, wfContext) {
///          return MaterialApp.router(
///            routeInformationParser: wfContext.informationParser,
///            routerDelegate: wfContext.routerDelegate,
///          );
///        },
///      ),
///    );
///  }
/// ```
class UIStateWorkflow extends StatelessWidget {
  /// Creates an instance of [UIStateWorkflow].
  ///
  /// The manager which is used by the workflow is created by [managerFactory].
  /// The context available to this factory method contains the value providers
  /// which are provided through [valueProviders]. Triggers and conditions on
  /// states and trantitions should only depend on providers known to the
  /// workflow, as they are listened on. This way workflow conditions can be
  /// evaluated on every change, and trigger transitions can be applied if
  /// needed. Whether a change notification should trigger a reevaluation of the
  /// worklow conditions, can be adjusted by defining [changeHandler].
  ///
  /// __Location adjustment__
  ///
  /// By default, the engine does not display a URL for the current state. This
  /// behavior can be configured by [enableLocations] and [enableFullLocations].
  /// The exact URL to state association can be further adjusted by passing in
  /// an custom implementation of [LocationConverter] for [locationConverter].
  /// By omitting the parameter, the default implementation is used.
  /// See [LocationConverter] for further information about this.
  ///
  /// __Page generation__
  ///
  /// The association between pages and workflow states is created with the
  /// [pageSelector] function. Each existing state, with exception of group
  /// states, should be associated with an [UIStatePage, as they can not be
  /// targeted directly.
  UIStateWorkflow({
    required UIStateManager Function(ProviderContext context) managerFactory,
    required UIStatePage Function(PageConfiguration? config) pageSelector,
    required Widget Function(BuildContext context, WorkflowContext wfContext)
        builder,
    Set<Listenable> valueProviders = const {},
    bool Function(ProviderContext context)? changeHandler,
    bool enableLocations = false,
    bool useFullLocations = false,
    LocationConverter? locationConverter,
  })  : _context = _createContext(
          managerFactory,
          valueProviders,
          enableLocations,
          useFullLocations,
          pageSelector,
          locationConverter,
        ),
        _builder = builder,
        _changeHandler = changeHandler {
    _init();
  }

  /// The workflow context related to this workflow instance.
  final WorkflowContext _context;

  /// The builder method used within the [build] method.
  final Widget Function(BuildContext context, WorkflowContext config) _builder;

  /// The change handler used in [_onChangeNotification].
  final bool Function(ProviderContext context)? _changeHandler;

  /// Getter for the workflow context.
  WorkflowContext get workflowContext => _context;

  /// Returns the nearest [UIStateWorkflow] instance in the UI tree.
  static UIStateWorkflow of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_UIStateWorkflowScope>()!
        .workflow;
  }

  /// Creates a new instance of [WorkflowContext].
  static WorkflowContext _createContext(
    UIStateManager Function(ProviderContext context) managerFactory,
    Set<Listenable> valueProviders,
    bool enableLocations,
    bool useFullLocations,
    UIStatePage Function(PageConfiguration? config) pageSelector,
    LocationConverter? locationConverter,
  ) {
    final context = ProviderContext(valueProviders: valueProviders);
    final manager = managerFactory(context);

    final _locationConverter = locationConverter ??
        LocationConverter(
          states: manager.states,
          useFullLocations: useFullLocations,
        );
    final informationParser = UIStateInformationParser(
      manager: manager,
      enableLocations: enableLocations,
      useFullLocations: useFullLocations,
      locationConverter: _locationConverter,
    );
    final stateDelegate = UIStateDelegate(
      manager: manager,
      pageSelector: pageSelector,
      enableLocations: enableLocations,
      useFullLocations: useFullLocations,
      locationConverter: _locationConverter,
    );

    return WorkflowContext(
      manager: manager,
      informationParser: informationParser,
      routerDelegate: stateDelegate,
      valueProviders: valueProviders,
    );
  }

  /// Initializes the workflow instance.
  void _init() {
    if (!_context.manager.isInitialized) {
      _context.manager.initialize();
    }

    Listenable.merge(_context.valueProviders.toList())
      ..addListener(() => _onChangeNotification());
  }

  /// Refreshes the workflow state.
  ///
  /// Therefore the method [UIStateManager.applyTriggers] is called on the
  /// contained manager.
  void refresh() {
    _context.manager.applyTriggers();
  }

  /// Tries to make the transition to the state with the specified id.
  ///
  /// Therefore the method [UIStateManager.goTo] is called on the contained
  /// manager.
  void goToState(String stateId) {
    _context.manager.goTo(stateId);
  }

  /// Is triggered if a value provider has changed.
  void _onChangeNotification() {
    if (_changeHandler?.call(_context) ?? true) {
      _context.manager.applyTriggers();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _UIStateWorkflowScope(
      workflow: this,
      child: _builder(context, _context),
    );
  }
}

/// Inherited widget which grants access to [UIStateWorkflow].
class _UIStateWorkflowScope extends InheritedWidget {
  /// Creates an instance of [_UIStateWorkflowScope].
  const _UIStateWorkflowScope({
    required this.workflow,
    required Widget child,
    Key? key,
  }) : super(key: key, child: child);

  /// The contained workflow.
  final UIStateWorkflow workflow;

  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) {
    return false;
  }
}

/// Consists of the relevant data instances of [UIStateWorkflow].
///
/// An instance of this class is passed into the [UIStateWorkflow.builder]
/// method to provide access to the information parser and router delegate,
/// which can then be passed into a [Router] or [MaterialApp] constructor.
///
/// For further information see also [UIStateWorkflow].
class WorkflowContext extends ProviderContext {
  /// Creates an instance of [WorkflowContext].
  const WorkflowContext({
    required this.manager,
    required this.informationParser,
    required this.routerDelegate,
    Set<Listenable> valueProviders = const {},
  }) : super(valueProviders: valueProviders);

  /// The manager of the workflow.
  final UIStateManager manager;

  /// [RouteInformationParser] implementation instance.
  final UIStateInformationParser informationParser;

  /// [RouterDelegate] implementation instance.
  final UIStateDelegate routerDelegate;
}

/// Wraps a set of value providers and provides helper methods to access these.
class ProviderContext {
  const ProviderContext({Set<Listenable> valueProviders = const {}})
      : _valueProviders = valueProviders;

  /// Value providers used within the workflow.
  final Set<Listenable> _valueProviders;

  /// Getter for the value providers.
  Set<Listenable> get valueProviders => UnmodifiableSetView(_valueProviders);

  /// Checks whether the provider of a specific type exists within the set.
  bool exists<T extends Listenable>() {
    return fetch<T>() != null;
  }

  /// Searches the set of providers for the one with the specific type.
  ///
  /// Returns null if no provider was found.
  T? fetch<T extends Listenable>() {
    final providers = valueProviders.whereType<T>();
    if (providers.isNotEmpty) {
      return providers.first;
    }

    return null;
  }

  /// Searches the set of providers for the one with the specific type.
  ///
  /// Throws an exception if no provider was found. Consider using [exists]
  /// beforehand, or use [fetch].
  T access<T extends Listenable>() {
    return valueProviders.whereType<T>().first;
  }
}

/// Extension for [BuildContext].
///
/// Provides several shortcuts and helper methods regarding UI state workflow.
extension WorkflowContextExtension on BuildContext {
  /// Shortcut for [UIStateWorkflow.of].
  UIStateWorkflow workflow() {
    return UIStateWorkflow.of(this);
  }

  /// Shortcut for [UIStateWorkflow.goToState].
  void goToState(String stateId) {
    return this.workflow().goToState(stateId);
  }

  /// Shortcut for [ProviderContext.access].
  bool exists<T extends Listenable>() {
    return this.workflow().workflowContext.exists<T>();
  }

  /// Shortcut for [ProviderContext.access].
  T? fetch<T extends Listenable>() {
    return this.workflow().workflowContext.fetch<T>();
  }

  /// Shortcut for [ProviderContext.access].
  T access<T extends Listenable>() {
    return this.workflow().workflowContext.access<T>();
  }
}
