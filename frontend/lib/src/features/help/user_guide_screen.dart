import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

class UserGuideScreen extends StatelessWidget {
  const UserGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        Container(
          color: colorScheme.surface,
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Row(
            children: [
              Icon(Icons.menu_book_rounded, color: colorScheme.primary, size: 28),
              const SizedBox(width: 12),
              Text('How to Use UniScheduler', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Overview ──
                    _GuideSection(
                      icon: Icons.info_outline_rounded,
                      color: Colors.blue,
                      title: 'What is UniScheduler?',
                      content: 'UniScheduler is a university timetable scheduling tool. '
                          'It helps you create clash-free timetables by organizing your teachers, rooms, subjects, '
                          'and student groups, and then automatically generating schedules.\n\n'
                          'The software works in two main areas:\n'
                          '• Central Database — where you store all your data (teachers, rooms, subjects, branches, students, groups)\n'
                          '• Sessions — where you pick entities from the central database, create enrollments, and generate timetables',
                    ),

                    const SizedBox(height: 20),

                    // ── Step-by-step ──
                    _GuideSectionHeader(title: 'Step-by-Step Setup', icon: Icons.checklist_rounded, color: Colors.green),
                    const SizedBox(height: 12),

                    _StepCard(
                      step: 1,
                      title: 'Add Your Branches',
                      description: 'Branches represent academic departments like CSE, IT, ECE, Mechanical, etc.\n\n'
                          'Go to Branches in the sidebar and add each department with its full name and abbreviation.',
                      icon: Icons.account_tree_rounded,
                      color: Colors.teal,
                    ),
                    _StepCard(
                      step: 2,
                      title: 'Add Your Students',
                      description: 'Students belong to a branch and have a roll number, batch (admission year), and program (B.Tech, M.Tech, etc.).\n\n'
                          'You can add them one-by-one or use Bulk Import with an Excel file (.xlsx). '
                          'The Excel file should have columns: name, student_id, branch_name (or branch), and optionally program, batch, email.',
                      icon: Icons.school_rounded,
                      color: Colors.indigo,
                    ),
                    _StepCard(
                      step: 3,
                      title: 'Add Teachers',
                      description: 'Teachers are the instructors who will be assigned to teach subjects.\n\n'
                          'Each teacher needs a name and a unique short code (e.g., "Dr. Sharma" → "DS"). '
                          'You can also optionally set their availability (which days/periods they are free).',
                      icon: Icons.people_rounded,
                      color: Colors.blue,
                    ),
                    _StepCard(
                      step: 4,
                      title: 'Add Rooms',
                      description: 'Rooms are the classrooms and labs where lectures happen.\n\n'
                          'Each room has a name (e.g., "Room 101", "CS Lab 1"), a capacity, and a type (Lecture or Lab).',
                      icon: Icons.meeting_room_rounded,
                      color: Colors.orange,
                    ),
                    _StepCard(
                      step: 5,
                      title: 'Add Subjects',
                      description: 'Subjects are the courses that will be scheduled.\n\n'
                          'Each subject has a name, code, type (Theory or Lab), and hours per week. '
                          'Optionally, add an abbreviation for cleaner display on the timetable.',
                      icon: Icons.book_rounded,
                      color: Colors.purple,
                    ),
                    _StepCard(
                      step: 6,
                      title: 'Create Groups',
                      description: 'Groups are collections of students who attend lectures together.\n\n'
                          'For example, "CSE Batch 2024" could be a group containing all CSE students from 2024. '
                          'You can also create combined groups like "CSE+IT Elective" for shared subjects.\n\n'
                          'After creating a group, click "Manage Students" to add students into it.',
                      icon: Icons.groups_rounded,
                      color: Colors.pink,
                    ),

                    const SizedBox(height: 24),

                    _GuideSectionHeader(title: 'Working with Sessions', icon: Icons.layers_rounded, color: Colors.deepPurple),
                    const SizedBox(height: 12),

                    _GuideSection(
                      icon: Icons.layers_outlined,
                      color: Colors.deepPurple,
                      title: 'What is a Session?',
                      content: 'A Session represents a specific scheduling scenario — for example, "Odd Semester 2025" or "Even Semester 2026".\n\n'
                          'Sessions let you pick a subset of teachers, rooms, subjects, and groups from the central database, '
                          'and create a timetable specifically for them.\n\n'
                          'This way, your central database stays as a master record, and each session is a self-contained workspace.',
                    ),

                    _StepCard(
                      step: 7,
                      title: 'Create a Session',
                      description: 'Use the "Select Workspace" dropdown in the sidebar to create a new session.\n\n'
                          'Give it a meaningful name like "Odd Sem 2025-26". ',
                      icon: Icons.add_circle_outline_rounded,
                      color: Colors.deepPurple,
                    ),
                    _StepCard(
                      step: 8,
                      title: 'Add Entities to the Session',
                      description: 'Once inside a session, go to Teachers, Rooms, Subjects, and Groups tabs.\n\n'
                          'Use the "Add from Central DB" button to pick entities from your central database into this session. '
                          'Only entities added to the session will be used for timetable generation.',
                      icon: Icons.playlist_add_rounded,
                      color: Colors.cyan,
                    ),
                    _StepCard(
                      step: 9,
                      title: 'Configure Time Slots',
                      description: 'Go to Slot Config to set up your daily periods.\n\n'
                          'Define how many periods per day, their start and end times, and which slot is the lunch break. '
                          'You can also set teaching days (e.g., Monday to Friday).',
                      icon: Icons.access_time_filled_rounded,
                      color: Colors.amber.shade700,
                    ),

                    const SizedBox(height: 24),

                    _GuideSectionHeader(title: 'Enrollments & Generation', icon: Icons.link_rounded, color: Colors.red),
                    const SizedBox(height: 12),

                    _GuideSection(
                      icon: Icons.link_rounded,
                      color: Colors.red,
                      title: 'What is an Enrollment?',
                      content: 'An Enrollment is the core building block of the timetable. '
                          'It links three things together:\n\n'
                          '• A Teacher — who will teach\n'
                          '• A Subject — what will be taught\n'
                          '• A Group — who will be taught\n\n'
                          'For example: "Dr. Sharma teaches Data Structures to CSE Batch 2024"\n\n'
                          'Each enrollment becomes one or more lecture slots in the final timetable. '
                          'The number of lecture slots is determined by the subject\'s "hours per week" setting.',
                    ),

                    _StepCard(
                      step: 10,
                      title: 'Create Enrollments',
                      description: 'Go to Enrollment in the sidebar and add enrollments by selecting a teacher, subject, and group for each.\n\n'
                          'Make sure to create all the enrollments that represent your semester\'s teaching plan before generating.',
                      icon: Icons.link_rounded,
                      color: Colors.red,
                    ),
                    _StepCard(
                      step: 11,
                      title: 'Generate the Timetable!',
                      description: 'Once all enrollments are in place, click the "Generate" button in the sidebar.\n\n'
                          'The system will automatically create a clash-free timetable, ensuring:\n'
                          '• No teacher has two lectures at the same time\n'
                          '• No room is double-booked\n'
                          '• No student group has overlapping classes\n'
                          '• Teacher availability preferences are respected',
                      icon: Icons.rocket_launch_rounded,
                      color: Colors.green,
                    ),
                    _StepCard(
                      step: 12,
                      title: 'View & Export',
                      description: 'After generation, go to the Timetable section to explore the result.\n\n'
                          'You can view timetables by teacher, room, group, or branch. '
                          'Export to Excel for sharing or printing.',
                      icon: Icons.calendar_month_rounded,
                      color: Colors.blue,
                    ),

                    const SizedBox(height: 24),

                    _GuideSectionHeader(title: 'Quick Tips', icon: Icons.tips_and_updates_rounded, color: Colors.amber.shade700),
                    const SizedBox(height: 12),

                    _TipCard(
                      tip: 'You can set teacher availability by clicking the calendar icon next to each teacher in the Teachers list. '
                          'This tells the system which time slots a teacher prefers not to be scheduled.',
                    ),
                    _TipCard(
                      tip: 'Groups are flexible — a student can be in multiple groups. '
                          'Use this for elective courses where students from different branches take the same subject together.',
                    ),
                    _TipCard(
                      tip: 'The Central Database is your master data. Sessions pull from it, so keep the central database up to date. '
                          'You can create multiple sessions (e.g., one per semester) all sharing the same teacher and room data.',
                    ),
                    _TipCard(
                      tip: 'If the generated timetable isn\'t perfect, you can regenerate. Each generation creates a new "version" — '
                          'you can compare versions and pick the one you prefer.',
                    ),
                    _TipCard(
                      tip: 'Use Bulk Import for students to save time. Prepare an Excel file with all student data and import hundreds of students at once.',
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GuideSectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;

  const _GuideSectionHeader({required this.title, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: color.withAlpha(30),
          radius: 18,
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Text(title, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold)),
      ],
    ).animate().fadeIn().slideX(begin: -0.03);
  }
}

class _GuideSection extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String content;

  const _GuideSection({required this.icon, required this.color, required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 10),
              Text(title, style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Text(content, style: GoogleFonts.inter(fontSize: 14, height: 1.6, color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.02);
  }
}

class _StepCard extends StatelessWidget {
  final int step;
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  const _StepCard({required this.step, required this.title, required this.description, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outlineVariant.withAlpha(60)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text('$step', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, color: color, size: 18),
                      const SizedBox(width: 8),
                      Text(title, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(description, style: GoogleFonts.inter(fontSize: 13, height: 1.55, color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: (step * 40).ms).slideX(begin: 0.03);
  }
}

class _TipCard extends StatelessWidget {
  final String tip;

  const _TipCard({required this.tip});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.amber.withAlpha(15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.amber.withAlpha(50)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lightbulb_outline_rounded, color: Colors.amber.shade700, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(tip, style: GoogleFonts.inter(fontSize: 13, height: 1.5, color: theme.colorScheme.onSurfaceVariant)),
            ),
          ],
        ),
      ),
    );
  }
}
