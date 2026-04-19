import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:university_timetable_frontend/src/features/organization/org_forms.dart';
import 'package:university_timetable_frontend/src/features/organization/org_providers.dart';
import 'package:university_timetable_frontend/src/features/organization/bulk_import_dialog.dart';
import 'package:university_timetable_frontend/src/models/org_models.dart';
import 'package:university_timetable_frontend/src/features/organization/widgets/student_list_view.dart';

class OrgCenterScreen extends ConsumerStatefulWidget {
  final int initialTabIndex;
  final bool isFocused;
  const OrgCenterScreen({super.key, this.initialTabIndex = 0, this.isFocused = false});

  @override
  ConsumerState<OrgCenterScreen> createState() => _OrgCenterScreenState();
}

class _OrgCenterScreenState extends ConsumerState<OrgCenterScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isTreeView = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: widget.initialTabIndex);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(OrgCenterScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTabIndex != widget.initialTabIndex) {
      _tabController.animateTo(widget.initialTabIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenTitle = widget.isFocused 
        ? ['Branch List', 'Group List', 'Student List'][widget.initialTabIndex]
        : 'Organization Hub';

    return Column(
      children: [
        Container(
          color: Theme.of(context).colorScheme.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(24, 24, 24, widget.isFocused ? 20 : 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(screenTitle, style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold)),
                    if (_tabController.index == 2)
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: true, label: Text('Hierarchy'), icon: Icon(Icons.account_tree_outlined)),
                          ButtonSegment(value: false, label: Text('List View'), icon: Icon(Icons.list_alt_rounded)),
                        ],
                        selected: {_isTreeView},
                        onSelectionChanged: (val) => setState(() => _isTreeView = val.first),
                      ),
                  ],
                ),
              ),
              if (!widget.isFocused)
                TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(text: 'Branches', icon: Icon(Icons.account_tree_rounded)),
                    Tab(text: 'Groups', icon: Icon(Icons.groups_rounded)),
                    Tab(text: 'Students', icon: Icon(Icons.school_rounded)),
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
              // Branches
              _OrgList<BranchModel>(
                provider: branchesProvider,
                idField: (b) => b.branchId.toString(),
                nameField: (b) => b.abbreviation != null ? '${b.name} (${b.abbreviation})' : b.name,
                subtitleField: (b) => 'Academic Branch',
                onDelete: (id) async {
                  try {
                    await ProviderScope.containerOf(context).read(branchesProvider.notifier).deleteBranch(int.parse(id));
                  } catch (e) {
                    if (context.mounted) {
                      final message = e is DioException ? (e.message ?? e.toString()) : e.toString();
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red.shade700, behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 5)));
                    }
                  }
                },
                onAdd: () => _showAddDialog(context, OrgType.branch),
                onEdit: (b) => _showAddDialog(context, OrgType.branch, initialData: b),
                icon: Icons.account_tree_rounded,
              ),

              _OrgList<GroupModel>(
                provider: groupsProvider,
                idField: (g) => g.groupId.toString(),
                nameField: (g) => g.name,
                subtitleField: (g) => '${g.studentCount} Students${g.description != null ? ' • ${g.description}' : ''}',
                onDelete: (id) async {
                  try {
                    await ref.read(groupsProvider.notifier).deleteGroup(int.parse(id));
                  } catch (e) {
                    if (context.mounted) {
                      final message = e is DioException ? (e.message ?? e.toString()) : e.toString();
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red.shade700, behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 5)));
                    }
                  }
                },
                onAdd: () => _showAddDialog(context, OrgType.group),
                onEdit: (g) => _showAddDialog(context, OrgType.group, initialData: g),
                onManage: (g) async {
                  await context.push('/group-designer/${g.groupId}?name=${g.name}');
                  ref.invalidate(groupsProvider);
                },
                icon: Icons.groups_rounded,
              ),

              // Students
              _isTreeView 
                ? _HierarchicalView<StudentModel>(
                    provider: studentsProvider,
                    title: 'Student',
                    nameExtractor: (s) => s.name,
                    idExtractor: (s) => s.studentId,
                    onAdd: () => _showAddDialog(context, OrgType.student),
                    onBulkImport: () => _showBulkImportDialog(context),
                    onEdit: (s) => _showAddDialog(context, OrgType.student, initialData: s),
                    onDelete: (s) => ref.read(studentsProvider.notifier).deleteStudent(s.studentId),
                    groupByFields: (s) => {'program': s.program, 'batch': s.batch ?? 0, 'branchId': s.branchId},
                    itemBuilder: (s, index, colorScheme) => ListTile(
                      leading: Text('${index + 1}.', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: colorScheme.onSurfaceVariant)),
                      title: Text(s.name, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                      subtitle: Text('ID: ${s.studentId}${s.email != null ? ' • ${s.email}' : ''}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.blue), onPressed: () => _showAddDialog(context, OrgType.student, initialData: s)),
                          IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _confirmDelete(context, 'Student', s.name, () async => ref.read(studentsProvider.notifier).deleteStudent(s.studentId))),
                        ],
                      ),
                    ),
                  )
                : const StudentListView(),
            ],
          ),
        ),
      ],
    );
  }

  void _showAddDialog(BuildContext context, OrgType type, {dynamic initialData}) {
    showDialog(context: context, builder: (context) => OrgAddDialog(type: type, initialData: initialData));
  }

  void _showBulkImportDialog(BuildContext context) {
    showDialog(context: context, builder: (context) => const BulkStudentImportDialog());
  }

  Future<void> _confirmDelete(BuildContext context, String type, String name, Future<void> Function() onConfirm) async {
    final ok = await showDialog<bool>(
      context: context, 
      builder: (c) => AlertDialog(
        title: Text('Delete $type?'),
        content: Text('Are you sure you want to delete "$name"? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: const Text('Delete')),
        ],
      )
    );
    if (ok == true) {
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

class _HierarchicalView<T> extends ConsumerStatefulWidget {
  final AsyncNotifierProvider<dynamic, List<T>> provider;
  final String title;
  final VoidCallback onAdd;
  final VoidCallback? onBulkImport;
  final Function(T) onEdit;
  final Function(T) onDelete;
  final Function(T)? onManage;
  final Map<String, dynamic> Function(T) groupByFields;
  final Widget Function(T, int, ColorScheme) itemBuilder;
  final String Function(T) nameExtractor;
  final String Function(T)? idExtractor;

  const _HierarchicalView({
    required this.provider,
    required this.title,
    required this.onAdd,
    this.onBulkImport,
    required this.onEdit,
    required this.onDelete,
    this.onManage,
    required this.groupByFields,
    required this.itemBuilder,
    required this.nameExtractor,
    this.idExtractor,
  });

  @override
  ConsumerState<_HierarchicalView<T>> createState() => _HierarchicalViewState<T>();
}

class _HierarchicalViewState<T> extends ConsumerState<_HierarchicalView<T>> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemsState = ref.watch(widget.provider);
    final branchesState = ref.watch(branchesProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (widget.onBulkImport != null) ...[
                OutlinedButton.icon(
                  onPressed: widget.onBulkImport,
                  icon: const Icon(Icons.upload_file_rounded),
                  label: const Text('Bulk Import'),
                ),
                const SizedBox(width: 12),
              ],
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
              hintText: 'Search ${widget.title.toLowerCase()}s by name or ID...',
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
          child: itemsState.when(
            data: (items) {
              if (items.isEmpty) return Center(child: Text('No ${widget.title}s found.'));

              // Filter by search query
              final filtered = _searchQuery.isEmpty
                  ? items
                  : items.where((item) {
                      final name = widget.nameExtractor(item).toLowerCase();
                      final rawId = widget.idExtractor?.call(item);
                      final id = rawId?.toLowerCase() ?? '';
                      return name.contains(_searchQuery) || id.contains(_searchQuery);
                    }).toList();

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

              // When searching, show a flat list instead of hierarchy
              if (_searchQuery.isNotEmpty) {
                final sortedFiltered = List<T>.from(filtered)
                  ..sort((a, b) => (widget.idExtractor?.call(a) ?? "").toLowerCase().compareTo((widget.idExtractor?.call(b) ?? "").toLowerCase()));

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: sortedFiltered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    return Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: theme.colorScheme.outlineVariant.withAlpha(80)),
                      ),
                      child: widget.itemBuilder(sortedFiltered[index], index, colorScheme),
                    ).animate().fadeIn(delay: (index * 30).ms).slideX(begin: 0.05);
                  },
                );
              }

              // Default: show hierarchy
              final branches = branchesState.asData?.value ?? [];
              final branchMap = {for (var b in branches) b.branchId: b.name};

              // Grouping Logic: Program -> Batch -> Branch
              final data = filtered.map((item) => {
                'item': item,
                'fields': widget.groupByFields(item),
              }).toList();

              final programGroups = groupBy(data, (d) => (d['fields'] as Map<String, dynamic>)['program'] as String);
              final sortedPrograms = programGroups.keys.toList()..sort();

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: sortedPrograms.length,
                itemBuilder: (context, pIndex) {
                  final program = sortedPrograms[pIndex];
                  final programData = programGroups[program]!;
                  
                  final batchGroups = groupBy(programData, (d) => (d['fields'] as Map<String, dynamic>)['batch'] as int);
                  final sortedBatches = batchGroups.keys.toList()..sort((a,b) => a.compareTo(b));

                  return _HierarchySection(
                    title: program,
                    subtitle: '${programData.length} Total ${widget.title}s',
                    icon: Icons.school_rounded,
                    color: Colors.blue,
                    children: sortedBatches.map((batch) {
                      final batchData = batchGroups[batch]!;
                      final branchGroups = groupBy(batchData, (d) => (d['fields'] as Map<String, dynamic>)['branchId'] as int?);
                      final sortedBranches = branchGroups.keys.toList()..sort((a, b) {
                        final nameA = (branchMap[a] ?? 'General Branch').toLowerCase();
                        final nameB = (branchMap[b] ?? 'General Branch').toLowerCase();
                        return nameA.compareTo(nameB);
                      });

                      return _HierarchySection(
                        title: batch == 0 ? "General / Unassigned" : "Batch $batch",
                        subtitle: '${batchData.length} ${widget.title}${batchData.length == 1 ? '' : 's'}',
                        icon: Icons.layers_rounded,
                        color: Colors.indigo,
                        children: sortedBranches.map((branchId) {
                          final branchItems = branchGroups[branchId]!;
                          final branchName = branchMap[branchId] ?? 'General Branch';

                          // Sort students within branch by Roll Number (Student ID)
                          branchItems.sort((a, b) {
                            final idA = (widget.idExtractor?.call(a['item'] as T) ?? "").toLowerCase();
                            final idB = (widget.idExtractor?.call(b['item'] as T) ?? "").toLowerCase();
                            return idA.compareTo(idB);
                          });

                          return _HierarchySection(
                            title: branchName,
                            subtitle: '${branchItems.length} ${widget.title}${branchItems.length == 1 ? '' : 's'}',
                            icon: Icons.account_tree_rounded,
                            color: Colors.teal,
                            children: branchItems.asMap().entries.map((entry) {
                              return widget.itemBuilder(entry.value['item'] as T, entry.key, colorScheme);
                            }).toList(),
                          );
                        }).toList(),
                      );
                    }).toList(),
                  );
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

class _HierarchySection extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<Widget> children;

  const _HierarchySection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant.withAlpha(50)),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          leading: CircleAvatar(
            backgroundColor: color.withAlpha(30),
            child: Icon(icon, color: color, size: 20),
          ),
          title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
          subtitle: Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
          children: children,
        ),
      ),
    );
  }
}

