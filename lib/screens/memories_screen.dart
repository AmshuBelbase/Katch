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
import '../tutorial_keys.dart';
import '../widgets/custom_showcase.dart';
import 'package:showcaseview/showcaseview.dart';

class MemoriesScreen extends StatefulWidget {
  const MemoriesScreen({super.key});

  @override
  State<MemoriesScreen> createState() => _MemoriesScreenState();
}

class _MemoriesScreenState extends State<MemoriesScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _timeScrollController = ScrollController(initialScrollOffset: 40.0);
  String _timeFilter = 'This Month';
  DateTime? _selectedDate;
  final Set<String> _typeFilters = {};
  final List<String> _availableTypeFilters = ['Audio', 'Text', 'Starred', 'Has Transaction', 'Has Reminder'];
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
    _timeScrollController.dispose();
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
                  Text('KATCH', style: GoogleFonts.michroma(fontWeight: FontWeight.bold, fontSize: 20, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Theme.of(context).colorScheme.primary)),
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
          preferredSize: const Size.fromHeight(160),
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
                controller: _timeScrollController,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Consumer<ApiProvider>(
                  builder: (context, api, child) {
                    return Row(
                      children: [
                        _buildFilterChip('Last 7 Days', api),
                        const SizedBox(width: 8),
                        _buildFilterChip('This Month', api),
                        const SizedBox(width: 8),
                        _buildFilterChip('Select Month', api, isSelectMonth: true),
                        const SizedBox(width: 8),
                        _buildFilterChip('All Time', api),
                      ]
                    );
                  }
                )
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: _availableTypeFilters.map((f) {
                    final isSelected = _typeFilters.contains(f);
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: FilterChip(
                        label: Builder(
                          builder: (ctx) {
                            String labelText = f;
                            if (isSelected) {
                              final api = Provider.of<ApiProvider>(ctx);
                              int count = api.memories.where((m) {
                                if (_searchController.text.isNotEmpty) {
                                  if (!(m['raw_text'] ?? '').toLowerCase().contains(_searchController.text.toLowerCase())) return false;
                                }
                                final now = DateTime.now();
                                if (m['created_at'] == null) return false;
                                DateTime createdAt = DateTime.parse(m['created_at']).toLocal();
                                if (_timeFilter == 'Last 7 Days') {
                                  final today = DateTime(now.year, now.month, now.day);
                                  final createdDate = DateTime(createdAt.year, createdAt.month, createdAt.day);
                                  final difference = today.difference(createdDate).inDays;
                                  if (difference < 0 || difference >= 7) return false;
                                } else if (_timeFilter == 'This Month') {
                                  if (createdAt.year != now.year || createdAt.month != now.month) return false;
                                } else if (_timeFilter == 'Select Month' && _selectedDate != null) {
                                  if (createdAt.year != _selectedDate!.year || createdAt.month != _selectedDate!.month) return false;
                                }
                                
                                bool matches = true;
                                if (_typeFilters.contains('Audio') && (m['source'] ?? '').toLowerCase() != 'audio') matches = false;
                                if (_typeFilters.contains('Text') && (m['source'] ?? '').toLowerCase() != 'text') matches = false;
                                if (_typeFilters.contains('Starred') && m['is_starred'] != true) matches = false;
                                if (_typeFilters.contains('Has Transaction')) {
                                  if (!api.transactions.any((t) => t['memory_id'] == m['id'].toString())) matches = false;
                                }
                                if (_typeFilters.contains('Has Reminder')) {
                                  if (!api.reminders.any((r) => r['memory_id'] == m['id'].toString())) matches = false;
                                }
                                return matches;
                              }).length;
                              labelText = '$f ($count)';
                            }
                            return Text(labelText);
                          }
                        ),
                        selected: isSelected,
                        onSelected: (bool selected) {
                          setState(() {
                            if (selected) {
                              _typeFilters.add(f);
                            } else {
                              _typeFilters.remove(f);
                            }
                          });
                        },
                        selectedColor: Theme.of(context).colorScheme.primary,
                        checkmarkColor: Theme.of(context).colorScheme.onPrimary,
                        labelStyle: TextStyle(
                          color: isSelected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onBackground,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
              if (api.showTimezonePrompt) {
                return SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.public, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 8),
                            Text('Timezone Change Detected', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).colorScheme.onPrimaryContainer)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Update your recurring reminders to trigger at the same local time in your new timezone?', style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer)),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => api.dismissTimezonePrompt(),
                              child: const Text('Keep Home Timezone'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () => api.syncRecurringRemindersTimezone(),
                              child: const Text('Update All'),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                );
              }
              return const SliverToBoxAdapter(child: SizedBox.shrink());
            },
          ),
          Consumer<ApiProvider>(
            builder: (context, api, child) {
              List<dynamic> chartMemories = List.from(api.memories);
              
              if (_searchController.text.isNotEmpty) {
                final query = _searchController.text.toLowerCase();
                chartMemories = chartMemories.where((m) {
                  return (m['raw_text'] ?? '').toLowerCase().contains(query);
                }).toList();
              }

              final now = DateTime.now();
              chartMemories = chartMemories.where((m) {
                if (m['created_at'] == null) return false;
                DateTime createdAt = DateTime.parse(m['created_at']).toLocal();
                if (_timeFilter == 'Last 7 Days') {
                  final today = DateTime(now.year, now.month, now.day);
                  final createdDate = DateTime(createdAt.year, createdAt.month, createdAt.day);
                  final difference = today.difference(createdDate).inDays;
                  return difference >= 0 && difference < 7;
                } else if (_timeFilter == 'This Month') {
                  return createdAt.year == now.year && createdAt.month == now.month;
                } else if (_timeFilter == 'Select Month' && _selectedDate != null) {
                  return createdAt.year == _selectedDate!.year && createdAt.month == _selectedDate!.month;
                }
                return true;
              }).toList();

              if (_typeFilters.isNotEmpty) {
                chartMemories = chartMemories.where((m) {
                  bool matches = true;
                  if (_typeFilters.contains('Audio') && (m['source'] ?? '').toLowerCase() != 'audio') matches = false;
                  if (_typeFilters.contains('Text') && (m['source'] ?? '').toLowerCase() != 'text') matches = false;
                  if (_typeFilters.contains('Starred') && m['is_starred'] != true) matches = false;
                  if (_typeFilters.contains('Has Transaction')) {
                    if (!api.transactions.any((t) => t['memory_id'] == m['id'].toString())) matches = false;
                  }
                  if (_typeFilters.contains('Has Reminder')) {
                    if (!api.reminders.any((r) => r['memory_id'] == m['id'].toString())) matches = false;
                  }
                  return matches;
                }).toList();
              }

              return SliverToBoxAdapter(
                child: CustomShowcase(
                  showcaseKey: TutorialKeys.noteChartKey,
                  title: 'Activity Chart',
                  description: 'Click a bar in the last 7 days visualizer to filter notes for that day. Click again to clear.',
                  onNextOverride: () {
                    ShowCaseWidget.of(context).dismiss();
                    TutorialKeys.dashboardShellKey.currentState?.continueTutorialToChat();
                  },
                  child: _buildActivityChart(chartMemories),
                ),
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

              // Apply Time Filter
              final now = DateTime.now();
              displayMemories = displayMemories.where((m) {
                if (m['created_at'] == null) return false;
                DateTime createdAt = DateTime.parse(m['created_at']).toLocal();
                if (_timeFilter == 'Last 7 Days') {
                  final today = DateTime(now.year, now.month, now.day);
                  final createdDate = DateTime(createdAt.year, createdAt.month, createdAt.day);
                  final difference = today.difference(createdDate).inDays;
                  return difference >= 0 && difference < 7;
                } else if (_timeFilter == 'This Month') {
                  return createdAt.year == now.year && createdAt.month == now.month;
                } else if (_timeFilter == 'Select Month' && _selectedDate != null) {
                  return createdAt.year == _selectedDate!.year && createdAt.month == _selectedDate!.month;
                }
                return true;
              }).toList();

              // Apply Type Filters
              if (_typeFilters.isNotEmpty) {
                displayMemories = displayMemories.where((m) {
                  bool matches = true;
                  if (_typeFilters.contains('Audio') && (m['source'] ?? '').toLowerCase() != 'audio') matches = false;
                  if (_typeFilters.contains('Text') && (m['source'] ?? '').toLowerCase() != 'text') matches = false;
                  if (_typeFilters.contains('Starred') && m['is_starred'] != true) matches = false;
                  if (_typeFilters.contains('Has Transaction')) {
                    if (!api.transactions.any((t) => t['memory_id'] == m['id'].toString())) matches = false;
                  }
                  if (_typeFilters.contains('Has Reminder')) {
                    if (!api.reminders.any((r) => r['memory_id'] == m['id'].toString())) matches = false;
                  }
                  return matches;
                }).toList();
              }

              if (displayMemories.isEmpty && api.isTutorialActive) {
                displayMemories = [{
                  'id': 'dummy',
                  'created_at': DateTime.now().toIso8601String(),
                  'source': 'text',
                  'raw_text': 'This is a sample memory. Our AI automatically extracts tasks and expenses from notes like this!',
                  'is_starred': false,
                }];
              }
              
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    Widget card = _buildMemoryCard(displayMemories[index], api, index == 0);
                    if (index == 0) {
                      return CustomShowcase(
                        showcaseKey: TutorialKeys.noteCardKey,
                        title: 'Memory Card',
                        description: 'Your voice and text notes appear here. AI organizes them automatically.',
                        child: card,
                      );
                    }
                    return card;
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

  Future<DateTime?> _showMonthPicker(BuildContext context, DateTime initialDate) async {
    DateTime selectedDate = initialDate;
    return showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Month'),
          content: SizedBox(
            width: 300,
            height: 300,
            child: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => selectedDate = DateTime(selectedDate.year - 1, selectedDate.month))),
                        Text('${selectedDate.year}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.arrow_forward), onPressed: () => setState(() => selectedDate = DateTime(selectedDate.year + 1, selectedDate.month))),
                      ],
                    ),
                    Expanded(
                      child: GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 2),
                        itemCount: 12,
                        itemBuilder: (context, index) {
                          bool isSelected = selectedDate.month == index + 1;
                          return InkWell(
                            onTap: () {
                              setState(() => selectedDate = DateTime(selectedDate.year, index + 1));
                            },
                            child: Container(
                              margin: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                DateFormat('MMM').format(DateTime(2020, index + 1)),
                                style: TextStyle(color: isSelected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onBackground),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(context, selectedDate), child: const Text('OK')),
          ],
        );
      },
    );
  }

  Widget _buildFilterChip(String label, ApiProvider api, {bool isSelectMonth = false}) {
    bool isSelected = _timeFilter == (isSelectMonth ? 'Select Month' : label);
    String displayLabel = label;
    if (isSelectMonth && isSelected && _selectedDate != null) {
      displayLabel = DateFormat('MMM yyyy').format(_selectedDate!);
    }

    int count = 0;
    if (!isSelectMonth || (isSelectMonth && isSelected && _selectedDate != null)) {
      count = api.memories.where((m) {
        if (_searchController.text.isNotEmpty) {
          if (!(m['raw_text'] ?? '').toLowerCase().contains(_searchController.text.toLowerCase())) return false;
        }
        if (m['created_at'] == null) return false;
        DateTime createdAt = DateTime.parse(m['created_at']).toLocal();
        final now = DateTime.now();

        if (label == 'Last 7 Days') {
          final today = DateTime(now.year, now.month, now.day);
          final createdDate = DateTime(createdAt.year, createdAt.month, createdAt.day);
          final difference = today.difference(createdDate).inDays;
          return difference >= 0 && difference < 7;
        } else if (label == 'This Month') {
          return createdAt.year == now.year && createdAt.month == now.month;
        } else if (isSelectMonth && _selectedDate != null) {
          return createdAt.year == _selectedDate!.year && createdAt.month == _selectedDate!.month;
        }
        return true;
      }).length;
      displayLabel = '$displayLabel ($count)';
    }

    return FilterChip(
      label: Text(displayLabel),
      selected: isSelected,
      selectedColor: Theme.of(context).colorScheme.primary,
      checkmarkColor: Theme.of(context).colorScheme.onPrimary,
      labelStyle: TextStyle(
        color: isSelected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onBackground,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (selected) async {
        if (isSelectMonth) {
          final picked = await _showMonthPicker(context, _selectedDate ?? DateTime.now());
          if (picked != null) {
            setState(() {
              _timeFilter = 'Select Month';
              _selectedDate = picked;
            });
          }
        } else {
          setState(() {
            _timeFilter = label;
          });
        }
      },
    );
  }

  Widget _buildMemoryCard(dynamic memory, ApiProvider api, bool isFirst) {
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
                children: [
                  Expanded(
                    child: Row(
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
                        Expanded(
                          child: Text(
                            formattedDate, 
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      isFirst ? CustomShowcase(
                        showcaseKey: TutorialKeys.noteAlarmIconKey,
                        title: 'Manual Reminder',
                        description: 'Shows if AI extracted a reminder. Tap to force retry.',
                        child: _buildAlarmIcon(memoryId, api, context),
                      ) : _buildAlarmIcon(memoryId, api, context),
                      isFirst ? CustomShowcase(
                        showcaseKey: TutorialKeys.noteWalletIconKey,
                        title: 'Manual Finance',
                        description: 'Shows if AI extracted a transaction. Tap to force retry.',
                        child: _buildWalletIcon(memoryId, api, context),
                      ) : _buildWalletIcon(memoryId, api, context),
                      isFirst ? CustomShowcase(
                        showcaseKey: TutorialKeys.noteStarIconKey,
                        title: 'Star Note',
                        description: 'Tap here to mark this note as important.',
                        child: _buildStarIcon(memoryId, isStarred, api, context),
                      ) : _buildStarIcon(memoryId, isStarred, api, context),
                      if (!_isSelectionMode)
                        Builder(
                          builder: (context) {
                            Widget menu = SizedBox(
                              width: 28,
                              height: 28,
                              child: PopupMenuButton<String>(
                                padding: EdgeInsets.zero,
                                onSelected: (val) async {
                                  if (val == 'delete' && memory['id'] != 'dummy') {
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
                                  } else if (val == 'edit' && memory['id'] != 'dummy') {
                                    _showEditDialog(context, memory, api);
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                  const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                                ],
                                icon: const Icon(Icons.more_vert, size: 20),
                              )
                            );
                            if (isFirst) {
                              return CustomShowcase(
                                showcaseKey: TutorialKeys.noteDeleteKey,
                                title: 'Manage Note',
                                description: 'Tap here to edit or delete your memory.',
                                onNextOverride: () {
                                  ShowCaseWidget.of(context).dismiss();
                                  TutorialKeys.dashboardShellKey.currentState?.continueTutorialToChat();
                                },
                                child: menu,
                              );
                            }
                            return menu;
                          }
                        )
                    ],
                  ),
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
  Widget _buildAlarmIcon(String memoryId, ApiProvider api, BuildContext context) {
    return IconButton(
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
    );
  }

  Widget _buildWalletIcon(String memoryId, ApiProvider api, BuildContext context) {
    return IconButton(
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
    );
  }

  Widget _buildStarIcon(String memoryId, bool isStarred, ApiProvider api, BuildContext context) {
    return IconButton(
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
    );
  }
}
