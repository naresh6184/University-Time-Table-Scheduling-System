import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:university_timetable_frontend/src/features/organization/org_providers.dart';
import 'package:university_timetable_frontend/src/models/org_models.dart';

class StudentListView extends ConsumerStatefulWidget {
  const StudentListView({super.key});

  @override
  ConsumerState<StudentListView> createState() => _StudentListViewState();
}

class _StudentListViewState extends ConsumerState<StudentListView> {
  final Set<String> _selectedIds = {};
  String _searchQuery = '';
  String? _filterProgram;
  int? _filterBatch;
  int? _filterBranch;

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll(List<StudentModel> students) {
    setState(() {
      if (_selectedIds.length == students.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(students.map((e) => e.studentId));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(studentsProvider);
    final branchesAsync = ref.watch(branchesProvider);
    final theme = Theme.of(context);

    return studentsAsync.when(
      data: (students) {
        final branches = branchesAsync.value ?? [];
        
        // Apply Filters
        final filtered = students.where((s) {
          final matchesSearch = s.name.toLowerCase().contains(_searchQuery.toLowerCase()) || 
                               s.studentId.toLowerCase().contains(_searchQuery.toLowerCase());
          final matchesProgram = _filterProgram == null || s.program == _filterProgram;
          final matchesBatch = _filterBatch == null || s.batch == _filterBatch;
          final matchesBranch = _filterBranch == null || s.branchId == _filterBranch;
          return matchesSearch && matchesProgram && matchesBatch && matchesBranch;
        }).toList();

        return Column(
          children: [
            // Filter Bar
            _buildFilterBar(context, students, branches),
            
            // Bulk Action Bar
            if (_selectedIds.isNotEmpty)
              _buildBulkActionBar(context, theme),

            // Table Header
            _buildTableHeader(context, filtered),

            // Table Body
            Expanded(
              child: ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final student = filtered[index];
                  final isSelected = _selectedIds.contains(student.studentId);
                  final branch = branches.firstWhere((b) => b.branchId == student.branchId, 
                      orElse: () => BranchModel(branchId: -1, name: 'Unknown'));

                  return InkWell(
                    onTap: () => _toggleSelection(student.studentId),
                    child: Container(
                      color: isSelected ? theme.colorScheme.primaryContainer.withAlpha(50) : null,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 48,
                            child: Checkbox(
                              value: isSelected,
                              onChanged: (_) => _toggleSelection(student.studentId),
                            ),
                          ),
                          Expanded(flex: 3, child: Text(student.studentId, style: GoogleFonts.inter(fontWeight: FontWeight.w600))),
                          Expanded(flex: 4, child: Text(student.name, style: GoogleFonts.inter())),
                          Expanded(flex: 2, child: Text(student.program, style: GoogleFonts.inter())),
                          Expanded(flex: 2, child: Text(student.batch?.toString() ?? '-', style: GoogleFonts.inter())),
                          Expanded(flex: 3, child: Text(branch.abbreviation ?? branch.name, style: GoogleFonts.inter())),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildFilterBar(BuildContext context, List<StudentModel> allStudents, List<BranchModel> branches) {
    final programs = allStudents.map((e) => e.program).toSet().toList();
    final batches = allStudents.map((e) => e.batch).whereType<int>().toSet().toList()..sort();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search by Name or Roll No...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
          const SizedBox(width: 12),
          _buildDropdown<String>(
            label: 'Program',
            value: _filterProgram,
            items: programs,
            onChanged: (v) => setState(() => _filterProgram = v),
          ),
          const SizedBox(width: 12),
          _buildDropdown<int>(
            label: 'Batch',
            value: _filterBatch,
            items: batches,
            onChanged: (v) => setState(() => _filterBatch = v),
          ),
          const SizedBox(width: 12),
          _buildDropdown<int>(
            label: 'Branch',
            value: _filterBranch,
            items: branches.map((b) => b.branchId).toList(),
            itemLabels: Map.fromEntries(branches.map((b) => MapEntry(b.branchId, b.abbreviation ?? b.name))),
            onChanged: (v) => setState(() => _filterBranch = v),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: () => setState(() {
              _filterProgram = null;
              _filterBatch = null;
              _filterBranch = null;
              _searchQuery = '';
            }),
            icon: const Icon(Icons.filter_list_off),
            tooltip: 'Clear Filters',
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    Map<T, String>? itemLabels,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButton<T>(
        value: value,
        hint: Text(label),
        underline: const SizedBox(),
        items: [
          DropdownMenuItem<T>(value: null, child: Text('All $label')),
          ...items.map((item) => DropdownMenuItem<T>(
            value: item,
            child: Text(itemLabels?[item] ?? item.toString()),
          )),
        ],
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildBulkActionBar(BuildContext context, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(
            '${_selectedIds.length} Students Selected',
            style: GoogleFonts.inter(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: () => _showMassEditDialog(context),
            icon: Icon(Icons.edit, color: theme.colorScheme.onPrimary, size: 20),
            label: Text('Mass Edit', style: TextStyle(color: theme.colorScheme.onPrimary)),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () => _handleBulkDelete(context),
            icon: Icon(Icons.delete, color: theme.colorScheme.onPrimary, size: 20),
            label: Text('Delete Selected', style: TextStyle(color: theme.colorScheme.onPrimary)),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => setState(() => _selectedIds.clear()),
            icon: Icon(Icons.close, color: theme.colorScheme.onPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(BuildContext context, List<StudentModel> students) {
    final isAllSelected = _selectedIds.length == students.length && students.isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: Colors.grey.shade100,
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Checkbox(
              value: isAllSelected,
              tristate: _selectedIds.isNotEmpty && !isAllSelected,
              onChanged: (_) => _selectAll(students),
            ),
          ),
          Expanded(flex: 3, child: Text('Roll Number', style: GoogleFonts.inter(fontWeight: FontWeight.bold))),
          Expanded(flex: 4, child: Text('Name', style: GoogleFonts.inter(fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text('Program', style: GoogleFonts.inter(fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text('Batch', style: GoogleFonts.inter(fontWeight: FontWeight.bold))),
          Expanded(flex: 3, child: Text('Branch', style: GoogleFonts.inter(fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Future<void> _handleBulkDelete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Bulk Delete'),
        content: Text('Are you sure you want to delete ${_selectedIds.length} students? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(studentsProvider.notifier).bulkDeleteStudents(_selectedIds.toList());
      setState(() => _selectedIds.clear());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Students deleted successfully')));
      }
    }
  }

  void _showMassEditDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => MassEditDialog(
        selectedIds: _selectedIds.toList(),
        onComplete: () => setState(() => _selectedIds.clear()),
      ),
    );
  }
}

class MassEditDialog extends ConsumerStatefulWidget {
  final List<String> selectedIds;
  final VoidCallback onComplete;
  const MassEditDialog({super.key, required this.selectedIds, required this.onComplete});

  @override
  ConsumerState<MassEditDialog> createState() => _MassEditDialogState();
}

class _MassEditDialogState extends ConsumerState<MassEditDialog> {
  String? _program;
  int? _batch;
  int? _branchId;
  bool _updateProgram = false;
  bool _updateBatch = false;
  bool _updateBranch = false;

  @override
  Widget build(BuildContext context) {
    final branches = ref.watch(branchesProvider).value ?? [];
    
    return AlertDialog(
      title: Text('Mass Edit ${widget.selectedIds.length} Students'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CheckboxListTile(
              title: const Text('Update Program'),
              value: _updateProgram,
              onChanged: (v) => setState(() => _updateProgram = v!),
            ),
            if (_updateProgram)
              TextField(
                decoration: const InputDecoration(labelText: 'New Program (e.g. B.Tech)'),
                onChanged: (v) => _program = v,
              ),
            const Divider(),
            CheckboxListTile(
              title: const Text('Update Batch'),
              value: _updateBatch,
              onChanged: (v) => setState(() => _updateBatch = v!),
            ),
            if (_updateBatch)
              TextField(
                decoration: const InputDecoration(labelText: 'New Batch (Year)'),
                keyboardType: TextInputType.number,
                onChanged: (v) => _batch = int.tryParse(v),
              ),
            const Divider(),
            CheckboxListTile(
              title: const Text('Update Branch'),
              value: _updateBranch,
              onChanged: (v) => setState(() => _updateBranch = v!),
            ),
            if (_updateBranch)
              DropdownButtonFormField<int>(
                value: _branchId,
                items: branches.map((b) => DropdownMenuItem(value: b.branchId, child: Text(b.name))).toList(),
                onChanged: (v) => _branchId = v,
                decoration: const InputDecoration(labelText: 'New Branch'),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () async {
            await ref.read(studentsProvider.notifier).bulkUpdateStudents(
              rollNumbers: widget.selectedIds,
              program: _updateProgram ? _program : null,
              batch: _updateBatch ? _batch : null,
              branchId: _updateBranch ? _branchId : null,
            );
            widget.onComplete();
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Apply Changes'),
        ),
      ],
    );
  }
}
