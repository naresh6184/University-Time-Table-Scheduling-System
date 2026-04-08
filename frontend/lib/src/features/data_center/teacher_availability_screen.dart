import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:collection/collection.dart';
import 'package:university_timetable_frontend/src/features/data_center/teacher_availability_provider.dart';
import 'package:university_timetable_frontend/src/features/slot_config/slot_config_provider.dart';
import 'package:university_timetable_frontend/src/features/sessions/session_provider.dart';
import 'package:university_timetable_frontend/src/features/sessions/widgets/sync_banner.dart';

class TeacherAvailabilityScreen extends ConsumerStatefulWidget {
  final int teacherId;
  final String teacherName;

  const TeacherAvailabilityScreen({
    super.key,
    required this.teacherId,
    required this.teacherName,
  });

  @override
  ConsumerState<TeacherAvailabilityScreen> createState() => _TeacherAvailabilityScreenState();
}

class _TeacherAvailabilityScreenState extends ConsumerState<TeacherAvailabilityScreen> {
  // Map of slot_id -> preference rank. If slot_id missing, it's unavailable.
  final Map<int, int> _availability = {}; 
  bool _isSaving = false;
  bool _isUnconfigured = false;
  final ScrollController _horizontalScrollController = ScrollController();

  late TeacherAvailabilityParams _params;

  @override
  void initState() {
    super.initState();
    _params = TeacherAvailabilityParams(widget.teacherId, -1);
  }

  void _initializeFromConfig(TeacherAvailabilityConfig config, List<dynamic> allSlots, {bool force = false}) {
    if (_availability.isNotEmpty && !force) return;
    
    // Clear before initializing if forced (e.g., after save refresh)
    if (force) _availability.clear();
    setState(() {
      _isUnconfigured = allSlots.any((s) => (s['slot_id'] as int? ?? 0) <= 0);
      
      if (allSlots.isNotEmpty && config.entries.isEmpty) {
        // First-time load: default all to available
        for (final slot in allSlots) {
          final sId = slot['slot_id'] as int?;
          final pNum = slot['period'] as int? ?? 0;
          if (sId != null && pNum != 5) { // Skip lunch
            _availability[sId] = 5;
          }
        }
      } else {
        // Respect saved configuration
        for (final entry in config.entries) {
          int? targetSlotId = entry['slot_id'] as int?;
          
          // --- GLOBAL MAPPING FIX ---
          // If slot_id is missing (Global Mode), map via (day, period_number)
          if (targetSlotId == null || targetSlotId == 0) {
             final eDay = entry['day'] as String?;
             final ePeriod = entry['period'] as int?;
             
             if (eDay != null && ePeriod != null) {
                final matchingSlot = allSlots.firstWhereOrNull(
                   (s) => s['day'] == eDay && s['period'] == ePeriod
                );
                if (matchingSlot != null) {
                   targetSlotId = matchingSlot['slot_id'] as int?;
                }
             }
          }

          if (targetSlotId != null) {
             _availability[targetSlotId] = entry['preference_rank'] as int? ?? 5;
          }
        }
      }
    });
  }

  void _saveAvailability() async {
    setState(() => _isSaving = true);
    final sessionId = ref.read(activeSessionProvider)?.sessionId ?? -1;

    try {
      final List<Map<String, dynamic>> entries = _availability.entries.map((e) {
         return {'slot_id': e.key, 'preference_rank': e.value};
      }).toList();

      final slotState = ref.read(slotConfigProvider);
      List<Map<String, dynamic>>? allSlots;
      if (slotState.hasValue) {
          allSlots = List<Map<String, dynamic>>.from(slotState.value!.slots);
      }

      await ref.read(saveAvailabilityProvider).save(
        widget.teacherId, 
        entries, 
        sessionId: sessionId,
        allSlots: allSlots,
      );
      
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Availability saved successfully!'))
         );
      }
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // Set all current slots in grid to available with rank 5
  void _setAllAvailable(List<dynamic> currentSlots) {
     setState(() {
        _availability.clear();
        for (final slot in currentSlots) {
           final sId = slot['slot_id'] as int?;
           if (sId != null) {
             _availability[sId] = 5;
           }
        }
     });
  }

  void _clearAll(List<dynamic> currentSlots) {
     setState(() {
        _availability.clear();
     });
  }

