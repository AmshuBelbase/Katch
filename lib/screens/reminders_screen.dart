import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/api_provider.dart';
import '../theme.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  DateTime? _selectedDate;

  void _onDateSelected(DateTime date) {
    setState(() {
      if (_selectedDate != null && 
          _selectedDate!.year == date.year && 
          _selectedDate!.month == date.month && 
          _selectedDate!.day == date.day) {
        _selectedDate = null;
      } else {
        _selectedDate = date;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ApiProvider>(context, listen: false).fetchReminders();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks & Reminders', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Consumer<ApiProvider>(
        builder: (context, api, child) {
          if (api.isLoading && api.reminders.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (api.reminders.isEmpty) {
            return const Center(child: Text("No upcoming tasks."));
          }

          // Categorize
          final nowUtc = DateTime.now().toUtc();
          final nowLocal = DateTime.now();
          
          List<dynamic> overdue = [];
          List<dynamic> inAnHour = [];
          List<dynamic> today = [];
          List<dynamic> upcoming = [];
          List<dynamic> completedToday = [];
          List<dynamic> completedPast = [];

          for (var r in api.reminders) {
            DateTime dueUtc = DateTime.parse(r['due_datetime']);
            // Fallback: if not UTC, assume it is UTC (sometimes backend sends without Z)
            if (!dueUtc.isUtc) {
              dueUtc = DateTime.parse('${r['due_datetime']}Z');
            }
            DateTime dueLocal = dueUtc.toLocal();
            
            if (_selectedDate != null) {
              if (dueLocal.year != _selectedDate!.year || 
                  dueLocal.month != _selectedDate!.month || 
                  dueLocal.day != _selectedDate!.day) {
                continue;
              }
            }
            
            bool isDueToday = dueLocal.year == nowLocal.year && dueLocal.month == nowLocal.month && dueLocal.day == nowLocal.day;

            if (r['is_completed'] == true) {
              if (isDueToday) {
                completedToday.add(r);
              } else {
                completedPast.add(r);
              }
              continue;
            }
            
            Duration diffFromNow = dueUtc.difference(nowUtc);

            if (diffFromNow.isNegative) {
              overdue.add(r);
            } else if (diffFromNow.inMinutes <= 60) {
              inAnHour.add(r);
            } else if (isDueToday) {
              today.add(r);
            } else {
              upcoming.add(r);
            }
          }

          completedPast.sort((a, b) {
            DateTime dueA = DateTime.parse(a['due_datetime']);
            DateTime dueB = DateTime.parse(b['due_datetime']);
            return dueB.compareTo(dueA);
          });

          List<dynamic> completedList = [...completedToday];
          if (_selectedDate != null) {
            completedList.addAll(completedPast);
          } else if (completedList.length < 3) {
            int needed = 3 - completedList.length;
            completedList.addAll(completedPast.take(needed));
          }

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: TaskCalendar(
                  reminders: api.reminders,
                  selectedDate: _selectedDate,
                  onDateSelected: _onDateSelected,
                ),
              ),
              if (overdue.isNotEmpty)
                _buildSectionHeader('Overdue', AppTheme.error),
              if (overdue.isNotEmpty)
                _buildList(overdue, api),
                
              if (inAnHour.isNotEmpty)
                _buildSectionHeader('In an hour', Colors.orange),
              if (inAnHour.isNotEmpty)
                _buildList(inAnHour, api),
                
              if (today.isNotEmpty)
                _buildSectionHeader('Today', AppTheme.primary),
              if (today.isNotEmpty)
                _buildList(today, api),
                
              if (upcoming.isNotEmpty)
                _buildSectionHeader('Upcoming', Colors.grey.shade700),
              if (upcoming.isNotEmpty)
                _buildList(upcoming, api),
                
              if (completedList.isNotEmpty)
                _buildSectionHeader('Completed', Colors.grey.shade500),
              if (completedList.isNotEmpty)
                _buildList(completedList, api),
                
              const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
            ],
          );
        },
      ),
    );
  }



  Widget _buildSectionHeader(String title, Color color) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8),
        child: Text(
          title,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
        ),
      ),
    );
  }

  Widget _buildList(List<dynamic> items, ApiProvider api) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final item = items[index];
          DateTime dueUtc = DateTime.parse(item['due_datetime']);
          DateTime dueLocal = dueUtc.toLocal();
          String formattedDue = DateFormat('MMM d, h:mm a').format(dueLocal);
          
          bool isOverdue = dueUtc.isBefore(DateTime.now().toUtc());

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              leading: Checkbox(
                value: item['is_completed'] == true,
                onChanged: (val) {
                  if (val != null) {
                    api.updateReminderSettings(item['id'].toString(), val, item['status'] ?? 'pending');
                  }
                },
                activeColor: AppTheme.success,
                checkColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              title: Text(
                item['task_name'],
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  decoration: item['is_completed'] == true ? TextDecoration.lineThrough : null,
                  color: item['is_completed'] == true ? Colors.grey : Colors.black87,
                ),
              ),
              subtitle: Row(
                children: [
                  Icon(Icons.calendar_today, size: 12, color: isOverdue ? AppTheme.error : Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    formattedDue,
                    style: TextStyle(
                      color: isOverdue ? AppTheme.error : Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              trailing: IconButton(
                icon: _getStatusIcon(item['status']),
                onPressed: () {
                  String currentStatus = item['status'] ?? 'pending';
                  String nextStatus;
                  if (currentStatus == 'pending') nextStatus = 'sent';
                  else if (currentStatus == 'sent') nextStatus = 'Not needed';
                  else nextStatus = 'pending';
                  
                  api.updateReminderSettings(item['id'].toString(), item['is_completed'] == true, nextStatus);
                },
              ),
            ),
          );
        },
        childCount: items.length,
      ),
    );
  }

  Widget _getStatusIcon(String? status) {
    switch (status) {
      case 'sent':
        return const Icon(Icons.notifications_active, color: AppTheme.primary, size: 20);
      case 'Not needed':
        return const Icon(Icons.notifications_off, color: Colors.grey, size: 20);
      case 'pending':
      default:
        return const Icon(Icons.notifications, color: AppTheme.success, size: 20);
    }
  }

}

