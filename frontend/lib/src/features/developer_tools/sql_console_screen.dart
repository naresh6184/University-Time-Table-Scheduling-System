import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:university_timetable_frontend/src/features/developer_tools/sql_provider.dart';

class SqlConsoleScreen extends ConsumerStatefulWidget {
  const SqlConsoleScreen({super.key});

  @override
  ConsumerState<SqlConsoleScreen> createState() => _SqlConsoleScreenState();
}

class _SqlConsoleScreenState extends ConsumerState<SqlConsoleScreen> {
  bool _isUnlocking = false;
  bool _agreedToRisks = false;
  final TextEditingController _queryController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  SqlResponse? _lastResponse;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _queryController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _unlockConsole() async {
    final password = _passwordController.text.trim();
    if (password.isEmpty) return;

    setState(() {
      _isUnlocking = true;
      _error = null;
    });

    final success = await ref.read(sqlControllerProvider).verifyPassword(password);
    
    if (mounted) {
      setState(() {
        _isUnlocking = false;
        if (success) {
          ref.read(devAuthNotifierProvider.notifier).unlock(password);
          _error = null;
        } else {
          _error = "Invalid developer password. Access denied.";
        }
      });
    }
  }

  Future<void> _executeQuery() async {
    final query = _queryController.text.trim();
    final password = ref.read(devAuthNotifierProvider).cachedPassword;
    if (query.isEmpty || password == null) return;

    ref.read(devAuthNotifierProvider.notifier).registerActivity();

    setState(() {
      _isLoading = true;
      _error = null;
      _lastResponse = null;
    });

    try {
      final response = await ref.read(sqlControllerProvider).executeQuery(query, password);
      setState(() {
        _lastResponse = response;
      });
    } catch (e) {
      setState(() {
        if (e is DioException) {
          _error = e.message ?? e.toString();
        } else {
          _error = e.toString();
        }
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final devAuthState = ref.watch(devAuthNotifierProvider);

    return Listener(
      onPointerDown: (_) => ref.read(devAuthNotifierProvider.notifier).registerActivity(),
      onPointerHover: (_) => ref.read(devAuthNotifierProvider.notifier).registerActivity(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
          color: colorScheme.surface,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.terminal_rounded, size: 28, color: colorScheme.primary),
                  const SizedBox(width: 12),
                  Text('SQL Console', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Execute raw SQLite queries directly against the database. Common MySQL aliases (like SHOW TABLES) are also supported. Use with extreme caution.',
                style: GoogleFonts.inter(color: colorScheme.error, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),

        if (!devAuthState.isUnlocked)
          // Lock Screen View
          Expanded(
            flex: 5,
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colorScheme.outlineVariant.withAlpha(50)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 20, offset: const Offset(0, 10)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_rounded, size: 64, color: colorScheme.primary),
                    const SizedBox(height: 24),
                    Text('Developer Access Required', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Text(
                      'This area allows direct database manipulation. It is locked to prevent accidental data corruption.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(fontSize: 14, color: colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 24),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(_error!, style: GoogleFonts.inter(color: colorScheme.error, fontWeight: FontWeight.w600)),
                      ),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      onSubmitted: (_) {
                        if (_agreedToRisks) _unlockConsole();
                      },
                      decoration: InputDecoration(
                        labelText: 'Developer Password',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.key_rounded),
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest.withAlpha(50),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer.withAlpha(50),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: colorScheme.error.withAlpha(100)),
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: _agreedToRisks,
                            onChanged: (val) {
                              setState(() {
                                _agreedToRisks = val ?? false;
                              });
                            },
                            isError: true,
                          ),
                          Expanded(
                            child: Text(
                              'I understand the risks and want to proceed',
                              style: GoogleFonts.inter(fontSize: 13, color: colorScheme.error, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: (_isUnlocking || !_agreedToRisks) ? null : _unlockConsole,
                        style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                        child: _isUnlocking 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text('Unlock Console', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else ...[
          // Editor Area
          Expanded(
            flex: 2,
            child: Container(
              margin: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.outlineVariant.withAlpha(100)),
              ),
              child: Column(
                children: [
                  // Auto-lock Countdown Warning
                  if (devAuthState.secondsUntilLock != null)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      decoration: BoxDecoration(
                        color: colorScheme.error,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Console will auto-lock in ${devAuthState.secondsUntilLock} seconds due to inactivity. Move your mouse or click here to cancel.',
                            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  // Toolbar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withAlpha(100),
                      borderRadius: devAuthState.secondsUntilLock == null 
                          ? const BorderRadius.vertical(top: Radius.circular(12))
                          : BorderRadius.zero,
                      border: Border(bottom: BorderSide(color: colorScheme.outlineVariant.withAlpha(100))),
                    ),
                    child: Row(
                      children: [
                        Text('Session Unlocked', style: GoogleFonts.inter(color: Colors.green.shade600, fontWeight: FontWeight.w600, fontSize: 13)),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () {
                            ref.read(devAuthNotifierProvider.notifier).lock();
                            _passwordController.clear();
                          },
                          icon: const Icon(Icons.lock_rounded, size: 18),
                          label: const Text('Lock Now'),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () {
                            _queryController.clear();
                            setState(() {
                              _lastResponse = null;
                              _error = null;
                            });
                          },
                          icon: const Icon(Icons.clear_all_rounded, size: 18),
                          label: const Text('Clear Output'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: _isLoading ? null : _executeQuery,
                          icon: _isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.play_arrow_rounded, size: 18),
                          label: const Text('Execute'),
                          style: FilledButton.styleFrom(backgroundColor: Colors.green.shade600),
                        ),
                      ],
                    ),
                  ),
                  // Editor
                  Expanded(
                    child: TextField(
                      controller: _queryController,
                      maxLines: null,
                      expands: true,
                      style: GoogleFonts.jetBrainsMono(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'SELECT * FROM student LIMIT 10;',
                        hintStyle: GoogleFonts.jetBrainsMono(color: colorScheme.onSurfaceVariant.withAlpha(100)),
                        contentPadding: const EdgeInsets.all(16),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
  
          // Results Area
          Expanded(
            flex: 3,
            child: Container(
              margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.outlineVariant.withAlpha(100)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Results Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withAlpha(100),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      border: Border(bottom: BorderSide(color: colorScheme.outlineVariant.withAlpha(100))),
                    ),
                    child: Text('Results', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: colorScheme.onSurfaceVariant)),
                  ),
                  // Results Body
                  Expanded(
                    child: _buildResultsView(theme, colorScheme),
                  ),
                ],
              ),
            ),
          ),
        ],
        ],
      ),
    );
  }

  Widget _buildResultsView(ThemeData theme, ColorScheme colorScheme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline_rounded, color: colorScheme.error, size: 32),
                const SizedBox(width: 12),
                Text('Query Failed', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.error)),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer.withAlpha(50),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colorScheme.error.withAlpha(100)),
              ),
              child: SelectableText(_error!, style: GoogleFonts.jetBrainsMono(color: colorScheme.error, fontSize: 13)),
            ),
          ],
        ),
      );
    }

    if (_lastResponse == null) {
      return Center(
        child: Text('Enter a query and click Execute', style: GoogleFonts.inter(color: colorScheme.onSurfaceVariant.withAlpha(150))),
      );
    }

    final response = _lastResponse!;

    if (!response.success) {
      return Center(child: Text('Unknown error occurred.'));
    }

    if (!response.isSelect) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline_rounded, size: 64, color: Colors.green.shade600),
            const SizedBox(height: 16),
            Text(response.message, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    if (response.rows.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_rounded, size: 64, color: colorScheme.outlineVariant),
            const SizedBox(height: 16),
            Text('No rows returned.', style: GoogleFonts.inter(fontSize: 16)),
          ],
        ),
      );
    }

    // Render Data Table
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(colorScheme.surfaceContainerHighest.withAlpha(50)),
          columns: response.columns
              .map((col) => DataColumn(label: Text(col, style: GoogleFonts.inter(fontWeight: FontWeight.bold))))
              .toList(),
          rows: response.rows
              .map(
                (row) => DataRow(
                  cells: response.columns
                      .map((col) => DataCell(SelectableText(row[col]?.toString() ?? 'NULL', style: GoogleFonts.jetBrainsMono(fontSize: 13))))
                      .toList(),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}
