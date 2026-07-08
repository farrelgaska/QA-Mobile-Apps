import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/bottom_nav.dart';

class MainShell extends StatelessWidget {
  final Widget child;

  const MainShell({
    Key? key,
    required this.child,
  }) : super(key: key);

  int _getSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/reports')) return 1;
    if (location.startsWith('/dashboard')) return 2;
    if (location.startsWith('/profile')) return 3;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/reports');
        break;
      case 2:
        context.go('/dashboard');
        break;
      case 3:
        context.go('/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _getSelectedIndex(context);
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNav(
        currentIndex: selectedIndex,
        onTap: (index) => _onItemTapped(index, context),
      ),
    );
  }
}
