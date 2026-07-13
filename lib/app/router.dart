import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/home/screens/home_screen.dart';
import '../features/reports/screens/reports_screen.dart';
import '../features/reports/screens/report_detail_screen.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/profile/screens/account_setting_page.dart';
import '../features/qc_material/screens/qc_material_list_screen.dart';
import '../features/qc_material/screens/qc_material_form_screen.dart';
import '../features/qc_pekerjaan/screens/qc_pekerjaan_segment_screen.dart';
import '../features/qc_pekerjaan/screens/qc_pekerjaan_list_screen.dart';
import '../features/qc_pekerjaan/screens/qc_pekerjaan_form_screen.dart';
import '../shared/layouts/main_shell.dart';
import '../shared/models/qc_material_template_model.dart';

CustomTransitionPage<void> _buildPageWithTransition({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 240),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );

      return FadeTransition(
        opacity: curvedAnimation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.03, 0.02),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: child,
        ),
      );
    },
  );
}

final GoRouter appRouter = GoRouter(
  initialLocation: '/login',
  routes: [
    // Auth route (No Bottom Nav)
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),

    // ShellRoute for Bottom Navigation Tabs
    ShellRoute(
      builder: (context, state, child) {
        return MainShell(child: child);
      },
      routes: [
        GoRoute(
          path: '/home',
          pageBuilder: (context, state) => _buildPageWithTransition(
            context: context,
            state: state,
            child: const HomeScreen(),
          ),
        ),
        GoRoute(
          path: '/reports',
          pageBuilder: (context, state) {
            final statusParam = state.uri.queryParameters['status'];
            return _buildPageWithTransition(
              context: context,
              state: state,
              child: ReportsScreen(initialStatus: statusParam),
            );
          },
        ),
        GoRoute(
          path: '/dashboard',
          pageBuilder: (context, state) => _buildPageWithTransition(
            context: context,
            state: state,
            child: const DashboardScreen(),
          ),
        ),
        GoRoute(
          path: '/profile',
          pageBuilder: (context, state) => _buildPageWithTransition(
            context: context,
            state: state,
            child: const ProfileScreen(),
          ),
        ),
      ],
    ),

    // Profile Account Settings (No Bottom Nav)
    GoRoute(
      path: '/profile/settings',
      pageBuilder: (context, state) => _buildPageWithTransition(
        context: context,
        state: state,
        child: const AccountSettingPage(),
      ),
    ),

    // QC Material sub-screens (No Bottom Nav)
    GoRoute(
      path: '/qc-material',
      pageBuilder: (context, state) => _buildPageWithTransition(
        context: context,
        state: state,
        child: const QCMaterialListScreen(),
      ),
    ),
    GoRoute(
      path: '/qc-material/form/:id',
      pageBuilder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        final editReportId = state.uri.queryParameters['editReportId'];
        final isRevision = state.uri.queryParameters['isRevision'] == 'true';
        final template = state.extra is QCMaterialTemplate
            ? state.extra as QCMaterialTemplate
            : null;
        return _buildPageWithTransition(
          context: context,
          state: state,
          child: QCMaterialFormScreen(
            materialId: id,
            editReportId: editReportId,
            isRevision: isRevision,
            template: template,
          ),
        );
      },
    ),

    // QC Pekerjaan sub-screens (No Bottom Nav)
    GoRoute(
      path: '/qc-pekerjaan',
      pageBuilder: (context, state) => _buildPageWithTransition(
        context: context,
        state: state,
        child: const QCPekerjaanSegmentScreen(),
      ),
    ),
    GoRoute(
      path: '/qc-pekerjaan/list/:segment',
      pageBuilder: (context, state) {
        final segment = state.pathParameters['segment'] ?? '';
        return _buildPageWithTransition(
          context: context,
          state: state,
          child: QCPekerjaanListScreen(segment: segment),
        );
      },
    ),
    GoRoute(
      path: '/qc-pekerjaan/form/:id',
      pageBuilder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        final editReportId = state.uri.queryParameters['editReportId'];
        final isRevision = state.uri.queryParameters['isRevision'] == 'true';
        return _buildPageWithTransition(
          context: context,
          state: state,
          child: QCPekerjaanFormScreen(
            pekerjaanId: id,
            editReportId: editReportId,
            isRevision: isRevision,
          ),
        );
      },
    ),

    // Report Detail (No Bottom Nav)
    GoRoute(
      path: '/reports/:id',
      pageBuilder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return _buildPageWithTransition(
          context: context,
          state: state,
          child: ReportDetailScreen(reportId: id),
        );
      },
    ),
  ],
);
