import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:university_timetable_frontend/src/theme/theme_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final themeMode = ref.watch(themeModeProvider);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Settings', style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
            const SizedBox(height: 4),
            Text('Configure your application preferences.', style: GoogleFonts.inter(fontSize: 15, color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 40),

            // ── Appearance Section ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colorScheme.outlineVariant.withAlpha(50)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.palette_rounded, color: colorScheme.primary),
                      const SizedBox(width: 12),
                      Text('Appearance', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Choose your preferred color theme.', style: GoogleFonts.inter(color: colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 24),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode_rounded)),
                      ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode_rounded)),
                      ButtonSegment(value: ThemeMode.system, label: Text('System'), icon: Icon(Icons.settings_suggest_rounded)),
                    ],
                    selected: {themeMode},
                    onSelectionChanged: (newSelection) {
                      ref.read(themeModeProvider.notifier).setMode(newSelection.first);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // ── About Section ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colorScheme.outlineVariant.withAlpha(50)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: colorScheme.primary),
                      const SizedBox(width: 12),
                      Text('About', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _InfoRow(label: 'Application', value: 'UniScheduler'),
                  _InfoRow(label: 'Version', value: '1.0.0'),
                  _InfoRow(label: 'Engine', value: 'NSGA-II Genetic Algorithm'),

                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
          Expanded(child: Text(value, style: GoogleFonts.inter())),
        ],
      ),
    );
  }
}
