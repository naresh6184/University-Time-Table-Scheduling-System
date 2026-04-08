import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:university_timetable_frontend/src/features/organization/org_providers.dart';
import 'package:university_timetable_frontend/src/models/org_models.dart';

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

enum OrgType { branch, group, student }

class OrgAddDialog extends ConsumerStatefulWidget {
  final OrgType type;
  final dynamic initialData;

  const OrgAddDialog({super.key, required this.type, this.initialData});

  @override
  ConsumerState<OrgAddDialog> createState() => _OrgAddDialogState();
}

class _OrgAddDialogState extends ConsumerState<OrgAddDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _abbreviationController = TextEditingController();
  final _rollController = TextEditingController();
  final _emailController = TextEditingController();
  final _batchController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  int? _selectedBranchId;
  String _selectedProgram = 'B.Tech';
  bool _isAutoGeneratingAbbr = true;

  bool get _isEditing => widget.initialData != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final data = widget.initialData;
      _nameController.text = data.name;
      _isAutoGeneratingAbbr = false; 
      
      if (data is BranchModel) {
        _abbreviationController.text = data.abbreviation ?? '';
      }
      if (data is StudentModel) {
        _rollController.text = data.studentId;
        _emailController.text = data.email ?? '';
        _batchController.text = data.batch?.toString() ?? '';
        _selectedBranchId = data.branchId;
        _selectedProgram = data.program;
      }
      if (data is GroupModel) {
        _descriptionController.text = data.description ?? '';
      }
    }
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      switch (widget.type) {
        case OrgType.branch:
          final abbr = _abbreviationController.text.trim().isEmpty ? null : _abbreviationController.text.trim();
          if (_isEditing) {
            ref.read(branchesProvider.notifier).updateBranch(widget.initialData.branchId, _nameController.text, abbreviation: abbr);
          } else {
            ref.read(branchesProvider.notifier).addBranch(_nameController.text, abbreviation: abbr);
          }
          break;

        case OrgType.group:
          final name = _nameController.text.trim();
          final desc = _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim();
          
          if (_isEditing) {
            ref.read(groupsProvider.notifier).updateGroup(
              widget.initialData.groupId, 
              name, 
              description: desc,
            );
          } else {
            ref.read(groupsProvider.notifier).addGroup(
              name, 
              description: desc,
            );
          }
          break;

        case OrgType.student:
          if (_isEditing) {
            ref.read(studentsProvider.notifier).updateStudent(
                  rollNumber: _rollController.text,
                  name: _nameController.text,
                  branchId: _selectedBranchId!,
                  email: _emailController.text.isEmpty ? null : _emailController.text,
                  batch: int.tryParse(_batchController.text),
                  program: _selectedProgram,
                );
          } else {
            ref.read(studentsProvider.notifier).addStudent(
                  rollNumber: _rollController.text,
                  name: _nameController.text,
                  branchId: _selectedBranchId!,
                  email: _emailController.text.isEmpty ? null : _emailController.text,
                  batch: int.tryParse(_batchController.text),
                  program: _selectedProgram,
                );
          }
          break;
      }
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final branches = ref.watch(branchesProvider);

    return AlertDialog(
      title: Text(_isEditing ? 'Edit ${widget.type.name.toUpperCase()}' : 'Add New ${widget.type.name.toUpperCase()}',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.type == OrgType.student) ...[
                TextFormField(
                  controller: _rollController,
                  decoration: const InputDecoration(labelText: 'Roll Number / ID'),
                  readOnly: _isEditing,
                  validator: (v) => v!.isEmpty ? 'Enter Roll Number' : null,
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: widget.type == OrgType.student ? 'Student Name' : (widget.type == OrgType.group ? 'Group Name' : 'Branch Name'),
                  hintText: widget.type == OrgType.group ? 'e.g. CSE A' : null,
                ),
                onChanged: (v) {
                  if (_isAutoGeneratingAbbr && widget.type == OrgType.branch) {
                    final ignoreWords = ['AND', 'OF', 'THE', 'IN', 'ON', 'AT', 'BY', 'FOR', 'WITH', 'TO', 'A', 'AN'];
                    final words = v.split(RegExp(r'\s+')).where((w) => w.isNotEmpty && !ignoreWords.contains(w.toUpperCase())).toList();
                    if (words.isNotEmpty) {
                      _abbreviationController.text = words.map((w) => w[0].toUpperCase()).join();
                    } else {
                      _abbreviationController.text = '';
                    }
                  }
                },
                validator: (v) => v!.isEmpty ? 'Enter name' : null,
              ),
              const SizedBox(height: 16),
              
              if (widget.type == OrgType.branch) ...[
                TextFormField(
                  controller: _abbreviationController,
                  decoration: InputDecoration(
                    labelText: 'Abbreviation (Optional)',
                    helperText: _isAutoGeneratingAbbr ? 'Auto-generating from name...' : null,
                  ),
                  onTap: () => setState(() => _isAutoGeneratingAbbr = false),
                  inputFormatters: [UpperCaseTextFormatter()],
                ),
                const SizedBox(height: 16),
              ],

              if (widget.type == OrgType.group) ...[
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'Description (Optional)'),
                ),
                const SizedBox(height: 16),
              ],

              if (widget.type == OrgType.student) ...[
                DropdownButtonFormField<String>(
                  initialValue: _selectedProgram,
                  items: const [
                    DropdownMenuItem(value: 'B.Tech', child: Text('B.Tech')),
                    DropdownMenuItem(value: 'M.Tech', child: Text('M.Tech')),
                    DropdownMenuItem(value: 'MBA', child: Text('MBA')),
                    DropdownMenuItem(value: 'BBA', child: Text('BBA')),
                  ],
                  onChanged: (v) => setState(() => _selectedProgram = v!),
                  decoration: const InputDecoration(labelText: 'Program'),
                ),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _batchController,
                  decoration: const InputDecoration(labelText: 'Batch (e.g. 2024)'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),

                branches.when(
                  data: (list) => DropdownButtonFormField<int>(
                    initialValue: _selectedBranchId,
                    items: list.map((b) => DropdownMenuItem(value: b.branchId, child: Text(b.name))).toList(),
                    onChanged: (v) => setState(() => _selectedBranchId = v),
                    decoration: const InputDecoration(labelText: 'Select Branch'),
                    validator: (v) => (widget.type == OrgType.student && v == null) ? 'Select a branch' : null,
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (e, s) => Text('Error loading branches: $e'),
                ),
                const SizedBox(height: 16),
              ],

              if (widget.type == OrgType.student) ...[
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email (Optional)'),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _abbreviationController.dispose();
    _rollController.dispose();
    _emailController.dispose();
    _batchController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
