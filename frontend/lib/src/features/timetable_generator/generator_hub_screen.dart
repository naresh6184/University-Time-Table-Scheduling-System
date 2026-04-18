import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:university_timetable_frontend/src/features/sessions/session_provider.dart';
import 'package:university_timetable_frontend/src/features/timetable_generator/generator_provider.dart';
import 'package:university_timetable_frontend/src/models/timetable_models.dart';
import 'package:go_router/go_router.dart';

class GeneratorHubScreen extends ConsumerWidget {
  const GeneratorHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final generationState = ref.watch(generationNotifierProvider);
    final versionsState = ref.watch(versionsProvider);
    final activeSession = ref.watch(activeSessionProvider);

    ref.listen(generationNotifierProvider, (previous, next) {
      if (previous?.status != GenerationStatus.success && next.status == GenerationStatus.success) {
        final res = next.result;
        if (res?.status == 'duplicate') {
           ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Found duplicate! ${res?.message}'),
              backgroundColor: Colors.blue,
              action: SnackBarAction(
                label: 'View Original',
                textColor: Colors.white,
                onPressed: () => context.push('/timetable?versionId=${res?.versionId}'),
              ),
            ),
          );
        } else if (res?.status == 'conflicts') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Generated with Conflicts: ${res?.message}'),
              backgroundColor: Colors.orange,
              action: SnackBarAction(
                label: 'View',
                textColor: Colors.white,
                onPressed: () => context.push('/timetable?versionId=${res?.versionId}'),
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Generation Complete! Version v.${res?.versionId} created.'),
              backgroundColor: Colors.green,
              action: SnackBarAction(
                label: 'View',
                textColor: Colors.white,
                onPressed: () => context.push('/timetable?versionId=${res?.versionId}'),
              ),
            ),
          );
        }
      } else if (previous?.status != GenerationStatus.error && next.status == GenerationStatus.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Generation Failed: ${next.errorMessage}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 10),
          ),
        );
      }
    });

    return Container(
      color: colorScheme.surfaceContainerLowest,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _GeneratorHeader(activeSession: activeSession),
            const SizedBox(height: 32),

            // Main Content Split
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: _LiveProgressPanel(state: generationState),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 2,
                  child: _EngineConfiguration(
                    status: generationState.status,
                    onGenerate: (pop, gen) => ref.read(generationNotifierProvider.notifier).generate(population: pop, generations: gen),
                    onCancel: () => ref.read(generationNotifierProvider.notifier).cancel(),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 40),
            Text(
              'Recent Timetable Versions',
              style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Versions List
            versionsState.when(
              data: (versions) => versions.isEmpty
                  ? const _EmptyVersions()
                  : Column(
                      children: versions.map((version) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _VersionCard(
                          version: version,
                          onActivate: () => ref.read(versionsProvider.notifier).activateVersion(version.versionId),
                        ),
                      )).toList(),
                    ),
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, s) => Center(child: Text('Error loading versions: $e')),
            ),
          ],
        ),
      ),
    );
  }
}

