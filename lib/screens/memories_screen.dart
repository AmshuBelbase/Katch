import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import '../providers/api_provider.dart';
import '../theme.dart';
import '../widgets/app_drawer.dart';
import '../utils/undo_helper.dart';

class MemoriesScreen extends StatefulWidget {
  const MemoriesScreen({super.key});

  @override
  State<MemoriesScreen> createState() => _MemoriesScreenState();
}

class _MemoriesScreenState extends State<MemoriesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _filter = 'Recent';
  final List<String> _filters = ['Recent', 'All', 'Audio', 'Text', 'Starred'];
  DateTime? _selectedChartDate;
  
  Set<String> _selectedMemoryIds = {};
  bool get _isSelectionMode => _selectedMemoryIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ApiProvider>(context, listen: false).fetchMemories();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: _isSelectionMode 
            ? Text('${_selectedMemoryIds.length} Selected', style: const TextStyle(fontWeight: FontWeight.bold))
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    Theme.of(context).brightness == Brightness.dark ? 'assets/katch_logo_dark.png' : 'assets/katch_logo_light.png',
                    height: 24,
                  ),
                  const SizedBox(width: 8),
                  Text('KATCH', style: GoogleFonts.michroma(fontWeight: FontWeight.bold, fontSize: 20, color: Theme.of(context).colorScheme.primary)),
                ],
              ),
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _selectedMemoryIds.clear();
                  });
                },
              )
            : null,
        actions: _isSelectionMode
            ? [
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  onPressed: () {
                    final api = Provider.of<ApiProvider>(context, listen: false);
                    final count = _selectedMemoryIds.length;
                    final idsToDelete = _selectedMemoryIds.toList();
                    api.hideMultipleMemoriesOptimistically(idsToDelete);
                    setState(() {
                      _selectedMemoryIds.clear();
                    });
                    UndoHelper.showUndoDeleteSnackbar(
                      context: context,
                      itemName: '$count notes',
                      onUndo: () {
                        api.fetchMemories();
                        api.fetchReminders();
                        api.fetchTransactions();
                      },
                      onExecute: () => api.deleteMultipleMemories(idsToDelete),
                    );
                  },
                ),
              ]
            : [],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search notes...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => _searchController.clear(),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: _filters.map((f) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: FilterChip(
                        label: Text(f),
                        selected: _filter == f,
                        onSelected: (bool selected) {
                          setState(() => _filter = f);
                        },
                        selectedColor: Theme.of(context).colorScheme.primary,
                        checkmarkColor: Theme.of(context).colorScheme.onPrimary,
                        labelStyle: TextStyle(
                          color: _filter == f ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onBackground,
                          fontWeight: _filter == f ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          Consumer<ApiProvider>(
            builder: (context, api, child) {
              List<dynamic> chartMemories = List.from(api.memories);
              
              if (_searchController.text.isNotEmpty) {
                final query = _searchController.text.toLowerCase();
                chartMemories = chartMemories.where((m) {
                  return (m['raw_text'] ?? '').toLowerCase().contains(query);
                }).toList();
              }

              if (_filter != 'All') {
                chartMemories = chartMemories.where((m) {
                  if (_filter == 'Recent') {
                    if (m['created_at'] == null) return false;
                    DateTime createdAt = DateTime.parse(m['created_at']).toLocal();
                    final now = DateTime.now();
                    final today = DateTime(now.year, now.month, now.day);
                    final createdDate = DateTime(createdAt.year, createdAt.month, createdAt.day);
                    final difference = today.difference(createdDate).inDays;
                    return difference >= 0 && difference < 7;
                  }
                  if (_filter == 'Audio') return (m['source'] ?? '').toLowerCase() == 'audio';
                  if (_filter == 'Text') return (m['source'] ?? '').toLowerCase() == 'text';
                  if (_filter == 'Starred') return m['is_starred'] == true;
                  return true;
                }).toList();
              }

              return SliverToBoxAdapter(
                child: _buildActivityChart(chartMemories),
              );
            },
          ),
          Consumer<ApiProvider>(
            builder: (context, api, child) {
              if (api.isLoading && api.memories.isEmpty) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              // Apply Search, Filter, and Sorting
              List<dynamic> displayMemories = List.from(api.memories);
              
              // Sort by created_at (Date/Time) descending
              displayMemories.sort((a, b) {
                DateTime timeA = DateTime.parse(a['created_at']);
                DateTime timeB = DateTime.parse(b['created_at']);
                return timeB.compareTo(timeA);
              });

              // Apply Chart Date Filter
              if (_selectedChartDate != null) {
                displayMemories = displayMemories.where((m) {
                  if (m['created_at'] == null) return false;
                  DateTime createdAt = DateTime.parse(m['created_at']).toLocal();
                  return createdAt.year == _selectedChartDate!.year && 
                         createdAt.month == _selectedChartDate!.month && 
                         createdAt.day == _selectedChartDate!.day;
                }).toList();
              }

              // Apply Text Filter
              if (_searchController.text.isNotEmpty) {
                final query = _searchController.text.toLowerCase();
                displayMemories = displayMemories.where((m) {
                  return (m['raw_text'] ?? '').toLowerCase().contains(query);
                }).toList();
              }

              // Apply Chip Filter
              if (_filter != 'All') {
                displayMemories = displayMemories.where((m) {
                  if (_filter == 'Recent') {
                    if (m['created_at'] == null) return false;
                    DateTime createdAt = DateTime.parse(m['created_at']).toLocal();
                    final now = DateTime.now();
                    final today = DateTime(now.year, now.month, now.day);
                    final createdDate = DateTime(createdAt.year, createdAt.month, createdAt.day);
                    final difference = today.difference(createdDate).inDays;
                    return difference >= 0 && difference < 7;
                  }
                  if (_filter == 'Audio') return (m['source'] ?? '').toLowerCase() == 'audio';
                  if (_filter == 'Text') return (m['source'] ?? '').toLowerCase() == 'text';
                  if (_filter == 'Starred') return m['is_starred'] == true;
                  return true;
                }).toList();
              }

              if (displayMemories.isEmpty) {
                return const SliverFillRemaining(
                  child: Center(child: Text("No notes found.")),
                );
              }
              
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return _buildMemoryCard(displayMemories[index], api);
                  },
                  childCount: displayMemories.length,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActivityChart(List<dynamic> memories) {
    // Calculate activity for the last 7 days
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final List<int> activityCounts = List.filled(7, 0);
    final List<String> dayLabels = List.filled(7, '');

    for (int i = 0; i < 7; i++) {
      final date = today.subtract(Duration(days: 6 - i));
      dayLabels[i] = DateFormat('E').format(date); // Mon, Tue...
    }

    for (var m in memories) {
      if (m['created_at'] != null) {
        DateTime createdAt = DateTime.parse(m['created_at']).toLocal();
        DateTime createdDate = DateTime(createdAt.year, createdAt.month, createdAt.day);
        final difference = today.difference(createdDate).inDays;
        if (difference >= 0 && difference < 7) {
          activityCounts[6 - difference]++;
        }
      }
    }

    double maxY = activityCounts.isEmpty ? 5 : activityCounts.reduce(max).toDouble();
    if (maxY < 5) maxY = 5; // Give it a decent scale

    int totalMemories = 0;
    if (_selectedChartDate != null) {
      final difference = today.difference(_selectedChartDate!).inDays;
      if (difference >= 0 && difference < 7) {
        totalMemories = activityCounts[6 - difference];
      }
    } else {
      totalMemories = activityCounts.fold(0, (sum, item) => sum + item);
    }

    return Container(
      height: 140,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_selectedChartDate != null)
                Text(
                  'Activity (${DateFormat('MMM d').format(_selectedChartDate!)})',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                )
              else if (memories.isEmpty && _searchController.text.isEmpty)
                const Text(
                  'Record a KATCH Note',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                )
              else
                const Text(
                  'Activity (Last 7 Days)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              Text(
                '$totalMemories notes',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY,
                barTouchData: BarTouchData(
                  enabled: true,
                  handleBuiltInTouches: false,
                  touchCallback: (FlTouchEvent event, barTouchResponse) {
                    if (barTouchResponse == null || barTouchResponse.spot == null) {
                      return;
                    }
                    if (event is FlTapDownEvent) {
                      int index = barTouchResponse.spot!.touchedBarGroupIndex;
                      final date = today.subtract(Duration(days: 6 - index));
                      setState(() {
                        if (_selectedChartDate != null && 
                            _selectedChartDate!.year == date.year && 
                            _selectedChartDate!.month == date.month && 
                            _selectedChartDate!.day == date.day) {
                          _selectedChartDate = null;
                        } else {
                          _selectedChartDate = date;
                        }
                      });
                    }
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            dayLabels[value.toInt()],
                            style: const TextStyle(color: Colors.grey, fontSize: 10),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(show: false),
                barGroups: List.generate(7, (index) {
                  final barDate = today.subtract(Duration(days: 6 - index));
                  bool isSelected = _selectedChartDate != null &&
                      barDate.year == _selectedChartDate!.year &&
                      barDate.month == _selectedChartDate!.month &&
                      barDate.day == _selectedChartDate!.day;
                  bool anySelected = _selectedChartDate != null;

                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: activityCounts[index].toDouble(),
                        color: anySelected 
                            ? (isSelected ? Theme.of(context).colorScheme.primary : Colors.grey.withOpacity(0.3))
                            : Theme.of(context).colorScheme.primary.withOpacity(0.8),
                        width: 12,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemoryCard(dynamic memory, ApiProvider api) {
    DateTime createdAt = DateTime.parse(memory['created_at']).toLocal();
    String formattedDate = DateFormat('MMM d, yyyy • h:mm a').format(createdAt);
    
    String source = memory['source'] ?? 'text';
    bool isAudio = source.toLowerCase() == 'audio';
    bool isStarred = memory['is_starred'] ?? false;
    String memoryId = memory['id'].toString();
    bool isSelected = _selectedMemoryIds.contains(memoryId);

    return Card(
      color: isSelected ? Theme.of(context).colorScheme.primary.withOpacity(0.1) : Theme.of(context).colorScheme.surface,
      child: InkWell(
        onLongPress: () {
          setState(() {
            _selectedMemoryIds.add(memoryId);
          });
        },
        onTap: () {
          if (_isSelectionMode) {
            setState(() {
              if (isSelected) {
                _selectedMemoryIds.remove(memoryId);
              } else {
                _selectedMemoryIds.add(memoryId);
              }
            });
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      if (_isSelectionMode)
                        Checkbox(
                          value: isSelected,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedMemoryIds.add(memoryId);
                              } else {
                                _selectedMemoryIds.remove(memoryId);
                              }
                            });
                          },
                        ),
                      Icon(isAudio ? Icons.mic : Icons.notes, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(formattedDate, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          api.reminders.any((r) => r['memory_id'] == memoryId) ? Icons.alarm_on : Icons.add_alarm, 
                          color: api.reminders.any((r) => r['memory_id'] == memoryId) ? AppTheme.successColor(context) : Colors.grey, 
                          size: 20
                        ),
                        onPressed: () async {
                          if (!api.reminders.any((r) => r['memory_id'] == memoryId)) {
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) => const Center(child: CircularProgressIndicator()),
                            );
                            final res = await api.forceExtractReminder(memoryId);
                            if (context.mounted) {
                              Navigator.of(context).pop();
                              if (res['status'] == 'error') {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Error'), backgroundColor: AppTheme.error, behavior: SnackBarBehavior.floating));
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Success'), backgroundColor: AppTheme.success, behavior: SnackBarBehavior.floating));
                              }
                            }
                          }
                        },
                        tooltip: api.reminders.any((r) => r['memory_id'] == memoryId) ? 'Reminder added' : 'Add to Reminders',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      ),
                      IconButton(
                        icon: Icon(
                          api.transactions.any((t) => t['memory_id'] == memoryId) ? Icons.monetization_on : Icons.add_card, 
                          color: api.transactions.any((t) => t['memory_id'] == memoryId) ? AppTheme.successColor(context) : Colors.grey, 
                          size: 20
                        ),
                        onPressed: () async {
                          if (!api.transactions.any((t) => t['memory_id'] == memoryId)) {
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) => const Center(child: CircularProgressIndicator()),
                            );
                            final res = await api.forceExtractFinance(memoryId);
                            if (context.mounted) {
                              Navigator.of(context).pop();
                              if (res['status'] == 'error') {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Error'), backgroundColor: AppTheme.error, behavior: SnackBarBehavior.floating));
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Success'), backgroundColor: AppTheme.success, behavior: SnackBarBehavior.floating));
                              }
                            }
                          }
                        },
                        tooltip: api.transactions.any((t) => t['memory_id'] == memoryId) ? 'Finance added' : 'Add to Finance',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      ),
                      IconButton(
                        icon: Icon(
                          isStarred ? Icons.star : Icons.star_border,
                          color: isStarred ? Colors.amber : Colors.grey,
                          size: 20
                        ),
                        onPressed: () async {
                          bool success = await api.toggleStarMemory(memoryId, !isStarred);
                          if (!success && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Couldn't star due to a connection problem."),
                                duration: Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      ),
                      if (!_isSelectionMode)
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                          onSelected: (val) async {
                            if (val == 'delete') {
                              api.hideMemoryOptimistically(memoryId);
                              UndoHelper.showUndoDeleteSnackbar(
                                context: context,
                                itemName: 'Note',
                                onUndo: () {
                                  api.fetchMemories();
                                  api.fetchReminders();
                                  api.fetchTransactions();
                                },
                                onExecute: () => api.deleteMemory(memoryId),
                              );
                            } else if (val == 'edit') {
                              _showEditDialog(context, memory, api);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'edit', child: Text('Edit')),
                            const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                          ],
                          icon: const Icon(Icons.more_vert, size: 20),
                        )
                        )
                    ],
                  )
                ],
              ),
            const SizedBox(height: 8),
            Text(
              memory['raw_text'] ?? '',
              style: const TextStyle(fontSize: 16),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      ),
    );
  }
  void _showEditDialog(BuildContext context, dynamic memory, ApiProvider api) {
    final TextEditingController editController = TextEditingController(text: memory['raw_text']);
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Note'),
          content: TextField(
            controller: editController,
            maxLines: 5,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newText = editController.text.trim();
                Navigator.pop(dialogContext);
                if (newText.isNotEmpty && newText != memory['raw_text']) {
                  final success = await api.updateMemory(memory['id'].toString(), newText);
                  if (context.mounted) {
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Note updated successfully.'), backgroundColor: AppTheme.success, behavior: SnackBarBehavior.floating));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update note.'), backgroundColor: AppTheme.error, behavior: SnackBarBehavior.floating));
                    }
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      }
    );
  }
}
