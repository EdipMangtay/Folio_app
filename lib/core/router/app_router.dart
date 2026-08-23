import 'package:go_router/go_router.dart';

import '../../presentation/analytics/analytics_screen.dart';
import '../../presentation/budgets/budgets_screen.dart';
import '../../presentation/dashboard/dashboard_screen.dart';
import '../../presentation/import/receipt_scan_screen.dart';
import '../../presentation/import/statement_import_screen.dart';
import '../../presentation/onboarding/onboarding_screen.dart';
import '../../presentation/profile/profile_screen.dart';
import '../../presentation/report/monthly_report_screen.dart';
import '../../presentation/shell/app_shell.dart';
import '../../presentation/subscriptions/subscriptions_screen.dart';
import '../../presentation/transactions/transaction_detail_screen.dart';
import '../../presentation/transactions/transactions_screen.dart';

GoRouter buildAppRouter({required bool onboardingSeen}) {
  return GoRouter(
    initialLocation: onboardingSeen ? '/' : '/onboarding',
    routes: <RouteBase>[
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      StatefulShellRoute(
        builder: (context, state, navigationShell) => navigationShell,
        navigatorContainerBuilder: (context, navigationShell, children) {
          return AppShell(
            navigationShell: navigationShell,
            children: children,
          );
        },
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            preload: true,
            routes: <RouteBase>[
              GoRoute(path: '/', builder: (context, state) => const DashboardScreen()),
            ],
          ),
          StatefulShellBranch(
            preload: true,
            routes: <RouteBase>[
              GoRoute(path: '/transactions', builder: (context, state) => const TransactionsScreen()),
            ],
          ),
          StatefulShellBranch(
            preload: true,
            routes: <RouteBase>[
              GoRoute(path: '/analytics', builder: (context, state) => const AnalyticsScreen()),
            ],
          ),
          StatefulShellBranch(
            preload: true,
            routes: <RouteBase>[
              GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/transaction/:id',
        builder: (context, state) => TransactionDetailScreen(transactionId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/receipt', builder: (context, state) => const ReceiptScanScreen()),
      GoRoute(path: '/statement', builder: (context, state) => const StatementImportScreen()),
      GoRoute(path: '/budgets', builder: (context, state) => const BudgetsScreen()),
      GoRoute(path: '/subscriptions', builder: (context, state) => const SubscriptionsScreen()),
      GoRoute(path: '/monthly-report', builder: (context, state) => const MonthlyReportScreen()),
    ],
  );
}
