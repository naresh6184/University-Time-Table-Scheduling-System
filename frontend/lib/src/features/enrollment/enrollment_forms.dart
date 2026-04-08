import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:university_timetable_frontend/src/features/data_center/data_providers.dart';
import 'package:university_timetable_frontend/src/features/enrollment/enrollment_provider.dart';
import 'package:university_timetable_frontend/src/features/organization/org_providers.dart';
import 'package:university_timetable_frontend/src/features/sessions/session_entities_provider.dart';
import 'package:university_timetable_frontend/src/features/enrollment/entity_picker_dialog.dart';

import 'package:university_timetable_frontend/src/models/org_models.dart';
import 'package:university_timetable_frontend/src/models/academic_entities.dart';

class EnrollmentFormDialog extends ConsumerStatefulWidget {
  final EnrollmentModel? initialData;
  const EnrollmentFormDialog({super.key, this.initialData});

  @override
  ConsumerState<EnrollmentFormDialog> createState() => _EnrollmentFormDialogState();
}

class _EnrollmentFormDialogState extends ConsumerState<EnrollmentFormDialog> {
  final _formKey = GlobalKey<FormState>();
  int? _selectedTeacherId;
  int? _selectedSubjectId;
  int? _selectedGroupId;

  // Partition as a list of durations (e.g. [2, 2, 1])
  List<int> _partitionBlocks = [];

  @override
  void initState() {
    super.initState();
    _selectedTeacherId = widget.initialData?.teacherId;
    _selectedSubjectId = widget.initialData?.subjectId;
    _selectedGroupId = widget.initialData?.groupId;

    // Parse existing partition string into blocks
    final raw = widget.initialData?.partition;
    if (raw != null && raw.trim().isNotEmpty) {
      _partitionBlocks = raw.split(',').map((s) => int.tryParse(s.trim()) ?? 1).toList();
    }
  }

  String _buildPartitionString() {
    if (_partitionBlocks.isEmpty) return '';
    return _partitionBlocks.join(',');
  }

