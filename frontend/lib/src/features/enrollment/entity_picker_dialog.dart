import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:university_timetable_frontend/src/utils/string_utils.dart';

class EntityItem<T> {
  final T data;
  final String label;
  final String subtitle;

  EntityItem({required this.data, required this.label, this.subtitle = ''});
}

class EntityPickerDialog<T> extends StatefulWidget {
  final String title;
  final List<EntityItem<T>> sessionItems;
  final List<EntityItem<T>> centralItems;
  
  /// Label for the entity type, e.g. "Teacher", "Room"
  final String? entityLabel;
  
  // Callback to open the full creation form or redirect to Central DB
  final VoidCallback? onCreateNew;
  
  // Import callback links an existing central item to the session
  final Future<void> Function(T item) onImport;

  const EntityPickerDialog({
    super.key,
    required this.title,
    required this.sessionItems,
    required this.centralItems,
    this.entityLabel,
    this.onCreateNew,
    required this.onImport,
  });

  @override
  State<EntityPickerDialog<T>> createState() => _EntityPickerDialogState();
}

class _EntityPickerDialogState<T> extends State<EntityPickerDialog<T>> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = false;

  // Track items imported/created during this dialog session
  final Set<String> _newlyImportedLabels = {};
  final List<EntityItem<T>> _newlyImportedItems = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String get _label => widget.entityLabel ?? widget.title.replaceAll('Import / Create ', '').replaceAll('Select ', '');

  List<EntityItem<T>> _getFilteredItems(List<EntityItem<T>> list) {
    if (_searchQuery.isEmpty) return list;
    return list
        .where((item) =>
            item.label.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            item.subtitle.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  Widget _buildList(List<EntityItem<T>> items, {required bool isCentralTab}) {
    // For session tab, merge original items with newly imported ones
    final effectiveItems = isCentralTab ? items : [...items, ..._newlyImportedItems.where((n) => !items.any((i) => i.label == n.label))];
    
    // Sort alphabetically by label, ignoring titles
    effectiveItems.sort((a, b) => getSortableName(a.label).toLowerCase().compareTo(getSortableName(b.label).toLowerCase()));

    final filtered = _getFilteredItems(effectiveItems);
    final theme = Theme.of(context);

    if (filtered.isEmpty) {
      // Different messages for "no items at all" vs "search found nothing"
      final bool hasNoItems = effectiveItems.isEmpty;
      final bool isSearching = _searchQuery.isNotEmpty;

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                hasNoItems ? Icons.inbox_rounded : Icons.search_off_rounded,
                size: 48,
                color: theme.colorScheme.outlineVariant,
              ),
              const SizedBox(height: 16),
              Text(
                hasNoItems && !isSearching
                    ? (isCentralTab
                        ? 'No ${_label}s in the Central Database yet.'
                        : 'No ${_label}s linked to this session yet.')
                    : 'No results matching "$_searchQuery".',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              if (hasNoItems && !isSearching) ...[
                const SizedBox(height: 8),
                Text(
                  isCentralTab
                      ? 'Create one using the button above.'
                      : 'Import from Central Database or create a new one.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: theme.colorScheme.onSurfaceVariant.withAlpha(180),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      key: PageStorageKey('entity_picker_${isCentralTab ? 'central' : 'session'}_$_label'),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = filtered[index];
        final isAlreadyInSession = widget.sessionItems.any((si) => si.label == item.label) || _newlyImportedLabels.contains(item.label);
        
        return ListTile(
          title: Text(item.label, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
          subtitle: item.subtitle.isNotEmpty ? Text(item.subtitle, style: GoogleFonts.inter()) : null,
          trailing: isCentralTab
              ? (isAlreadyInSession
                  ? Chip(
                      label: Text('Added', style: GoogleFonts.inter(fontSize: 12)),
                      avatar: const Icon(Icons.check_circle, color: Colors.green, size: 16),
                      visualDensity: VisualDensity.compact,
                    )
                  : FilledButton.tonal(
                      onPressed: _isLoading ? null : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        setState(() => _isLoading = true);
                        try {
                          await widget.onImport(item.data);
                          if (mounted) {
                            setState(() {
                              _newlyImportedLabels.add(item.label);
                              _newlyImportedItems.add(item);
                            });
                          }
                        } catch (e) {
                          if (mounted) messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
                        } finally {
                          if (mounted) setState(() => _isLoading = false);
                        }
                      },
                      child: const Text('Import'),
                    ))
              : const Icon(Icons.chevron_right),
          onTap: () {
            if (isCentralTab && !isAlreadyInSession) {
              // Force explicit Import button click
            } else {
              Navigator.pop(context, item.data);
            }
          },
        );
      },
    );
  }



  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 600,
        height: 700,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              color: theme.colorScheme.surfaceContainerHighest.withAlpha(100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(widget.title, style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Search + Create button row
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search ${_label}s...',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: theme.colorScheme.surface,
                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onChanged: (val) => setState(() => _searchQuery = val),
                        ),
                      ),
                      if (widget.onCreateNew != null) ...[
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          onPressed: () => widget.onCreateNew!(),
                          icon: const Icon(Icons.add_rounded, size: 20),
                          label: const Text('Add New'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Tabs
            TabBar(
              controller: _tabController,
              labelColor: theme.colorScheme.primary,
              indicatorColor: theme.colorScheme.primary,
              tabs: const [
                Tab(text: 'Session Objects'),
                Tab(text: 'Central Database'),
              ],
            ),
            // Content
            Expanded(
              child: Stack(
                children: [
                  TabBarView(
                    controller: _tabController,
                    children: [
                      _buildList(widget.sessionItems, isCentralTab: false),
                      _buildList(widget.centralItems, isCentralTab: true),
                    ],
                  ),
                  if (_isLoading)
                    Container(
                      color: Colors.black.withAlpha(20),
                      child: const Center(child: CircularProgressIndicator()),
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
