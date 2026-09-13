import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../providers/api_provider.dart';
import '../theme.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  int _currentMode = 0; // 0 = Personal, 1 = Splitwise

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ApiProvider>(context, listen: false).fetchTransactions();
    });
  }

  void _showAddCategoryDialog(ApiProvider api) {
    TextEditingController catController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Custom Category'),
          content: TextField(
            controller: catController,
            decoration: const InputDecoration(hintText: 'e.g. Subscriptions'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: const Text('Cancel')
            ),
            ElevatedButton(
              onPressed: () {
                if (catController.text.isNotEmpty) {
                  api.addExpenseCategory(catController.text);
                  Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            )
          ],
        );
      }
    );
  }

  Widget _buildKPICard(String title, double amount, Color color) {
    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            currencyFormatter.format(amount),
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ================= PERSONAL MODE =================

  Widget _buildPersonalTab(ApiProvider api) {
    final now = DateTime.now();
    final personalTx = api.transactions.where((t) {
      if (t['transaction_type'] != 'expense' && t['transaction_type'] != 'income') return false;
      if (t['created_at'] != null) {
        final date = DateTime.parse(t['created_at']).toLocal();
        return date.year == now.year && date.month == now.month;
      }
      return false;
    }).toList();

    double totalIncome = 0;
    double totalExpense = 0;
    Map<String, double> categoryTotals = {};

    for (var t in personalTx) {
      double amt = double.parse(t['amount'].toString());
      bool isIncome = t['transaction_type'] == 'income';
      
      if (isIncome) {
        totalIncome += amt;
      } else {
        totalExpense += amt;
        String cat = (t['category'] ?? 'Others').toString();
        categoryTotals[cat] = (categoryTotals[cat] ?? 0) + amt;
      }
    }

    double netBalance = totalIncome - totalExpense;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Expanded(child: _buildKPICard('Balance', netBalance, netBalance >= 0 ? AppTheme.success : AppTheme.error)),
                const SizedBox(width: 8),
                Expanded(child: _buildKPICard('Income', totalIncome, AppTheme.success)),
                const SizedBox(width: 8),
                Expanded(child: _buildKPICard('Expense', totalExpense, AppTheme.error)),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: _buildPersonalVisualizations(totalIncome, totalExpense, categoryTotals),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Recent Transactions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                TextButton.icon(
                  onPressed: () => _showAddCategoryDialog(api),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Category'),
                ),
              ],
            ),
          ),
        ),
        if (personalTx.isEmpty)
          const SliverFillRemaining(
            child: Center(child: Text('No personal transactions recorded this month.')),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                // sort personalTx so newest is first
                personalTx.sort((a, b) {
                  DateTime da = a['created_at'] != null ? DateTime.parse(a['created_at']) : DateTime.now();
                  DateTime db = b['created_at'] != null ? DateTime.parse(b['created_at']) : DateTime.now();
                  return db.compareTo(da);
                });

                final t = personalTx[index];
                final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
                String cat = t['category'] ?? (t['transaction_type'] == 'income' ? 'Income' : 'Others');
                DateTime date = t['created_at'] != null ? DateTime.parse(t['created_at']).toLocal() : DateTime.now();
                bool isIncome = t['transaction_type'] == 'income';

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  color: AppTheme.surface,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isIncome ? AppTheme.success.withOpacity(0.1) : AppTheme.error.withOpacity(0.1),
                      child: Icon(isIncome ? Icons.download : Icons.receipt_long, color: isIncome ? AppTheme.success : AppTheme.error),
                    ),
                    title: Text(t['description'] ?? 'Transaction', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('$cat • ${DateFormat('MMM d, h:mm a').format(date)}'),
                    trailing: Text(
                      '${isIncome ? '+' : '-'}${currencyFormatter.format(double.parse(t['amount'].toString()))}',
                      style: TextStyle(fontWeight: FontWeight.bold, color: isIncome ? AppTheme.success : AppTheme.error, fontSize: 16),
                    ),
                  ),
                );
              },
              childCount: personalTx.length,
            ),
          ),
      ],
    );
  }

  Widget _buildPersonalVisualizations(double income, double expense, Map<String, double> categoryTotals) {
    return Container(
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
          const Text('Cash Flow', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildCashFlowBar(income, expense),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 12),
          const Text('Expense Breakdown', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: _buildExpensePieChart(categoryTotals),
          )
        ],
      ),
    );
  }

  Widget _buildCashFlowBar(double income, double expense) {
    double total = income + expense;
    if (total == 0) return const Center(child: Text('No cash flow data.'));
    
    int incomeFlex = (income / total * 100).toInt();
    int expenseFlex = (expense / total * 100).toInt();
    
    // Ensure at least 1 flex if there is some amount
    if (income > 0 && incomeFlex == 0) incomeFlex = 1;
    if (expense > 0 && expenseFlex == 0) expenseFlex = 1;

    return Column(
      children: [
        Row(
          children: [
            if (incomeFlex > 0) 
              Expanded(
                flex: incomeFlex, 
                child: Container(
                  height: 16, 
                  decoration: BoxDecoration(
                    color: AppTheme.success, 
                    borderRadius: expenseFlex == 0 ? BorderRadius.circular(8) : const BorderRadius.only(topLeft: Radius.circular(8), bottomLeft: Radius.circular(8))
                  )
                )
              ),
            if (expenseFlex > 0) 
              Expanded(
                flex: expenseFlex, 
                child: Container(
                  height: 16, 
                  decoration: BoxDecoration(
                    color: AppTheme.error, 
                    borderRadius: incomeFlex == 0 ? BorderRadius.circular(8) : const BorderRadius.only(topRight: Radius.circular(8), bottomRight: Radius.circular(8))
                  )
                )
              ),
          ]
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [Container(width: 12, height: 12, decoration: BoxDecoration(color: AppTheme.success, borderRadius: BorderRadius.circular(2))), const SizedBox(width: 4), const Text('Income', style: TextStyle(fontSize: 12))]),
            Row(children: [const Text('Expense', style: TextStyle(fontSize: 12)), const SizedBox(width: 4), Container(width: 12, height: 12, decoration: BoxDecoration(color: AppTheme.error, borderRadius: BorderRadius.circular(2)))]),
          ]
        )
      ]
    );
  }

  Widget _buildExpensePieChart(Map<String, double> categoryTotals) {
    if (categoryTotals.isEmpty) return const Center(child: Text("No expense data for pie chart."));

    List<PieChartSectionData> sections = [];
    int i = 0;
    List<Color> colors = [AppTheme.primary, AppTheme.secondary, AppTheme.tertiary, AppTheme.warning, AppTheme.error, Colors.purple, Colors.teal];
    
    categoryTotals.forEach((name, amount) {
      sections.add(PieChartSectionData(
        value: amount,
        title: name.length > 8 ? '${name.substring(0, 7)}..' : name,
        color: colors[i % colors.length],
        radius: 60,
        titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
      ));
      i++;
    });

    return PieChart(PieChartData(sectionsSpace: 2, centerSpaceRadius: 30, sections: sections));
  }

  // ================= SPLITWISE MODE =================

  Widget _buildSplitwiseTab(ApiProvider api) {
    final splits = api.transactions.where((t) => t['transaction_type'] == 'split' || t['transaction_type'] == null).toList();

    double totalInflow = 0; // Owed to me
    double totalOutflow = 0; // I owe

    // personName -> Balance (positive = they owe me, negative = I owe them)
    Map<String, double> personBalances = {};
    // personName -> List of transactions
    Map<String, List<dynamic>> personHistory = {};

    for (var t in splits) {
      double amt = double.parse(t['amount'].toString());
      String creditor = t['creditor'].toString();
      String debtor = t['debtor'].toString();

      if (creditor.toLowerCase() == 'self') {
        totalInflow += amt;
        personBalances[debtor] = (personBalances[debtor] ?? 0) + amt;
        
        personHistory.putIfAbsent(debtor, () => []).add(t);
      } else if (debtor.toLowerCase() == 'self') {
        totalOutflow += amt;
        personBalances[creditor] = (personBalances[creditor] ?? 0) - amt;
        
        personHistory.putIfAbsent(creditor, () => []).add(t);
      }
    }

    double netBalance = totalInflow - totalOutflow;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Expanded(child: _buildKPICard('Balance', netBalance, netBalance >= 0 ? AppTheme.success : AppTheme.error)),
                const SizedBox(width: 8),
                Expanded(child: _buildKPICard('Owed to You', totalInflow, AppTheme.success)),
                const SizedBox(width: 8),
                Expanded(child: _buildKPICard('You Owe', totalOutflow, AppTheme.error)),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Container(
            height: 220,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black.withOpacity(0.05)),
            ),
            child: _buildSplitwiseBarChart(personBalances),
          ),
        ),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Friends & Balances', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ),
        if (personBalances.isEmpty)
          const SliverFillRemaining(
            child: Center(child: Text('No splitwise transactions recorded.')),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                String person = personBalances.keys.elementAt(index);
                double balance = personBalances[person]!;
                List<dynamic> history = personHistory[person] ?? [];
                
                return _buildPersonExpandableCard(person, balance, history);
              },
              childCount: personBalances.length,
            ),
          ),
      ],
    );
  }

  Widget _buildSplitwiseBarChart(Map<String, double> personBalances) {
    if (personBalances.isEmpty) return const Center(child: Text("No data for bar chart."));
    
    double maxY = 0;
    double minY = 0;
    
    List<BarChartGroupData> barGroups = [];
    int i = 0;
    List<String> labels = [];

    personBalances.forEach((person, balance) {
      if (balance > maxY) maxY = balance;
      if (balance < minY) minY = balance;
      
      barGroups.add(BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: balance,
            color: balance >= 0 ? AppTheme.success : AppTheme.error,
            width: 16,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ));
      labels.add(person.length > 5 ? '${person.substring(0,4)}.' : person);
      i++;
    });

    if (maxY == 0 && minY == 0) {
      maxY = 100;
      minY = -100;
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY * 1.2,
        minY: minY < 0 ? minY * 1.2 : 0,
        barTouchData: BarTouchData(
          enabled: true,
          handleBuiltInTouches: true,
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true, 
              getTitlesWidget: (val, meta) {
                if (val.toInt() >= labels.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(labels[val.toInt()], style: const TextStyle(fontSize: 10, color: Colors.grey)),
                );
              }
            ),
          ),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true, border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.1)))),
        gridData: FlGridData(show: false),
        barGroups: barGroups,
      ),
    );
  }

  Widget _buildPersonExpandableCard(String person, double balance, List<dynamic> history) {
    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    bool owesYou = balance >= 0;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: AppTheme.surface,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: owesYou ? AppTheme.success.withOpacity(0.1) : AppTheme.error.withOpacity(0.1),
          child: Text(person.isNotEmpty ? person[0].toUpperCase() : '?', style: TextStyle(color: owesYou ? AppTheme.success : AppTheme.error, fontWeight: FontWeight.bold)),
        ),
        title: Text(person, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          owesYou ? 'Owes you ${currencyFormatter.format(balance)}' : 'You owe ${currencyFormatter.format(balance.abs())}',
          style: TextStyle(color: owesYou ? AppTheme.success : AppTheme.error, fontWeight: FontWeight.bold),
        ),
        children: history.map((t) {
          double amt = double.parse(t['amount'].toString());
          String creditor = t['creditor'].toString();
          bool isPositive = creditor.toLowerCase() == 'self';
          DateTime date = t['created_at'] != null ? DateTime.parse(t['created_at']).toLocal() : DateTime.now();

          return Container(
            color: Colors.black.withOpacity(0.02),
            child: ListTile(
              dense: true,
              title: Text(t['description'] ?? 'Transaction'),
              subtitle: Text(DateFormat('MMM d, h:mm a').format(date)),
              trailing: Text(
                '${isPositive ? '+' : '-'}${currencyFormatter.format(amt)}',
                style: TextStyle(color: isPositive ? AppTheme.success : AppTheme.error, fontWeight: FontWeight.bold),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Finances', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 0, label: Text('Personal')),
                      ButtonSegment(value: 1, label: Text('Splitwise')),
                    ],
                    selected: {_currentMode},
                    onSelectionChanged: (Set<int> newSelection) {
                      setState(() {
                        _currentMode = newSelection.first;
                      });
                    },
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                        if (states.contains(WidgetState.selected)) {
                          return AppTheme.primary;
                        }
                        return AppTheme.surface;
                      }),
                      foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                        if (states.contains(WidgetState.selected)) {
                          return Colors.white;
                        }
                        return Colors.black87;
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Consumer<ApiProvider>(
        builder: (context, api, child) {
          if (api.isLoading && api.transactions.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_currentMode == 0) {
            return _buildPersonalTab(api);
          } else {
            return _buildSplitwiseTab(api);
          }
        },
      ),
    );
  }
}
