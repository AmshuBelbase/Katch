import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import '../providers/api_provider.dart';
import '../theme.dart';

class MemoriesScreen extends StatefulWidget {
  const MemoriesScreen({super.key});

  @override
  State<MemoriesScreen> createState() => _MemoriesScreenState();
}

class _MemoriesScreenState extends State<MemoriesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _filter = 'All';
  final List<String> _filters = ['All', 'Audio', 'Text', 'Starred'];
  
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
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            floating: true,
            pinned: true,
            title: _isSelectionMode 
                ? Text('${_selectedMemoryIds.length} Selected', style: const TextStyle(fontWeight: FontWeight.bold))
                : null,
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
                        api.deleteMultipleMemories(_selectedMemoryIds.toList());
                        setState(() {
                          _selectedMemoryIds.clear();
                        });
                      },
                    ),
                  ]
                : null,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: AppTheme.background,
                padding: const EdgeInsets.only(top: 110, left: 16, right: 16),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search memories...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => _searchController.clear(),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(50),
              child: SingleChildScrollView(
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
                        selectedColor: AppTheme.primary,
                        checkmarkColor: Colors.white,
                        labelStyle: TextStyle(
                          color: _filter == f ? Colors.white : Colors.black87,
                          fontWeight: _filter == f ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          Consumer<ApiProvider>(
            builder: (context, api, child) {
              return SliverToBoxAdapter(
                child: _buildActivityChart(api.memories),
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
                  if (_filter == 'Audio') return (m['source'] ?? '').toLowerCase() == 'audio';
                  if (_filter == 'Text') return (m['source'] ?? '').toLowerCase() == 'text';
                  if (_filter == 'Starred') return m['is_starred'] == true;
                  return true;
                }).toList();
              }

              if (displayMemories.isEmpty) {
                return const SliverFillRemaining(
                  child: Center(child: Text("No memories found.")),
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
    final List<int> activityCounts = List.filled(7, 0);
    final List<String> dayLabels = List.filled(7, '');

    for (int i = 0; i < 7; i++) {
      final date = now.subtract(Duration(days: 6 - i));
      dayLabels[i] = DateFormat('E').format(date); // Mon, Tue...
    }

    for (var m in memories) {
      if (m['created_at'] != null) {
        DateTime createdAt = DateTime.parse(m['created_at']).toLocal();
        final difference = now.difference(createdAt).inDays;
        if (difference >= 0 && difference < 7) {
          activityCounts[6 - difference]++;
        }
      }
    }

    double maxY = activityCounts.isEmpty ? 5 : activityCounts.reduce(max).toDouble();
    if (maxY < 5) maxY = 5; // Give it a decent scale

    return Container(
      height: 140,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Activity (Last 7 Days)', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY,
                barTouchData: BarTouchData(enabled: false),
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
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: activityCounts[index].toDouble(),
                        color: AppTheme.primary.withOpacity(0.8),
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
      color: isSelected ? AppTheme.primary.withOpacity(0.1) : AppTheme.surface,
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
                          isStarred ? Icons.star : Icons.star_border,
                          color: isStarred ? Colors.amber : Colors.grey,
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
                      ),
                      if (!_isSelectionMode)
                        PopupMenuButton<String>(
                          onSelected: (val) {
                            if (val == 'delete') {
                              api.deleteMemory(memoryId);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'edit', child: Text('Edit')),
                            const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                          ],
                          icon: const Icon(Icons.more_vert, size: 20),
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
}
