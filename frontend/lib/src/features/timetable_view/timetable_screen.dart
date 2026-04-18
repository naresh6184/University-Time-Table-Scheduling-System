import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:university_timetable_frontend/src/features/timetable_view/timetable_grid_provider.dart';
import 'package:university_timetable_frontend/src/features/timetable_generator/generator_provider.dart';
import 'package:university_timetable_frontend/src/services/api_service.dart';
import 'package:university_timetable_frontend/src/models/grid_models.dart';
import 'package:university_timetable_frontend/src/features/sessions/session_provider.dart';
import 'package:university_timetable_frontend/src/features/sessions/session_entities_provider.dart';

class TimetableScreen extends ConsumerStatefulWidget {
  final int? versionId;
  const TimetableScreen({super.key, this.versionId});

  @override
  ConsumerState<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends ConsumerState<TimetableScreen> {
  TimetableEntityType _selectedType = TimetableEntityType.group;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(selectedVersionIdProvider.notifier).set(widget.versionId);
    });
  }

  @override
  void didUpdateWidget(covariant TimetableScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.versionId != widget.versionId) {
      Future.microtask(() {
        ref.read(selectedVersionIdProvider.notifier).set(widget.versionId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final gridState = ref.watch(gridDataProvider);
    final selectedEntity = ref.watch(selectedTableEntityProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: Row(
            children: [
              Text('Timetable Explorer', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold)),
              const Spacer(),
              const _VersionHeaderCard(),
              const SizedBox(width: 8),
              // Only show export when timetables exist
              if (ref.watch(versionsProvider).value?.isNotEmpty == true)
                IconButton(
                  icon: const Icon(Icons.download_rounded),
                  tooltip: 'Export Timetables',
                  onPressed: () => _showExportOptionsDialog(context, ref, _selectedType, selectedEntity),
                ),
            ],
          ),
        ),
        Expanded(
          child: ref.watch(versionsProvider).when(
            data: (versions) {
              if (versions.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_month_rounded, size: 64, color: colorScheme.onSurfaceVariant.withAlpha(100)),
                      const SizedBox(height: 16),
                      Text(
                        'No Timetables Generated',
                        style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'You need to generate a timetable on the Dashboard before exploring it here.',
                        style: GoogleFonts.inter(fontSize: 16, color: colorScheme.onSurfaceVariant.withAlpha(150)),
                      ),
                    ],
                  ),
                );
              }

              // Auto-select the active version if nothing is selected
              final currentSelection = ref.read(selectedVersionIdProvider);
              if (currentSelection == null) {
                final activeVersion = versions.where((v) => v.isActive).firstOrNull;
                if (activeVersion != null) {
                  Future.microtask(() => ref.read(selectedVersionIdProvider.notifier).set(activeVersion.versionId));
                }
              }
              final selectedVersionId = ref.watch(selectedVersionIdProvider);

              return Row(
                children: [
                  // Sidebar Filters
                  _EntitySidebar(
                    selectedType: _selectedType,
                    onTypeChanged: (type) => setState(() => _selectedType = type),
                    onEntitySelected: (entity) => ref.read(selectedTableEntityProvider.notifier).set(entity),
                  ),
        
                  // Main Grid Area
                  Expanded(
                    child: Container(
                      color: colorScheme.surface,
                      child: selectedVersionId == null
                          ? const _NoVersionSelectedState()
                          : (selectedEntity == null
                              ? _EmptyState(type: _selectedType)
                              : gridState.when(
                                  data: (grid) => grid == null ? const Center(child: Text('No grid data found.')) : _TimetableGridWithConflicts(grid: grid),
                                  loading: () => const Center(child: CircularProgressIndicator()),
                                  error: (e, s) => Center(child: Text('Error loading timetable: $e')),
                                )),
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(child: Text('Error checking versions: $e')),
          ),
        ),
      ],
    );

  }

  void _showExportOptionsDialog(BuildContext context, WidgetRef ref, TimetableEntityType type, TimetableEntity? currentEntity) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Export ${type.name.toUpperCase()}s', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (currentEntity != null)
                ListTile(
                  leading: const Icon(Icons.file_download_rounded),
                  title: Text('Export Timetable of current ${type.name}', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  subtitle: Text('Download only the selected timetable.', style: GoogleFonts.inter(fontSize: 12)),
                  onTap: () {
                    Navigator.pop(context);
                    final api = ref.read(apiServiceProvider);
                    final vId = ref.read(selectedVersionIdProvider);
                    final q = vId != null ? "?version_id=$vId" : "";
                    final url = "${api.baseUrl}/timetable/${currentEntity.type.name}/${currentEntity.id}/export$q";
                    launchUrl(Uri.parse(url));
                  },
                ),
              ListTile(
                leading: const Icon(Icons.library_books_rounded),
                title: Text('Export Timetable of all ${type.name}s', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                subtitle: Text('Download all ${type.name}s in the current session.', style: GoogleFonts.inter(fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  _showExportFormatDialog(context, ref, type);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _showExportFormatDialog(BuildContext context, WidgetRef ref, TimetableEntityType type) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Formatting: All ${type.name.toUpperCase()}s', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('How would you like the timetables formatted in the Excel file?', style: GoogleFonts.inter()),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.tab_rounded),
                title: Text('Multiple Tabs', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                subtitle: Text('Each timetable gets its own bottom tab.', style: GoogleFonts.inter(fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  _triggerExportAll(ref, type, 'tabs');
                },
              ),
              ListTile(
                leading: const Icon(Icons.view_day_rounded),
                title: Text('Single Sheet', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                subtitle: Text('Stacked vertically on one continuous page.', style: GoogleFonts.inter(fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  _triggerExportAll(ref, type, 'vertical');
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _triggerExportAll(WidgetRef ref, TimetableEntityType type, String format) {
    final api = ref.read(apiServiceProvider);
    final vId = ref.read(selectedVersionIdProvider);
    final activeSession = ref.read(activeSessionProvider);
    
    if (activeSession == null || activeSession.sessionId == -1) return;
    
    final versionParam = vId != null ? "&version_id=$vId" : "";
    final url = "${api.baseUrl}/timetable/export_all?entity_type=${type.name}&format_type=$format&session_id=${activeSession.sessionId}$versionParam";
    launchUrl(Uri.parse(url));
  }
}

class _EntitySidebar extends ConsumerWidget {
  final TimetableEntityType selectedType;
  final Function(TimetableEntityType) onTypeChanged;
  final Function(TimetableEntity) onEntitySelected;

  const _EntitySidebar({
    required this.selectedType,
    required this.onTypeChanged,
    required this.onEntitySelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(right: BorderSide(color: theme.colorScheme.outlineVariant.withAlpha(50))),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SegmentedButton<TimetableEntityType>(
              segments: const [
                ButtonSegment(value: TimetableEntityType.group, label: Icon(Icons.groups_rounded), tooltip: 'Groups'),
                ButtonSegment(value: TimetableEntityType.teacher, label: Icon(Icons.person_rounded), tooltip: 'Teachers'),
                ButtonSegment(value: TimetableEntityType.room, label: Icon(Icons.room_rounded), tooltip: 'Rooms'),
              ],
              selected: {selectedType},
              onSelectionChanged: (set) => onTypeChanged(set.first),
            ),
          ),
          const Divider(),
          Expanded(
            child: _EntitySelectionList(
              type: selectedType,
              onSelected: onEntitySelected,
            ),
          ),
        ],
      ),
    );
  }
}

class _EntitySelectionList extends ConsumerWidget {
  final TimetableEntityType type;
  final Function(TimetableEntity) onSelected;

  const _EntitySelectionList({required this.type, required this.onSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<dynamic>> providerState;
    final theme = Theme.of(context);
    final selectedEntity = ref.watch(selectedTableEntityProvider);
    final activeEntities = ref.watch(activeTimetableEntitiesProvider).value;

    switch (type) {
      case TimetableEntityType.group:
        providerState = ref.watch(sessionGroupsProvider);
        break;
      case TimetableEntityType.teacher:
        providerState = ref.watch(sessionTeachersProvider);
        break;
      case TimetableEntityType.room:
        providerState = ref.watch(sessionRoomsProvider);
        break;
    }

    return providerState.when(
      data: (list) => ListView.builder(
        itemCount: list.length,
        itemBuilder: (context, index) {
          final item = list[index];
          String name = '';
          int id = 0;

          if (type == TimetableEntityType.group) {
            name = item.name;
            id = item.groupId;
          } else if (type == TimetableEntityType.teacher) {
            name = item.name;
            id = item.teacherId;
          } else if (type == TimetableEntityType.room) {
            name = item.name;
            id = item.roomId;
          }

          final isSelected = selectedEntity?.id == id && selectedEntity?.type == type;

          bool hasTimetable = false;
          if (activeEntities != null) {
            if (type == TimetableEntityType.group) hasTimetable = activeEntities.groups.contains(id);
            if (type == TimetableEntityType.teacher) hasTimetable = activeEntities.teachers.contains(id);
            if (type == TimetableEntityType.room) hasTimetable = activeEntities.rooms.contains(id);
          }

          return ListTile(
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    name, 
                    style: GoogleFonts.inter(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (hasTimetable) ...[
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Participating in this version',
                    child: Container(
                      width: 8, 
                      height: 8, 
                      decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)
                    ),
                  ),
                ],
              ],
            ),
            selected: isSelected,
            selectedTileColor: theme.colorScheme.primaryContainer.withAlpha(50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            onTap: () => onSelected(TimetableEntity(type: type, id: id, name: name)),
            trailing: isSelected ? const Icon(Icons.chevron_right_rounded) : null,
          );
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Error: $e')),
    );
  }
}

// ---- Wrapper that shows conflict panel + grid ----
class _TimetableGridWithConflicts extends ConsumerWidget {
  final GridResponse grid;
  const _TimetableGridWithConflicts({required this.grid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conflictsAsync = ref.watch(versionConflictsProvider);
    final conflictsData = conflictsAsync.value;

    return Column(
      children: [
        // Conflict summary panel (only shows if there are conflicts)
        if (conflictsData != null && conflictsData.total > 0)
          _ConflictPanel(conflictsData: conflictsData),
        // The grid itself, with conflict data passed down
        Expanded(child: _TimetableGrid(grid: grid, conflictsData: conflictsData)),
      ],
    );
  }
}

// ---- Conflict summary panel ----
class _ConflictPanel extends ConsumerWidget {
  final VersionConflictsData conflictsData;
  const _ConflictPanel({required this.conflictsData});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeFilter = ref.watch(activeConflictFilterProvider);
    final highlightedEntries = ref.watch(highlightedEntryIdsProvider);
    final hasHighlights = highlightedEntries.isNotEmpty;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.withAlpha(15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red[400], size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${conflictsData.total} Conflict${conflictsData.total == 1 ? '' : 's'}',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red[700]),
                ),
              ),
              if (hasHighlights)
                TextButton.icon(
                  onPressed: () => ref.read(highlightedEntryIdsProvider.notifier).clear(),
                  icon: const Icon(Icons.highlight_off_rounded, size: 14),
                  label: Text('Clear Highlight', style: GoogleFonts.inter(fontSize: 11)),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.orange[700],
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              if (activeFilter != null)
                IconButton(
                  onPressed: () => ref.read(activeConflictFilterProvider.notifier).set(null),
                  icon: const Icon(Icons.clear_rounded, size: 16),
                  tooltip: 'Show all conflicts',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ...conflictsData.summary.map((item) {
                  final isActive = activeFilter == item.type;
                  final description = conflictTypeDescriptions[item.type];
                  
                  Widget chip = FilterChip(
                    label: Text(
                      '${item.type} (${item.count})',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: isActive ? Colors.white : Colors.red[700]),
                    ),
                    selected: isActive,
                    onSelected: (selected) {
                      ref.read(activeConflictFilterProvider.notifier).set(selected ? item.type : null);
                    },
                    selectedColor: Colors.red[400],
                    backgroundColor: Colors.red.withAlpha(20),
                    showCheckmark: false,
                    side: BorderSide(color: isActive ? Colors.red : Colors.red.withAlpha(60)),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                    visualDensity: VisualDensity.compact,
                  );
                  
                  if (description != null) {
                    chip = Tooltip(
                      message: description,
                      textStyle: GoogleFonts.inter(fontSize: 12, color: Colors.white),
                      decoration: BoxDecoration(
                        color: Colors.grey[850],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.all(12),
                      preferBelow: true,
                      waitDuration: const Duration(milliseconds: 300),
                      child: chip,
                    );
                  }
                  
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: chip,
                  );
                }),
                const SizedBox(width: 8),
                Text(
                  'Click on red cells for details',
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.red[300], fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class _TimetableGrid extends ConsumerWidget {
  final GridResponse grid;
  final VersionConflictsData? conflictsData;
  const _TimetableGrid({required this.grid, this.conflictsData});

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    final days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];
    final filteredDays = days.where((d) => grid.grid.containsKey(d)).toList();

    bool hasAnyEntry = false;
    for (final day in filteredDays) {
      for (final cell in grid.grid[day]!) {
        if (!cell.isEmpty) {
          hasAnyEntry = true;
          break;
        }
      }
      if (hasAnyEntry) break;
    }

    if (!hasAnyEntry) {
      final versionsState = ref.watch(versionsProvider);
      final selectedVersionId = ref.watch(selectedVersionIdProvider);

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.event_busy_rounded, size: 64, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 16),
              Text('No Schedule Generated', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                'This entity has no lectures assigned in the currently selected version.\nThe generator may have produced a partial or infeasible result.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              // Show available versions so user can try switching
              versionsState.when(
                data: (versions) {
                  if (versions.isEmpty) return const SizedBox.shrink();
                  final activeVersion = versions.where((v) => v.isActive).firstOrNull;
                  final otherVersions = versions.where((v) => v.versionId != (selectedVersionId ?? activeVersion?.versionId)).toList();

                  return Container(
                    width: 400,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withAlpha(80)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.history_rounded, size: 18, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 8),
                            Text('Available Versions (${versions.length})', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                        ),
                        const Divider(height: 20),
                        if (otherVersions.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              'No other versions to try. Generate a new timetable from the Dashboard.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500]),
                            ),
                          )
                        else
                          ...otherVersions.map((v) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.0),
                            child: ListTile(
                              dense: true,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              leading: Icon(
                                v.isActive ? Icons.check_circle_rounded : Icons.circle_outlined,
                                size: 18,
                                color: v.isActive ? Colors.green : Colors.grey,
                              ),
                              title: Text('Version v.${v.versionId}', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                              subtitle: v.isActive
                                  ? Text('Currently Active', style: GoogleFonts.inter(fontSize: 11, color: Colors.green))
                                  : null,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextButton(
                                    onPressed: () => ref.read(selectedVersionIdProvider.notifier).set(v.versionId),
                                    child: Text('Browse', style: GoogleFonts.inter(fontSize: 12)),
                                  ),
                                  if (!v.isActive)
                                    TextButton(
                                      onPressed: () => ref.read(versionsProvider.notifier).activateVersion(v.versionId),
                                      child: Text('Activate', style: GoogleFonts.inter(fontSize: 12, color: Colors.green[700])),
                                    ),
                                ],
                              ),
                            ),
                          )),
                      ],
                    ),
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      );
    }

    // Get the active conflict type filter (null = show all conflicts)
    final activeFilter = ref.watch(activeConflictFilterProvider);
    
    // Create ScrollControllers to link scrollbars to the scroll views
    final horizontalScrollController = ScrollController();
    final verticalScrollController = ScrollController();

    return LayoutBuilder(
      builder: (context, constraints) {
        // Account for ALL spacing: container padding + cell margins
        const containerPadding = 32.0; // left 16 + right 16
        const dayColumnWidth = 100.0;
        const cellMargin = 6.0; // horizontal: 3 each side
        const minCellWidth = 100.0;
        final numPeriods = grid.periods.isNotEmpty ? grid.periods.length : 1;
        final totalCellMargins = numPeriods * cellMargin;
        
        // Available space for cells after subtracting fixed elements
        final availableForCells = constraints.maxWidth - containerPadding - dayColumnWidth - totalCellMargins;
        final fittedCellWidth = availableForCells / numPeriods;
        
        // Use fitted width if it's >= minimum, otherwise use minimum and enable scroll
        final cellWidth = fittedCellWidth >= minCellWidth ? fittedCellWidth : minCellWidth;
        final totalTableWidth = dayColumnWidth + (cellWidth + cellMargin) * numPeriods + containerPadding;

        return Scrollbar(
          controller: horizontalScrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: horizontalScrollController,
            scrollDirection: Axis.horizontal,
            child: Scrollbar(
              controller: verticalScrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: verticalScrollController,
                child: Container(
                  width: totalTableWidth,
                  padding: const EdgeInsets.only(top: 12.0, left: 16.0, right: 16.0, bottom: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Period Headers
                      Row(
                        children: [
                          const SizedBox(width: dayColumnWidth),
                          ...grid.periods.map((p) => _PeriodHeader(period: p, width: cellWidth)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Day Rows
                      ...filteredDays.map((day) => _DayRow(
                            day: day,
                            cells: grid.grid[day]!,
                            periods: grid.periods,
                            cellWidth: cellWidth,
                            conflictsData: conflictsData,
                            activeFilter: activeFilter,
                          )),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PeriodHeader extends StatelessWidget {
  final PeriodMeta period;
  final double width;
  
  const _PeriodHeader({required this.period, required this.width});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: width,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Center(
        child: Column(
          children: [
            Text('P${period.period}', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12)),
            Text('${period.start}-${period.end}', style: GoogleFonts.inter(fontSize: 10, color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _DayRow extends ConsumerWidget {
  final String day;
  final List<GridCell> cells;
  final List<PeriodMeta> periods;
  final double cellWidth;
  final VersionConflictsData? conflictsData;
  final String? activeFilter;

  const _DayRow({required this.day, required this.cells, required this.periods, required this.cellWidth, this.conflictsData, this.activeFilter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final highlightedEntries = ref.watch(highlightedEntryIdsProvider);
    final Set<int> absorbedOffsets = {}; 

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant.withAlpha(50))),
      ),
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 100,
            height: 68,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 8),
            child: Text(day, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: theme.colorScheme.primary)),
          ),
          ...List.generate(periods.length, (index) {
            if (absorbedOffsets.contains(index)) return const SizedBox.shrink();
            final cell = cells.length > index ? cells[index] : GridCell();
            
            if (cell.isEmpty) {
              return _TimetableCell(
                cell: cell,
                width: cellWidth,
                slotKey: '${day}_${periods[index].period}',
                conflictsData: conflictsData,
              );
            }

            if (cell.isContinuation) {
              return _TimetableCell(
                cell: cell,
                width: cellWidth,
                slotKey: '${day}_${periods[index].period}',
                conflictsData: conflictsData,
              );
            }

            int visibleDuration = cell.duration;
            if (index + visibleDuration > periods.length) {
              visibleDuration = periods.length - index;
            }

            final Map<int, GridCell> absorbedOverlays = {};
            for (int d = 1; d < visibleDuration; d++) {
              final nextIndex = index + d;
              final nextCell = (nextIndex < cells.length) ? cells[index + d] : GridCell();
              
              // CRITICAL: Always absorb the slot's content to keep span clean
              absorbedOffsets.add(nextIndex);
              
              // CRITICAL: If the slot contains a STARTING session (not a continuation), 
              // we must render it as an overlay so it doesn't "disappear".
              if (!nextCell.isEmpty && !nextCell.isContinuation) {
                absorbedOverlays[d] = nextCell;
              }
            }

            final startPeriod = periods[index].period;
            final slotKey = '${day}_$startPeriod';
            List<SlotConflict> slotConflicts = [];
            if (conflictsData != null) {
              List<SlotConflict> raw = [];
              for (int d = 0; d < visibleDuration; d++) {
                final p = startPeriod + d;
                if (activeFilter != null) {
                  raw.addAll(conflictsData!.getConflictsAt(day, p, filterType: activeFilter));
                } else {
                  raw.addAll(conflictsData!.getConflictsAt(day, p));
                }
              }
              
              // Deduplicate so we don't show the exact same tooltip twice for a 2-hour class
              final Map<String, SlotConflict> uniqueRaw = {
                for (var c in raw) c.detail: c
              };

              // Filter to only show conflicts relevant to THIS cell's data
              slotConflicts = uniqueRaw.values.where((c) => c.isRelevantTo(
                cellRoom: cell.room,
                cellTeacher: cell.teacher,
                cellGroup: cell.group,
                cellEntryId: cell.entryId,
                cellEnrollmentId: cell.enrollmentId,
              )).toList();
            }

            final bool isHighlighted = cell.entryId != null && highlightedEntries.contains(cell.entryId);

            return _TimetableCell(
              cell: cell,
              width: cellWidth,
              visibleDuration: visibleDuration,
              absorbedOverlays: absorbedOverlays,
              slotConflicts: slotConflicts,
              slotKey: slotKey,
              isHighlighted: isHighlighted,
              conflictsData: conflictsData,
            );
          }),
        ],
      ),
    );
  }
}

class _TimetableCell extends ConsumerWidget {
  final GridCell cell;
  final double width;
  final int visibleDuration;
  final Map<int, GridCell> absorbedOverlays;
  final List<SlotConflict> slotConflicts;
  final String slotKey;
  final bool isHighlighted;
  final VersionConflictsData? conflictsData;
  
  const _TimetableCell({
    required this.cell,
    required this.width,
    this.visibleDuration = 1,
    this.absorbedOverlays = const {},
    this.slotConflicts = const [],
    required this.slotKey,
    this.isHighlighted = false,
    this.conflictsData,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final highlightedEntries = ref.watch(highlightedEntryIdsProvider);
    final bool isHighlighted = cell.entryId != null && highlightedEntries.contains(cell.entryId);
    final bool hasConflict = slotConflicts.isNotEmpty;
    final bool hasStack = cell.hasStack || absorbedOverlays.isNotEmpty;
    final int badgeCount = cell.stackedEntries.length + absorbedOverlays.length;

    // Calculate span width factoring in margins
    final targetWidth = (width * visibleDuration) + (6 * (visibleDuration - 1));

    if (cell.isEmpty) {
      return Container(
        width: targetWidth,
        height: 68,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withAlpha(40),
          ),
        ),
      );
    }

    // Color mapping based on subject string hash for consistent distinct colors
    final Color subjectBaseColor = _getSubjectColor(cell.subject ?? "");
    
    // Color logic: highlighted > conflict > normal
    Color bgColor;
    Color borderColor;
    double borderWidth;

    if (isHighlighted) {
      bgColor = Colors.amber.withAlpha(50);
      borderColor = Colors.orange;
      borderWidth = 3.0;
    } else if (hasConflict) {
      bgColor = Colors.red.withAlpha(30);
      borderColor = Colors.red;
      borderWidth = 2.5;
    } else {
      bgColor = subjectBaseColor.withAlpha(35);
      borderColor = subjectBaseColor.withAlpha(150);
      borderWidth = 1.5;
    }

    final currentEntity = ref.watch(selectedTableEntityProvider);
    final bool showGroup = cell.group != null && currentEntity?.type != TimetableEntityType.group;
    final bool showTeacher = cell.teacher != null && currentEntity?.type != TimetableEntityType.teacher;
    final bool showRoom = cell.room != null && currentEntity?.type != TimetableEntityType.room;

    // --- SINGLE cell content with optional stacked indicator ---
    Widget cellContentWrapper = SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  cell.subject!,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 10.5,
                    color: isHighlighted ? Colors.orange[900] : (hasConflict ? Colors.red[900] : theme.colorScheme.onSurface),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (hasStack)
                Container(
                  margin: const EdgeInsets.only(left: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(color: Colors.white.withAlpha(200), borderRadius: BorderRadius.circular(4)),
                  child: Text('+$badgeCount', style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.red[800])),
                ),
            ],
          ),
          const SizedBox(height: 1),
          if (showGroup)
            Row(
              children: [
                Icon(Icons.groups_rounded, size: 8, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 2),
                Expanded(child: Text(cell.group!, style: GoogleFonts.inter(fontSize: 8.5, height: 1.1), overflow: TextOverflow.ellipsis)),
              ],
            ),
          if (showTeacher)
            Row(
              children: [
                Icon(Icons.person_rounded, size: 8, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 2),
                Expanded(child: Text(cell.teacher!, style: GoogleFonts.inter(fontSize: 8.5, height: 1.1), overflow: TextOverflow.ellipsis)),
              ],
            ),
          if (showRoom)
            Row(
              children: [
                Icon(Icons.room_rounded, size: 8, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 2),
                Expanded(child: Text(cell.room!, style: GoogleFonts.inter(fontSize: 8.5, height: 1.1), overflow: TextOverflow.ellipsis)),
              ],
            ),
        ],
      ),
    );

    // Check if this cell is part of an overlap where we are "on top" of another bar
    final GridCell? underlayCell = cell.stackedEntries.where((e) => e.isContinuation).firstOrNull;
    final Color? underlayColor = underlayCell != null ? _getSubjectColor(underlayCell.subject!) : null;

    Widget cellWidget = Container(
      width: targetWidth,
      height: 68,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: underlayColor?.withAlpha(40) ?? Colors.transparent,
        // No border radius if we are an underlay continuation to look continuous
        borderRadius: underlayCell != null ? null : BorderRadius.circular(8),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // The main content/background bar (the spanning session)
          Positioned.fill(
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(underlayCell != null ? 6 : 8),
                border: Border.all(color: borderColor.withAlpha(underlayCell != null ? 200 : 255), width: borderWidth),
                boxShadow: [
                  if (isHighlighted)
                    BoxShadow(color: Colors.amber.withAlpha(60), blurRadius: 12, spreadRadius: 3)
                  else if (hasConflict)
                    BoxShadow(color: Colors.red.withAlpha(50), blurRadius: 10, spreadRadius: 2)
                  else
                    BoxShadow(color: subjectBaseColor.withAlpha(underlayCell != null ? 30 : 15), blurRadius: 4, offset: const Offset(0, 2)),
                ],
              ),
              child: cellContentWrapper,
            ),
          ),

          // Render any absorbed overlays as 'Squares inside the Rectangle'
          ...absorbedOverlays.entries.map((entry) {
            final offsetIndex = entry.key;
            final overlayCell = entry.value;
            // Calculate horizontal offset: index * (cellWidth + margin)
            // margin is 3px left and 3px right = 6px total
            final xOffset = offsetIndex * (width + 6);

            return Positioned(
              left: xOffset + 6,
              top: 5,
              bottom: 5,
              width: width - 6,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 6, spreadRadius: 1),
                  ],
                ),
                child: _TimetableCell(
                  cell: overlayCell,
                  width: width - 6,
                  slotKey: slotKey,
                  conflictsData: conflictsData,
                  // Ensure the overlay card is solid and has its own accurate conflict status
                  slotConflicts: conflictsData?.getConflictsAt(
                    slotKey.split('_')[0],
                    int.tryParse(slotKey.split('_')[1])! + offsetIndex
                  ) ?? [],
                ),
              ),
            );
          }),
          
          // CONFLICT ICON (Top Right)
          if (hasConflict)
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () {
                  final selectedType = ref.read(activeConflictFilterProvider);
                  final dialogConflicts = selectedType == null 
                      ? slotConflicts 
                      : slotConflicts.where((c) => c.type == selectedType).toList();
                  if (dialogConflicts.isNotEmpty) {
                    _showConflictDetailDialog(context, dialogConflicts, cell);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.red[600],
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withAlpha(50), blurRadius: 4, offset: const Offset(0, 1)),
                    ],
                  ),
                  child: const Icon(Icons.priority_high_rounded, size: 12, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );

    // Wrap with click handler for conflict interaction
    if (hasConflict || isHighlighted) {
      final selectedType = ref.watch(activeConflictFilterProvider);
      final gridState = ref.watch(gridDataProvider);
      
      cellWidget = MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () {
            if (conflictsData != null) {
              final selectedType = ref.read(activeConflictFilterProvider);
              
              // NEW: Filter conflicts to only those affecting this specific cell
              // This prevents G4 from being highlighted when you click G5's availability conflict.
              final cellSpecificConflicts = slotConflicts.where((c) => 
                (cell.enrollmentId != null && c.enrollmentIds.contains(cell.enrollmentId)) || 
                (cell.entryId != null && c.entryIds.contains(cell.entryId))
              ).toList();

              // Toggle highlight on related slots using ONLY cell-relevant conflicts
              final related = conflictsData!.getRelatedConflictSlots(
                cellSpecificConflicts.isEmpty ? slotConflicts : cellSpecificConflicts, 
                slotKey, 
                gridState.value, 
                typeFilter: selectedType
              );
              if (cell.entryId != null) {
                ref.read(highlightedEntryIdsProvider.notifier).toggle(cell.entryId!, related);
              }
            }
          },
          child: cellWidget,
        ),
      );
    }

    return cellWidget.animate().scale(duration: 400.ms, curve: Curves.easeOutBack).fadeIn();
  }

  Color _getSubjectColor(String subject) {
    if (subject.isEmpty) return Colors.grey;
    return Colors.primaries[subject.hashCode % Colors.primaries.length];
  }

  void _showConflictDetailDialog(BuildContext context, List<SlotConflict> conflicts, GridCell cell) {
    // Detect if any conflict detail mentions a multi-period class extending into
    // this slot (the backend embeds "starting P\d+" in the detail string for
    // continuation-slot overlaps).
    final bool hasMultiPeriodNote = conflicts.any((c) => c.detail.contains('starting P'));

    showDialog(
      context: context,
      builder: (ctx) {
        final colorScheme = Theme.of(context).colorScheme;
        
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Container(
            width: 500,
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(color: Colors.black.withAlpha(40), blurRadius: 24, spreadRadius: 4),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 24, 16, 16),
                  decoration: BoxDecoration(
                    color: Colors.red.withAlpha(15),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.red[100], shape: BoxShape.circle),
                        child: Icon(Icons.warning_amber_rounded, color: Colors.red[700], size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Conflict Analysis',
                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.red[900]),
                            ),
                            Text(
                              '${conflicts.length} overlapping issue${conflicts.length == 1 ? '' : 's'} detected',
                              style: GoogleFonts.inter(fontSize: 13, color: Colors.red[700], fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
                
                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (hasMultiPeriodNote)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: _buildInfoNotice(
                              'Multi-period session overlap',
                              'These conflicts involve sessions that started at an earlier period. The overlap occurs because they extend into this current time slot.'
                            ),
                          ),

                        ...conflicts.map((c) => _buildConflictCard(context, c)),

                        if (cell.hasStack) ...[
                          const SizedBox(height: 12),
                          const Divider(height: 32),
                          Text(
                            'SLOT OCCUPANCY',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _stackedEntryRow(cell.subject, cell.group, cell.teacher, isPrimary: true),
                          ...cell.stackedEntries.map((s) => _stackedEntryRow(s.subject, s.group, s.teacher)),
                        ],
                      ],
                    ),
                  ),
                ),
                
                // Footer
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text('Dismiss', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoNotice(String title, String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withAlpha(100)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: Colors.amber[800]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amber[900])),
                const SizedBox(height: 2),
                Text(message, style: GoogleFonts.inter(fontSize: 12, color: Colors.amber[900], height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConflictCard(BuildContext context, SlotConflict conflict) {
    final description = conflictTypeDescriptions[conflict.type];
    
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withAlpha(50)),
        boxShadow: [
          BoxShadow(color: Colors.red.withAlpha(10), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Text(
                conflict.type.toUpperCase(),
                style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.5, color: Colors.red[700]),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            conflict.detail,
            style: GoogleFonts.inter(fontSize: 14, height: 1.5, fontWeight: FontWeight.w500),
          ),
          if (description != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.withAlpha(10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                description,
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic, height: 1.4),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stackedEntryRow(String? subject, String? group, String? teacher, {bool isPrimary = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Icon(
            isPrimary ? Icons.circle : Icons.circle_outlined,
            size: 6,
            color: isPrimary ? Colors.orange[700] : Colors.grey[500],
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              [
                if (subject != null) subject,
                if (group != null) '($group)',
                if (teacher != null) '— $teacher',
              ].join(' '),
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isPrimary ? FontWeight.w600 : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final TimetableEntityType type;
  const _EmptyState({required this.type});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.touch_app_rounded, size: 64, color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: 16),
          Text('Select a ${type.name.toUpperCase()} to view Timetable', 
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Text('Choose an entity from the sidebar to explore its schedule.', 
            style: GoogleFonts.inter(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(150))),
        ],
      ),
    );
  }
}

class _NoVersionSelectedState extends StatelessWidget {
  const _NoVersionSelectedState();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.unarchive_rounded, size: 64, color: colorScheme.outlineVariant),
            const SizedBox(height: 24),
            Text('No Version Selected or Active', 
              style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
            const SizedBox(height: 12),
            Text(
              'A schedule has not been selected for viewing, and no timetable is currently marked as "Active" for this session.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 16, color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colorScheme.outlineVariant.withAlpha(50)),
              ),
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                children: [
                  Text(
                    'How to Proceed:',
                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: colorScheme.primary),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '• Use the "Select Version" menu at the top-right to browse any generated version.\n'
                    '• Once viewing a version, you can "Activate" it to set it as the session primary.\n'
                    '• Return to the Dashboard if you need to generate a new timetable.',
                    textAlign: TextAlign.left,
                    style: GoogleFonts.inter(fontSize: 14, color: colorScheme.onSurfaceVariant, height: 1.8),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VersionHeaderCard extends ConsumerWidget {
  const _VersionHeaderCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final versionsState = ref.watch(versionsProvider);
    final selectedVersionId = ref.watch(selectedVersionIdProvider);
    final theme = Theme.of(context);

    return versionsState.when(
      data: (versions) {
        if (versions.isEmpty) return const SizedBox.shrink();

        final activeVersion = versions.where((v) => v.isActive).firstOrNull;
        final selectedVersion = versions.where((v) => v.versionId == selectedVersionId).firstOrNull;

        final bool isViewingActive = activeVersion?.versionId == selectedVersionId;
        final bool hasConflicts = selectedVersion != null && selectedVersion.bestViolation > 0;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outlineVariant.withAlpha(50)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ACTIVE BADGE
                if (isViewingActive)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withAlpha(40),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.green.withAlpha(100)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle, size: 12, color: Colors.green),
                        const SizedBox(width: 4),
                        Text('ACTIVE', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green[700])),
                      ],
                    ),
                  ),
  
                // CONFLICT BADGE
                if (hasConflicts)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withAlpha(30),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.red.withAlpha(100)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 12, color: Colors.red[600]),
                        const SizedBox(width: 4),
                        Text('CONFLICTS', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red[700])),
                      ],
                    ),
                  ),
  
                // THE DROPDOWN
                DropdownButtonHideUnderline(
                  child: DropdownButton<int?>(
                    value: selectedVersionId,
                    hint: Text('Select Version', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500)),
                    icon: const Icon(Icons.expand_more_rounded, size: 20),
                    items: [
                      ...versions.map((v) {
                        final label = 'Version v.${v.versionId}${v.isActive ? ' ★' : ''}${v.bestViolation > 0 ? ' ⚠' : ''}';
                        return DropdownMenuItem(
                          value: v.versionId,
                          child: Text(label, style: GoogleFonts.inter(fontSize: 14, fontWeight: v.isActive ? FontWeight.bold : FontWeight.normal)),
                        );
                      }),
                    ],
                    onChanged: (newVal) {
                      ref.read(selectedVersionIdProvider.notifier).set(newVal);
                      // Clear conflict filter when switching versions
                      ref.read(activeConflictFilterProvider.notifier).set(null);
                    },
                  ),
                ),
  
                // ACTION BUTTONS (For specific version view only)
                if (selectedVersionId != null && selectedVersion != null) ...[
                  Container(
                    height: 24, padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: VerticalDivider(color: theme.colorScheme.outlineVariant),
                  ),
                  
                  if (!selectedVersion.isActive)
                    TextButton.icon(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: const Text('Set Active Version'),
                            content: Text('Do you want to set Version v.$selectedVersionId as the primary active timetable?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                              FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Set Active')),
                            ],
                          ),
                        );
                        if (confirm == true) ref.read(versionsProvider.notifier).activateVersion(selectedVersionId);
                      },
                      icon: const Icon(Icons.verified_rounded, size: 16),
                      label: Text('Activate', style: GoogleFonts.inter(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.blueAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                    
                  const SizedBox(width: 4),
                  TextButton.icon(
                      onPressed: () async {
                        final isDeletingActive = selectedVersionId == activeVersion?.versionId;
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            icon: Icon(Icons.warning_amber_rounded, size: 48, color: isDeletingActive ? Colors.red : Colors.orange),
                            title: Text(isDeletingActive ? 'Delete Active Timetable?' : 'Delete Version'),
                            content: Text(isDeletingActive
                                ? 'This is the currently active timetable. Deleting it will remove all scheduled entries for this version.\n\nThis action cannot be undone.'
                                : 'Are you sure you want to delete Version v.$selectedVersionId?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                              FilledButton(
                                onPressed: () => Navigator.pop(c, true),
                                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                child: Text(isDeletingActive ? 'Delete Active Timetable' : 'Delete'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          ref.read(versionsProvider.notifier).deleteVersion(selectedVersionId);
                          ref.read(selectedVersionIdProvider.notifier).set(null);
                        }
                      },
                      icon: const Icon(Icons.delete_forever_rounded, size: 16),
                      label: Text('Delete', style: GoogleFonts.inter(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                ],
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
