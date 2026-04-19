import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:university_timetable_frontend/src/features/organization/org_providers.dart';
import 'package:university_timetable_frontend/src/models/org_models.dart';

class GroupDesignerScreen extends ConsumerStatefulWidget {
  final int groupId;
  final String groupName;

  const GroupDesignerScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  ConsumerState<GroupDesignerScreen> createState() => _GroupDesignerScreenState();
}

class _GroupDesignerScreenState extends ConsumerState<GroupDesignerScreen> {
  String? _selectedProgram;
  int? _selectedBatch;
  int? _selectedBranchId;
  int? _selectedSourceGroupId;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  final Set<String> _selectedStudentIds = {};
  final Set<String> _membersToRemove = {};

  void _addSelectedStudents(List<StudentModel> currentMembers) async {
    if (_selectedStudentIds.isEmpty) return;

    // Filter out students who are already members to avoid duplicate errors
    final existingMemberIds = currentMembers.map((m) => m.studentId).toSet();
    final newStudentIds = _selectedStudentIds.where((id) => !existingMemberIds.contains(id)).toList();

    if (newStudentIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All selected students are already in the group.')),
      );
      setState(() => _selectedStudentIds.clear());
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Adding ${newStudentIds.length} students...')),
    );

    await ref.read(groupMembershipControllerProvider).bulkAdd(
          targetGroupId: widget.groupId,
          studentIds: newStudentIds,
        );
        
