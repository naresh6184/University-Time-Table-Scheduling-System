import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:university_timetable_frontend/src/features/data_center/data_providers.dart';
import 'package:university_timetable_frontend/src/features/enrollment/enrollment_provider.dart';
import 'package:university_timetable_frontend/src/features/organization/org_providers.dart';
import 'package:university_timetable_frontend/src/features/slot_config/slot_config_provider.dart';
import 'package:university_timetable_frontend/src/features/sessions/session_dialog.dart';
import 'package:university_timetable_frontend/src/features/sessions/session_provider.dart';
import 'package:university_timetable_frontend/src/features/sessions/session_entities_provider.dart';
import 'package:university_timetable_frontend/src/features/sessions/widgets/sync_banner.dart';
import 'package:university_timetable_frontend/src/models/org_models.dart';
import 'package:university_timetable_frontend/src/models/session.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Force refresh global metrics whenever returning to Central Database
    ref.listen<SessionModel?>(activeSessionProvider, (previous, next) {
      if (next?.sessionId == -1 && (previous == null || previous.sessionId != -1)) {
        ref.read(sessionsProvider.notifier).refresh();
        ref.invalidate(teachersProvider);
        ref.invalidate(classroomsProvider);
        ref.invalidate(subjectsProvider);
        ref.invalidate(groupsProvider);
        ref.invalidate(branchesProvider);
        ref.invalidate(studentsProvider);
        ref.invalidate(enrollmentsProvider);
      }
    });

    return Stack(
      children: [
        SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: _Header(colorScheme: colorScheme),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _WelcomeSection(),
                      Builder(
                        builder: (context) {
                          final activeSession = ref.watch(activeSessionProvider);

                          if (activeSession == null) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 32),
                                Text(
                                  "No Workspace Selected\n\nPlease select the Central Database or a custom Session from the sidebar to begin managing data and schedules.",
                                  style: GoogleFonts.inter(fontSize: 16, color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.5),
                                ),
                              ],
                            );
                          } else if (activeSession.sessionId == -1) {
                            return const _CentralDatabaseDashboard();
                          } else {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 12),
                                const SyncBanner(),
                                const SizedBox(height: 32),
                                const _SetupProgress(),
                                const SizedBox(height: 32),
                                const _QuickActions(),
                              ],
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Welcome Section ──────────────────────────────────────────────
class _WelcomeSection extends StatelessWidget {
  const _WelcomeSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'University Timetable Scheduler',
          style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ).animate().fadeIn().slideX(begin: -0.1),
        const SizedBox(height: 8),
        Text(
          'Manage departments, academic data, and generate optimized schedules — all from one place.',
          style: GoogleFonts.inter(fontSize: 15, color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.5),
        ).animate().fadeIn(delay: 100.ms),
      ],
    );
  }
}

// ─── Setup Progress ───────────────────────────────────────────────
class _SetupProgress extends ConsumerWidget {
  const _SetupProgress();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    final hasSlots = (ref.watch(slotConfigProvider).value?.slots.isNotEmpty ?? false);
    final hasTeachers = (ref.watch(sessionTeachersProvider).value?.isNotEmpty ?? false);
    final hasRooms = (ref.watch(sessionRoomsProvider).value?.isNotEmpty ?? false);
    final hasSubjects = (ref.watch(sessionSubjectsProvider).value?.isNotEmpty ?? false);
    final hasGroups = (ref.watch(sessionGroupsProvider).value?.isNotEmpty ?? false);
    final hasEnrollments = (ref.watch(enrollmentsProvider).value?.isNotEmpty ?? false);

