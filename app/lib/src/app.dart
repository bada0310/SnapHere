import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snap_here/src/app/router/app_router.dart';
import 'package:snap_here/src/app/theme/app_theme.dart';
import 'package:snap_here/src/features/auth/application/auth_controller.dart';

class SnapHereApp extends ConsumerStatefulWidget {
  const SnapHereApp({super.key});

  @override
  ConsumerState<SnapHereApp> createState() => _SnapHereAppState();
}

class _SnapHereAppState extends ConsumerState<SnapHereApp> {
  bool _initialAuthResolved = false;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    if (!_initialAuthResolved && auth.isLoading) {
      return MaterialApp(
        title: 'SnapHere',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    _initialAuthResolved = true;
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'SnapHere',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}