    setState(() => _selectedStudentIds.clear());
  }

  void _removeSelectedStudents() async {
    if (_membersToRemove.isEmpty) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Removing ${_membersToRemove.length} students...')),
    );

    await ref.read(groupMembershipControllerProvider).bulkRemove(
          targetGroupId: widget.groupId,
          studentIds: _membersToRemove.toList(),
        );

    setState(() => _membersToRemove.clear());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final membersState = ref.watch(groupMembersProvider(widget.groupId));
    final currentMembers = membersState.value ?? [];
    
    final studentsAsync = ref.watch(studentsProvider);
    final branchesState = ref.watch(branchesProvider);

    final groupsState = ref.watch(groupsProvider);
    
    final sourceMembersState = _selectedSourceGroupId != null 
        ? ref.watch(groupMembersProvider(_selectedSourceGroupId!))
        : null;
    final sourceMemberIds = sourceMembersState?.value?.map((s) => s.studentId).toSet() ?? {};

    // Dynamic Batches
    final List<int> availableBatches = studentsAsync.maybeWhen(
      data: (list) => list.map((s) => s.batch).whereType<int>().toSet().toList()..sort(),
      orElse: () => [],
    );

    // Filter students for the left panel
    List<StudentModel> filteredAvailable = studentsAsync.maybeWhen(
      data: (list) {
        return list.where((s) {
          if (_selectedProgram != null && s.program != _selectedProgram) return false;
          if (_selectedBatch != null && s.batch != _selectedBatch) return false;
          if (_selectedBranchId != null && s.branchId != _selectedBranchId) return false;
          if (_selectedSourceGroupId != null && !sourceMemberIds.contains(s.studentId)) return false;
          if (_searchQuery.isNotEmpty) {
            final query = _searchQuery.toLowerCase();
            if (!s.name.toLowerCase().contains(query) && !s.studentId.toLowerCase().contains(query)) {
              return false;
            }
          }
          return true;
        }).toList()..sort((a,b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      },
      orElse: () => [],
    );

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Designing Group: ${widget.groupName}', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            if (groupsState.value != null)
              Builder(
                builder: (context) {
                  final group = groupsState.value!.firstWhereOrNull((g) => g.groupId == widget.groupId);
                  if (group?.description != null && group!.description!.isNotEmpty) {
                    return Text(
                      group.description!,
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.normal, color: theme.colorScheme.onSurfaceVariant),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
          ],
        ),
      ),
      body: Row(
        children: [
          // Left Panel: Student Filters & Selection
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border(right: BorderSide(color: theme.colorScheme.outlineVariant.withAlpha(50))),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text('Add Students', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 8),
                      if (_selectedStudentIds.isNotEmpty)
                        ElevatedButton.icon(
                          onPressed: () => _addSelectedStudents(currentMembers),
                          icon: const Icon(Icons.group_add),
                          label: Text('Add ${_selectedStudentIds.length} Selected'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: colorScheme.onPrimary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Search Bar
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by Name or Roll No...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => setState(() {
                                _searchController.clear();
                                _searchQuery = '';
                              }),
                            )
                          : null,
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                  const SizedBox(height: 16),
                  
                  // Filters section with responsiveness
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 600;
                      
                      final programDropdown = DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Select Program'),
                        initialValue: _selectedProgram,
                        items: [
                          const DropdownMenuItem<String>(value: null, child: Text('All Programs')),
                          ...['B.Tech', 'M.Tech', 'MBA', 'BBA'].map((p) => DropdownMenuItem(value: p, child: Text(p, overflow: TextOverflow.ellipsis))),
                        ],
                        onChanged: (val) => setState(() {
                          _selectedProgram = val;
                          _selectedStudentIds.clear();
                        }),
                      );

                      final batchDropdown = DropdownButtonFormField<int>(
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Select Batch'),
                        initialValue: _selectedBatch,
                        items: [
                          const DropdownMenuItem<int>(value: null, child: Text('All Batches')),
                          ...availableBatches.map((b) => DropdownMenuItem(value: b, child: Text(b.toString(), overflow: TextOverflow.ellipsis))),
                        ],
                        onChanged: (val) => setState(() {
                          _selectedBatch = val;
                          _selectedStudentIds.clear();
                        }),
                      );

                      final branchDropdown = branchesState.when(
                        data: (list) => DropdownButtonFormField<int>(
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Select Branch'),
                          initialValue: _selectedBranchId,
                          items: [
                            const DropdownMenuItem<int>(value: null, child: Text('All Branches')),
                            ...list.map((b) => DropdownMenuItem(value: b.branchId, child: Text(b.name, overflow: TextOverflow.ellipsis))),
                          ],
                          onChanged: (val) => setState(() {
                            _selectedBranchId = val;
                            _selectedStudentIds.clear();
                          }),
                        ),
                        loading: () => const LinearProgressIndicator(),
                        error: (e, s) => Text('Error: $e'),
                      );

                      final sourceGroupDropdown = groupsState.when(
                        data: (list) => DropdownButtonFormField<int>(
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'From Another Group'),
                          initialValue: _selectedSourceGroupId,
                          items: [
                            const DropdownMenuItem<int>(value: null, child: Text('None (See All)')),
                            ...list.where((g) => g.groupId != widget.groupId).map((g) => DropdownMenuItem(value: g.groupId, child: Text(g.name, overflow: TextOverflow.ellipsis))),
                          ],
                          onChanged: (val) => setState(() {
                            _selectedSourceGroupId = val;
                            _selectedStudentIds.clear();
                          }),
                        ),
                        loading: () => const LinearProgressIndicator(),
                        error: (e, s) => Text('Error: $e'),
                      );

                      if (isNarrow) {
                        return Column(
                          children: [
                            programDropdown,
                            const SizedBox(height: 12),
                            batchDropdown,
                            const SizedBox(height: 12),
                            branchDropdown,
                            const SizedBox(height: 12),
                            sourceGroupDropdown,
                          ],
                        );
                      }

                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: programDropdown),
                              const SizedBox(width: 16),
                              Expanded(child: batchDropdown),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(child: branchDropdown),
                              const SizedBox(width: 16),
                              Expanded(child: sourceGroupDropdown),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // List Controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Found ${filteredAvailable.length} students', style: theme.textTheme.labelLarge),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            final selectableIds = filteredAvailable
                                .where((s) => !currentMembers.any((m) => m.studentId == s.studentId))
                                .map((s) => s.studentId)
                                .toSet();

                            if (_selectedStudentIds.length == selectableIds.length && selectableIds.isNotEmpty) {
                              _selectedStudentIds.clear();
                            } else {
                              _selectedStudentIds.addAll(selectableIds);
                            }
                          });
                        },
                        icon: Icon(
                          _selectedStudentIds.length == filteredAvailable.where((s) => !currentMembers.any((m) => m.studentId == s.studentId)).length && filteredAvailable.isNotEmpty
                              ? Icons.deselect
                              : Icons.select_all
                        ),
                        label: Text(_selectedStudentIds.length == filteredAvailable.where((s) => !currentMembers.any((m) => m.studentId == s.studentId)).length && filteredAvailable.isNotEmpty
                            ? 'Deselect All' : 'Select All Filtered'),
                      )
                    ],
                  ),
                  const Divider(),
                  
                  // Student Checkbox List
                  Expanded(
                    child: studentsAsync.when(
                      data: (students) {
                        if (filteredAvailable.isEmpty) {
                          return const Center(child: Text('No students match the selected filters.'));
                        }
                        return ListView.separated(
                          itemCount: filteredAvailable.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final s = filteredAvailable[index];
                            final isAlreadyMember = currentMembers.any((m) => m.studentId == s.studentId);
                            
                            return Container(
                              decoration: BoxDecoration(
                                color: isAlreadyMember ? colorScheme.surfaceContainerHighest.withAlpha(100) : colorScheme.surfaceContainer,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: colorScheme.outlineVariant.withAlpha(50)),
                              ),
                              child: CheckboxListTile(
                                enabled: !isAlreadyMember,
                                value: _selectedStudentIds.contains(s.studentId) || isAlreadyMember,
                                onChanged: (bool? selected) {
                                  if (isAlreadyMember) return;
                                  setState(() {
                                    if (selected == true) {
                                      _selectedStudentIds.add(s.studentId);
                                    } else {
                                      _selectedStudentIds.remove(s.studentId);
                                    }
                                  });
                                },
                                title: Text(s.name, style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: isAlreadyMember ? Colors.grey : null)),
                                subtitle: Text('ID: ${s.studentId} | ${s.batch ?? "No Batch"}', style: TextStyle(color: isAlreadyMember ? Colors.grey : null)),
                                secondary: isAlreadyMember ? const Icon(Icons.check_circle, color: Colors.green) : null,
                              ),
                            );
                          },
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, s) => Center(child: Text('Error: $e')),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Right Panel: Current Members
          Expanded(
            flex: 2,
            child: Container(
              color: colorScheme.surfaceContainerLow,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Current Members', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold)),
                      if (_membersToRemove.isNotEmpty)
                        ElevatedButton.icon(
                          onPressed: _removeSelectedStudents,
                          icon: const Icon(Icons.group_remove),
                          label: Text('Remove ${_membersToRemove.length}'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.error,
                            foregroundColor: colorScheme.onError,
                          ),
                        ),
                      if (_membersToRemove.isEmpty)
                        Chip(label: Text('${currentMembers.length} Members')),
                    ],
                  ),
                  if (currentMembers.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: TextButton.icon(
                        onPressed: () {
                          setState(() {
                            if (_membersToRemove.length == currentMembers.length) {
                              _membersToRemove.clear();
                            } else {
                              _membersToRemove.addAll(currentMembers.map((s) => s.studentId));
                            }
                          });
                        },
                        icon: Icon(_membersToRemove.length == currentMembers.length ? Icons.deselect : Icons.select_all),
                        label: Text(_membersToRemove.length == currentMembers.length ? 'Deselect All' : 'Select All to Remove'),
                      ),
                    ),
                  const Divider(),
                  Expanded(
                    child: membersState.when(
                      data: (list) {
                        final sortedList = List<StudentModel>.from(list)
                          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
                        
                        if (sortedList.isEmpty) return const Center(child: Text('This group is empty.'));
                        
                        return ListView.separated(
                          itemCount: sortedList.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final s = sortedList[index];
                                final isSelectedToRemove = _membersToRemove.contains(s.studentId);
                                return Container(
                                  decoration: BoxDecoration(
                                    color: isSelectedToRemove ? colorScheme.errorContainer.withAlpha(50) : theme.colorScheme.surface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: isSelectedToRemove ? Border.all(color: colorScheme.error) : null,
                                  ),
                                  child: CheckboxListTile(
                                    value: isSelectedToRemove,
                                    activeColor: colorScheme.error,
                                    onChanged: (val) {
                                      setState(() {
                                        if (val == true) {
                                          _membersToRemove.add(s.studentId);
                                        } else {
                                          _membersToRemove.remove(s.studentId);
                                        }
                                      });
                                    },
                                    title: Text(s.name, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                                    subtitle: Text(s.studentId),
                                    secondary: IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                      onPressed: () => ref.read(groupMembershipControllerProvider).removeStudent(widget.groupId, s.studentId),
                                    ),
                                  ),
                                ).animate().fadeIn(delay: (index * 30).ms).slideX(begin: 0.1);
                              },
                            );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, s) => Center(child: Text('Error: $e')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
