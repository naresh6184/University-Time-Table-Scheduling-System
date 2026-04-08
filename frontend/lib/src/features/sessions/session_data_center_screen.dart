import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:university_timetable_frontend/src/features/data_center/data_providers.dart';
import 'package:university_timetable_frontend/src/features/organization/org_providers.dart';
import 'package:university_timetable_frontend/src/features/enrollment/entity_picker_dialog.dart';
import 'package:university_timetable_frontend/src/features/sessions/session_entities_provider.dart';
import 'package:university_timetable_frontend/src/models/academic_entities.dart';
import 'package:university_timetable_frontend/src/models/org_models.dart';

class SessionDataCenterScreen extends ConsumerStatefulWidget {
  final int initialTabIndex;
  final bool isFocused;
  const SessionDataCenterScreen({super.key, this.initialTabIndex = 0, this.isFocused = false});

  @override
  ConsumerState<SessionDataCenterScreen> createState() => _SessionDataCenterScreenState();
}


class _SessionDataCenterScreenState extends ConsumerState<SessionDataCenterScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: widget.initialTabIndex);
  }

  @override
  void didUpdateWidget(SessionDataCenterScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTabIndex != widget.initialTabIndex) {
      _tabController.animateTo(widget.initialTabIndex);
    }
  }


  /// Shows a guidance dialog telling the user to create the entity in the Central Database,
  /// with a button that navigates directly to the correct tab.
  void _showGoToCentralDbDialog(BuildContext context, String entityLabel, int dataCenterTabIndex) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.info_outline_rounded, size: 48, color: Theme.of(context).colorScheme.primary),
        title: Text('Create in Central Database', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'To maintain data consistency, new ${entityLabel}s must be created in the Central Database first.',
              style: GoogleFonts.inter(fontSize: 15),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withAlpha(80),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: Theme.of(context).colorScheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Create → Configure → Come back here to Import',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.primary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx); // Close dialog
              Navigator.pop(context); // Close the EntityPickerDialog that's beneath
              context.push('/data-center?tab=$dataCenterTabIndex');
            },
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: Text('Go to $entityLabel Section'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final screenTitle = widget.isFocused 
        ? ['Session Teachers', 'Session Rooms', 'Session Subjects', 'Session Groups'][widget.initialTabIndex]
        : 'Session Workspace';

    return Column(
      children: [
        Container(
          color: colorScheme.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(24, 24, 24, widget.isFocused ? 20 : 0),
                child: Text(screenTitle, style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold)),
              ),
              if (!widget.isFocused)
                TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(text: 'Teachers', icon: Icon(Icons.people_rounded)),
                    Tab(text: 'Rooms', icon: Icon(Icons.meeting_room_rounded)),
                    Tab(text: 'Subjects', icon: Icon(Icons.book_rounded)),
                    Tab(text: 'Groups', icon: Icon(Icons.groups_rounded)),
                  ],
                ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            physics: widget.isFocused ? const NeverScrollableScrollPhysics() : null,
            controller: _tabController,
            children: [

              _EntityList<TeacherModel>(
                provider: sessionTeachersProvider,
                title: 'Teacher',
                nameExtractor: (item) => item.name,
                builder: (item, index) => ListTile(
                  leading: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 24,
                        child: Text('${index + 1}.', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: colorScheme.onSurfaceVariant)),
                      ),
                      const Icon(Icons.person_rounded, color: Colors.blue),
                    ],
                  ),

                title: Text(
                  '${item.name} (${item.code})', 
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600)
                ),
                subtitle: Text('Teacher', style: GoogleFonts.inter(fontSize: 12, color: colorScheme.onSurfaceVariant.withAlpha(150))),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.calendar_month_outlined, color: Colors.blue),
                      onPressed: () => context.push('/teacher-availability/${item.teacherId}?name=${Uri.encodeComponent(item.name)}'),
                      tooltip: 'Set Availability',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      tooltip: 'Remove from session',
                      onPressed: () => ref.read(sessionTeachersProvider.notifier).removeTeacherFromSession(item.teacherId),
                    ),
                  ],
                ),
              ),
              onAdd: () async {
                final sessionData = ref.read(sessionTeachersProvider).value ?? [];
                final centralData = ref.read(teachersProvider).value ?? [];
                await showDialog(
                  context: context,
                  builder: (c) => EntityPickerDialog<int>(
                    title: 'Import / Create Teacher',
                    entityLabel: 'Teacher',
                    sessionItems: sessionData.map((t) => EntityItem(data: t.teacherId, label: t.name, subtitle: t.code)).toList(),
                    centralItems: centralData.map((t) => EntityItem(data: t.teacherId, label: t.name, subtitle: t.code)).toList(),
                    onCreateNew: () => _showGoToCentralDbDialog(c, 'Teacher', 0),
                    onImport: (id) async {
                      await ref.read(sessionTeachersProvider.notifier).addTeacherToSession(id);
                      ref.invalidate(sessionTeachersProvider);
                    },
                  ),
                );
              },
            ),

            _EntityList<ClassroomModel>(
              provider: sessionRoomsProvider,
              title: 'Room',
              nameExtractor: (item) => item.name,
              builder: (item, index) => ListTile(
                leading: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 24,
                      child: Text('${index + 1}.', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: colorScheme.onSurfaceVariant)),
                    ),
                    Icon(
                      item.roomType == 'lab' ? Icons.computer_rounded : Icons.meeting_room_rounded,
                      color: colorScheme.primary,
                    ),
                  ],
                ),
                title: Text(item.name, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                subtitle: Text('${item.capacity} People | ${item.roomType.toUpperCase()}', style: GoogleFonts.inter()),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'Remove from session',
                  onPressed: () => ref.read(sessionRoomsProvider.notifier).removeRoomFromSession(item.roomId),
                ),
              ),
              onAdd: () async {
                final sessionData = ref.read(sessionRoomsProvider).value ?? [];
                final centralData = ref.read(classroomsProvider).value ?? [];
                await showDialog(
                  context: context,
                  builder: (c) => EntityPickerDialog<int>(
                    title: 'Import / Create Room',
                    entityLabel: 'Room',
                    sessionItems: sessionData.map((r) => EntityItem(data: r.roomId, label: r.name, subtitle: '${r.capacity} People | ${r.roomType}')).toList(),
                    centralItems: centralData.map((r) => EntityItem(data: r.roomId, label: r.name, subtitle: '${r.capacity} People | ${r.roomType}')).toList(),
                    onCreateNew: () => _showGoToCentralDbDialog(c, 'Room', 1),
                    onImport: (id) async {
                      await ref.read(sessionRoomsProvider.notifier).addRoomToSession(id);
                      ref.invalidate(sessionRoomsProvider);
                    },
                  ),
                );
              },
            ),

            _EntityList<SubjectModel>(
              provider: sessionSubjectsProvider,
              title: 'Subject',
              nameExtractor: (item) => item.name,
              builder: (item, index) => ListTile(
                leading: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 24,
                      child: Text('${index + 1}.', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: colorScheme.onSurfaceVariant)),
                    ),
                    const Icon(Icons.history_edu_rounded, color: Colors.indigo),
                  ],
                ),
                title: Text(
                  '${item.name}${item.abbreviation != null ? ' (${item.abbreviation})' : ''}', 
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600)
                ),
                subtitle: Text(
                  'Code: ${item.code} • ${item.hoursPerWeek}h/week • ${item.subjectType.toUpperCase()}',
                  style: GoogleFonts.inter(),
                ),

                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'Remove from session',
                  onPressed: () => ref.read(sessionSubjectsProvider.notifier).removeSubjectFromSession(item.subjectId),
                ),
              ),
              onAdd: () async {
                final sessionData = ref.read(sessionSubjectsProvider).value ?? [];
                final centralData = ref.read(subjectsProvider).value ?? [];
                await showDialog(
                  context: context,
                  builder: (c) => EntityPickerDialog<int>(
                    title: 'Import / Create Subject',
                    entityLabel: 'Subject',
                    sessionItems: sessionData.map((s) => EntityItem(
                      data: s.subjectId, 
                      label: '${s.name}${s.abbreviation != null ? ' (${s.abbreviation})' : ''}', 
                      subtitle: 'Code: ${s.code} • ${s.hoursPerWeek}h/week'
                    )).toList(),
                    centralItems: centralData.map((s) => EntityItem(
                      data: s.subjectId, 
                      label: '${s.name}${s.abbreviation != null ? ' (${s.abbreviation})' : ''}', 
                      subtitle: 'Code: ${s.code} • ${s.hoursPerWeek}h/week'
                    )).toList(),

                    onCreateNew: () => _showGoToCentralDbDialog(c, 'Subject', 2),
                    onImport: (id) async {
                      await ref.read(sessionSubjectsProvider.notifier).addSubjectToSession(id);
                      ref.invalidate(sessionSubjectsProvider);
                    },
                  ),
                );
              },
            ),

            _EntityList<GroupModel>(
              provider: sessionGroupsProvider,
              title: 'Group',
              nameExtractor: (item) => item.name,
              builder: (item, index) => ListTile(
                leading: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 24,
                      child: Text('${index + 1}.', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: colorScheme.onSurfaceVariant)),
                    ),
                  ],
                ),

                title: Text(item.name, style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                subtitle: Text(item.description ?? 'No description', style: GoogleFonts.outfit()),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'Remove from session',
                  onPressed: () => ref.read(sessionGroupsProvider.notifier).removeGroupFromSession(item.groupId),
                ),
              ),
              onAdd: () async {
                final sessionData = ref.read(sessionGroupsProvider).value ?? [];
                final centralData = ref.read(groupsProvider).value ?? [];
                await showDialog(
                  context: context,
                  builder: (c) => EntityPickerDialog<int>(
                    title: 'Import / Create Group',
                    entityLabel: 'Group',
                    sessionItems: sessionData.map((g) => EntityItem(data: g.groupId, label: g.name, subtitle: g.description ?? '')).toList(),
                    centralItems: centralData.map((g) => EntityItem(data: g.groupId, label: g.name, subtitle: g.description ?? '')).toList(),
                    onCreateNew: () => _showGoToCentralDbDialog(c, 'Group', 3),
                    onImport: (id) async {
                      await ref.read(sessionGroupsProvider.notifier).addGroupToSession(id);
                      ref.invalidate(sessionGroupsProvider);
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
      ],
    );
  }
}

