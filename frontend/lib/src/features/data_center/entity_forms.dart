import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:university_timetable_frontend/src/features/data_center/data_providers.dart';
import 'package:university_timetable_frontend/src/models/academic_entities.dart';

class UpperCaseTextFormatter extends TextInputFormatter {

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}


enum EntityType { teacher, room, subject }

class EntityAddDialog extends ConsumerStatefulWidget {
  final EntityType type;
  final dynamic initialData;

  const EntityAddDialog({super.key, required this.type, this.initialData});

  @override
  ConsumerState<EntityAddDialog> createState() => _EntityAddDialogState();
}

class _EntityAddDialogState extends ConsumerState<EntityAddDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _abbrController = TextEditingController(); // New field for Subject Abbreviation
  final _extra1Controller = TextEditingController(); // Email / Capacity
  final _extra2Controller = TextEditingController(); // hours_per_week
  String _selectedType = 'theory'; // for room and subject

  bool get _isEditing => widget.initialData != null;


  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final data = widget.initialData;
      _nameController.text = data.name;
      if (data is TeacherModel) {
        _codeController.text = data.code;
        _extra1Controller.text = data.email ?? '';
      } else if (data is ClassroomModel) {
        _extra1Controller.text = data.capacity.toString();
        _selectedType = data.roomType;
      } else if (data is SubjectModel) {
        _codeController.text = data.code;
        _abbrController.text = data.abbreviation ?? '';
        _selectedType = data.subjectType;
        _extra2Controller.text = data.hoursPerWeek.toString();

        // If abbreviation exists and matches initials of the name, keep auto-gen on
        // Otherwise, turn it off to respect manual edits
      }


    }
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      final name = _nameController.text;
      final code = _codeController.text;
      final abbr = _abbrController.text.isEmpty ? null : _abbrController.text;
      final extra1 = _extra1Controller.text.isEmpty ? null : _extra1Controller.text;
      final extra2 = _extra2Controller.text;

      try {
        int? createdId;
        switch (widget.type) {
          case EntityType.teacher:
            if (_isEditing) {
              await ref.read(teachersProvider.notifier).updateTeacher(widget.initialData.teacherId, name, code, extra1);
            } else {
              await ref.read(teachersProvider.notifier).addTeacher(name, code, extra1);
            }
            break;
          case EntityType.room:
            if (_isEditing) {
              await ref.read(classroomsProvider.notifier).updateClassroom(widget.initialData.roomId, name, int.parse(extra1!), _selectedType);
            } else {
              createdId = await ref.read(classroomsProvider.notifier).addClassroom(name, int.parse(extra1!), _selectedType);
            }
            break;
          case EntityType.subject:
            if (_isEditing) {
              await ref.read(subjectsProvider.notifier).updateSubject(widget.initialData.subjectId, name, code, abbr, _selectedType, int.parse(extra2));
            } else {
              createdId = await ref.read(subjectsProvider.notifier).addSubject(name, code, abbr, _selectedType, int.parse(extra2));
            }
            break;

        }

        if (mounted) Navigator.of(context).pop(createdId);
      } catch (e) {
        String errMsg = 'An error occurred while saving.';
        if (e is DioException && e.response?.data != null && e.response!.data is Map && e.response!.data['detail'] != null) {
          errMsg = e.response!.data['detail'].toString();
        } else {
          errMsg = e.toString();
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errMsg), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        _isEditing ? 'Edit ${widget.type.name.toUpperCase()}' : 'Add New ${widget.type.name.toUpperCase()}',
        style: GoogleFonts.inter(fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Full Name'),
                onChanged: (v) {
                  final ignoreWords = [
                    'MR.', 'DR.', 'MRS.', 'MISS.', 'MS.', 'PROF.', 'SIR.',
                    'MR', 'DR', 'MRS', 'MISS', 'MS', 'PROF', 'SIR',
                    'AND', 'OF', 'THE', 'IN', 'ON', 'AT', 'BY', 'FOR', 'WITH', 'TO', 'LIKE'
                  ];
                  final allWords = v.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
                  final filteredWords = allWords.where((w) => !ignoreWords.contains(w.toUpperCase())).toList();
                  final targetWords = filteredWords.isNotEmpty ? filteredWords : allWords;

                  if (targetWords.isNotEmpty) {
                    final abbr = targetWords.map((w) => w[0].toUpperCase()).join();
                    if (widget.type == EntityType.subject) {
                      _abbrController.text = abbr;
                    } else if (widget.type == EntityType.teacher) {
                      _codeController.text = abbr;
                    }
                  } else {
                    if (widget.type == EntityType.subject) _abbrController.text = '';
                    if (widget.type == EntityType.teacher) _codeController.text = '';
                  }
                },
                validator: (v) => v!.isEmpty ? 'Enter name' : null,
              ),
              const SizedBox(height: 16),
              if (widget.type == EntityType.teacher || widget.type == EntityType.subject) ...[
                TextFormField(
                  controller: _codeController,
                  decoration: InputDecoration(
                    labelText: widget.type == EntityType.subject ? 'Subject Code (Unique)' : 'Code / Abbreviation (e.g. AT, JD)',
                  ),
                  inputFormatters: [UpperCaseTextFormatter()],
                  validator: (v) => v!.isEmpty ? 'Enter code' : null,
                ),
                const SizedBox(height: 16),
                if (widget.type == EntityType.subject) ...[
                  TextFormField(
                    controller: _abbrController,
                    decoration: const InputDecoration(
                      labelText: 'Subject Abbreviation',
                      helperText: 'Auto-generates from name',
                    ),
                    inputFormatters: [UpperCaseTextFormatter()],
                    validator: (v) => v!.isEmpty ? 'Enter abbreviation' : null,
                  ),
                  const SizedBox(height: 16),
                ],
              ],
              if (widget.type == EntityType.teacher) ...[
                TextFormField(
                  controller: _extra1Controller,
                  decoration: const InputDecoration(labelText: 'Email (Optional)'),
                ),
              ],


              if (widget.type == EntityType.room) ...[
                TextFormField(
                  controller: _extra1Controller,
                  decoration: const InputDecoration(labelText: 'Capacity'),
                  keyboardType: TextInputType.number,
                  validator: (v) => v!.isEmpty ? 'Enter capacity' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedType,
                  items: const [
                    DropdownMenuItem(value: 'theory', child: Text('Theory Room')),
                    DropdownMenuItem(value: 'lab', child: Text('Laboratory')),
                  ],
                  onChanged: (v) => setState(() => _selectedType = v!),
                  decoration: const InputDecoration(labelText: 'Room Type'),
                ),
              ],
              if (widget.type == EntityType.subject) ...[

                DropdownButtonFormField<String>(
                  initialValue: _selectedType,
                  items: const [
                    DropdownMenuItem(value: 'theory', child: Text('Theory Subject')),
                    DropdownMenuItem(value: 'lab', child: Text('Practical / Lab')),
                  ],
                  onChanged: (v) => setState(() => _selectedType = v!),
                  decoration: const InputDecoration(labelText: 'Subject Type'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _extra2Controller,
                  decoration: const InputDecoration(labelText: 'Hours per Week'),
                  keyboardType: TextInputType.number,
                  validator: (v) => v!.isEmpty ? 'Enter hours' : null,
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
    _codeController.dispose();
    _abbrController.dispose();

    _extra1Controller.dispose();
    _extra2Controller.dispose();
    super.dispose();
  }
}