    final statuses = [hasSlots, hasTeachers, hasRooms, hasSubjects, hasGroups, hasEnrollments];
    final completedCount = statuses.where((e) => e).length;
    final totalCount = statuses.length;
    final progress = completedCount / totalCount;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Session Setup Progress', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: progress == 1.0 ? Colors.green.withAlpha(20) : theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('$completedCount of $totalCount Done', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: progress == 1.0 ? Colors.green : theme.colorScheme.primary)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(value: progress, minHeight: 8, backgroundColor: theme.colorScheme.surfaceContainerHighest, color: progress == 1.0 ? Colors.green : theme.colorScheme.primary),
          ),
          const SizedBox(height: 24),
          _StatusLine(label: 'Review Timetable Slots (Default Applied)', isDone: hasSlots, onTap: () => context.go('/slot-config')),
          _StatusLine(label: 'Import Session Teachers', isDone: hasTeachers, onTap: () => context.go('/session-data?tab=0&focused=true')),
          _StatusLine(label: 'Import Session Classrooms', isDone: hasRooms, onTap: () => context.go('/session-data?tab=1&focused=true')),
          _StatusLine(label: 'Import Session Subjects', isDone: hasSubjects, onTap: () => context.go('/session-data?tab=2&focused=true')),
          _StatusLine(label: 'Configure Session Groups', isDone: hasGroups, onTap: () => context.go('/session-data?tab=3&focused=true')),
          _StatusLine(label: 'Create Enrollment Assignments', isDone: hasEnrollments, onTap: () => context.go('/enrollment')),
          const Divider(height: 32),
          Text(
            progress == 1.0 ? "🚀 All steps completed! You're ready to generate a schedule." : "Complete the checklist above to unlock scheduling.",
            style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: progress == 1.0 ? Colors.green : theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms);
  }
}

