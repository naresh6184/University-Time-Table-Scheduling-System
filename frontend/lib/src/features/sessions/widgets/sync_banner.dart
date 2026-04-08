import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:university_timetable_frontend/src/features/sessions/session_sync_provider.dart';
import 'package:university_timetable_frontend/src/features/sessions/session_provider.dart';

class SyncBanner extends ConsumerWidget {
  const SyncBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(sessionSyncProvider);
    final activeSession = ref.watch(activeSessionProvider);

    // Only show if a workspace session is active and NOT the central database
    if (activeSession == null || activeSession.sessionId == -1) {
      return const SizedBox.shrink();
    }

    return syncState.when(
      data: (status) {
        if (!status.outOfSync) return const SizedBox.shrink();

        String message = "Changes detected in Central Database:\n";
        if (status.details['master_config'] == true) message += "• Slot Configuration updated\n";
        if (status.details['availability'] == true) message += "• Teacher Availability changed\n";
        if (status.details['basic_entities'] == true) message += "• Basic entity info updated\n";

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.orange.withAlpha(20),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.orange.withAlpha(50)),
          ),
          child: Row(
            children: [
              Icon(Icons.sync_problem_rounded, color: Colors.orange.shade800, size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Synchronization Required',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.orange.shade900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message.trim(),
                      style: GoogleFonts.inter(fontSize: 13, color: Colors.orange.shade900.withAlpha(200)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: syncState.isLoading ? null : () => _handleSync(context, ref),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade800,
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
                icon: syncState.isLoading 
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.sync_rounded),
                label: Text(syncState.isLoading ? 'Syncing...' : 'Sync Now'),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(), // Still hide initially, but the button handles inner loading
      error: (err, _) => Center(child: Text('Sync Error: $err', style: const TextStyle(color: Colors.red))),
    );
  }

  Future<void> _handleSync(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(sessionSyncProvider.notifier).triggerSync();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: ${e.toString()}'),
            backgroundColor: Colors.red.shade800,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