  void _quickSetupSlots() async {
    final notifier = ref.read(slotConfigProvider.notifier);
    final result = await notifier.configureSlots({
      "start_hour": 9,
      "end_hour": 18,
      "working_days": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"],
      "blocked_slots": []
    });

      if (result != null && mounted) {
        // No need for a separate snackbar if it's silent
      }
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final sessionId = ref.watch(activeSessionProvider)?.sessionId ?? -1;
    final isGlobalMode = sessionId == -1;
    
    // Update params if sessionId changed
    if (_params.sessionId != sessionId) {
        _params = TeacherAvailabilityParams(widget.teacherId, sessionId);
    }

    final availabilityState = ref.watch(teacherAvailabilityProvider(_params));
    final slotState = ref.watch(slotConfigProvider);

    // Sync only when data is fully available and NOT currently initialized
    ref.listen<AsyncValue<TeacherAvailabilityConfig>>(teacherAvailabilityProvider(_params), (prev, next) {
      if (next is AsyncData<TeacherAvailabilityConfig> && slotState is AsyncData) {
         _initializeFromConfig(next.value, slotState.value!.slots, force: true);
      }
    });

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text('${widget.teacherName} - Availability', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        actions: [
          ElevatedButton.icon(
             onPressed: _isSaving ? null : _saveAvailability,
             icon: _isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save),
             label: const Text('Save Availability'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: slotState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (slotConfig) {
           if (slotConfig.slots.isEmpty) {
              return Center(child: Text('Please configure university slots first.', style: GoogleFonts.inter(fontSize: 18)));
           }

           if (availabilityState.isLoading) {
              return const Center(child: CircularProgressIndicator());
           }
           
           // If _availability is empty on first load (manual refresh or initial entry),
           // ensure it is initialized.
           if (_availability.isEmpty && availabilityState.hasValue) {
               final config = availabilityState.value!;
               if (config.entries.isEmpty) {
                   // This is where the magic happens for "First Time" teachers
                   Future.microtask(() => _initializeFromConfig(config, slotConfig.slots));
               } else {
                   // This handles the case where state was lost but DB has data
                   Future.microtask(() => _initializeFromConfig(config, slotConfig.slots));
               }
           }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                   const SyncBanner(),
                   if (isGlobalMode) ...[
                     _buildGlobalModeWarning(colorScheme),
                     const SizedBox(height: 24),
                   ],
                   if (_isUnconfigured) ...[
                     _buildUnconfiguredWarning(colorScheme),
                     const SizedBox(height: 24),
                   ],
                   _buildAvailabilityHeader(theme, colorScheme, slotConfig.slots),
                   const SizedBox(height: 32),
                   _buildGrid(theme, colorScheme, slotConfig),
                ],
              ),
            );
        }
      )
    );
  }

   Widget _buildAvailabilityHeader(ThemeData theme, ColorScheme colorScheme, List<dynamic> currentSlots) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
           color: colorScheme.surfaceContainer,
           borderRadius: BorderRadius.circular(24),
           border: Border.all(color: colorScheme.outlineVariant.withAlpha(50)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                  Text('Availability Management', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                       TextButton.icon(
                         icon: const Icon(Icons.check_circle_rounded),
                         label: const Text('Set All Available'),
                         onPressed: () => _setAllAvailable(currentSlots),
                       ),
                       TextButton.icon(
                         icon: const Icon(Icons.cancel_rounded, color: Colors.orange),
                         label: const Text('Clear All'),
                         onPressed: () => _clearAll(currentSlots),
                       ),
                    ],
                  )
               ],
             ),
             const SizedBox(height: 16),
             _buildLegend(colorScheme),
             const SizedBox(height: 16),
             Text('Note: Click a slot to toggle state. Preference rank (1-5) only applies to Available slots.', 
                  style: GoogleFonts.inter(fontSize: 12, color: colorScheme.onSurfaceVariant.withAlpha(180))),
          ],
        )
      ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.05);
   }

  Widget _buildGlobalModeWarning(ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 32),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline.withAlpha(50)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: colorScheme.primary, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Global Availability Mode (Preview)',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 4),
                Text(
                  'Teacher availability is session-specific. Please open a Workspace Session to customize this teacher\'s availability for that specific term.',
                  style: GoogleFonts.inter(fontSize: 14, color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildGrid(ThemeData theme, ColorScheme colorScheme, SlotConfig config) {
     final workingDays = config.workingDays;
     if (workingDays.isEmpty) return const SizedBox.shrink();

     final startHour = config.startHour;
     final endHour = config.endHour;
     final totalPeriods = endHour - startHour;

     // Group slots by Day -> Period
     final slotMap = <String, Map<int, dynamic>>{};
     for (final s in config.slots) {
         slotMap.putIfAbsent(s['day'] as String, () => {})[s['period'] as int] = s;
     }

     return Container(
       padding: const EdgeInsets.all(24),
       decoration: BoxDecoration(
          color: colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(24),
       ),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
            Text('Timetable Slots Configuration', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Scrollbar(
               controller: _horizontalScrollController,
               thumbVisibility: true,
               child: SingleChildScrollView(
                  controller: _horizontalScrollController,
                  scrollDirection: Axis.horizontal,
                  child: Table(
                     defaultColumnWidth: const FixedColumnWidth(110),
                     border: TableBorder.all(color: colorScheme.outlineVariant.withAlpha(50)),
                     children: [
                        // Header Row
                        TableRow(
                           decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest),
                           children: [
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text('Day', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                              ),
                              for (int p = 0; p < totalPeriods; p++)
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Text((p + 1) == 5 ? 'LUNCH' : '${startHour + p}:00 - ${startHour + p + 1}:00', 
                                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center),
                                )
                           ]
                        ),
                        // Data Rows
                        for (final day in workingDays)
                          TableRow(
                            children: [
                               Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Text(day, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                               ),
                               for (int p = 0; p < totalPeriods; p++)
                                 _buildSlotCell(day, p + 1, slotMap[day]?[p+1], colorScheme),
                            ]
                          )
                     ],
                  ),
               ),
            ),
         ]
       ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.05);
  }

   Widget _buildLegend(ColorScheme colorScheme) {
      return Wrap(
        spacing: 24,
        runSpacing: 12,
        children: [
            _LegendItem(color: colorScheme.primaryContainer, label: 'Available', icon: Icons.check_circle_outline_rounded, iconColor: colorScheme.primary),
            _LegendItem(color: Colors.red.withAlpha(40), label: 'Unavailable', icon: Icons.person_off_rounded, iconColor: Colors.red),
            _LegendItem(color: colorScheme.errorContainer.withAlpha(100), label: 'Blocked', icon: Icons.block_rounded, iconColor: colorScheme.error),
            _LegendItem(color: Colors.orange.withAlpha(50), label: 'Lunch', icon: Icons.restaurant_rounded, iconColor: Colors.orange),
        ],
      );
   }

   Widget _buildSlotCell(String day, int expectedPeriod, dynamic slotObj, ColorScheme colorScheme) {
      final isBlocked = slotObj == null || (slotObj['status'] as int?) == -1;
      if (isBlocked) {
         final isLunch = expectedPeriod == 5;

           return Container(
              height: 80,
              decoration: BoxDecoration(
                color: isLunch ? Colors.orange.withAlpha(50) : colorScheme.errorContainer.withAlpha(100),
              ),
              child: Center(
                child: isLunch 
                  ? Column(
                     mainAxisAlignment: MainAxisAlignment.center,
                     children: [
                       Icon(Icons.restaurant_rounded, size: 16, color: Colors.orange),
                       const SizedBox(height: 4),
                       Text('LUNCH', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange, letterSpacing: 1.2)),
                     ],
                   )
                  : Icon(Icons.block_rounded, size: 24, color: colorScheme.error.withAlpha(180)),
              ),
           );
      }

     final slotId = slotObj['slot_id'] as int;
     final isLunch = expectedPeriod == 5;

     // Enforce blocking for Lunch even if it exists in DB
     if (isLunch) {
         return _buildSlotCell(day, expectedPeriod, null, colorScheme);
     }

     final isAvailable = _availability.containsKey(slotId);
     final prefRank = isAvailable ? _availability[slotId]! : 5;

     return InkWell(
        onTap: () {
           setState(() {
              if (isAvailable) {
                 _availability.remove(slotId); // Make unavailable
              } else {
                 _availability[slotId] = 5; // Make available with neutral rank
              }
           });
        },
        child: Container(
           height: 80,
           decoration: BoxDecoration(
              color: isAvailable ? colorScheme.primaryContainer.withAlpha(120) : Colors.red.withAlpha(40),
           ),
           child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                 if (isAvailable)
                   DropdownButton<int>(
                     value: prefRank,
                     isDense: true,
                     underline: const SizedBox.shrink(),
                     items: const [
                        DropdownMenuItem(value: 1, child: Text('⭐ 1 Best', style: TextStyle(fontSize: 11))),
                        DropdownMenuItem(value: 2, child: Text('⭐ 2', style: TextStyle(fontSize: 11))),
                        DropdownMenuItem(value: 3, child: Text('⭐ 3', style: TextStyle(fontSize: 11))),
                        DropdownMenuItem(value: 4, child: Text('⭐ 4', style: TextStyle(fontSize: 11))),
                        DropdownMenuItem(value: 5, child: Text('⭐ 5 Neut', style: TextStyle(fontSize: 11))),
                     ],
                     onChanged: (v) {
                        if (v != null) {
                           setState(() {
                              _availability[slotId] = v;
                           });
                        }
                     },
                   )
                 else
                   const Icon(Icons.person_off_rounded, color: Colors.red, size: 24),
              ],
           ),
        ),
     );
  }
  Widget _buildUnconfiguredWarning(ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 32),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withAlpha(100),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.error.withAlpha(100)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: colorScheme.error, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'University Slots Not Configured',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: colorScheme.error),
                ),
                Text(
                  'Please configure the university timetable slots in the \'Slot Config\' section before setting teacher availability. The current grid is only a template and cannot be saved.',
                  style: GoogleFonts.inter(fontSize: 14, color: colorScheme.onErrorContainer),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton(
             onPressed: _quickSetupSlots,
             style: ElevatedButton.styleFrom(
               backgroundColor: colorScheme.error,
               foregroundColor: colorScheme.onError,
             ),
             child: const Text('Setup Defaults Now'),
          ),
        ],
      ),
    ).animate().shake(duration: 500.ms);
  }
}
class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final IconData icon;
  final Color iconColor;

  const _LegendItem({required this.color, required this.label, required this.icon, required this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 12),
        Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
