import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pixel_pocket/core/widgets/pixel_bottom_nav.dart';
import 'package:pixel_pocket/features/chart/presentation/screens/chart_screen.dart';
import 'package:pixel_pocket/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:pixel_pocket/features/settings/presentation/screens/settings_screen.dart';
import 'package:pixel_pocket/features/transactions/presentation/screens/transaction_screen.dart';
import 'package:pixel_pocket/features/transactions/presentation/screens/widgets/transaction_form_sheet.dart';
import 'package:pixelarticons/pixel.dart';

import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../features/auth/presentation/controllers/pin_controller.dart';
import '../../features/auth/presentation/screens/forgot_pin_screen.dart';
import '../../features/auth/presentation/screens/set_pin_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/unlock_pin_screen.dart';
import '../../features/auth/presentation/states/auth_state.dart';

class AppRoutes {
  AppRoutes._();

  static const splash = '/splash';
  static const setPin = '/set-pin';
  static const unlock = '/unlock';
  static const resetPin = '/reset-pin';
  static const String dashboard = '/';
  static const String transactions = '/transactions';
  static const String addTransaction = '/transactions/add';
  static const String chart = '/chart';
  static const String settings = '/settings';
  static const String salaryPeriods = '/settings/salary-periods';
}

const _navItems = [
  PixelNavItem(icon: Pixel.home, label: 'HOME', path: AppRoutes.dashboard),
  PixelNavItem(icon: Pixel.reciept, label: 'TXN', path: AppRoutes.transactions),
  PixelNavItem(icon: Pixel.chartbar, label: 'CHART', path: AppRoutes.chart),
  PixelNavItem(
    icon: Pixel.sliders,
    label: 'SETTINGS',
    path: AppRoutes.settings,
  ),
];

/// Default date for a transaction started from the navbar's + button. On the
/// Transactions tab the form keeps following the visible range (null); every
/// other tab defaults to today, so a range parked on an old month there
/// doesn't leak into Home, Chart or Settings.
DateTime? addTransactionInitialDate({
  required String currentPath,
  required DateTime now,
}) => currentPath == AppRoutes.transactions
    ? null
    : DateTime(now.year, now.month, now.day);

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: _AuthRefreshNotifier(ref),
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final location = state.matchedLocation;

      if (auth is AuthUnknown) {
        return location == AppRoutes.splash ? null : AppRoutes.splash;
      }

      if (auth is AuthLocked) {
        final allowed =
            location == AppRoutes.unlock || location == AppRoutes.resetPin;
        return allowed ? null : AppRoutes.unlock;
      }

      final hasPin = ref.read(pinControllerProvider);
      if (hasPin == false) {
        return location == AppRoutes.setPin ? null : AppRoutes.setPin;
      }

      if (location == AppRoutes.splash ||
          location == AppRoutes.setPin ||
          location == AppRoutes.unlock ||
          location == AppRoutes.resetPin) {
        return AppRoutes.dashboard;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.setPin,
        name: 'setPin',

        builder: (context, state) => const SetPinScreen(),
      ),
      GoRoute(
        path: AppRoutes.unlock,
        name: 'unlock',

        builder: (context, state) => UnlockPinScreen(
          onSuccess: () => ref.read(authControllerProvider.notifier).unlock(),
        ),
      ),
      GoRoute(
        path: AppRoutes.resetPin,
        name: 'resetPin',

        builder: (context, state) => ForgotPinScreen(
          onSuccess: () => ref.read(authControllerProvider.notifier).unlock(),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) {
          return AppShell(shell: shell);
        },

        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.dashboard,
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),

          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.transactions,
                builder: (context, state) => const TransactionScreen(),
              ),
            ],
          ),

          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.chart,
                builder: (context, state) => const ChartScreen(),
              ),
            ],
          ),

          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.settings,
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],

    errorBuilder: (context, state) =>
        Scaffold(body: Center(child: Text('Page not found: ${state.uri}'))),
  );
});

class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    ref.listen(authControllerProvider, (_, _) => notifyListeners());

    ref.listen(pinControllerProvider, (_, _) => notifyListeners());
  }
}

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: SafeArea(bottom: false, child: shell),
      bottomNavigationBar: PixelBottomNav(
        items: _navItems,
        currentIndex: shell.currentIndex,
        onTap: _onTap,
        onAdd: () => _onAdd(context),
      ),
    );
  }

  void _onTap(int index) {
    shell.goBranch(index, initialLocation: index == shell.currentIndex);
  }

  void _onAdd(BuildContext context) {
    // Open on the active tab's navigator, like the tabs' own sheets: the sheet
    // then lives inside this Scaffold's body, so the form's snackbars render
    // above it instead of behind a root-level route.
    final tabContext =
        shell.route.branches[shell.currentIndex].navigatorKey.currentContext;
    TransactionFormSheet.show(
      tabContext ?? context,
      initialDate: addTransactionInitialDate(
        currentPath: _navItems[shell.currentIndex].path,
        now: DateTime.now(),
      ),
    );
  }
}
