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
  bool _showPieChart = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ApiProvider>(context, listen: false).fetchTransactions();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Finances', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(_showPieChart ? Icons.bar_chart : Icons.pie_chart),
            onPressed: () {
              setState(() {
                _showPieChart = !_showPieChart;
              });
            },
          )
        ],
      ),
      body: Consumer<ApiProvider>(
        builder: (context, api, child) {
          if (api.isLoading && api.transactions.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (api.transactions.isEmpty) {
            return const Center(child: Text("No transactions recorded."));
          }

          // Compute KPI
          double inflow = 0;
          double outflow = 0;

          for (var t in api.transactions) {
            double amt = double.parse(t['amount'].toString());
            String creditor = t['creditor'].toString().toLowerCase();
            String debtor = t['debtor'].toString().toLowerCase();

            if (creditor == 'self') inflow += amt;
            if (debtor == 'self') outflow += amt;
          }

          double balance = inflow - outflow;

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      Expanded(child: _buildKPICard('Balance', balance, balance >= 0 ? AppTheme.success : AppTheme.error)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildKPICard('Inflow', inflow, AppTheme.success)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildKPICard('Outflow', outflow, AppTheme.error)),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _buildChart(api.transactions),
              ),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Recent Transactions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final t = api.transactions[index];
                    return _buildTransactionTile(t);
                  },
                  childCount: api.transactions.length,
                ),
              ),
            ],
          );
        },
      ),
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

  Widget _buildChart(List<dynamic> transactions) {
    return Container(
      height: 220,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: _showPieChart ? _buildPieChart(transactions) : _buildBarChart(transactions),
    );
  }

  Widget _buildPieChart(List<dynamic> transactions) {
    // Group outflow by debtor to see who we owe, or creditor if we are the debtor
    Map<String, double> categories = {};
    for (var t in transactions) {
      double amt = double.parse(t['amount'].toString());
      String debtor = t['debtor'].toString();
      String creditor = t['creditor'].toString();
      
      if (debtor.toLowerCase() == 'self') {
        categories[creditor] = (categories[creditor] ?? 0) + amt;
      }
    }

    if (categories.isEmpty) {
      return const Center(child: Text("No outflow data for pie chart."));
    }

    List<PieChartSectionData> sections = [];
    int i = 0;
    List<Color> colors = [AppTheme.primary, AppTheme.secondary, AppTheme.tertiary, AppTheme.warning, AppTheme.error];
    
    categories.forEach((name, amount) {
      sections.add(PieChartSectionData(
        value: amount,
        title: name,
        color: colors[i % colors.length],
        radius: 60,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      ));
      i++;
    });

    return PieChart(PieChartData(sectionsSpace: 2, centerSpaceRadius: 30, sections: sections));
  }

  Widget _buildBarChart(List<dynamic> transactions) {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 5000,
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, getTitlesWidget: (val, meta) => Text('D${val.toInt()}')),
          ),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(show: false),
        barGroups: List.generate(5, (index) {
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: (index + 1) * 1000 % 5000, 
                color: AppTheme.primary,
                width: 16,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildTransactionTile(dynamic t) {
    String creditor = t['creditor'].toString();
    String debtor = t['debtor'].toString();
    double amt = double.parse(t['amount'].toString());
    
    bool isInflow = creditor.toLowerCase() == 'self';
    String otherParty = isInflow ? debtor : creditor;
    
    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    DateTime date = DateTime.parse(t['created_at']).toLocal();
    String formattedDate = DateFormat('MMM d, h:mm a').format(date);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isInflow ? AppTheme.success.withOpacity(0.1) : AppTheme.error.withOpacity(0.1),
          child: Icon(
            isInflow ? Icons.arrow_downward : Icons.arrow_upward,
            color: isInflow ? AppTheme.success : AppTheme.error,
          ),
        ),
        title: Text(t['description'] ?? otherParty, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(formattedDate, style: const TextStyle(fontSize: 12)),
        trailing: Text(
          '${isInflow ? '+' : '-'}${currencyFormatter.format(amt)}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isInflow ? AppTheme.success : AppTheme.error,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