  /// Shows a guidance dialog telling the user to create the entity in the Central Database
  void _showGoToCentralDbDialog(BuildContext dialogContext, String entityLabel, int dataCenterTabIndex) {
    showDialog(
      context: dialogContext,
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
              Navigator.pop(ctx); // Close this guidance dialog
              Navigator.pop(dialogContext); // Close the EntityPickerDialog
              Navigator.pop(context); // Close the EnrollmentFormDialog
              context.push('/data-center?tab=$dataCenterTabIndex');
            },
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: Text('Go to $entityLabel Section'),
          ),
        ],
      ),
    );
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      // Validate partition hours vs subject hours
      if (_selectedSubjectId != null) {
        final totalHours = _partitionBlocks.fold(0, (sum, v) => sum + v);
        final subjectsState = ref.read(subjectsProvider);
        if (subjectsState.hasValue && subjectsState.value != null) {
          final subj = subjectsState.value!.where((s) => s.subjectId == _selectedSubjectId).firstOrNull;
          if (subj != null && totalHours > subj.hoursPerWeek) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Total partition hours ($totalHours) cannot exceed subject hours (${subj.hoursPerWeek})'),
                backgroundColor: Theme.of(context).colorScheme.error,
                behavior: SnackBarBehavior.floating,
              ),
            );
            return;
          }
        }
      }

      final partitionStr = _buildPartitionString();
      if (widget.initialData == null) {
        ref.read(enrollmentsProvider.notifier).addEnrollment(
              teacherId: _selectedTeacherId!,
              subjectId: _selectedSubjectId!,
              groupId: _selectedGroupId!,
              partition: partitionStr.isEmpty ? null : partitionStr,
            );
      } else {
        ref.read(enrollmentsProvider.notifier).updateEnrollment(
              widget.initialData!.enrollmentId,
              teacherId: _selectedTeacherId,
              subjectId: _selectedSubjectId,
              groupId: _selectedGroupId,
              partition: partitionStr.isEmpty ? null : partitionStr,
            );
      }
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final teachers = ref.watch(teachersProvider);
    final subjects = ref.watch(subjectsProvider);
    final groups = ref.watch(groupsProvider);

    final sessionTeachers = ref.watch(sessionTeachersProvider);
    final sessionSubjects = ref.watch(sessionSubjectsProvider);
    final sessionGroups = ref.watch(sessionGroupsProvider);

    final isEditing = widget.initialData != null;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Helper to find names for selected items
    final selectedTeacherName = sessionTeachers.value?.firstWhere((t) => t.teacherId == _selectedTeacherId, orElse: () => TeacherModel(teacherId: -1, name: 'Select a teacher', code: '')).name ?? 'Select a teacher';
    final subjectMatch = sessionSubjects.value?.where((s) => s.subjectId == _selectedSubjectId).firstOrNull;
    final selectedSubjectName = subjectMatch != null 
        ? '${subjectMatch.name}${subjectMatch.abbreviation != null ? ' (${subjectMatch.abbreviation})' : ''}'
        : 'Select a subject';

    final selectedGroupName = sessionGroups.value?.firstWhere((g) => g.groupId == _selectedGroupId, orElse: () => GroupModel(groupId: -1, name: 'Select a group')).name ?? 'Select a group';

    return AlertDialog(
      title: Text(isEditing ? 'Edit Assignment' : 'New Class Assignment', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Student Group', style: GoogleFonts.inter(fontSize: 14)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft, padding: const EdgeInsets.all(16)),
                icon: const Icon(Icons.groups_rounded),
                label: Text(selectedGroupName, style: GoogleFonts.inter(fontSize: 16)),
                onPressed: () async {
                  final result = await showDialog<int>(
                    context: context,
                    builder: (c) => EntityPickerDialog<int>(
                      title: 'Select Group',
                      sessionItems: sessionGroups.value?.map((g) => EntityItem(data: g.groupId, label: g.name, subtitle: g.description ?? '')).toList() ?? [],
                      centralItems: groups.value?.map((g) => EntityItem(data: g.groupId, label: g.name, subtitle: g.description ?? '')).toList() ?? [],
                      onCreateNew: () => _showGoToCentralDbDialog(c, 'Group', 3),
                      onImport: (id) async {
                        await ref.read(sessionGroupsProvider.notifier).addGroupToSession(id);
                        setState(() => _selectedGroupId = id);
                      },
                    ),
                  );
                  if (result != null) setState(() => _selectedGroupId = result);
                },
              ),
              if (_selectedGroupId == null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Required', style: TextStyle(color: theme.colorScheme.error, fontSize: 12))),
              const SizedBox(height: 16),
              
              Text('Professor / Teacher', style: GoogleFonts.inter(fontSize: 14)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft, padding: const EdgeInsets.all(16)),
                icon: const Icon(Icons.person_rounded),
                label: Text(selectedTeacherName, style: GoogleFonts.inter(fontSize: 16)),
                onPressed: () async {
                  final result = await showDialog<int>(
                    context: context,
                    builder: (c) => EntityPickerDialog<int>(
                      title: 'Select Teacher',
                      sessionItems: sessionTeachers.value?.map((t) => EntityItem(data: t.teacherId, label: t.name, subtitle: t.code)).toList() ?? [],
                      centralItems: teachers.value?.map((t) => EntityItem(data: t.teacherId, label: t.name, subtitle: t.code)).toList() ?? [],
                      onCreateNew: () => _showGoToCentralDbDialog(c, 'Teacher', 0),
                      onImport: (id) async {
                        await ref.read(sessionTeachersProvider.notifier).addTeacherToSession(id);
                        setState(() => _selectedTeacherId = id);
                      },
                    ),
                  );
                  if (result != null) setState(() => _selectedTeacherId = result);
                },
              ),
              if (_selectedTeacherId == null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Required', style: TextStyle(color: theme.colorScheme.error, fontSize: 12))),
              const SizedBox(height: 16),

              Text('Subject', style: GoogleFonts.inter(fontSize: 14)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft, padding: const EdgeInsets.all(16)),
                icon: const Icon(Icons.book_rounded),
                label: Text(selectedSubjectName, style: GoogleFonts.inter(fontSize: 16)),
                onPressed: () async {
                  final result = await showDialog<int>(
                    context: context,
                    builder: (c) => EntityPickerDialog<int>(
                      title: 'Select Subject',
                      sessionItems: sessionSubjects.value?.map((s) => EntityItem(
                        data: s.subjectId, 
                        label: '${s.name}${s.abbreviation != null ? ' (${s.abbreviation})' : ''}', 
                        subtitle: 'Code: ${s.code} • ${s.hoursPerWeek}h/week'
                      )).toList() ?? [],
                      centralItems: subjects.value?.map((s) => EntityItem(
                        data: s.subjectId, 
                        label: '${s.name}${s.abbreviation != null ? ' (${s.abbreviation})' : ''}', 
                        subtitle: 'Code: ${s.code} • ${s.hoursPerWeek}h/week'
                      )).toList() ?? [],
                      onCreateNew: () => _showGoToCentralDbDialog(c, 'Subject', 2),
                      onImport: (id) async {
                        await ref.read(sessionSubjectsProvider.notifier).addSubjectToSession(id);
                        setState(() => _selectedSubjectId = id);
                      },
                    ),
                  );
                  if (result != null) setState(() => _selectedSubjectId = result);
                },
              ),
              if (_selectedSubjectId == null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Required', style: TextStyle(color: theme.colorScheme.error, fontSize: 12))),
              const SizedBox(height: 24),
              // Partition builder
              _buildPartitionSection(colorScheme, subjects.value),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(onPressed: _submit, child: Text(isEditing ? 'Save Changes' : 'Create Assignment')),
      ],
    );
  }

  Widget _buildPartitionSection(ColorScheme colorScheme, List<SubjectModel>? subjectsList) {
    final totalHours = _partitionBlocks.fold(0, (sum, v) => sum + v);
    
    int? maxHours;
    if (_selectedSubjectId != null && subjectsList != null) {
      final match = subjectsList.where((s) => s.subjectId == _selectedSubjectId).firstOrNull;
      maxHours = match?.hoursPerWeek;
    }

    final exceedsLimit = maxHours != null && totalHours > maxHours;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Partition', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(width: 8),
            Text('(Optional)', style: GoogleFonts.outfit(fontSize: 12, color: colorScheme.onSurfaceVariant)),
            const Spacer(),
            if (_partitionBlocks.isNotEmpty)
              Text(
                'Total: ${totalHours}h${maxHours != null ? ' / ${maxHours}h' : ''}',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: exceedsLimit ? colorScheme.error : colorScheme.primary,
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          exceedsLimit 
            ? 'Total hours exceed subject limit!' 
            : 'Each block is a session. Tap a block to change its duration.',
          style: GoogleFonts.outfit(
            fontSize: 11,
            color: exceedsLimit ? colorScheme.error : colorScheme.onSurfaceVariant,
            fontWeight: exceedsLimit ? FontWeight.bold : FontWeight.normal
          ),
        ),
        const SizedBox(height: 12),
        if (_partitionBlocks.isEmpty && _selectedSubjectId != null && maxHours != null)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withAlpha(50),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colorScheme.primaryContainer.withAlpha(100)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: colorScheme.primary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No partition defined. The scheduler will create $maxHours individual 1-hour lectures per week for this subject.',
                    style: GoogleFonts.outfit(fontSize: 12, color: colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Existing blocks as tappable chips
            for (int i = 0; i < _partitionBlocks.length; i++)
              GestureDetector(
                onTap: () {
                  setState(() {
                    // Cycle: 1 -> 2 -> 3 -> 1
                    _partitionBlocks[i] = (_partitionBlocks[i] % 3) + 1;
                  });
                },
                child: Chip(
                  label: Text('${_partitionBlocks[i]}h', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                  backgroundColor: exceedsLimit
                      ? colorScheme.errorContainer
                      : _partitionBlocks[i] == 1
                          ? colorScheme.surfaceContainerHighest
                          : _partitionBlocks[i] == 2
                              ? colorScheme.primaryContainer
                              : colorScheme.tertiaryContainer,
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: () {
                    setState(() => _partitionBlocks.removeAt(i));
                  },
                ),
              ),
            // Add block button
            ActionChip(
              avatar: const Icon(Icons.add, size: 18),
              label: const Text('Add Block'),
              onPressed: () {
                setState(() => _partitionBlocks.add(1));
              },
            ),
          ],
        ),
      ],
    );

  }
}
