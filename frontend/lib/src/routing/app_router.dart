import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:university_timetable_frontend/src/features/dashboard/dashboard_screen.dart';
import 'package:university_timetable_frontend/src/features/data_center/data_center_screen.dart';
import 'package:university_timetable_frontend/src/features/enrollment/enrollment_screen.dart';
import 'package:university_timetable_frontend/src/features/organization/group_designer_screen.dart';
import 'package:university_timetable_frontend/src/features/organization/org_center_screen.dart';
import 'package:university_timetable_frontend/src/features/timetable_generator/generator_hub_screen.dart';
import 'package:university_timetable_frontend/src/features/timetable_view/timetable_screen.dart';
import 'package:university_timetable_frontend/src/features/slot_config/slot_config_screen.dart';
import 'package:university_timetable_frontend/src/features/data_center/teacher_availability_screen.dart';
import 'package:university_timetable_frontend/src/features/sessions/session_data_center_screen.dart';
import 'package:university_timetable_frontend/src/features/settings/settings_screen.dart';
import 'package:university_timetable_frontend/src/features/developer_tools/sql_console_screen.dart';
import 'package:university_timetable_frontend/src/features/help/user_guide_screen.dart';
import 'package:university_timetable_frontend/src/routing/app_shell.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

final router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
    // ── Shell Route: persistent sidebar wraps these ──
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: '/',
          pageBuilder: (context, state) => const NoTransitionPage(child: DashboardScreen()),
        ),
        GoRoute(
          path: '/data-center',
          pageBuilder: (context, state) {
            final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '0') ?? 0;
            final isFocused = state.uri.queryParameters['focused'] == 'true';
            return NoTransitionPage(child: DataCenterScreen(initialTabIndex: tab, isFocused: isFocused));
          },
        ),
        GoRoute(
          path: '/session-data',
          pageBuilder: (context, state) {
            final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '0') ?? 0;
            final isFocused = state.uri.queryParameters['focused'] == 'true';
            return NoTransitionPage(child: SessionDataCenterScreen(initialTabIndex: tab, isFocused: isFocused));
          },
        ),
        GoRoute(
          path: '/org-center',
          pageBuilder: (context, state) {
            final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '0') ?? 0;
            final isFocused = state.uri.queryParameters['focused'] == 'true';
            return NoTransitionPage(child: OrgCenterScreen(initialTabIndex: tab, isFocused: isFocused));
          },
        ),

        GoRoute(
          path: '/enrollment',
          pageBuilder: (context, state) => const NoTransitionPage(child: EnrollmentScreen()),
        ),
        GoRoute(
          path: '/scheduler',
          pageBuilder: (context, state) => const NoTransitionPage(child: GeneratorHubScreen()),
        ),
        GoRoute(
          path: '/timetable',
          pageBuilder: (context, state) {
            final versionIdRaw = state.uri.queryParameters['versionId'];
            return NoTransitionPage(child: TimetableScreen(versionId: versionIdRaw != null ? int.tryParse(versionIdRaw) : null));
          },
        ),
        GoRoute(
          path: '/slot-config',
          pageBuilder: (context, state) => const NoTransitionPage(child: SlotConfigScreen()),
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) => const NoTransitionPage(child: SettingsScreen()),
        ),
        GoRoute(
          path: '/user-guide',
          pageBuilder: (context, state) => const NoTransitionPage(child: UserGuideScreen()),
        ),
        GoRoute(
          path: '/sql-console',
          pageBuilder: (context, state) => const NoTransitionPage(child: SqlConsoleScreen()),
        ),
      ],
    ),

    // ── Full-screen routes (outside shell, with back button) ──
    GoRoute(
      path: '/teacher-availability/:id',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        final name = state.uri.queryParameters['name'] ?? 'Teacher';
        return TeacherAvailabilityScreen(teacherId: id, teacherName: name);
      },
    ),
    GoRoute(
      path: '/group-designer/:id',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        final name = state.uri.queryParameters['name'] ?? 'Group';
        return GroupDesignerScreen(groupId: id, groupName: name);
      },
    ),
  ],
);
