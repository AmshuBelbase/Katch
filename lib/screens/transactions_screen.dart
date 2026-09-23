import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../providers/api_provider.dart';
import '../theme.dart';
import '../widgets/app_drawer.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  int _currentMode = 0; // 0 = Personal, 1 = Splitwise
  bool _showChart = true; // true = Pie, false = Bar
  
  String _selectedFilter = 'This Month'; // 'This Week', 'This Month', 'Select Month'
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ApiProvider>(context, listen: false).fetchTransactions();
    });
  }

  void _showAddCategoryDialog(ApiProvider api) {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            TextEditingController catController = TextEditingController();
            bool isLoading = false;
            
            return AlertDialog(
              title: const Text('Manage Categories'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: api.expenseCategories.length,
                        itemBuilder: (context, index) {
                          final cat = api.expenseCategories[index];
                          final isCustom = cat['user_id'] != null;
                          return ListTile(
                            title: Text(cat['name']),
                            trailing: isCustom 
                                ? IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () async {
                                      setState(() => isLoading = true);
                                      final res = await api.deleteExpenseCategory(cat['name']);
                                      if (res['status'] != 'success' && context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'])));
                                      }
                                      setState(() => isLoading = false);
                                    },
                                  )
                                : null,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: catController,
                      decoration: const InputDecoration(hintText: 'Add new (e.g. Subscriptions)'),
                      maxLength: 30,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context), 
                  child: const Text('Done')
                ),
                ElevatedButton(
                  onPressed: isLoading ? null : () async {
                    if (catController.text.isNotEmpty) {
                      setState(() => isLoading = true);
                      final res = await api.addExpenseCategory(catController.text);
                      if (res['status'] != 'success' && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'])));
                      } else {
                        catController.clear();
                      }
                      setState(() => isLoading = false);
                    }
                  },
                  child: isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Add'),
                )
              ],
            );
          }
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

  Widget _buildFilterRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildFilterChip('This Week'),
          const SizedBox(width: 8),
          _buildFilterChip('This Month'),
          const SizedBox(width: 8),
          _buildFilterChip('Select Month', isSelectMonth: true),
        ]
      )
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

  Widget _buildFilterChip(String label, {bool isSelectMonth = false}) {
    bool isSelected = _selectedFilter == (isSelectMonth ? 'Select Month' : label);
    String displayLabel = label;
    if (isSelectMonth && isSelected && _selectedDate != null) {
      displayLabel = DateFormat('MMM yyyy').format(_selectedDate!);
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
              _selectedFilter = 'Select Month';
              _selectedDate = picked;
            });
          }
        } else {
          setState(() {
            _selectedFilter = label;
          });
        }
      },
    );
  }

  Widget _buildPersonalTab(ApiProvider api) {
    final now = DateTime.now();
    final personalTx = api.transactions.where((t) {
      if (t['transaction_type'] != 'expense' && t['transaction_type'] != 'income') return false;
      if (t['created_at'] != null) {
        final date = DateTime.parse(t['created_at']).toLocal();
        if (_selectedFilter == 'This Week') {
          final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
          return date.isAfter(startOfWeek.subtract(const Duration(days: 1)));
        } else if (_selectedFilter == 'This Month') {
          return date.year == now.year && date.month == now.month;
        } else if (_selectedFilter == 'Select Month' && _selectedDate != null) {
          return date.year == _selectedDate!.year && date.month == _selectedDate!.month;
        }
      }
      return true;
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
          child: _buildFilterRow(),
        ),
        SliverToBoxAdapter(
          child: _buildCashFlowHeader(netBalance, totalIncome, totalExpense),
        ),
        SliverToBoxAdapter(
          child: _buildExpenseVisualization(categoryTotals, totalExpense),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Transactions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
            child: Center(child: Text('No transactions recorded in this period.')),
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

                return Dismissible(
                  key: Key(t['id'].toString()),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    color: AppTheme.errorColor(context),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20.0),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (direction) {
                    Provider.of<ApiProvider>(context, listen: false).deleteTransaction(t['id'].toString());
                  },
                  child: Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    color: Theme.of(context).colorScheme.surface,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isIncome ? AppTheme.successColor(context).withValues(alpha: 0.1) : AppTheme.errorColor(context).withValues(alpha: 0.1),
                        child: Icon(isIncome ? Icons.download : Icons.receipt_long, color: isIncome ? AppTheme.successColor(context) : AppTheme.errorColor(context)),
                      ),
                      title: Text(t['description'] ?? 'Transaction', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('$cat • ${DateFormat('MMM d, h:mm a').format(date)}'),
                      trailing: Text(
                        '${isIncome ? '+' : '-'}${currencyFormatter.format(double.parse(t['amount'].toString()))}',
                        style: TextStyle(fontWeight: FontWeight.bold, color: isIncome ? AppTheme.successColor(context) : AppTheme.errorColor(context), fontSize: 16),
                      ),
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

  Widget _buildCashFlowHeader(double netBalance, double totalIncome, double totalExpense) {
    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          const Text('Balance', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            currencyFormatter.format(netBalance), 
            style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: netBalance >= 0 ? AppTheme.successColor(context) : AppTheme.errorColor(context))
          ),
          const SizedBox(height: 32),
          _buildCashFlowBar(totalIncome, totalExpense),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Income: ${currencyFormatter.format(totalIncome)}', style: TextStyle(color: AppTheme.successColor(context), fontWeight: FontWeight.bold)),
              Text('Expense: ${currencyFormatter.format(totalExpense)}', style: TextStyle(color: AppTheme.errorColor(context), fontWeight: FontWeight.bold)),
            ]
          )
        ]
      )
    );
  }

  Widget _buildCashFlowBar(double income, double expense) {
    double total = income + expense;
    if (total == 0) return const Center(child: Text('No cash flow data.'));
    
    int incomeFlex = (income / total * 100).toInt();
    int expenseFlex = (expense / total * 100).toInt();
    
    if (income > 0 && incomeFlex == 0) incomeFlex = 1;
    if (expense > 0 && expenseFlex == 0) expenseFlex = 1;

    return Row(
      children: [
        if (incomeFlex > 0) 
          Expanded(
            flex: incomeFlex, 
            child: Container(
              height: 12, 
              decoration: BoxDecoration(
                color: AppTheme.successColor(context), 
                borderRadius: expenseFlex == 0 ? BorderRadius.circular(6) : const BorderRadius.only(topLeft: Radius.circular(6), bottomLeft: Radius.circular(6))
              )
            )
          ),
        if (expenseFlex > 0) 
          Expanded(
            flex: expenseFlex, 
            child: Container(
              height: 12, 
              decoration: BoxDecoration(
                color: AppTheme.errorColor(context), 
                borderRadius: incomeFlex == 0 ? BorderRadius.circular(6) : const BorderRadius.only(topRight: Radius.circular(6), bottomRight: Radius.circular(6))
              )
            )
          ),
      ]
    );
  }

  Widget _buildExpenseVisualization(Map<String, double> categoryTotals, double totalExpense) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Expense Breakdown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 20),
          if (_showChart)
             _buildPieChartWithLegend(categoryTotals, totalExpense)
          else
             _buildHorizontalCategoryBar(categoryTotals, totalExpense)
        ]
      )
    );
  }

  Widget _buildPieChartWithLegend(Map<String, double> categoryTotals, double totalExpense) {
    if (categoryTotals.isEmpty || totalExpense == 0) return const SizedBox(height: 150, child: Center(child: Text("No expense data.")));

    List<PieChartSectionData> sections = [];
    int i = 0;
    List<Color> colors = Theme.of(context).brightness == Brightness.dark
        ? [const Color(0xFF6366F1), const Color(0xFF8B5CF6), const Color(0xFFEC4899), const Color(0xFFF43F5E), const Color(0xFFF59E0B), const Color(0xFF10B981), const Color(0xFF06B6D4)]
        : [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.secondary, Theme.of(context).colorScheme.tertiary, AppTheme.warning, AppTheme.errorColor(context), Colors.purple, Colors.teal];
    
    List<Widget> legendItems = [];

    // Sort categories by amount descending
    var sortedEntries = categoryTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    for (var entry in sortedEntries) {
      String name = entry.key;
      double amount = entry.value;
      Color c = colors[i % colors.length];
      double percent = (amount / totalExpense) * 100;
      
      sections.add(PieChartSectionData(
        value: amount,
        title: '',
        color: c,
        radius: 40,
      ));
      
      legendItems.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(width: 12, height: 12, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 8),
            Expanded(child: Text(name, style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
            Text('${percent.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ));
      
      i++;
    }

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 120,
            child: PieChart(PieChartData(sectionsSpace: 2, centerSpaceRadius: 20, sections: sections)),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          flex: 3,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: legendItems,
          ),
        ),
      ],
    );
  }

  Widget _buildHorizontalCategoryBar(Map<String, double> categoryTotals, double totalExpense) {
    if (categoryTotals.isEmpty || totalExpense == 0) return const SizedBox(height: 100, child: Center(child: Text("No expense data.")));

    List<Color> colors = Theme.of(context).brightness == Brightness.dark
        ? [const Color(0xFF6366F1), const Color(0xFF8B5CF6), const Color(0xFFEC4899), const Color(0xFFF43F5E), const Color(0xFFF59E0B), const Color(0xFF10B981), const Color(0xFF06B6D4)]
        : [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.secondary, Theme.of(context).colorScheme.tertiary, AppTheme.warning, AppTheme.errorColor(context), Colors.purple, Colors.teal];
    
    List<Widget> barSegments = [];
    List<Widget> legendItems = [];
    int i = 0;
    
    var sortedEntries = categoryTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    
    int processedCount = 0;
    int totalCount = sortedEntries.length;

    for (var entry in sortedEntries) {
      String name = entry.key;
      double amount = entry.value;
      Color c = colors[i % colors.length];
      int flex = (amount / totalExpense * 100).toInt();
      if (flex == 0 && amount > 0) flex = 1;
      
      processedCount++;
      BorderRadiusGeometry radius = BorderRadius.zero;
      if (totalCount == 1) {
        radius = BorderRadius.circular(8);
      } else if (processedCount == 1) {
        radius = const BorderRadius.only(topLeft: Radius.circular(8), bottomLeft: Radius.circular(8));
      } else if (processedCount == totalCount) {
        radius = const BorderRadius.only(topRight: Radius.circular(8), bottomRight: Radius.circular(8));
      }

      if (flex > 0) {
        barSegments.add(Expanded(
          flex: flex,
          child: Container(
            height: 24,
            decoration: BoxDecoration(color: c, borderRadius: radius),
          )
        ));
      }
      
      double percent = (amount / totalExpense) * 100;
      legendItems.add(Padding(
        padding: const EdgeInsets.only(right: 16, bottom: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 12, height: 12, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 6),
            Text('$name (${percent.toStringAsFixed(1)}%)', style: const TextStyle(fontSize: 12)),
          ],
        ),
      ));
      
      i++;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: barSegments),
        const SizedBox(height: 24),
        Wrap(children: legendItems),
      ],
    );
  }

  // ================= SPLITWISE MODE =================

  Widget _buildSplitwiseTab(ApiProvider api) {
    final splits = api.transactions.where((t) => t['transaction_type'] == 'split' || t['transaction_type'] == null).toList();

    double totalInflow = 0; 
    double totalOutflow = 0; 

    Map<String, double> personBalances = {};
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
                Expanded(child: _buildKPICard('Balance', netBalance, netBalance >= 0 ? AppTheme.successColor(context) : AppTheme.errorColor(context))),
                const SizedBox(width: 8),
                Expanded(child: _buildKPICard('Owed to You', totalInflow, AppTheme.successColor(context))),
                const SizedBox(width: 8),
                Expanded(child: _buildKPICard('You Owe', totalOutflow, AppTheme.errorColor(context))),
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
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1)),
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
            color: balance >= 0 ? AppTheme.successColor(context) : AppTheme.errorColor(context),
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
        borderData: FlBorderData(show: true, border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.15)))),
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
      color: Theme.of(context).colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: owesYou ? AppTheme.successColor(context).withOpacity(0.1) : AppTheme.errorColor(context).withOpacity(0.1),
          child: Text(person.isNotEmpty ? person[0].toUpperCase() : '?', style: TextStyle(color: owesYou ? AppTheme.successColor(context) : AppTheme.errorColor(context), fontWeight: FontWeight.bold)),
        ),
        title: Text(person, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          owesYou ? 'Owes you ${currencyFormatter.format(balance)}' : 'You owe ${currencyFormatter.format(balance.abs())}',
          style: TextStyle(color: owesYou ? AppTheme.successColor(context) : AppTheme.errorColor(context), fontWeight: FontWeight.bold),
        ),
        children: history.map((t) {
          double amt = double.parse(t['amount'].toString());
          String creditor = t['creditor'].toString();
          bool isPositive = creditor.toLowerCase() == 'self';
          DateTime date = t['created_at'] != null ? DateTime.parse(t['created_at']).toLocal() : DateTime.now();

          return Dismissible(
            key: Key(t['id'].toString()),
            direction: DismissDirection.endToStart,
            background: Container(
              color: AppTheme.errorColor(context),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20.0),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            onDismissed: (direction) {
              Provider.of<ApiProvider>(context, listen: false).deleteTransaction(t['id'].toString());
            },
            child: Container(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
              child: ListTile(
                dense: true,
                title: Text(t['description'] ?? 'Transaction'),
                subtitle: Text(DateFormat('MMM d, h:mm a').format(date)),
                trailing: Text(
                  '${isPositive ? '+' : '-'}${currencyFormatter.format(amt)}',
                  style: TextStyle(color: isPositive ? AppTheme.successColor(context) : AppTheme.errorColor(context), fontWeight: FontWeight.bold),
                ),
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
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Row(
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
        actions: [
          if (_currentMode == 0)
            IconButton(
              icon: Icon(_showChart ? Icons.bar_chart : Icons.pie_chart),
              onPressed: () => setState(() => _showChart = !_showChart),
            ),
          
        ],
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
                          return Theme.of(context).colorScheme.primary;
                        }
                        return Theme.of(context).colorScheme.surface;
                      }),
                      foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                        if (states.contains(WidgetState.selected)) {
                          return Theme.of(context).colorScheme.onPrimary;
                        }
                        return Theme.of(context).colorScheme.onBackground;
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