class _OrgList<T> extends ConsumerStatefulWidget {
  final AsyncNotifierProvider<dynamic, List<T>> provider;
  final String Function(T) idField;
  final String Function(T) nameField;
  final String Function(T) subtitleField;
  final Function(String) onDelete;
  final VoidCallback onAdd;
  final Function(T)? onEdit;
  final Function(T)? onManage;
  final IconData? icon;

  const _OrgList({
    required this.provider,
    required this.idField,
    required this.nameField,
    required this.subtitleField,
    required this.onDelete,
    required this.onAdd,
    this.onEdit,
    this.onManage,
    this.icon,
  });

  @override
  ConsumerState<_OrgList<T>> createState() => _OrgListState<T>();
}

class _OrgListState<T> extends ConsumerState<_OrgList<T>> {
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
    final entityLabel = T == BranchModel ? 'Branch' : 'Group';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: widget.onAdd,
                icon: const Icon(Icons.add),
                label: Text('Add $entityLabel'),
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
              hintText: 'Search ${entityLabel.toLowerCase()}es...',
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
                ..sort((a, b) => widget.nameField(a).toLowerCase().compareTo(widget.nameField(b).toLowerCase()));

              // Filter by search query
              final filtered = _searchQuery.isEmpty
                  ? sorted
                  : sorted.where((item) => widget.nameField(item).toLowerCase().contains(_searchQuery)).toList();