class _EntityList<T> extends ConsumerStatefulWidget {
  final AsyncNotifierProvider<dynamic, List<T>> provider;
  final Widget Function(T, int) builder;
  final String title;
  final VoidCallback onAdd;
  final String Function(T) nameExtractor;

  const _EntityList({
    required this.provider,
    required this.builder,
    required this.title,
    required this.onAdd,
    required this.nameExtractor,
  });

  @override
  ConsumerState<_EntityList<T>> createState() => _EntityListState<T>();
}

class _EntityListState<T> extends ConsumerState<_EntityList<T>> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(widget.provider);
    final theme = Theme.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Session Linked ${widget.title}s',
                style: GoogleFonts.outfit(fontSize: 18, color: theme.colorScheme.onSurfaceVariant),
              ),
              ElevatedButton.icon(
                onPressed: widget.onAdd,
                icon: const Icon(Icons.import_export_rounded),
                label: Text('Import / Create ${widget.title}'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Search ${widget.title.toLowerCase()}s by name...',
              hintStyle: GoogleFonts.inter(color: theme.colorScheme.onSurfaceVariant.withAlpha(150)),
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        Expanded(
          child: state.when(
            data: (list) {
              // 1. Sort alphabetically by name
              final sorted = List<T>.from(list)
                ..sort((a, b) => widget.nameExtractor(a).toLowerCase().compareTo(widget.nameExtractor(b).toLowerCase()));

              // 2. Filter by search query
              final filtered = _searchQuery.isEmpty
                  ? sorted
                  : sorted.where((item) => widget.nameExtractor(item).toLowerCase().contains(_searchQuery)).toList();

              if (list.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inbox_rounded, size: 64, color: theme.colorScheme.outlineVariant),
                      const SizedBox(height: 16),
                      Text('No ${widget.title}s linked to this session.', style: GoogleFonts.outfit(fontSize: 16)),
                      const SizedBox(height: 8),
                      const Text('Use the Import button to add them.'),
                    ],
                  ),
                );
              }

              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search_off_rounded, size: 48, color: theme.colorScheme.outlineVariant),
                      const SizedBox(height: 12),
                      Text('No ${widget.title.toLowerCase()}s matching "$_searchQuery"',
                          style: GoogleFonts.inter(fontSize: 14, color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  return Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: theme.colorScheme.outlineVariant.withAlpha(80)),
                    ),
                    child: widget.builder(filtered[index], index),
                  ).animate().fadeIn(delay: (index * 50).ms).slideX(begin: 0.05);
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(child: Text('Error: $e')),
          ),
        ),
      ],
    );
  }
}
