import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:university_timetable_frontend/src/features/organization/org_providers.dart';

class BulkStudentImportDialog extends ConsumerStatefulWidget {
  const BulkStudentImportDialog({super.key});

  @override
  ConsumerState<BulkStudentImportDialog> createState() => _BulkStudentImportDialogState();
}

class _BulkStudentImportDialogState extends ConsumerState<BulkStudentImportDialog> {
  bool _isLoading = false;
  Map<String, dynamic>? _previewData;
  String? _error;
  final ScrollController _errorScrollController = ScrollController();

  @override
  void dispose() {
    _errorScrollController.dispose();
    super.dispose();
  }

  Future<void> _pickAndPreview() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _previewData = null;
    });

    try {
      fp.FilePickerResult? result = await fp.FilePicker.pickFiles(
        type: fp.FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
        withData: true,
      );

      if (result != null) {
        final file = result.files.first;
        final data = await ref.read(studentsProvider.notifier).previewImport(file.bytes!, file.name);
        
        if (data.containsKey('error')) {
          setState(() => _error = data['error']);
        } else {
          setState(() => _previewData = data);
        }
      }
    } catch (e) {
      setState(() => _error = 'Failed to process file: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _confirm() async {
    if (_previewData == null) return;
    
    setState(() => _isLoading = true);
    try {
      final validStudents = List<Map<String, dynamic>>.from(_previewData!['valid_students']);
      final message = await ref.read(studentsProvider.notifier).confirmImport(validStudents);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _error = 'Failed to import: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Map<String, List<int>> _getGroupedErrors() {
    if (_previewData == null) return {};
    final grouped = <String, List<int>>{};
    final invalidRows = _previewData!['invalid_rows'] as List;
    
    for (final row in invalidRows) {
      final line = row['line'] as int;
      final errors = (row['errors'] as List).join(', ');
      grouped.update(errors, (list) => list..add(line), ifAbsent: () => [line]);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.upload_file_rounded, color: colorScheme.primary),
          const SizedBox(width: 12),
          Text('Bulk Student Import', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_previewData == null && _error == null) ...[
                Text(
                  'Upload an Excel (.xlsx) or CSV file containing student information.',
                  style: GoogleFonts.inter(color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withAlpha(50),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colorScheme.primary.withAlpha(50)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Required Columns:', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text('• name — Full name of the student', style: GoogleFonts.inter(fontSize: 12)),
                      Text('• student_id / roll_no — Unique roll number', style: GoogleFonts.inter(fontSize: 12)),
                      Text('• branch / branch_name — Branch name or abbreviation', style: GoogleFonts.inter(fontSize: 12)),
                      Text('• program — e.g. B.Tech, M.Tech, MBA', style: GoogleFonts.inter(fontSize: 12)),
                      Text('• batch — Admission year, e.g. 2022', style: GoogleFonts.inter(fontSize: 12)),
                      const SizedBox(height: 8),
                      Text('Optional Columns:', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text('• email — Student email address', style: GoogleFonts.inter(fontSize: 12)),
                      const SizedBox(height: 8),
                      Text('Duplicates (by Roll No) are automatically detected.',
                        style: GoogleFonts.inter(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.0),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (_error != null)
                Container(
                  margin: const EdgeInsets.only(top: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer.withAlpha(100),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: colorScheme.error),
                      const SizedBox(width: 12),
                      Expanded(child: Text(_error!, style: GoogleFonts.inter(color: colorScheme.error))),
                    ],
                  ),
                ),
              if (_previewData != null) ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _CountBox(label: 'Total', count: _previewData!['total'], color: colorScheme.primary),
                    _CountBox(label: 'Ready', count: _previewData!['valid_count'], color: Colors.green),
                    _CountBox(label: 'Invalid', count: _previewData!['invalid_count'], color: colorScheme.error),
                  ],
                ),
                if (_previewData!['invalid_count'] > 0) ...[
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 20, color: colorScheme.error),
                      const SizedBox(width: 8),
                      Text(
                        'Correction Required', 
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: colorScheme.error),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: Scrollbar(
                      controller: _errorScrollController,
                      thumbVisibility: true,
                      child: ListView(
                        controller: _errorScrollController,
                        shrinkWrap: true,
                        children: _getGroupedErrors().entries.map((entry) {
                          final errorMsg = entry.key;
                          final lines = entry.value;
                          final linesText = lines.length > 5 
                              ? '${lines.take(5).join(', ')}... (+${lines.length - 5} more)' 
                              : lines.join(', ');

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colorScheme.error.withAlpha(10),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: colorScheme.error.withAlpha(30)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  errorMsg,
                                  style: GoogleFonts.inter(
                                    fontSize: 13, 
                                    fontWeight: FontWeight.w600, 
                                    color: colorScheme.error,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Lines: $linesText',
                                  style: GoogleFonts.inter(
                                    fontSize: 11, 
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (_previewData == null)
          FilledButton.icon(
            onPressed: _isLoading ? null : _pickAndPreview,
            icon: const Icon(Icons.search_rounded),
            label: const Text('Select File'),
          )
        else
          FilledButton.icon(
            onPressed: (_isLoading || _previewData!['valid_count'] == 0) ? null : _confirm,
            icon: const Icon(Icons.check_circle_outline),
            label: Text('Import ${_previewData!['valid_count']} Students'),
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
          ),
      ],
    );
  }
}

class _CountBox extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _CountBox({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(count.toString(), style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