              if (list.isEmpty) {
                return const Center(child: Text('No entries found.'));
              }

              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search_off_rounded, size: 48, color: theme.colorScheme.outlineVariant),
                      const SizedBox(height: 12),
                      Text('No ${entityLabel.toLowerCase()}es matching "$_searchQuery"',
                          style: GoogleFonts.inter(fontSize: 14, color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = filtered[index];
                  return Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: theme.colorScheme.outlineVariant.withAlpha(80)),
                    ),
                    child: ListTile(
                      leading: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 30,
                            child: Text('${index + 1}.', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: theme.colorScheme.onSurfaceVariant)),
                          ),
                          if (widget.icon != null) ...[
                            Icon(widget.icon, color: theme.colorScheme.primary, size: 20),
                            const SizedBox(width: 8),
                          ],
                        ],
                      ),
                      title: Text(widget.nameField(item), style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                      subtitle: Text(widget.subtitleField(item), style: GoogleFonts.inter()),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.onManage != null)
                            TextButton.icon(
                              onPressed: () => widget.onManage!(item),
                              icon: const Icon(Icons.people_outline_rounded, size: 18),
                              label: const Text('Manage'),
                            ),
                          if (widget.onEdit != null)
                            IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.blue), onPressed: () => widget.onEdit!(item)),
                          IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => widget.onDelete(widget.idField(item))),
                        ],
                      ),
                    ),
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
