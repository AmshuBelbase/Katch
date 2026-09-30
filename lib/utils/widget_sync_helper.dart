import 'package:home_widget/home_widget.dart';

class WidgetSyncHelper {
  static Future<void> syncWidgets(List<dynamic> reminders, List<dynamic> transactions) async {
    try {
      final nowUtc = DateTime.now().toUtc();
      
      // 1. Reminders
      String reminderWidgetText = "No upcoming reminders";
      final pending = reminders.where((r) {
        if (r['is_completed'] == true) return false;
        final dateStr = r['next_due_datetime'] ?? r['due_datetime'];
        if (dateStr == null) return false;
        try {
          DateTime dueUtc = DateTime.parse(dateStr);
          if (!dueUtc.isUtc && !dateStr.endsWith('Z')) {
            dueUtc = DateTime.parse('${dateStr}Z');
          }
          return true;
        } catch (e) {
          return false;
        }
      }).toList();
      
      if (pending.isNotEmpty) {
        pending.sort((a, b) {
          final dA = a['next_due_datetime'] ?? a['due_datetime'] ?? '';
          final dB = b['next_due_datetime'] ?? b['due_datetime'] ?? '';
          return dA.compareTo(dB);
        });
        
        final next5 = pending.take(5).toList();
        List<String> reminderLines = [];
        for (var r in next5) {
            String title = r['task_name'] ?? r['title'] ?? 'Reminder';
            String dateStr = r['next_due_datetime'] ?? r['due_datetime'] ?? '';
            String formattedDate = "";
            if (dateStr.isNotEmpty) {
               try {
                 DateTime dueUtc = DateTime.parse(dateStr);
                 if (!dueUtc.isUtc && !dateStr.endsWith('Z')) dueUtc = DateTime.parse('${dateStr}Z');
                 DateTime local = dueUtc.toLocal();
                 formattedDate = " (${local.day}/${local.month} ${local.hour}:${local.minute.toString().padLeft(2,'0')})";
               } catch (e) {}
            }
            reminderLines.add("• $title$formattedDate");
        }
        reminderWidgetText = reminderLines.join("\n");
      }
      await HomeWidget.saveWidgetData<String>('upcoming_reminders', reminderWidgetText);

      // 2. Personal Finance
      String personalFinanceWidgetText = "No expenses this month";
      final thisMonthExpenses = transactions.where((t) {
        if (t['transaction_type'] != 'expense') return false;
        if (t['created_at'] == null) return false;
        try {
          DateTime dt = DateTime.parse(t['created_at']);
          if (!dt.isUtc && !t['created_at'].endsWith('Z')) dt = DateTime.parse('${t['created_at']}Z');
          return dt.toLocal().month == nowUtc.toLocal().month && dt.toLocal().year == nowUtc.toLocal().year;
        } catch (e) {
          return false;
        }
      }).toList();
      
      if (thisMonthExpenses.isNotEmpty) {
        Map<String, double> categoryTotals = {};
        for (var t in thisMonthExpenses) {
           String cat = t['category'] ?? 'Others';
           double amt = double.tryParse(t['amount'].toString()) ?? 0.0;
           categoryTotals[cat] = (categoryTotals[cat] ?? 0.0) + amt;
        }
        var sortedCats = categoryTotals.entries.toList()..sort((a,b) => b.value.compareTo(a.value));
        List<String> financeLines = [];
        for (var entry in sortedCats.take(5)) {
           financeLines.add("${entry.key}: ₹${entry.value.toStringAsFixed(0)}");
        }
        personalFinanceWidgetText = financeLines.join("\n");
      }
      await HomeWidget.saveWidgetData<String>('personal_finance_summary', personalFinanceWidgetText);

      // 3. Splitwise
      String splitwiseWidgetText = "No pending splitwise balances";
      final splitTx = transactions.where((t) => t['transaction_type'] == 'split' || (t['creditor'] != null && t['debtor'] != null && t['transaction_type'] != 'expense' && t['transaction_type'] != 'income')).toList();
      if (splitTx.isNotEmpty) {
        Map<String, double> balances = {};
        for (var t in splitTx) {
          double amt = double.tryParse(t['amount'].toString()) ?? 0.0;
          String creditor = (t['creditor'] ?? '').toString();
          String debtor = (t['debtor'] ?? '').toString();
          
          if (creditor.toLowerCase() == 'self') {
            balances[debtor] = (balances[debtor] ?? 0.0) + amt;
          } else if (debtor.toLowerCase() == 'self') {
            balances[creditor] = (balances[creditor] ?? 0.0) - amt;
          }
        }
        
        List<String> owedToYou = [];
        List<String> youOwe = [];
        balances.forEach((person, amt) {
          if (amt > 0.1) {
            owedToYou.add("$person: ₹${amt.toStringAsFixed(0)}");
          } else if (amt < -0.1) {
            youOwe.add("$person: ₹${(-amt).toStringAsFixed(0)}");
          }
        });
        
        List<String> splitLines = [];
        if (owedToYou.isNotEmpty) splitLines.add("Owes you:\n" + owedToYou.join("\n"));
        if (youOwe.isNotEmpty) {
          if (splitLines.isNotEmpty) splitLines.add("");
          splitLines.add("You owe:\n" + youOwe.join("\n"));
        }
        
        if (splitLines.isNotEmpty) {
          splitwiseWidgetText = splitLines.join("\n");
        }
      }
      await HomeWidget.saveWidgetData<String>('splitwise_summary', splitwiseWidgetText);

      await HomeWidget.updateWidget(name: 'KatchWidgetProvider', iOSName: 'KatchWidget');
      await HomeWidget.updateWidget(name: 'KatchNoteWidgetProvider');
      await HomeWidget.updateWidget(name: 'KatchReminderWidgetProvider');
      await HomeWidget.updateWidget(name: 'KatchFinanceWidgetProvider');
      await HomeWidget.updateWidget(name: 'KatchSplitwiseWidgetProvider');
    } catch (e) {
      print("Error syncing widget data: $e");
    }
  }
}
