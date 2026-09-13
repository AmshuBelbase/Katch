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

          // Calculate completion %
          int total = api.reminders.length;
          int completed = api.reminders.where((r) => r['status'] == 'completed').length;
          double percent = total == 0 ? 0 : completed / total;

          // Categorize
          final now = DateTime.now().toUtc();
          
          List<dynamic> overdue = [];
          List<dynamic> today = [];
          List<dynamic> upcoming = [];

          for (var r in api.reminders) {
            if (r['status'] == 'completed') continue;
            
            DateTime due = DateTime.parse(r['due_datetime']);
            if (due.isBefore(now)) {
              overdue.add(r);
            } else if (due.difference(now).inDays == 0 && due.day == now.day) {
              today.add(r);
            } else {
              upcoming.add(r);
            }
          }

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _buildHeaderKPI(percent, completed, total),
              ),
              if (overdue.isNotEmpty)
                _buildSectionHeader('Overdue', AppTheme.error),
              if (overdue.isNotEmpty)
                _buildList(overdue, api),
                
              if (today.isNotEmpty)
                _buildSectionHeader('Today', AppTheme.primary),
              if (today.isNotEmpty)
                _buildList(today, api),
                
              if (upcoming.isNotEmpty)
                _buildSectionHeader('Upcoming', Colors.grey.shade700),
              if (upcoming.isNotEmpty)
                _buildList(upcoming, api),
                
              const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeaderKPI(double percent, int completed, int total) {
    String timezone = DateTime.now().timeZoneName;
    int offsetHours = DateTime.now().timeZoneOffset.inHours;
    int offsetMinutes = DateTime.now().timeZoneOffset.inMinutes.remainder(60);
    String offsetStr = 'GMT${offsetHours >= 0 ? '+' : ''}$offsetHours:${offsetMinutes.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          SizedBox(
            height: 60,
            width: 60,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: percent,
                  strokeWidth: 6,
                  backgroundColor: Colors.black.withOpacity(0.05),
                  color: AppTheme.success,
                  strokeCap: StrokeCap.round,
                ),
                Center(
                  child: Text(
                    '${(percent * 100).toInt()}%',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Completion Rate', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('$completed of $total tasks done', style: TextStyle(color: Colors.grey.shade600)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('$timezone ($offsetStr)', style: const TextStyle(fontSize: 10, color: AppTheme.primary)),
                )
              ],
            ),
          )
        ],
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
            child: CheckboxListTile(
              value: item['status'] == 'completed',
              onChanged: (val) {
                if (val == true) {
                  api.updateReminderStatus(item['id'], 'completed');
                }
              },
              title: Text(
                item['task_name'],
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  decoration: item['status'] == 'completed' ? TextDecoration.lineThrough : null,
                  color: item['status'] == 'completed' ? Colors.grey : Colors.black87,
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
              activeColor: AppTheme.success,
              checkColor: Colors.white,
              controlAffinity: ListTileControlAffinity.leading,
              checkboxShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
          );
        },
        childCount: items.length,
      ),
    );
  }
}