class _StatusLine extends StatelessWidget {
  final String label;
  final bool isDone;
  final VoidCallback? onTap;
  const _StatusLine({required this.label, required this.isDone, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: isDone ? Colors.green.withAlpha(15) : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDone ? Colors.green.withAlpha(40) : theme.colorScheme.outlineVariant.withAlpha(50)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(shape: BoxShape.circle, color: isDone ? Colors.green.withAlpha(25) : theme.colorScheme.surfaceContainerHighest),
                child: Icon(isDone ? Icons.check_rounded : Icons.radio_button_unchecked_rounded, color: isDone ? Colors.green : theme.colorScheme.onSurfaceVariant.withAlpha(150), size: 16),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(label, style: GoogleFonts.inter(fontWeight: isDone ? FontWeight.w500 : FontWeight.w600, color: isDone ? theme.colorScheme.onSurface.withAlpha(200) : theme.colorScheme.onSurface)),
              ),
              if (onTap != null) Icon(Icons.chevron_right_rounded, size: 20, color: theme.colorScheme.onSurfaceVariant.withAlpha(100)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Quick Actions ────────────────────────────────────────────────
class _QuickActions extends ConsumerWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeSession = ref.watch(activeSessionProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Actions', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [

            _ActionButton(label: 'Create Enrollment', icon: Icons.link_rounded, onPressed: () => context.go('/enrollment')),
            if (activeSession != null && activeSession.sessionId != -1) ...[
              _ActionButton(
                label: 'Rename Session',
                icon: Icons.edit_rounded,
                onPressed: () async {
                  String newName = activeSession.name;
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Rename Session'),
                      content: TextFormField(initialValue: activeSession.name, decoration: const InputDecoration(labelText: 'New Session Name'), onChanged: (val) => newName = val, autofocus: true),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Save')),
                      ],
                    ),
                  );
                  if (confirm == true && newName.trim().isNotEmpty && newName != activeSession.name) {
                    await ref.read(sessionsProvider.notifier).updateSession(activeSession.sessionId, newName.trim());
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Session Renamed')));
                  }
                },
              ),
              _ActionButton(
                label: 'Delete Session',
                icon: Icons.delete_forever_rounded,
                color: Colors.redAccent,
                onPressed: () async {
                  if (activeSession.sessionId == -1) return;
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Delete Session?'),
                      content: Text('Are you sure you want to completely delete "${activeSession.name}"?\n\nThis will wipe all slots, availabilities, enrollments, and timetables stored in this session permanently.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                        FilledButton(
                          onPressed: () => Navigator.pop(c, true),
                          style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                          child: const Text('Delete Session'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await ref.read(sessionsProvider.notifier).deleteSession(activeSession.sessionId);
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Session Deleted')));
                  }
                },
              ),
            ],
          ],
        ),
      ],
    ).animate().fadeIn(delay: 400.ms);
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final Color? color;
  const _ActionButton({required this.label, required this.icon, required this.onPressed, this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18, color: color ?? theme.colorScheme.primary),
      label: Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: color ?? theme.colorScheme.onSurface)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        side: BorderSide(color: (color ?? theme.colorScheme.primary).withAlpha(100)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

// ─── Header (no theme toggle, no New Timetable — those live in sidebar/settings now) ──
class _Header extends ConsumerWidget {
  final ColorScheme colorScheme;
  const _Header({required this.colorScheme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeSession = ref.watch(activeSessionProvider);

    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              activeSession?.sessionId == -1 ? 'Central Database' : (activeSession?.name ?? 'Dashboard'),
              style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.5),
            ),
            const SizedBox(height: 2),
            Text(
              activeSession?.sessionId == -1 ? "Manage global entities here." : "Here's your current overview.",
              style: GoogleFonts.inter(fontSize: 14, color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Central Database Dashboard ───────────────────────────────────
class _CentralDatabaseDashboard extends ConsumerWidget {
  const _CentralDatabaseDashboard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teachers = ref.watch(teachersProvider).when(data: (d) => d.length, error: (_, __) => 0, loading: () => null);
    final subjects = ref.watch(subjectsProvider).when(data: (d) => d.length, error: (_, __) => 0, loading: () => null);
    final rooms = ref.watch(classroomsProvider).when(data: (d) => d.length, error: (_, __) => 0, loading: () => null);
    final groups = ref.watch(groupsProvider).when(data: (d) => d.length, error: (_, __) => 0, loading: () => null);
    final branches = ref.watch(branchesProvider).when(data: (d) => d.length, error: (_, __) => 0, loading: () => null);
    
    final studentsAsync = ref.watch(studentsProvider);
    final studentsList = studentsAsync.value ?? [];
    final studentsCount = studentsAsync.isLoading ? null : studentsList.length;
    
    final sessionsAsync = ref.watch(sessionsProvider);
    final sessionsCount = sessionsAsync.isLoading 
        ? null 
        : sessionsAsync.value?.where((s) => s.sessionId != -1 && s.sessionId != -2).length ?? 0;

    final isDesktop = MediaQuery.of(context).size.width > 1200;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _MetricCard(title: 'Teachers', count: teachers, icon: Icons.people_rounded, color: Colors.blue),
            _MetricCard(title: 'Subjects', count: subjects, icon: Icons.book_rounded, color: Colors.orange),
            _MetricCard(title: 'Rooms', count: rooms, icon: Icons.meeting_room_rounded, color: Colors.green),
            _MetricCard(title: 'Students', count: studentsCount, icon: Icons.school_rounded, color: Colors.amber),
            _MetricCard(title: 'Groups', count: groups, icon: Icons.groups_rounded, color: Colors.purple),
            _MetricCard(title: 'Branches', count: branches, icon: Icons.account_tree_rounded, color: Colors.indigo),
            _MetricCard(title: 'Sessions', count: sessionsCount, icon: Icons.work_history_rounded, color: Colors.teal),
          ],
        ).animate().fadeIn(delay: 100.ms),
        const SizedBox(height: 48),
        if (isDesktop)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: _EntityPieChart(teachers: teachers, subjects: subjects, rooms: rooms, groups: groups, branches: branches, sessions: sessionsCount)),
              const SizedBox(width: 24),
              Expanded(
                flex: 4,
                child: Column(
                  children: [
                    _StudentBranchChart(students: studentsList, branches: ref.watch(branchesProvider).value ?? []),
                    const SizedBox(height: 24),
                    const _RoomCapacityBarChart(),
                  ],
                ),
              ),
            ],
          )
        else
          Column(
            children: [
              _EntityPieChart(teachers: teachers, subjects: subjects, rooms: rooms, groups: groups, branches: branches, sessions: sessionsCount),
              const SizedBox(height: 24),
              _StudentBranchChart(students: studentsList, branches: ref.watch(branchesProvider).value ?? []),
              const SizedBox(height: 24),
              const _RoomCapacityBarChart(),
            ],
          ),
        const SizedBox(height: 48),
        Text('Quick Global Actions', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold)).animate().fadeIn(delay: 200.ms),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _ActionButton(label: 'Add Teacher', icon: Icons.person_add_rounded, onPressed: () => context.go('/data-center?tab=0&focused=true')),
            _ActionButton(label: 'Add Student', icon: Icons.school_rounded, onPressed: () => context.go('/org-center?tab=2&focused=true')),
            _ActionButton(label: 'Add Subject', icon: Icons.my_library_books_rounded, onPressed: () => context.go('/data-center?tab=2&focused=true')),
            _ActionButton(label: 'Add Classroom', icon: Icons.domain_add_rounded, onPressed: () => context.go('/data-center?tab=1&focused=true')),
            _ActionButton(label: 'Add Branch', icon: Icons.account_tree_rounded, onPressed: () => context.go('/org-center?tab=0&focused=true')),
            _ActionButton(label: 'Add Group', icon: Icons.groups_rounded, onPressed: () => context.go('/org-center?tab=1&focused=true')),
            _ActionButton(label: 'New Session', icon: Icons.add_circle_outline_rounded, onPressed: () => showDialog(context: context, builder: (context) => const SessionDialog())),
          ],
        ).animate().fadeIn(delay: 400.ms),
      ],
    );
  }
}

