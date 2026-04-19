import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:university_timetable_frontend/src/features/data_center/data_providers.dart';
import 'package:university_timetable_frontend/src/features/enrollment/enrollment_provider.dart';
import 'package:university_timetable_frontend/src/features/organization/org_providers.dart';
import 'package:university_timetable_frontend/src/features/slot_config/slot_config_provider.dart';
import 'package:university_timetable_frontend/src/features/sessions/session_dialog.dart';
import 'package:university_timetable_frontend/src/features/sessions/session_provider.dart';
import 'package:university_timetable_frontend/src/features/sessions/session_entities_provider.dart';
import 'package:university_timetable_frontend/src/models/session.dart';

/// Global provider for sidebar collapse state
final sidebarCollapsedProvider = NotifierProvider<SidebarCollapsedNotifier, bool>(SidebarCollapsedNotifier.new);

class SidebarCollapsedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
  
  void set(bool value) => state = value;
}


class AppShell extends ConsumerWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCollapsed = ref.watch(sidebarCollapsedProvider);

    return Scaffold(
      body: Row(
        children: [
          // Persistent Sidebar
          _AppSidebar(isCollapsed: isCollapsed),
          // Main Content Area
          Expanded(
            child: Container(
              color: Theme.of(context).colorScheme.surfaceContainerLowest,
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _AppSidebar extends ConsumerStatefulWidget {
  final bool isCollapsed;
  const _AppSidebar({required this.isCollapsed});

  @override
  ConsumerState<_AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends ConsumerState<_AppSidebar> {
  String _sessionSearchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sessionsAsync = ref.watch(sessionsProvider);
    final activeSession = ref.watch(activeSessionProvider);

    // Automatically navigate to dashboard when session changes
    ref.listen<SessionModel?>(activeSessionProvider, (previous, next) {
      if (next?.sessionId != previous?.sessionId) {
        context.go('/');
      }
    });

    // Central DB counts
    final teacherCount = ref.watch(teachersProvider).value?.length;
    final roomCount = ref.watch(classroomsProvider).value?.length;
    final subjectCount = ref.watch(subjectsProvider).value?.length;
    final studentCount = ref.watch(studentsProvider).value?.length;
    final groupCount = ref.watch(groupsProvider).value?.length;
    final branchCount = ref.watch(branchesProvider).value?.length;
    final enrollCount = ref.watch(enrollmentsProvider).value?.length;

    // Session counts
    final sessionTeacherCount = ref.watch(sessionTeachersProvider).value?.length;
    final sessionRoomCount = ref.watch(sessionRoomsProvider).value?.length;
    final sessionSubjectCount = ref.watch(sessionSubjectsProvider).value?.length;
    final sessionGroupCount = ref.watch(sessionGroupsProvider).value?.length;

    // Readiness check for Generate button
    final hasSlots = (ref.watch(slotConfigProvider).value?.slots.isNotEmpty ?? false);
    final hasTeachers = (ref.watch(sessionTeachersProvider).value?.isNotEmpty ?? false);
    final hasRooms = (ref.watch(sessionRoomsProvider).value?.isNotEmpty ?? false);
    final hasSubjects = (ref.watch(sessionSubjectsProvider).value?.isNotEmpty ?? false);
    final hasGroups = (ref.watch(sessionGroupsProvider).value?.isNotEmpty ?? false);
    final hasEnrollments = (ref.watch(enrollmentsProvider).value?.isNotEmpty ?? false);
    final isReady = hasSlots && hasTeachers && hasRooms && hasSubjects && hasGroups && hasEnrollments;

    final sidebarWidth = widget.isCollapsed ? 72.0 : 260.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      width: sidebarWidth,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(right: BorderSide(color: theme.colorScheme.outlineVariant.withAlpha(80))),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: widget.isCollapsed ? 0 : 20, vertical: 20),
            decoration: BoxDecoration(color: theme.colorScheme.primary),
            child: SafeArea(
              bottom: false,
              child: widget.isCollapsed
                  ? Center(child: Icon(Icons.school_rounded, color: theme.colorScheme.onPrimary, size: 28))
                  : Row(
                      children: [
                        Icon(Icons.school_rounded, color: theme.colorScheme.onPrimary, size: 28),
                        const SizedBox(width: 12),
                        Text(
                          'UniScheduler',
                          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: theme.colorScheme.onPrimary, letterSpacing: -0.3),
                        ),
                      ],
                    ),
            ),
          ),

          // ── Collapse toggle ──
          Tooltip(
            message: widget.isCollapsed ? 'Expand Sidebar' : 'Collapse Sidebar',
            child: InkWell(
              onTap: () => ref.read(sidebarCollapsedProvider.notifier).toggle(),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant.withAlpha(50))),
                ),
                child: Icon(
                  Icons.menu_rounded,
                  size: 22,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // ── Scrollable nav items ──
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Central Database
                  _ShellNavItem(
                    icon: Icons.storage_rounded,
                    label: 'Central Database',
                    path: '', // Use empty path to allow strictly state-based highlighting
                    isCollapsed: widget.isCollapsed,
                    isHighlighted: activeSession == null || activeSession.sessionId == -1,
                    onTap: () async {
                      if (activeSession != null && activeSession.sessionId != -1) {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Return to Central Database?'),
                            content: const Text(
                              'You are currently working in a session. Returning to the central database will clear the current view context.'
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                               ),
                              FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Continue'),
                              ),
                            ],
                          ),
                        );
                        if (confirm != true) return;
                      }
                      if (!context.mounted) return;
                      // Force refresh the session list to ensure metrics are accurate
                      ref.read(sessionsProvider.notifier).refresh();
                      ref.read(activeSessionProvider.notifier).setSession(SessionModel(sessionId: -1, name: 'Central Database'));
                      context.go('/');
                    },
                  ),

                  // ── Session Picker ──

                  if (!widget.isCollapsed) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 16, top: 16, bottom: 4),
                      child: Text('SESSION', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: theme.colorScheme.onSurfaceVariant.withAlpha(150))),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: sessionsAsync.when(
                        data: (list) {
                          // --- AUTO-RESYNC FALLBACK ---
                          // If we have an active session that isn't in the list, trigger a silent refresh
                          if (activeSession != null && activeSession.sessionId != -1) {
                            final exists = list.any((s) => s.sessionId == activeSession.sessionId);
                            if (!exists) {
                              // We don't want to use state = AsyncLoading here to avoid flicker, 
                              // we just want to trigger a background fetch.
                              Future.microtask(() => ref.read(sessionsProvider.notifier).build());
                            }
                          }

                          // 1. Sort alphabetically
                          final sortedList = List<SessionModel>.from(list)
                            ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

                          // 2. Filter by search query
                          final filteredList = _sessionSearchQuery.isEmpty
                              ? sortedList
                              : sortedList.where((s) => s.name.toLowerCase().contains(_sessionSearchQuery.toLowerCase())).toList();

                          final selectedSession = (filteredList.any((s) => s.sessionId == activeSession?.sessionId) && activeSession?.sessionId != -1)
                              ? filteredList.firstWhere((s) => s.sessionId == activeSession?.sessionId)
                              : null;

                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Session search field
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: TextField(
                                  onChanged: (v) => setState(() => _sessionSearchQuery = v.trim()),
                                  style: GoogleFonts.inter(fontSize: 13),
                                  decoration: InputDecoration(
                                    hintText: 'Search sessions...',
                                    hintStyle: GoogleFonts.inter(fontSize: 12, color: theme.colorScheme.onSurfaceVariant.withAlpha(150)),
                                    prefixIcon: Icon(Icons.search_rounded, size: 16, color: theme.colorScheme.onSurfaceVariant.withAlpha(180)),
                                    isDense: true,
                                    filled: true,
                                    fillColor: theme.colorScheme.surfaceContainerHighest.withAlpha(50),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                  ),
                                ),
                              ),

                              PopupMenuButton<SessionModel>(
                                offset: const Offset(0, 44),
                                constraints: const BoxConstraints(minWidth: 236, maxWidth: 236),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                color: theme.colorScheme.surface,
                                elevation: 8,
                                tooltip: 'Select Workspace',
                                onSelected: (val) {
                                  if (val.sessionId == -2) {
                                    showDialog(context: context, builder: (context) => const SessionDialog());
                                  } else {
                                    ref.read(activeSessionProvider.notifier).setSession(val);
                                    context.go('/');
                                  }
                                },
                                itemBuilder: (context) => [
                                  if (filteredList.isEmpty)
                                    PopupMenuItem<SessionModel>(
                                      value: SessionModel(sessionId: -99, name: 'Empty'),
                                      enabled: false,
                                      child: Text(
                                          _sessionSearchQuery.isEmpty ? 'No sessions available' : 'No sessions matching "$_sessionSearchQuery"',
                                          style: GoogleFonts.inter(fontSize: 13, color: Colors.grey)),
                                    ),
                                  ...filteredList.map((s) => PopupMenuItem(
                                        value: s,
                                        child: Row(children: [
                                          Icon(Icons.layers_rounded, size: 18, color: (s.sessionId == activeSession?.sessionId) ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
                                          const SizedBox(width: 12),
                                          Expanded(child: Text(s.name, style: GoogleFonts.inter(fontSize: 14, fontWeight: (s.sessionId == activeSession?.sessionId) ? FontWeight.w600 : FontWeight.w500), overflow: TextOverflow.ellipsis)),
                                        ]),
                                      )),
                                  const PopupMenuDivider(),
                                  PopupMenuItem<SessionModel>(
                                    value: SessionModel(sessionId: -2, name: 'New Session'),
                                    child: Row(children: [
                                      Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(shape: BoxShape.circle, color: theme.colorScheme.primaryContainer),
                                        child: Icon(Icons.add_rounded, size: 16, color: theme.colorScheme.primary),
                                      ),
                                      const SizedBox(width: 12),
                                      Text('Create New Session', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: theme.colorScheme.primary)),
                                    ]),
                                  ),
                                ],
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surface,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: (selectedSession != null || (activeSession != null && activeSession.sessionId != -1)) ? theme.colorScheme.primary.withAlpha(50) : theme.colorScheme.outlineVariant.withAlpha(50)),
                                  ),
                                  child: Row(children: [
                                    Icon(Icons.layers_outlined, size: 18, color: (selectedSession != null || (activeSession != null && activeSession.sessionId != -1)) ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        (activeSession != null && activeSession.sessionId != -1) ? activeSession.name : 'Select Workspace...',
                                        style: GoogleFonts.inter(fontSize: 13, fontWeight: (activeSession != null && activeSession.sessionId != -1) ? FontWeight.w600 : FontWeight.w500, color: (activeSession != null && activeSession.sessionId != -1) ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Icon(Icons.unfold_more_rounded, size: 18, color: theme.colorScheme.onSurfaceVariant.withAlpha(150)),
                                  ]),
                                ),
                              ),
                            ],
                          );
                        },
                        loading: () => const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator()),
                        error: (e, s) => const Text('Error'),
                      ),
                    ),
                  ] else ...[
                    // Collapsed: just an icon for session
                    _ShellNavItem(
                      icon: Icons.layers_rounded,
                      label: 'Session',
                      path: '',
                      isCollapsed: true,
                      onTap: () => ref.read(sidebarCollapsedProvider.notifier).set(false),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // ── Central DB nav items ──

                  if (activeSession == null || activeSession.sessionId == -1) ...[
                    _ShellNavItem(icon: Icons.dashboard_customize_rounded, label: 'Dashboard', path: '/', isCollapsed: widget.isCollapsed),
                    _ShellNavItem(icon: Icons.people_rounded, label: 'Teachers', path: '/data-center', query: 'tab=0&focused=true', isCollapsed: widget.isCollapsed, count: teacherCount),
                    _ShellNavItem(icon: Icons.meeting_room_rounded, label: 'Rooms', path: '/data-center', query: 'tab=1&focused=true', isCollapsed: widget.isCollapsed, count: roomCount),
                    _ShellNavItem(icon: Icons.book_rounded, label: 'Subjects', path: '/data-center', query: 'tab=2&focused=true', isCollapsed: widget.isCollapsed, count: subjectCount),
                    _ShellNavItem(icon: Icons.account_tree_rounded, label: 'Branches', path: '/org-center', query: 'tab=0&focused=true', isCollapsed: widget.isCollapsed, count: branchCount),
                    _ShellNavItem(icon: Icons.school_rounded, label: 'Students', path: '/org-center', query: 'tab=2&focused=true', isCollapsed: widget.isCollapsed, count: studentCount),
                    _ShellNavItem(icon: Icons.groups_rounded, label: 'Groups', path: '/org-center', query: 'tab=1&focused=true', isCollapsed: widget.isCollapsed, count: groupCount),
                    const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Divider(height: 1)),
                    _ShellNavItem(icon: Icons.access_time_filled_rounded, label: 'Slot Config', path: '/slot-config', isCollapsed: widget.isCollapsed),
                    _ShellNavItem(icon: Icons.terminal_rounded, label: 'Developer Tools', path: '/sql-console', isCollapsed: widget.isCollapsed),
                  ],

                  // ── Session nav items ──
                  if (activeSession != null && activeSession.sessionId != -1) ...[
                    _ShellNavItem(icon: Icons.dashboard_rounded, label: 'Dashboard', path: '/', isCollapsed: widget.isCollapsed),
                    _ShellNavItem(icon: Icons.people_rounded, label: 'Teachers', path: '/session-data', query: 'tab=0&focused=true', isCollapsed: widget.isCollapsed, count: sessionTeacherCount),
                    _ShellNavItem(icon: Icons.meeting_room_rounded, label: 'Rooms', path: '/session-data', query: 'tab=1&focused=true', isCollapsed: widget.isCollapsed, count: sessionRoomCount),
                    _ShellNavItem(icon: Icons.book_rounded, label: 'Subjects', path: '/session-data', query: 'tab=2&focused=true', isCollapsed: widget.isCollapsed, count: sessionSubjectCount),
                    _ShellNavItem(icon: Icons.groups_rounded, label: 'Groups', path: '/session-data', query: 'tab=3&focused=true', isCollapsed: widget.isCollapsed, count: sessionGroupCount),

                    _ShellNavItem(icon: Icons.link_rounded, label: 'Enrollment', path: '/enrollment', isCollapsed: widget.isCollapsed, count: enrollCount),
                    _ShellNavItem(icon: Icons.access_time_filled_rounded, label: 'Slot Config', path: '/slot-config', isCollapsed: widget.isCollapsed),
                    _ShellNavItem(icon: Icons.calendar_month_rounded, label: 'Timetable', path: '/timetable', isCollapsed: widget.isCollapsed),
                  ],
                ],
              ),
            ),
          ),

          // ── Generate Schedule button ──
          if (activeSession != null && activeSession.sessionId != -1) ...[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: widget.isCollapsed ? 8 : 12, vertical: 4),
              child: Tooltip(
                message: isReady ? 'Generate a new timetable' : 'Complete setup first',
                child: widget.isCollapsed
                    ? IconButton(
                        onPressed: isReady ? () => context.go('/scheduler') : null,
                        icon: Icon(Icons.rocket_launch_rounded, color: isReady ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant.withAlpha(100)),
                        style: IconButton.styleFrom(
                          backgroundColor: isReady ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerHighest,
                        ),
                      )
                    : SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: isReady ? () => context.go('/scheduler') : null,
                          icon: const Icon(Icons.rocket_launch_rounded, size: 18),
                          label: Text('Generate', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                        ),
                      ),
              ),
            ),
          ],

          const Divider(height: 1),

          // ── How to Use ──
          _ShellNavItem(icon: Icons.menu_book_rounded, label: 'How to Use', path: '/user-guide', isCollapsed: widget.isCollapsed),

          // ── Settings ──
          _ShellNavItem(icon: Icons.settings_rounded, label: 'Settings', path: '/settings', isCollapsed: widget.isCollapsed),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