class TaskCalendar extends StatefulWidget {
  final List<dynamic> reminders;
  final DateTime? selectedDate;
  final Function(DateTime) onDateSelected;

  const TaskCalendar({
    super.key, 
    required this.reminders,
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  State<TaskCalendar> createState() => _TaskCalendarState();
}

class _TaskCalendarState extends State<TaskCalendar> {
  final PageController _pageController = PageController(initialPage: 10000);
  final DateTime _today = DateTime.now();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextMonth() {
    _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  void _prevMonth() {
    _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 320,
            child: PageView.builder(
              controller: _pageController,
              itemBuilder: (context, index) {
                final monthOffset = index - 10000;
                final currentMonth = DateTime(_today.year, _today.month + monthOffset, 1);
                return _buildMonthView(currentMonth);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthView(DateTime monthDate) {
    final int daysInMonth = DateUtils.getDaysInMonth(monthDate.year, monthDate.month);
    final int firstWeekday = monthDate.weekday; // 1 (Mon) to 7 (Sun)
    
    // Adjust weekday so Monday is 1
    final int emptyPrefixDays = firstWeekday - 1; 

    final List<String> weekDays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Column(
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: _prevMonth,
            ),
            Text(
              DateFormat('MMMM yyyy').format(monthDate),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: _nextMonth,
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Weekday row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: weekDays.map((day) => Expanded(
            child: Center(
              child: Text(day, style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          )).toList(),
        ),
        const SizedBox(height: 8),
        // Calendar Grid
        Expanded(
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 1,
            ),
            itemCount: emptyPrefixDays + daysInMonth,
            itemBuilder: (context, index) {
              if (index < emptyPrefixDays) {
                return const SizedBox();
              }
              
              final int dayNumber = index - emptyPrefixDays + 1;
              final DateTime cellDate = DateTime(monthDate.year, monthDate.month, dayNumber);
              
              bool isToday = cellDate.year == _today.year && cellDate.month == _today.month && cellDate.day == _today.day;
              
              // Find reminders for this cell
              int taskCount = 0;

              for (var r in widget.reminders) {
                if (r['is_completed'] == true) continue;
                DateTime due = DateTime.parse(r['due_datetime']).toLocal();
                if (due.year == cellDate.year && due.month == cellDate.month && due.day == cellDate.day) {
                  taskCount++;
                }
              }

              // Overdue logic: if the cell date is in the past entirely AND it has tasks
              DateTime startOfToday = DateTime(_today.year, _today.month, _today.day);
              bool cellIsInPast = cellDate.isBefore(startOfToday);
              bool showOverdueBackground = cellIsInPast && taskCount > 0;
              
              bool isSelected = widget.selectedDate != null &&
                  cellDate.year == widget.selectedDate!.year &&
                  cellDate.month == widget.selectedDate!.month &&
                  cellDate.day == widget.selectedDate!.day;

              return GestureDetector(
                onTap: () => widget.onDateSelected(cellDate),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? AppTheme.primary
                        : (showOverdueBackground ? AppTheme.error.withOpacity(0.1) : (isToday ? AppTheme.primary.withOpacity(0.1) : Colors.transparent)),
                    borderRadius: BorderRadius.circular(8),
                    border: isSelected 
                        ? Border.all(color: AppTheme.primary, width: 2)
                        : (isToday ? Border.all(color: AppTheme.primary, width: 1.5) : Border.all(color: Colors.black.withOpacity(0.05))),
                  ),
                child: Stack(
                  children: [
                    Positioned(
                      top: 4,
                      left: 6,
                      child: Text(
                        dayNumber.toString(),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: (isToday || isSelected) ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Colors.white : (isToday ? AppTheme.primary : Colors.black87),
                        ),
                      ),
                    ),
                    if (taskCount > 0)
                      Positioned(
                        bottom: 2,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white : (showOverdueBackground ? AppTheme.error : AppTheme.primary),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            taskCount.toString(),
                            style: TextStyle(color: isSelected ? AppTheme.primary : Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      )
                  ],
                ),
              ),
            );
          },
          ),
        ),
      ],
    );
  }
}