// ─── Metric Card ──────────────────────────────────────────────────
class _MetricCard extends StatelessWidget {
  final String title;
  final int? count;
  final IconData icon;
  final Color color;
  const _MetricCard({required this.title, required this.count, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardWidth = (MediaQuery.of(context).size.width < 600) ? double.infinity : 158.0;
    return Container(
      width: cardWidth,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant.withAlpha(50)),
        boxShadow: [BoxShadow(color: color.withAlpha(15), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 24)),
          const SizedBox(height: 16),
          if (count == null)
            SizedBox(
              height: 32,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: color.withAlpha(150)),
                ),
              ),
            )
          else
            Text('$count', style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.bold, height: 1)),
          const SizedBox(height: 4),
          Text(title, style: GoogleFonts.inter(fontSize: 14, color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ─── Charts ───────────────────────────────────────────────────────
class _EntityPieChart extends StatelessWidget {
  final int? teachers, subjects, rooms, groups, branches, sessions;
  const _EntityPieChart({
    required this.teachers, 
    required this.subjects, 
    required this.rooms, 
    required this.groups, 
    required this.branches,
    required this.sessions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = (teachers ?? 0) + (subjects ?? 0) + (rooms ?? 0) + (groups ?? 0) + (branches ?? 0) + (sessions ?? 0);
    if (total == 0) {
      return Container(
        height: 300,
        decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.colorScheme.outlineVariant.withAlpha(50))),
        child: Center(child: Text('No global entities defined yet.', style: GoogleFonts.inter(color: theme.colorScheme.onSurfaceVariant))),
      );
    }
    return Container(
      height: 480,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface, 
        borderRadius: BorderRadius.circular(16), 
        border: Border.all(color: theme.colorScheme.outlineVariant.withAlpha(50)),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Global Entity Distribution', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: PieChart(PieChartData(sectionsSpace: 4, centerSpaceRadius: 50, sections: [
                    if ((teachers ?? 0) > 0) PieChartSectionData(color: Colors.blue, value: teachers!.toDouble(), title: '', radius: 25, badgeWidget: _ChartBadge(count: teachers, color: Colors.blue)),
                    if ((subjects ?? 0) > 0) PieChartSectionData(color: Colors.orange, value: subjects!.toDouble(), title: '', radius: 25, badgeWidget: _ChartBadge(count: subjects, color: Colors.orange)),
                    if ((rooms ?? 0) > 0) PieChartSectionData(color: Colors.green, value: rooms!.toDouble(), title: '', radius: 25, badgeWidget: _ChartBadge(count: rooms, color: Colors.green)),

                    if ((groups ?? 0) > 0) PieChartSectionData(color: Colors.purple, value: groups!.toDouble(), title: '', radius: 25, badgeWidget: _ChartBadge(count: groups, color: Colors.purple)),
                    if ((branches ?? 0) > 0) PieChartSectionData(color: Colors.indigo, value: branches!.toDouble(), title: '', radius: 25, badgeWidget: _ChartBadge(count: branches, color: Colors.indigo)),
                    if ((sessions ?? 0) > 0) PieChartSectionData(color: Colors.teal, value: sessions!.toDouble(), title: '', radius: 25, badgeWidget: _ChartBadge(count: sessions, color: Colors.teal)),
                  ])),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    _Indicator(color: Colors.blue, text: 'Teachers', isSquare: false, count: teachers),
                    _Indicator(color: Colors.orange, text: 'Subjects', isSquare: false, count: subjects),
                    _Indicator(color: Colors.green, text: 'Rooms', isSquare: false, count: rooms),

                    _Indicator(color: Colors.purple, text: 'Groups', isSquare: false, count: groups),
                    _Indicator(color: Colors.indigo, text: 'Branches', isSquare: false, count: branches),
                    _Indicator(color: Colors.teal, text: 'Sessions', isSquare: false, count: sessions),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 500.ms);
  }
}

