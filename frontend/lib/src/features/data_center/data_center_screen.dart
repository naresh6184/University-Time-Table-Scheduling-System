import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:university_timetable_frontend/src/features/data_center/data_providers.dart';
import 'package:university_timetable_frontend/src/features/data_center/entity_forms.dart';
import 'package:university_timetable_frontend/src/features/organization/org_providers.dart';
import 'package:university_timetable_frontend/src/models/academic_entities.dart';
import 'package:university_timetable_frontend/src/models/org_models.dart';

class DataCenterScreen extends ConsumerStatefulWidget {
  final int initialTabIndex;
  final bool isFocused;
  const DataCenterScreen({super.key, this.initialTabIndex = 0, this.isFocused = false});

  @override
  ConsumerState<DataCenterScreen> createState() => _DataCenterScreenState();
}


class _DataCenterScreenState extends ConsumerState<DataCenterScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: widget.initialTabIndex);
  }

  @override
  void didUpdateWidget(DataCenterScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTabIndex != widget.initialTabIndex) {
      _tabController.animateTo(widget.initialTabIndex);
    }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final screenTitle = widget.isFocused 
        ? ['Teachers List', 'Rooms List', 'Subjects List', 'Groups List'][widget.initialTabIndex]
        : 'Data Center';

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
              provider: teachersProvider,
              title: 'Teacher',
              nameExtractor: (t) => t.name,
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


                subtitle: Text(item.email ?? 'No email', style: GoogleFonts.inter()),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.calendar_month_outlined, color: Colors.blue),
                      onPressed: () => context.push('/teacher-availability/${item.teacherId}?name=${Uri.encodeComponent(item.name)}'),
                      tooltip: 'Set Availability',
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                      onPressed: () => _showAddDialog(context, EntityType.teacher, initialData: item),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _confirmDelete(
                        context, 
                        'Teacher', 
                        item.name, 
                        () => ref.read(teachersProvider.notifier).deleteTeacher(item.teacherId)
                      ),
                    ),
                  ],
                ),
              ),
              onAdd: () => _showAddDialog(context, EntityType.teacher),
            ),
            _EntityList<ClassroomModel>(
              provider: classroomsProvider,
              title: 'Room',
              nameExtractor: (r) => r.name,
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
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                      onPressed: () => _showAddDialog(context, EntityType.room, initialData: item),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _confirmDelete(
                        context, 
                        'Room', 
                        item.name, 
                        () => ref.read(classroomsProvider.notifier).deleteClassroom(item.roomId)
                      ),
                    ),
                  ],
                ),
              ),
              onAdd: () => _showAddDialog(context, EntityType.room),
            ),
            _EntityList<SubjectModel>(
              provider: subjectsProvider,
              title: 'Subject',
              nameExtractor: (s) => s.name,
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

                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                      onPressed: () => _showAddDialog(context, EntityType.subject, initialData: item),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _confirmDelete(
                        context, 
                        'Subject', 
                        item.name, 
                        () => ref.read(subjectsProvider.notifier).deleteSubject(item.subjectId)
                      ),
                    ),
                  ],
                ),
              ),
              onAdd: () => _showAddDialog(context, EntityType.subject),
            ),
            // Groups Tab
            _EntityList<GroupModel>(
              provider: groupsProvider,
              title: 'Group',
              nameExtractor: (g) => g.name,
              builder: (item, index) => ListTile(
                leading: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 24,
                      child: Text('${index + 1}.', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: colorScheme.onSurfaceVariant)),
                    ),

                    Icon(Icons.groups_rounded, color: colorScheme.secondary),
                  ],
                ),
                title: Text(item.name, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  '${item.studentCount} students${item.description != null && item.description!.isNotEmpty ? ' • ${item.description}' : ''}',
                  style: GoogleFonts.inter(),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                      onPressed: () => context.push('/group-designer/${item.groupId}?name=${Uri.encodeComponent(item.name)}'),
                      icon: const Icon(Icons.people_outline_rounded, size: 18),
                      label: const Text('Manage Students'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        textStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),

                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                      tooltip: 'Edit Group',
                      onPressed: () => _showGroupEditDialog(context, item),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      tooltip: 'Delete Group',
                      onPressed: () => _confirmDelete(
                        context,
                        'Group',
                        item.name,
                        () => ref.read(groupsProvider.notifier).deleteGroup(item.groupId),
                      ),
                    ),
                  ],
                ),
              ),
              onAdd: () => _showGroupCreateDialog(context),
            ),
          ],
        ),
      ),
      ],
    );
  }

  void _showAddDialog(BuildContext context, EntityType type, {dynamic initialData}) {
    showDialog(
      context: context,
      builder: (context) => EntityAddDialog(type: type, initialData: initialData),
    );
  }

  void _showGroupCreateDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Create New Group', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Group Name', hintText: 'e.g. CSE+IT Batch 2024'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: 'Description (Optional)', hintText: 'e.g. Combined group for electives'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isNotEmpty) {
                await ref.read(groupsProvider.notifier).addGroup(
                  nameController.text.trim(),
                  description: descController.text.trim().isEmpty ? null : descController.text.trim(),
                );
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showGroupEditDialog(BuildContext context, GroupModel group) {
    final nameController = TextEditingController(text: group.name);
    final descController = TextEditingController(text: group.description ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Group', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Group Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: 'Description (Optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isNotEmpty) {
                await ref.read(groupsProvider.notifier).updateGroup(
                  group.groupId,
                  nameController.text.trim(),
                  description: descController.text.trim().isEmpty ? null : descController.text.trim(),
                );
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, String entityType, String itemName, Future<void> Function() onConfirm) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Delete $entityType?'),
        content: Text('Are you sure you want to delete "$itemName"?\n\nWarning: Doing this will immediately cascade and permanently delete any dependent schedules, availabilities, enrollments, and session links. You cannot undo this action.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await onConfirm();
      } catch (e) {
        if (context.mounted) {
          final message = e is DioException ? (e.message ?? e.toString()) : e.toString();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    }
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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Managing ${widget.title} List',
                style: GoogleFonts.inter(fontSize: 18, color: theme.colorScheme.onSurfaceVariant),
              ),
              ElevatedButton.icon(
                onPressed: widget.onAdd,
                icon: const Icon(Icons.add),
                label: Text('Add ${widget.title}'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Search ${widget.title.toLowerCase()}s...',
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
              // Sort alphabetically by name
              final sorted = List<T>.from(list)
                ..sort((a, b) => widget.nameExtractor(a).toLowerCase().compareTo(widget.nameExtractor(b).toLowerCase()));

              // Filter by search query
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
                      Text('No ${widget.title}s added yet.', style: GoogleFonts.inter(fontSize: 16)),
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
