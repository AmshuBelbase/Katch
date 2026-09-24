import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/api_provider.dart';
import '../theme.dart';
import '../widgets/app_drawer.dart';
import '../utils/undo_helper.dart';
import '../tutorial_keys.dart';
import '../widgets/custom_showcase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:showcaseview/showcaseview.dart';

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
      drawer: const AppDrawer(),
      appBar: AppBar(
          actions: [
            
          ],
        title: Row(
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
      ),
      body: Consumer<ApiProvider>(
        builder: (context, api, child) {
          if (api.isLoading && api.reminders.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          bool hasSeenTutorial = Supabase.instance.client.auth.currentUser?.userMetadata?['has_seen_initial_onboarding'] == true;

          List<dynamic> displayReminders = List.from(api.reminders);
          if (displayReminders.isEmpty && !hasSeenTutorial) {
            displayReminders.add({
              'id': 'dummy',
              'task_name': 'Sample Task',
              'due_datetime': DateTime.now().toUtc().add(const Duration(hours: 2)).toIso8601String(),
              'is_completed': false,
              'recurrence_rule': 'FREQ=DAILY',
              'status': 'both',
            });
          }

          final nowUtc = DateTime.now().toUtc();
          final nowLocal = DateTime.now();
          
          List<dynamic> overdue = [];
          List<dynamic> inAnHour = [];
          List<dynamic> today = [];
          List<dynamic> upcoming = [];
          List<dynamic> completedToday = [];
          List<dynamic> completedPast = [];
          List<dynamic> noDeadlines = [];

          for (var r in displayReminders) {
            DateTime dueUtc = DateTime.parse(r['due_datetime']);
            // Fallback: if not UTC, assume it is UTC (sometimes backend sends without Z)
            if (!dueUtc.isUtc) {
              dueUtc = DateTime.parse('${r['due_datetime']}Z');
            }
            DateTime dueLocal = dueUtc.toLocal();
            
            bool isNoDeadline = dueUtc.year >= 2099;
            
            if (_selectedDate != null) {
              if (dueLocal.year != _selectedDate!.year || 
                  dueLocal.month != _selectedDate!.month || 
                  dueLocal.day != _selectedDate!.day) {
                continue;
              }
              if (isNoDeadline) continue; // Hide "no deadline" tasks if a specific date is selected
            }
            
            bool isDueToday = dueLocal.year == nowLocal.year && dueLocal.month == nowLocal.month && dueLocal.day == nowLocal.day;

            if (r['is_completed'] == true) {
              if (isDueToday && !isNoDeadline) {
                completedToday.add(r);
              } else {
                completedPast.add(r);
              }
              continue;
            }
            
            if (isNoDeadline) {
              noDeadlines.add(r);
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

          List<List<dynamic>> allLists = [overdue, inAnHour, today, upcoming, completedList, noDeadlines];
          List<dynamic>? firstNonEmptyList;
          for (var l in allLists) {
             if (l.isNotEmpty) { firstNonEmptyList = l; break; }
          }

          return RefreshIndicator(
            onRefresh: () async {
              await api.fetchReminders();
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
              SliverToBoxAdapter(
                child: CustomShowcase(
                  showcaseKey: TutorialKeys.reminderCardKey,
                  title: 'Task Calendar',
                  description: 'Click on any date to filter reminders for that day. Click again to clear.',
                  child: TaskCalendar(
                    reminders: api.reminders,
                    selectedDate: _selectedDate,
                    onDateSelected: _onDateSelected,
                  ),
                )
              ),
              if (overdue.isNotEmpty)
                _buildSectionHeader('Overdue', AppTheme.error),
              if (overdue.isNotEmpty)
                _buildList(overdue, api, isFirstList: overdue == firstNonEmptyList),
                
              if (inAnHour.isNotEmpty)
                _buildSectionHeader('In an hour', Colors.orange),
              if (inAnHour.isNotEmpty)
                _buildList(inAnHour, api, isFirstList: inAnHour == firstNonEmptyList),
                
              if (today.isNotEmpty)
                _buildSectionHeader('Today', Theme.of(context).colorScheme.primary),
              if (today.isNotEmpty)
                _buildList(today, api, isFirstList: today == firstNonEmptyList),
                
              if (upcoming.isNotEmpty)
                _buildSectionHeader('Upcoming', Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
              if (upcoming.isNotEmpty)
                _buildList(upcoming, api, isFirstList: upcoming == firstNonEmptyList),
                
              if (completedList.isNotEmpty)
                _buildSectionHeader('Completed', Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
              if (completedList.isNotEmpty)
                _buildList(completedList, api, isFirstList: completedList == firstNonEmptyList),

              if (noDeadlines.isNotEmpty)
                _buildSectionHeader('No deadlines', Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
              if (noDeadlines.isNotEmpty)
                _buildList(noDeadlines, api, isFirstList: noDeadlines == firstNonEmptyList),
                
              const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
            ],
          ),
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

  Widget _buildList(List<dynamic> items, ApiProvider api, {bool isFirstList = false}) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final item = items[index];
          DateTime dueUtc = DateTime.parse(item['due_datetime']);
          DateTime dueLocal = dueUtc.toLocal();
          
          bool isNoDeadline = dueUtc.year >= 2099;
          String formattedDue = isNoDeadline ? 'No deadline' : DateFormat('MMM d, h:mm a').format(dueLocal);
          
          bool isOverdue = !isNoDeadline && dueUtc.isBefore(DateTime.now().toUtc());

          return Dismissible(
            key: Key(item['id'].toString()),
            direction: DismissDirection.endToStart,
            background: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              color: AppTheme.errorColor(context),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20.0),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            onDismissed: (direction) {
              final itemId = item['id'].toString();
              if (itemId == 'dummy') return;
              
              api.hideReminderOptimistically(itemId);
              UndoHelper.showUndoDeleteSnackbar(
                context: context,
                itemName: 'Reminder',
                onUndo: () => api.fetchReminders(),
                onExecute: () => api.deleteReminder(itemId),
              );
            },
            child: InkWell(
              onTap: () {
                if (item['id'].toString() == 'dummy') return;
                _showNoteDialog(context, item, api);
              },
              child: Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListTile(
                leading: index == 0 && isFirstList ? CustomShowcase(
                  showcaseKey: TutorialKeys.reminderCheckboxKey,
                  title: 'Complete Tasks',
                  description: 'Check off a task to mark it as completed. It will automatically move to the Completed section.',
                  child: Checkbox(
                    value: item['is_completed'] == true,
                    onChanged: (val) {
                      if (item['id'].toString() == 'dummy') return;
                      if (val != null) {
                        api.updateReminderSettings(item['id'].toString(), val, item['status'] ?? 'pending');
                      }
                    },
                    activeColor: AppTheme.success,
                    checkColor: Theme.of(context).colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                ) : Checkbox(
                  value: item['is_completed'] == true,
                  onChanged: (val) {
                    if (item['id'].toString() == 'dummy') return;
                    if (val != null) {
                      api.updateReminderSettings(item['id'].toString(), val, item['status'] ?? 'pending');
                    }
                  },
                  activeColor: AppTheme.success,
                  checkColor: Theme.of(context).colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                title: Text(
                  item['task_name'],
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    decoration: item['is_completed'] == true ? TextDecoration.lineThrough : null,
                    color: item['is_completed'] == true ? Colors.grey : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                subtitle: isNoDeadline ? null : Row(
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
                    if (item['recurrence_rule'] != null)
                      const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Icon(Icons.repeat, size: 14, color: Colors.blueGrey),
                      ),
                  ],
                ),
                trailing: index == 0 && isFirstList ? CustomShowcase(
                  showcaseKey: TutorialKeys.reminderAlarmIconKey,
                  title: 'Notification Type',
                  description: 'Click here to choose how you want to be notified (Silent, Push, Alarm, or Email).',
                  onNextOverride: () {
                    ShowCaseWidget.of(context).dismiss();
                    TutorialKeys.dashboardShellKey.currentState?.continueTutorialToFinance();
                  },
                  child: PopupMenuButton<String>(
                    icon: _getStatusIcon(item['status']),
                    onSelected: (String newValue) {
                      api.updateReminderSettings(item['id'].toString(), item['is_completed'] == true, newValue);
                    },
                    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                      const PopupMenuItem<String>(
                        value: 'none',
                        child: Row(children: [Icon(Icons.notifications_off, size: 20, color: Colors.grey), SizedBox(width: 8), Text('Silent')]),
                      ),
                      const PopupMenuItem<String>(
                        value: 'push_only',
                        child: Row(children: [Icon(Icons.notifications, size: 20, color: Colors.blue), SizedBox(width: 8), Text('Push Only')]),
                      ),
                      const PopupMenuItem<String>(
                        value: 'phone',
                        child: Row(children: [Icon(Icons.alarm, size: 20, color: Colors.orange), SizedBox(width: 8), Text('Push + Alarm')]),
                      ),
                      const PopupMenuItem<String>(
                        value: 'both',
                        child: Row(children: [Icon(Icons.notifications_active, size: 20, color: Colors.green), SizedBox(width: 8), Text('Push + Alarm + Email')]),
                      ),
                    ],
                  ),
                ) : PopupMenuButton<String>(
                  icon: _getStatusIcon(item['status']),
                  onSelected: (String newValue) {
                    api.updateReminderSettings(item['id'].toString(), item['is_completed'] == true, newValue);
                  },
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(
                      value: 'none',
                      child: Row(children: [Icon(Icons.notifications_off, size: 20, color: Colors.grey), SizedBox(width: 8), Text('Silent')]),
                    ),
                    const PopupMenuItem<String>(
                      value: 'push_only',
                      child: Row(children: [Icon(Icons.notifications, size: 20, color: Colors.blue), SizedBox(width: 8), Text('Push Only')]),
                    ),
                    const PopupMenuItem<String>(
                      value: 'phone',
                      child: Row(children: [Icon(Icons.alarm, size: 20, color: Colors.orange), SizedBox(width: 8), Text('Push + Alarm')]),
                    ),
                    const PopupMenuItem<String>(
                      value: 'both',
                      child: Row(children: [Icon(Icons.notifications_active, size: 20, color: Colors.green), SizedBox(width: 8), Text('Push + Alarm + Email')]),
                    ),
                  ],
                ),
              ),
            ),
            ),
          );
        },
        childCount: items.length,
      ),
    );
  }

  void _showNoteDialog(BuildContext context, dynamic item, ApiProvider api) {
    final rawText = item['memories']?['raw_text'] ?? 'Original note not found.';
    final memoryId = item['memory_id']?.toString();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Original Note',
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
          content: SingleChildScrollView(
            child: Text(rawText),
          ),
          actions: [
            SizedBox(
              width: MediaQuery.of(context).size.width,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (memoryId != null)
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      tooltip: 'Delete entirely',
                      onPressed: () {
                        Navigator.of(context).pop();
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
                      },
                    )
                  else
                    const SizedBox.shrink(),
                  TextButton(
                    child: const Text('Close'),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _getStatusIcon(String? status) {
    switch (status) {
      case 'none':
      case 'Not needed':
        return const Icon(Icons.notifications_off, color: Colors.grey, size: 20);
      case 'push_only':
        return const Icon(Icons.notifications, color: Colors.blue, size: 20);
      case 'phone':
        return const Icon(Icons.alarm, color: Colors.orange, size: 20);
      case 'both':
      case 'pending':
        return const Icon(Icons.notifications_active, color: Colors.green, size: 20);
      case 'sent_phone':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.smartphone, color: Colors.green, size: 20),
            Icon(Icons.check, color: Colors.green, size: 12),
          ],
        );
      case 'sent_both':
      case 'sent':
        return const Icon(Icons.done_all, color: Colors.green, size: 20);
      default:
        return const Icon(Icons.smartphone, color: Colors.blue, size: 20);
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
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 380,
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
                        ? Theme.of(context).colorScheme.primary
                        : (showOverdueBackground ? AppTheme.error.withOpacity(0.1) : (isToday ? Theme.of(context).colorScheme.primary.withOpacity(0.1) : Colors.transparent)),
                    borderRadius: BorderRadius.circular(8),
                    border: isSelected 
                        ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
                        : (isToday ? Border.all(color: Theme.of(context).colorScheme.primary, width: 1.5) : Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1))),
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
                          color: isSelected ? Theme.of(context).colorScheme.onPrimary : (isToday ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onBackground),
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
                            color: isSelected ? Theme.of(context).colorScheme.onPrimary : (showOverdueBackground ? AppTheme.error : Theme.of(context).colorScheme.primary),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            taskCount.toString(),
                            style: TextStyle(color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onPrimary, fontSize: 10, fontWeight: FontWeight.bold),
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
