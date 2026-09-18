import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Opens a route owned by the bottom-tab shell without adding a second shell.
void openShellRoute(BuildContext context, String location) {
  if (StatefulNavigationShell.maybeOf(context) == null) {
    context.go(location);
  } else {
    context.push(location);
  }
}
