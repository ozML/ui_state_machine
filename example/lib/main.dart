import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uistate/uistate.dart';

void main() {
  runApp(UIStateSampleApp());
}

/// Example app for UI state workflow.
class UIStateSampleApp extends StatelessWidget {
  Widget build(BuildContext context) {
    final appModel = AppModel();

    return ChangeNotifierProvider.value(
      value: appModel,
      child: UIStateWorkflow(
        managerFactory: _managerFactory,
        pageSelector: (config) =>
            DynamicAppView(config: config ?? PageConfiguration.empty()),
        valueProviders: {appModel},
        enableLocations: false,
        useFullLocations: false,
        builder: (context, wfContext) {
          return MaterialApp.router(
            routeInformationParser: wfContext.informationParser,
            routerDelegate: wfContext.routerDelegate,
          );
        },
      ),
    );
  }

  /// Builds the state manager.
  static UIStateManager _managerFactory(ProviderContext context) {
    final factory = UIStateManagerFactory()
        // Adds the start state.
        .addState(StartState(id: 'login'))

        // Adds the group 'logged_in', which consists of three childs.
        // The group is conditional, and can only be entered if the condition
        // 'AppModel.isSignedIn == true' is met. Also if the condition
        // parameters, change while in the state, the workflow will
        // automatically jump to the fallback state defined with 'fallbackId'.
        .addState(GroupState.conditional(
          id: 'logged_in',
          innerStates: {
            UIState(id: 'dashboard'),
            UIState(id: 'userview'),

            // This child is also a conditional group, with the condition
            // 'AppModel.isAdmin == true'.
            GroupState.conditional(
              id: 'admin_area',
              innerStates: {UIState(id: 'settings')},
              condition: () => context.access<AppModel>().isAdmin == true,
              fallbackId: 'dashboard',
            ),
          },
          condition: () => context.access<AppModel>().isSignedIn == true,
          fallbackId: 'login',
        ))

        // Adds an automatically evaluated transition. If 'AppModel.isSignedIn'
        // changes to 'true' while in the state 'login', the workflow will
        // automatically jump to the state 'dashboard'.
        .addTransition(TriggerTransition(
          id: 't|login:dashboard',
          sourceId: 'login',
          targetId: 'dashboard',
          condition: () => context.access<AppModel>().isSignedIn == true,
        ))

        // Adds transitions between all the inner views. Otherwise it won't be
        // possible to transition between them at all. It can be noted, that
        // although group states cannot be targeted directly, they can be indeed
        // sources of transitions.
        .addTransition(ActionTransition(
          id: '+:dashboard',
          sourceIds: {'userview', 'admin_area'},
          targetId: 'dashboard',
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

    return factory.build();
  }
}

/// Example model simulating sign in state and admin role.
class AppModel extends ChangeNotifier {
  bool _isSignedIn = false;
  bool _isAdmin = false;

  bool get isSignedIn => _isSignedIn;
  bool get isAdmin => _isAdmin;

  void toggleSignIn() {
    _isSignedIn = !_isSignedIn;
    notifyListeners();
  }

  void toggleAdminRole() {
    _isAdmin = !_isAdmin;
    notifyListeners();
  }
}

/// Example view that builds appearance depending on the config and model state.
class DynamicAppView extends UIStatePage {
  DynamicAppView({required PageConfiguration config}) : super(config: config);

  static String _toTitle(String id) {
    RegExp regExp = new RegExp(r'^(login|dashboard|userview|settings)$');
    return regExp.hasMatch(id)
        ? '${id[0].toUpperCase()}${id.substring(1)}'
        : 'Error';
  }

  @override
  Widget buildView(BuildContext context, PageConfiguration config) {
    final model = context.access<AppModel>();
    return Scaffold(
      appBar: AppBar(
        title: Text(_toTitle(config.stateId)),
        centerTitle: true,
        leading: Visibility(
          visible: model.isSignedIn,
          child: Consumer<AppModel>(
            builder: (_, model, __) {
              String text = '${model.isAdmin ? 'Remove' : 'Get'} admin role';
              return TextButton(
                child: Text(text, style: TextStyle(color: Colors.white)),
                onPressed: () => model.toggleAdminRole(),
              );
            },
          ),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (model.isSignedIn)
              for (final id in ['dashboard', 'userview', 'settings'])
                if (config.stateId != id)
                  TextButton(
                    child: Text('Go to $id'),
                    onPressed: () => context.goToState(id),
                  ),
            TextButton(
              child: Text(model.isSignedIn ? 'Logout' : 'Login'),
              onPressed: () => model.toggleSignIn(),
            )
          ],
        ),
      ),
    );
  }
}
