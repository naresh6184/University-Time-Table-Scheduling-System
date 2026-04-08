import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:university_timetable_frontend/src/features/data_center/data_providers.dart';
import 'package:university_timetable_frontend/src/features/enrollment/enrollment_forms.dart';
import 'package:university_timetable_frontend/src/features/enrollment/enrollment_provider.dart';
import 'package:university_timetable_frontend/src/features/organization/org_providers.dart';
import 'package:university_timetable_frontend/src/models/org_models.dart';

class EnrollmentScreen extends ConsumerWidget {
  const EnrollmentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final enrollmentsState = ref.watch(enrollmentsProvider);

    return Container(
      color: colorScheme.surfaceContainerLowest,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Enrollment Designer', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Link Teachers, Subjects, and Groups to define the workload.',
                        style: GoogleFonts.inter(fontSize: 14, color: colorScheme.onSurfaceVariant)),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _showAddDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Enrollment'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: enrollmentsState.when(
              data: (list) {
                if (list.isEmpty) return const _EmptyEnrollments();

                // Sort by Subject Name (need to map subject names first or sort in the list)
                // For now sorting by SubjectId as a proxy or fetching names.
                // Actually, let's just sort the list by Subject name.
                final subjects = ref.read(subjectsProvider).asData?.value ?? [];
                
                final sortedEnrollments = List<EnrollmentModel>.from(list)
                  ..sort((a, b) {
                    final subjA = subjects.firstWhereOrNull((s) => s.subjectId == a.subjectId)?.name.toLowerCase() ?? '';
                    final subjB = subjects.firstWhereOrNull((s) => s.subjectId == b.subjectId)?.name.toLowerCase() ?? '';
                    return subjA.compareTo(subjB);
                  });

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: sortedEnrollments.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => _EnrollmentListItem(
                    index: index + 1,
                    enrollment: sortedEnrollments[index],
                    onEdit: () => _showAddDialog(context, initialData: sortedEnrollments[index]),
                    onDelete: () => ref.read(enrollmentsProvider.notifier).deleteEnrollment(sortedEnrollments[index].enrollmentId),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddDialog(BuildContext context, {EnrollmentModel? initialData}) {
    showDialog(context: context, builder: (context) => EnrollmentFormDialog(initialData: initialData));
  }
}

class _EnrollmentListItem extends ConsumerWidget {
  final int index;
  final EnrollmentModel enrollment;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _EnrollmentListItem({required this.index, required this.enrollment, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final teachers = ref.watch(teachersProvider).asData?.value ?? [];
    final subjects = ref.watch(subjectsProvider).asData?.value ?? [];
    final groups = ref.watch(groupsProvider).asData?.value ?? [];

    final teacherName = teachers.where((t) => t.teacherId == enrollment.teacherId).firstOrNull?.name ?? 'Teacher #${enrollment.teacherId}';
    final subjectMatch = subjects.where((s) => s.subjectId == enrollment.subjectId).firstOrNull;
    final subjectDisplayName = subjectMatch != null 
        ? '${subjectMatch.name}${subjectMatch.abbreviation != null ? ' (${subjectMatch.abbreviation})' : ''}'
        : 'Subject #${enrollment.subjectId}';
    final groupName = groups.where((g) => g.groupId == enrollment.groupId).firstOrNull?.name ?? 'Group #${enrollment.groupId}';

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.outlineVariant.withAlpha(80)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 30,
              child: Text('$index.', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: theme.colorScheme.onSurfaceVariant)),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: theme.colorScheme.primary.withAlpha(20), borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.bookmark_added_rounded, color: theme.colorScheme.primary),
            ),
          ],
        ),
        title: Text(subjectDisplayName, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.label_outline_rounded, size: 14, color: theme.colorScheme.primary),
                const SizedBox(width: 4),
                Text('Code: ${subjectMatch?.code ?? 'N/A'}', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: theme.colorScheme.primary)),
                const SizedBox(width: 12),
                Icon(Icons.person_rounded, size: 14, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(teacherName, style: GoogleFonts.inter(color: theme.colorScheme.onSurfaceVariant, fontSize: 13)),
                const SizedBox(width: 12),
                Icon(Icons.groups_rounded, size: 14, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(groupName, style: GoogleFonts.inter(color: theme.colorScheme.onSurfaceVariant, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 4),
            Text(enrollment.partition != null ? 'PARTITION: ${enrollment.partition!.toUpperCase()}' : 'GENERAL LECTURE',
                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Colors.blue),
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    ).animate().fadeIn().slideY(begin: 0.05);
  }
}

class _EmptyEnrollments extends StatelessWidget {
  const _EmptyEnrollments();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.link_off_rounded, size: 64, color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: 16),
          Text('No Class Assignments created yet.', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Link teachers, subjects and groups to start scheduling.'),
        ],
      ),
    );
  }
}
