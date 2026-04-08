import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:flutter_animate/flutter_animate.dart';
import 'package:university_timetable_frontend/src/features/slot_config/slot_config_provider.dart';
import 'package:university_timetable_frontend/src/features/sessions/widgets/sync_banner.dart';

class SlotConfigScreen extends ConsumerStatefulWidget {
  const SlotConfigScreen({super.key});

  @override
  ConsumerState<SlotConfigScreen> createState() => _SlotConfigScreenState();
}

class _SlotConfigScreenState extends ConsumerState<SlotConfigScreen> {
  static const List<String> kAllDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  int _startHour = 9;
  int _endHour = 18;
  Set<String> _workingDays = {'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'};
  final Set<String> _blockedSlots = {}; // Format: "Day:Period"
  final ScrollController _horizontalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // After build, load initial config from provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(slotConfigProvider);
      if (state.hasValue && state.value != null) {
        _initializeFromConfig(state.value!);
      }
    });
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    super.dispose();
  }

  void _initializeFromConfig(SlotConfig config) {
    if (!mounted) return;
    setState(() {
      _startHour = config.startHour;
      _endHour = config.endHour;
      _workingDays = config.workingDays.toSet();

      // Find missing (blocked) slots within the working range
      _blockedSlots.clear();
      final currSlots = config.slots;
      
      for (final day in _workingDays) {
        int expectedPeriod = 1;
        for (int h = _startHour; h < _endHour; h++) {
          final matchingSlots = currSlots.where((s) => s['day'] == day && s['period'] == expectedPeriod).toList();
          final isBlocked = matchingSlots.isEmpty || matchingSlots.first['status'] == -1 || matchingSlots.first['status'] == 0;
          if (isBlocked) {
            _blockedSlots.add('$day:$expectedPeriod');
          }
          expectedPeriod++;
        }
      }
    });
  }

  // Lunch time (1 PM - 2 PM) is automatically blocked in the UI and save logic

  void _saveConfig() async {
    final List<Map<String, dynamic>> blocked = [];
    for (final day in _workingDays) {
       int period = 1;
       for (int h = _startHour; h < _endHour; h++) {
          if (h == 13 || _blockedSlots.contains('$day:$period')) {
              blocked.add({'day': day, 'period': period});
          }
          period++;
       }
    }

    final config = {
      'start_hour': _startHour,
      'end_hour': _endHour,
      'working_days': _workingDays.toList(),
      'blocked_slots': blocked
    };

    final result = await ref.read(slotConfigProvider.notifier).configureSlots(config);
    if (mounted && result != null && result['message'] != null) {
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text(result['message']))
       );
    }

  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final state = ref.watch(slotConfigProvider);

    // Watch for provider updates to keep local editing state in sync with server
    ref.listen<AsyncValue<SlotConfig>>(slotConfigProvider, (prev, next) {
      if (next.hasValue && next.value != null) {
         _initializeFromConfig(next.value!);
      }
    });

    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (config) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SyncBanner(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Schedule Options (Slots)', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold)),
                  ElevatedButton.icon(
                    onPressed: state.isLoading ? null : _saveConfig,
                    icon: const Icon(Icons.save),
                    label: const Text('Save Configuration'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildSettingsPanel(theme, colorScheme),
              const SizedBox(height: 32),
              _buildGrid(theme, colorScheme),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSettingsPanel(ThemeData theme, ColorScheme colorScheme) {
    return Container(
       padding: const EdgeInsets.all(22),
       decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outlineVariant.withAlpha(80)),
       ),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
            Text('Working Hours', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                 const Text('Start Time: '),
                 const SizedBox(width: 8),
                 DropdownButton<int>(
                   value: _startHour,
                   items: List.generate(13, (i) => i + 6).map((h) => DropdownMenuItem(value: h, child: Text('$h:00'))).toList(),
                   onChanged: (v) {
                     if (v != null && v < _endHour) setState(() => _startHour = v);
                   },
                 ),
                 const SizedBox(width: 32),
                 const Text('End Time: '),
                 const SizedBox(width: 8),
                 DropdownButton<int>(
                   value: _endHour,
                   items: List.generate(13, (i) => i + 10).map((h) => DropdownMenuItem(value: h, child: Text('$h:00'))).toList(),
                   onChanged: (v) {
                     if (v != null && v > _startHour) setState(() => _endHour = v);
                   },
                 ),
                 const SizedBox(width: 32),
                 Chip(
                    avatar: const Icon(Icons.restaurant, size: 16),
                    label: const Text('13:00 - 14:00 is Lunch'),
                 )
              ],
            ),
            const SizedBox(height: 32),
            Text('Working Days', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kAllDays.map((day) {
                 final isSelected = _workingDays.contains(day);
                 return FilterChip(
                    label: Text(day),
                    selected: isSelected,
                    onSelected: (selected) {
                       setState(() {
                          if (selected) {
                             _workingDays.add(day);
                          } else {
                             _workingDays.remove(day);
                          }
                       });
                    },
                 );
              }).toList(),
            ),
         ]
       ),
    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.05);
  }

  Widget _buildGrid(ThemeData theme, ColorScheme colorScheme) {
     if (_workingDays.isEmpty) return const SizedBox.shrink();

     final sortedDays = kAllDays.where((d) => _workingDays.contains(d)).toList();
     final totalPeriods = _endHour - _startHour;

     return Container(
       padding: const EdgeInsets.all(22),
       decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outlineVariant.withAlpha(80)),
       ),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
            Text('Slot Grid Configuration', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Click on a time slot to block or unblock it. Blocked slots will not be used for scheduling.', 
                 style: GoogleFonts.inter(color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 24),
            Scrollbar(
               controller: _horizontalScrollController,
               thumbVisibility: true,
               child: SingleChildScrollView(
                  controller: _horizontalScrollController,
                  scrollDirection: Axis.horizontal,
                  child: Table(
                     defaultColumnWidth: const FixedColumnWidth(100),
                     border: TableBorder.all(color: colorScheme.outlineVariant.withAlpha(50), width: 1),
                     children: [
                        // Header Row
                        TableRow(
                           decoration: BoxDecoration(color: colorScheme.surfaceContainerLowest),
                           children: [
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text('Day', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                              ),
                              for (int p = 0; p < totalPeriods; p++)
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Text('${_startHour + p}:00 - ${_startHour + p + 1}:00', 
                                              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center),
                                )
                           ]
                        ),
                        // Data Rows
                        for (final day in sortedDays)
                          TableRow(
                            children: [
                               Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Text(day, style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                               ),
                               for (int p = 0; p < totalPeriods; p++)
                                 _buildSlotCell(day, p + 1, _startHour + p, colorScheme),
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

  Widget _buildSlotCell(String day, int period, int hour, ColorScheme colorScheme) {
     final key = '$day:$period';
     final isLunch = hour == 13; // 13:00 is 1 PM
     final isBlocked = _blockedSlots.contains(key) || isLunch;

     return InkWell(
        onTap: isLunch ? null : () {
           setState(() {
              if (_blockedSlots.contains(key)) {
                 _blockedSlots.remove(key);
              } else {
                 _blockedSlots.add(key);
              }
           });
        },
        child: Container(
           height: 60,
           decoration: BoxDecoration(
              color: isLunch 
                  ? Colors.orange.withAlpha(50) 
                  : (isBlocked ? colorScheme.errorContainer.withAlpha(100) : colorScheme.primaryContainer),
           ),
           child: Center(
              child: isLunch 
                 ? Text('LUNCH', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.orange))
                 : Icon(
                     isBlocked ? Icons.block : Icons.check_circle_outline,
                     color: isBlocked ? colorScheme.error : colorScheme.primary,
                     size: 20,
                   )
           ),
        ),
     );
  }
}
