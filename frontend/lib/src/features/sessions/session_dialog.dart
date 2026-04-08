import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:university_timetable_frontend/src/features/sessions/session_provider.dart';

class SessionDialog extends ConsumerStatefulWidget {
  const SessionDialog({super.key});

  @override
  ConsumerState<SessionDialog> createState() => _SessionDialogState();
}

class _SessionDialogState extends ConsumerState<SessionDialog> {
  final _controller = TextEditingController();
  int? _sourceSessionId;
  bool _isLoading = false;

  void _submit() async {
    if (_controller.text.isNotEmpty && !_isLoading) {
      setState(() => _isLoading = true);
      try {
        await ref.read(sessionsProvider.notifier).createSession(
          _controller.text,
          fromSessionId: _sourceSessionId,
        );
        if (mounted) Navigator.of(context).pop();
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to create session: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Create New Session',
        style: GoogleFonts.inter(fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              enabled: !_isLoading,
              decoration: const InputDecoration(
                hintText: 'e.g., Fall 2026',
                labelText: 'Session Name',
              ),
              onSubmitted: (_) => _submit(),
              autofocus: true,
            ),
            if (_isLoading) ...[
              const SizedBox(height: 24),
              const CircularProgressIndicator(),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child: const Text('Create'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