class _GeneratorHeader extends StatelessWidget {
  final dynamic activeSession;
  const _GeneratorHeader({required this.activeSession});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Engine Control Center',
          style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        Text(
          'Active Workspace: ${activeSession?.name ?? 'None Selected'}',
          style: GoogleFonts.inter(fontSize: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _LiveProgressPanel extends StatelessWidget {
  final GenerationState state;
  const _LiveProgressPanel({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = state.statusData;
    final isGenerating = state.status == GenerationStatus.generating;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant.withAlpha(80), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Generation Feed', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 14, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Engine runs up to 5 attempts and automatically saves the best overall result (based on weighted severity and quality score).',
                  style: GoogleFonts.inter(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          
          if (state.status == GenerationStatus.idle) ...[
             Center(
               child: Column(
                 children: [
                   const SizedBox(height: 40),
                   Icon(Icons.monitor_heart_rounded, size: 64, color: theme.colorScheme.outlineVariant),
                   const SizedBox(height: 16),
                   Text('Engine is idle. Start generation to see real-time progress.', style: GoogleFonts.inter(color: theme.colorScheme.onSurfaceVariant)),
                   const SizedBox(height: 40),
                 ],
               ),
             )
          ] else if (isGenerating && data != null) ...[
            Row(
              children: [
                const SizedBox(width: 48, height: 48, child: _DnaHelixAnimation()),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Attempt ${data.attempt} / ${data.maxAttempts}', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                      Text('${data.status}...', style: GoogleFonts.inter(fontSize: 14)),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Score', style: GoogleFonts.inter(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                        Text('${data.bestSoftScore?.toStringAsFixed(2) ?? "-"}', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                      ],
                    ),
                    const SizedBox(width: 24),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Violations', style: GoogleFonts.inter(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                        Text('${data.bestViolation ?? "-"}', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: data.bestViolation == 0 ? Colors.green : Colors.red)),
                      ],
                    ),
                  ],
                )
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Generation Progress', style: GoogleFonts.inter(fontSize: 14)),
                Text('${data.generation} / ${data.maxGenerations}', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: data.maxGenerations > 0 ? (data.generation / data.maxGenerations) : null,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            if (data.conflictLogs.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('Current Conflicts:', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.redAccent)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: data.conflictLogs.map((log) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.withAlpha(20),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.red.withAlpha(40)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(log.type, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        child: Text('${log.count}', style: GoogleFonts.inter(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                )).toList(),
              ),
            ],
          ] else if (state.status == GenerationStatus.success) ...[
            Row(
              children: [
                Icon(data?.isFeasible == true ? Icons.check_circle_rounded : Icons.warning_rounded, size: 48, color: data?.isFeasible == true ? Colors.green : Colors.orange),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data?.status ?? 'Completed', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
                      if (data?.bestViolation != null)
                         Text('Final Violations: ${data?.bestViolation} • Score: ${data?.bestSoftScore?.toStringAsFixed(2)}', style: GoogleFonts.inter(color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
            if (data?.conflictLogs.isNotEmpty == true) ...[
              const SizedBox(height: 24),
              Text('Unresolved Constraints:', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.orange)),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.orange.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withAlpha(50)),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: (data?.conflictLogs ?? []).map((log) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('• ${log.type}', style: GoogleFonts.inter()),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(12)),
                          child: Text('${log.count}', style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        )
                      ],
                    ),
                  )).toList(),
                ),
              )
            ]
          ] else if (state.status == GenerationStatus.error) ...[
             Center(
               child: Column(
                 children: [
                   const SizedBox(height: 40),
                   Icon(Icons.error_outline_rounded, size: 64, color: Colors.red),
                   const SizedBox(height: 16),
                   Text('Generation Failed.', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.red)),
                   const SizedBox(height: 40),
                 ],
               ),
             )
          ],
          if (data?.feasibilityInfo != null) ...[
            const SizedBox(height: 32),
            Builder(
              builder: (_) {
                final feasibilityInfo = data?.feasibilityInfo;
                if (feasibilityInfo == null) return const SizedBox.shrink();
                return Container(
                  padding: const EdgeInsets.only(top: 24),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant.withAlpha(80)))
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Resource Pre-Check', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _FeasibilityBadge(label: 'Theory Capacity', data: feasibilityInfo['theory'])),
                          const SizedBox(width: 16),
                          Expanded(child: _FeasibilityBadge(label: 'Lab Capacity', data: feasibilityInfo['lab'])),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ]
        ],
      ),
    );
  }
}

class _FeasibilityBadge extends StatelessWidget {
  final String label;
  final Map<String, dynamic>? data;

  const _FeasibilityBadge({required this.label, this.data});

  @override
  Widget build(BuildContext context) {
    if (data == null) return const SizedBox.shrink();
    final req = data!['required'] ?? 0;
    final avail = data!['available'] ?? 0;
    final isOk = avail >= req;
    final color = isOk ? Colors.blue : Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        border: Border.all(color: color.withAlpha(40)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isOk ? Icons.check_circle_outline : Icons.warning_amber_rounded, size: 16, color: color),
              const SizedBox(width: 8),
              Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: color)),
            ]
          ),
          const SizedBox(height: 8),
          Text('Required: $req slots', style: GoogleFonts.inter(fontSize: 12)),
          Text('Available: $avail slots', style: GoogleFonts.inter(fontSize: 12)),
        ]
      ),
    );
  }
}

class _EngineConfiguration extends StatefulWidget {
  final GenerationStatus status;
  final void Function(int? pop, int? gen) onGenerate;
  final VoidCallback onCancel;

  const _EngineConfiguration({required this.status, required this.onGenerate, required this.onCancel});

  @override
  State<_EngineConfiguration> createState() => _EngineConfigurationState();
}

class _EngineConfigurationState extends State<_EngineConfiguration> {
  final _popController = TextEditingController();
  final _genController = TextEditingController();