class _ChartBadge extends StatelessWidget {
  final int? count;
  final Color color;
  const _ChartBadge({required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white, width: 1.5)),
      child: Text(count != null ? '$count' : '...', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
    );
  }
}

class _RoomCapacityBarChart extends ConsumerWidget {
  const _RoomCapacityBarChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rooms = ref.watch(classroomsProvider).value ?? [];
    final theme = Theme.of(context);
    int smallCount = rooms.where((r) => r.capacity < 30).length;
    int mediumCount = rooms.where((r) => r.capacity >= 30 && r.capacity <= 60).length;
    int largeCount = rooms.where((r) => r.capacity > 60).length;
    double maxY = [smallCount, mediumCount, largeCount].reduce((curr, next) => curr > next ? curr : next).toDouble();
    if (maxY < 5) maxY = 5;

    return Container(
      height: 300,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.colorScheme.outlineVariant.withAlpha(50))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Room Capacity Profiles', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 32),
          Expanded(
            child: BarChart(BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxY + (maxY * 0.2),
              barTouchData: BarTouchData(enabled: false),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, meta) {
                  const style = TextStyle(fontSize: 12, fontWeight: FontWeight.w500);
                  String text;
                  switch (value.toInt()) { case 0: text = '< 30\n(Small)'; break; case 1: text = '30-60\n(Med)'; break; case 2: text = '> 60\n(Large)'; break; default: text = ''; break; }
                  return SideTitleWidget(meta: meta, space: 8, child: Text(text, style: style, textAlign: TextAlign.center));
                }, reservedSize: 42)),
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28, interval: (maxY / 4).ceilToDouble() == 0 ? 1 : (maxY / 4).ceilToDouble(), getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: const TextStyle(fontSize: 12)))),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: (maxY / 4).ceilToDouble() == 0 ? 1 : (maxY / 4).ceilToDouble(), getDrawingHorizontalLine: (value) => FlLine(color: theme.colorScheme.outlineVariant.withAlpha(50), strokeWidth: 1)),
              borderData: FlBorderData(show: false),
              barGroups: [
                BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: smallCount.toDouble(), width: 32, color: Colors.blueAccent, borderRadius: const BorderRadius.vertical(top: Radius.circular(6)))]),
                BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: mediumCount.toDouble(), width: 32, color: Colors.orangeAccent, borderRadius: const BorderRadius.vertical(top: Radius.circular(6)))]),
                BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: largeCount.toDouble(), width: 32, color: Colors.greenAccent, borderRadius: const BorderRadius.vertical(top: Radius.circular(6)))]),
              ],
            )),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 600.ms);
  }
}

class _StudentBranchChart extends StatelessWidget {
  final List<StudentModel> students;
  final List<BranchModel> branches;
  const _StudentBranchChart({required this.students, required this.branches});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final branchCounts = <int, int>{};
    for (final student in students) {
      branchCounts[student.branchId] = (branchCounts[student.branchId] ?? 0) + 1;
    }

    final chartData = branches.map((BranchModel branch) {
      return MapEntry(branch.abbreviation ?? branch.name, branchCounts[branch.branchId] ?? 0);
    }).toList();

    chartData.sort((a, b) => b.value.compareTo(a.value));
    final topData = chartData.take(5).toList();

    double maxY = topData.isEmpty ? 5 : topData.map((e) => e.value.toDouble()).reduce((a, b) => a > b ? a : b);
    if (maxY < 5) maxY = 5;