/// A single sidebar navigation item that supports collapsed mode
class _ShellNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String path;
  final String? query;
  final int? count;
  final bool isCollapsed;
  final bool isHighlighted;
  final VoidCallback? onTap;

  const _ShellNavItem({
    required this.icon,
    required this.label,
    required this.path,
    this.query,
    this.count,
    required this.isCollapsed,
    this.isHighlighted = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final uri = GoRouterState.of(context).uri;
    final fullPath = uri.toString();
    final targetPath = query != null ? '$path?$query' : path;

    bool isSelected = isHighlighted;
    if (!isSelected) {
      if (path.isNotEmpty) {
        if (path == '/') {
          // Dashboard item logic
          isSelected = fullPath == '/';
        } else if (uri.path == path) {
          if (query == null) {
            isSelected = !fullPath.contains('tab=') || fullPath.contains('tab=0');
          } else {
            isSelected = fullPath.contains(query!);
          }
        }
      }
    }

    final navAction = onTap ?? () => context.go(targetPath);

    if (isCollapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: Tooltip(
          message: label,
          preferBelow: false,
          waitDuration: const Duration(milliseconds: 400),
          child: InkWell(
            onTap: navAction,
            borderRadius: BorderRadius.circular(10),
            child: AnimatedContainer(
              duration: 200.ms,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: isSelected ? colorScheme.primary.withAlpha(40) : Colors.transparent,
                border: isSelected ? Border.all(color: colorScheme.primary.withAlpha(80), width: 1.5) : null,
              ),
              child: Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(icon, size: 20, color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant),
                    if (count != null && count! > 0)
                      Positioned(
                        right: -8,
                        top: -6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(color: colorScheme.primary, borderRadius: BorderRadius.circular(8)),
                          child: Text('$count', style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: InkWell(
        onTap: navAction,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: 200.ms,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: isSelected ? colorScheme.primary.withAlpha(45) : Colors.transparent,
            border: isSelected ? Border.all(color: colorScheme.primary.withAlpha(90), width: 1.5) : null,
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500, color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant),
                ),
              ),
              if (count != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected ? colorScheme.primary : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$count',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