  @override
  void dispose() {
    _popController.dispose();
    _genController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isGenerating = widget.status == GenerationStatus.generating;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.primary.withAlpha(80), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Engine Settings', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          
          TextFormField(
            controller: _popController,
            enabled: !isGenerating,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Population Size',
              hintText: 'Default: 100',
              prefixIcon: const Icon(Icons.groups_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _genController,
            enabled: !isGenerating,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Max Generations',
              hintText: 'Default: 200',
              prefixIcon: const Icon(Icons.speed_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          
          const SizedBox(height: 32),
          
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: isGenerating ? null : () {
                final pop = int.tryParse(_popController.text);
                final gen = int.tryParse(_genController.text);
                widget.onGenerate(pop, gen);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: isGenerating
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                  : Text('Start Generation', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
          
          if (isGenerating) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: widget.onCancel,
                icon: const Icon(Icons.cancel, color: Colors.red),
                label: Text('Cancel', style: GoogleFonts.inter(color: Colors.red)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ]
        ],
      ),
    );
  }
}

class _VersionCard extends StatelessWidget {
  final TimetableVersion version;
  final VoidCallback onActivate;

  const _VersionCard({required this.version, required this.onActivate});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final conflictCount = version.bestViolation;
    final isFeasible = conflictCount == 0;
    final statusColor = isFeasible ? Colors.green : Colors.red;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: version.isActive ? theme.colorScheme.primary.withAlpha(150) : theme.colorScheme.outlineVariant.withAlpha(80),
          width: version.isActive ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withAlpha(30),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.assignment_rounded, color: statusColor),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Version v.${version.versionId}', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
                    if (version.isActive)
                      Container(
                        margin: const EdgeInsets.only(left: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(6)),
                        child: Text('ACTIVE', style: GoogleFonts.inter(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    if (version.isDuplicateOf != null)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: Colors.blue.withAlpha(100), borderRadius: BorderRadius.circular(6)),
                        child: Text('DUP of v.${version.isDuplicateOf}', style: GoogleFonts.inter(fontSize: 10, color: Colors.blue[900], fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
                Text(
                  'Conflicts: $conflictCount • Quality Score: ${version.bestSoftScore.toStringAsFixed(2)}',
                  style: GoogleFonts.inter(fontSize: 14, color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                isFeasible ? 'Feasible' : 'Infeasible',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: statusColor),
              ),
              const SizedBox(height: 8),
              if (!version.isActive)
                TextButton(
                  onPressed: onActivate,
                  child: const Text('Activate'),
                ),
              TextButton(
                onPressed: () => context.push('/timetable?versionId=${version.versionId}'),
                child: const Text('View'),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn().slideX(begin: 0.1);
  }
}

class _EmptyVersions extends StatelessWidget {
  const _EmptyVersions();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history_rounded, size: 48, color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: 16),
          const Text('No previous versions found in this session.'),
        ],
      ),
    );
  }
}

// ── DNA Helix Animation (Genetic Algorithm visual) ──

class _DnaHelixAnimation extends StatefulWidget {
  const _DnaHelixAnimation();

  @override
  State<_DnaHelixAnimation> createState() => _DnaHelixAnimationState();
}

class _DnaHelixAnimationState extends State<_DnaHelixAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(64, 64),
          painter: _DnaHelixPainter(_controller.value),
        );
      },
    );
  }
}

class _DnaHelixPainter extends CustomPainter {
  final double progress;
  _DnaHelixPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final amplitude = size.width * 0.35;
    final steps = 12;
    final phase = progress * 2 * pi;

    final strandPaint1 = Paint()
      ..color = const Color(0xFF1565C0)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final strandPaint2 = Paint()
      ..color = const Color(0xFF42A5F5)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path1 = Path();
    final path2 = Path();

    for (int i = 0; i <= steps * 4; i++) {
      final t = i / (steps * 4);
      final y = t * size.height;
      final angle = t * 4 * pi + phase;
      final x1 = centerX + amplitude * sin(angle);
      final x2 = centerX + amplitude * sin(angle + pi);

      if (i == 0) {
        path1.moveTo(x1, y);
        path2.moveTo(x2, y);
      } else {
        path1.lineTo(x1, y);
        path2.lineTo(x2, y);
      }
    }

    canvas.drawPath(path1, strandPaint1);
    canvas.drawPath(path2, strandPaint2);

    // Draw rungs (base pairs)
    final rungPaint = Paint()
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < steps; i++) {
      final t = (i + 0.5) / steps;
      final y = t * size.height;
      final angle = t * 4 * pi + phase;
      final x1 = centerX + amplitude * sin(angle);
      final x2 = centerX + amplitude * sin(angle + pi);

      // Depth determines opacity — rungs at "front" are more visible
      final depth = cos(angle);
      final alpha = (0.3 + 0.7 * ((depth + 1) / 2)).clamp(0.0, 1.0);

      // Alternate rung colors for visual variety
      final colors = [
        const Color(0xFFE53935), // red
        const Color(0xFF43A047), // green
        const Color(0xFFFDD835), // yellow
        const Color(0xFF8E24AA), // purple
      ];
      rungPaint.color = colors[i % colors.length].withValues(alpha: alpha);

      canvas.drawLine(Offset(x1, y), Offset(x2, y), rungPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DnaHelixPainter oldDelegate) => oldDelegate.progress != progress;
}