    return Container(
      height: 300,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface, 
        borderRadius: BorderRadius.circular(16), 
        border: Border.all(color: theme.colorScheme.outlineVariant.withAlpha(50)),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Students by Branch', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
              Icon(Icons.account_tree_rounded, size: 18, color: colorScheme.primary.withAlpha(150)),
            ],
          ),
          const SizedBox(height: 32),
          Expanded(
            child: BarChart(BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxY + (maxY * 0.2),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => colorScheme.surfaceContainerHighest,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    return BarTooltipItem(
                      '${topData[groupIndex].key}\n',
                      GoogleFonts.inter(color: colorScheme.onSurface, fontWeight: FontWeight.bold),
                      children: [
                        TextSpan(
                          text: rod.toY.toInt().toString(),
                          style: GoogleFonts.inter(color: colorScheme.primary, fontWeight: FontWeight.w900, fontSize: 16),
                        ),
                        const TextSpan(text: ' Students'),
                      ],
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, meta) {
                  if (value.toInt() < 0 || value.toInt() >= topData.length) return const SizedBox();
                  return SideTitleWidget(
                    meta: meta,
                    space: 8,
                    child: Text(
                      topData[value.toInt()].key,
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: colorScheme.onSurfaceVariant),
                    ),
                  );
                }, reservedSize: 28)),
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: GoogleFonts.inter(fontSize: 11, color: colorScheme.onSurfaceVariant)))),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (value) => FlLine(color: colorScheme.outlineVariant.withAlpha(40), strokeWidth: 1)),
              borderData: FlBorderData(show: false),
              barGroups: List.generate(topData.length, (i) => BarChartGroupData(x: i, barRods: [
                BarChartRodData(
                  toY: topData[i].value.toDouble(), 
                  width: 24, 
                  color: colorScheme.primary, 
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                  backDrawRodData: BackgroundBarChartRodData(show: true, toY: maxY + (maxY * 0.2), color: colorScheme.surfaceContainerHighest.withAlpha(100)),
                )
              ])),
            )),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 600.ms);
  }
}

class _Indicator extends StatelessWidget {
  final Color color;
  final String text;
  final bool isSquare;
  final int? count;
  const _Indicator({required this.color, required this.text, required this.isSquare, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 10, 
        height: 10, 
        decoration: BoxDecoration(
          shape: isSquare ? BoxShape.rectangle : BoxShape.circle, 
          color: color,
          boxShadow: [BoxShadow(color: color.withAlpha(50), blurRadius: 4, spreadRadius: 1)],
        ),
      ),
      const SizedBox(width: 10),
      Expanded(child: Text(text, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500))),
      const SizedBox(width: 16),
      Text(count != null ? '$count' : '-', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurfaceVariant)),
    ]);
  }
}

// ─── Splash Screen ────────────────────────────────────────────────
class _DashboardSplashScreen extends StatelessWidget {
  const _DashboardSplashScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      color: colorScheme.surface,
      width: double.infinity,
      height: double.infinity,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: colorScheme.primary.withAlpha(20),
                shape: BoxShape.circle,
                border: Border.all(color: colorScheme.primary.withAlpha(50), width: 2),
                boxShadow: [BoxShadow(color: colorScheme.primary.withAlpha(30), blurRadius: 30, spreadRadius: 10)],
              ),
              child: Icon(Icons.history_edu_rounded, size: 60, color: colorScheme.primary),
            )
                .animate(onPlay: (controller) => controller.repeat(reverse: true))
                .scale(duration: 1000.ms, begin: const Offset(0.95, 0.95), end: const Offset(1.05, 1.05))
                .shimmer(delay: 500.ms, duration: 2000.ms, color: colorScheme.onPrimary.withAlpha(100)),
            const SizedBox(height: 32),
            Text('UniScheduler', style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w900, color: colorScheme.onSurface, letterSpacing: -1)).animate().fadeIn(duration: 800.ms).slideY(begin: 0.2, end: 0),
            const SizedBox(height: 12),
            Text('Precision Scheduling for Modern Academics', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500, color: colorScheme.onSurfaceVariant.withAlpha(180), letterSpacing: 0.5)).animate().fadeIn(delay: 400.ms, duration: 800.ms).slideY(begin: 0.4, end: 0),
            const SizedBox(height: 48),
            SizedBox(
              width: 200,
              child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(minHeight: 3, backgroundColor: colorScheme.surfaceContainerHighest, color: colorScheme.primary)),
            ).animate().fadeIn(delay: 800.ms),
          ],
        ),
      ),
    ).animate().fadeOut(delay: 2200.ms, duration: 300.ms);
  }
}
