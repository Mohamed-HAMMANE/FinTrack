import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../Helpers/DatabaseHelper.dart';

class CategoryExpensePieChart extends StatefulWidget {
  final DateTime date;
  final bool isSubView;
  const CategoryExpensePieChart(this.date, {super.key, this.isSubView = false});

  @override
  State<CategoryExpensePieChart> createState() =>
      _CategoryExpensePieChartState();
}

class _CategoryExpensePieChartState extends State<CategoryExpensePieChart> {
  List<Map<String, dynamic>> _monthlyExpense = [];
  List<Map<String, dynamic>> _monthlyIncome = [];
  List<Map<String, dynamic>> _monthlyBudgetActual = [];
  List<Map<String, dynamic>> _categoryBreakdown = [];
  List<Map<String, dynamic>> _dailySpending = [];
  List<Map<String, dynamic>> _monthComparison = [];
  List<Map<String, dynamic>> _topExpenses = [];
  List<Map<String, dynamic>> _savingsTrend = [];
  bool isLoading = true;

  // Date range filter state
  String _selectedRange = 'This Month';
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  @override
  void initState() {
    super.initState();
    fetchCategoryExpenses();
  }

  // Get start and end dates based on selected range
  Map<String, DateTime> _getDateRange() {
    final now = DateTime.now();
    DateTime start, end;

    if (_customStartDate != null && _customEndDate != null) {
      return {'start': _customStartDate!, 'end': _customEndDate!};
    }

    switch (_selectedRange) {
      case 'Last 30 Days':
        start = now.subtract(const Duration(days: 30));
        end = now;
        break;
      case 'Last 3 Months':
        start = DateTime(now.year, now.month - 3, 1);
        end = now;
        break;
      case 'This Year':
        start = DateTime(now.year, 1, 1);
        end = now;
        break;
      case 'This Month':
      default:
        start = DateTime(widget.date.year, widget.date.month, 1);
        end = DateTime(widget.date.year, widget.date.month + 1, 0);
        break;
    }
    return {'start': start, 'end': end};
  }

  Future<void> fetchCategoryExpenses() async {
    final dateRange = _getDateRange();
    final startDate = dateRange['start']!;
    final endDate = dateRange['end']!;
    final startStr =
        "${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}";
    final endStr =
        "${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}";

    // Define queries as Futures
    final monthlyExpenseFuture = DatabaseHelper.select('''
      SELECT * FROM (
        SELECT strftime('%Y-%m', Date) as Month, SUM(Amount) as Total
        FROM Expense
        GROUP BY strftime('%Y-%m', Date)
        ORDER BY strftime('%Y-%m', Date) DESC
        LIMIT 10)
      ORDER BY Month
    ''');

    final monthlyIncomeFuture = DatabaseHelper.select('''
      SELECT * FROM (
        SELECT strftime('%Y-%m', Date) as Month, 
          SUM(CASE WHEN Amount >= 0 THEN Amount ELSE 0 END) as Income, 
          SUM(CASE WHEN Amount < 0 THEN Amount ELSE 0 END) as Outcome
        FROM Expense
        GROUP BY strftime('%Y-%m', Date)
        ORDER BY strftime('%Y-%m', Date) DESC
        LIMIT 10)
      ORDER BY Month
    ''');

    final monthlyBudgetActualFuture = DatabaseHelper.select('''
      SELECT
          Category.Name AS Category,
          Category.IconCode,
          ABS(Category.Budget) AS Budget,
          IFNULL(ABS(SUM(Expense.Amount)), 0) AS Actual
      FROM Category 
      LEFT JOIN Expense ON Category.Id = Expense.CategoryId 
        AND CAST(strftime('%Y', Expense.Date) AS INTEGER) = ${widget.date.year} 
        AND CAST(strftime('%m', Expense.Date) AS INTEGER) = ${widget.date.month}
      WHERE Category.Budget != 0
      GROUP BY Category.Id
      ORDER BY Category.Name;
    ''');

    final categoryBreakdownFuture = DatabaseHelper.select('''
      SELECT
        Category.Name AS Category,
        Category.IconCode,
        ABS(SUM(Expense.Amount)) AS Total
      FROM Expense
      INNER JOIN Category ON Expense.CategoryId = Category.Id
      WHERE Expense.Amount < 0 AND Expense.Date BETWEEN '$startStr' AND '$endStr'
      GROUP BY Category.Id
      ORDER BY Total DESC
    ''');

    final dailySpendingFuture = DatabaseHelper.select('''
      SELECT
        strftime('%d', Date) AS Day,
        ABS(SUM(CASE WHEN Amount < 0 THEN Amount ELSE 0 END)) AS Total
      FROM Expense
      WHERE CAST(strftime('%Y', Date) AS INTEGER) = ${widget.date.year}
        AND CAST(strftime('%m', Date) AS INTEGER) = ${widget.date.month}
      GROUP BY strftime('%d', Date)
      ORDER BY Day
    ''');

    final monthComparisonFuture = DatabaseHelper.select('''
      SELECT * FROM (
        SELECT
          strftime('%Y-%m', Date) AS Month,
          SUM(CASE WHEN Amount >= 0 THEN Amount ELSE 0 END) AS Income,
          ABS(SUM(CASE WHEN Amount < 0 THEN Amount ELSE 0 END)) AS Expenses
        FROM Expense
        GROUP BY strftime('%Y-%m', Date)
        ORDER BY Month DESC
        LIMIT 6
      )
      ORDER BY Month
    ''');

    final topExpensesFuture = DatabaseHelper.select('''
      SELECT
        Expense.Id,
        ABS(Expense.Amount) AS Amount,
        Expense.Comment,
        Expense.Date,
        Category.Name AS Category,
        Category.IconCode
      FROM Expense
      INNER JOIN Category ON Expense.CategoryId = Category.Id
      WHERE Expense.Amount < 0 AND Expense.Date BETWEEN '$startStr' AND '$endStr'
      ORDER BY ABS(Expense.Amount) DESC
      LIMIT 10
    ''');

    final savingsTrendFuture = DatabaseHelper.select('''
      SELECT
        strftime('%Y-%m', Date) AS Month,
        SUM(Amount)*-1 AS MonthTotal
      FROM Expense
      INNER JOIN Category ON Expense.CategoryId = Category.Id
      WHERE Category.Name = 'Emergency Fund'
      GROUP BY strftime('%Y-%m', Date)
      ORDER BY Month
    ''');

    // Execute all in parallel
    final results = await Future.wait([
      monthlyExpenseFuture,
      monthlyIncomeFuture,
      monthlyBudgetActualFuture,
      categoryBreakdownFuture,
      dailySpendingFuture,
      monthComparisonFuture,
      topExpensesFuture,
      savingsTrendFuture,
    ]);

    // Assign results
    _monthlyExpense = results[0];
    _monthlyIncome = results[1];
    _monthlyBudgetActual = results[2];
    _categoryBreakdown = results[3];
    _dailySpending = results[4];
    _monthComparison = results[5];
    _topExpenses = results[6];
    final rawSavings = results[7];

    // Calculate cumulative sum by month (processed in Dart)
    _savingsTrend = [];
    double cumulative = 0;
    for (var row in rawSavings) {
      cumulative += (row['MonthTotal'] as num).toDouble();
      _savingsTrend.add({'Month': row['Month'], 'Cumulative': cumulative});
    }

    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());

    // Calculate chart data
    List<String> incMonths = [];
    var monthlyIncomeDataPoints = List<FlSpot>.empty(growable: true);
    var monthlyOutcomeDataPoints = List<FlSpot>.empty(growable: true);
    for (int i = 0; i < _monthlyIncome.length; i++) {
      var row = _monthlyIncome[i];
      double income = (row['Income'] as num).toDouble();
      double outcome = (row['Outcome'] as num).toDouble();
      incMonths.add(row['Month']);
      monthlyIncomeDataPoints.add(FlSpot(i.toDouble(), income));
      monthlyOutcomeDataPoints.add(FlSpot(i.toDouble(), outcome));
    }

    var monthlyExpenseDataPoints = _monthlyExpense.asMap().entries.map((entry) {
      int index = entry.key;
      double total = (entry.value['Total'] as num).toDouble();
      return FlSpot(index.toDouble(), total);
    }).toList();

    Widget content = SingleChildScrollView(
      child: Column(
        spacing: 20,
        children: [
          // Date Range Selector
          Card(
            margin: const EdgeInsets.all(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Date Range:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('This Month'),
                        selected: _selectedRange == 'This Month',
                        onSelected: (_) {
                          setState(() {
                            _selectedRange = 'This Month';
                            _customStartDate = null;
                            _customEndDate = null;
                            isLoading = true;
                            fetchCategoryExpenses();
                          });
                        },
                      ),
                      ChoiceChip(
                        label: const Text('Last 30 Days'),
                        selected: _selectedRange == 'Last 30 Days',
                        onSelected: (_) {
                          setState(() {
                            _selectedRange = 'Last 30 Days';
                            _customStartDate = null;
                            _customEndDate = null;
                            isLoading = true;
                            fetchCategoryExpenses();
                          });
                        },
                      ),
                      ChoiceChip(
                        label: const Text('Last 3 Months'),
                        selected: _selectedRange == 'Last 3 Months',
                        onSelected: (_) {
                          setState(() {
                            _selectedRange = 'Last 3 Months';
                            _customStartDate = null;
                            _customEndDate = null;
                            isLoading = true;
                            fetchCategoryExpenses();
                          });
                        },
                      ),
                      ChoiceChip(
                        label: const Text('This Year'),
                        selected: _selectedRange == 'This Year',
                        onSelected: (_) {
                          setState(() {
                            _selectedRange = 'This Year';
                            _customStartDate = null;
                            _customEndDate = null;
                            isLoading = true;
                            fetchCategoryExpenses();
                          });
                        },
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.date_range, size: 18),
                        label: Text(
                          _customStartDate != null && _customEndDate != null
                              ? 'Custom Range'
                              : 'Custom',
                        ),
                        onPressed: () async {
                          final picked = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setState(() {
                              _selectedRange = 'Custom';
                              _customStartDate = picked.start;
                              _customEndDate = picked.end;
                              isLoading = true;
                              fetchCategoryExpenses();
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: EdgeInsets.only(top: 20),
              child: Column(
                spacing: 20,
                children: [
                  const Text(
                    'Monthly Income/Outcome Trends',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  AspectRatio(
                    aspectRatio: 16 / 13,
                    child: LineChart(
                      LineChartData(
                        lineTouchData: LineTouchData(
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipItems: (List<LineBarSpot> touchedSpots) {
                              return touchedSpots.map((
                                LineBarSpot touchedSpot,
                              ) {
                                return LineTooltipItem(
                                  NumberFormat.decimalPatternDigits(
                                    locale: 'fr_fr',
                                    decimalDigits: 2,
                                  ).format(touchedSpot.y),
                                  const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              }).toList();
                            },
                          ),
                        ),
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true, // Keep the X-axis values
                              reservedSize: 30,
                              interval: 1,
                              getTitlesWidget: (value, meta) {
                                int index = value.toInt();
                                if (index >= 0 && index < incMonths.length) {
                                  return Text(
                                    incMonths[index],
                                    style: const TextStyle(fontSize: 9),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                          topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        borderData: FlBorderData(
                          show: true,
                          border: const Border(
                            left: BorderSide(width: 20),
                            right: BorderSide(width: 20),
                          ),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: monthlyExpenseDataPoints,
                            barWidth: 4,
                            isStrokeCapRound: true,
                            color: Colors.white,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, barData, index) {
                                return FlDotCirclePainter(
                                  radius: 4,
                                  color: Colors.blueGrey,
                                  strokeWidth: 2,
                                  strokeColor: Colors.black,
                                );
                              },
                            ),
                          ),
                          LineChartBarData(
                            spots: monthlyIncomeDataPoints,
                            isCurved: true,
                            barWidth: 4,
                            isStrokeCapRound: true,
                            color: Colors.green,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, barData, index) {
                                return FlDotCirclePainter(
                                  radius: 4,
                                  color: Colors.blueGrey,
                                  strokeWidth: 2,
                                  strokeColor: Colors.black,
                                );
                              },
                            ),
                          ),
                          LineChartBarData(
                            spots: monthlyOutcomeDataPoints,
                            isCurved: true,
                            barWidth: 4,
                            isStrokeCapRound: true,
                            color: Colors.red,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, barData, index) {
                                return FlDotCirclePainter(
                                  radius: 4,
                                  color: Colors.blueGrey,
                                  strokeWidth: 2,
                                  strokeColor: Colors.black,
                                );
                              },
                            ),
                          ),
                        ],
                        extraLinesData: ExtraLinesData(
                          horizontalLines: [
                            HorizontalLine(
                              y: 0,
                              color: Colors.green,
                              strokeWidth: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Category Breakdown Pie Chart
          if (_categoryBreakdown.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  spacing: 10,
                  children: [
                    const Text(
                      'Spending by Category',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    AspectRatio(
                      aspectRatio: 16 / 10,
                      child: PieChart(
                        PieChartData(
                          sections: _categoryBreakdown.asMap().entries.map((
                            entry,
                          ) {
                            final index = entry.key;
                            final data = entry.value;
                            final total = _categoryBreakdown.fold(
                              0.0,
                              (sum, item) => sum + item['Total'],
                            );
                            final percentage = (data['Total'] / total) * 100;
                            final colors = [
                              Colors.blue,
                              Colors.red,
                              Colors.green,
                              Colors.orange,
                              Colors.purple,
                              Colors.teal,
                              Colors.pink,
                              Colors.amber,
                              Colors.cyan,
                              Colors.indigo,
                            ];
                            return PieChartSectionData(
                              color: colors[index % colors.length],
                              value: data['Total'].toDouble(),
                              title: '${percentage.toStringAsFixed(0)}%',
                              titleStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              radius: 100,
                            );
                          }).toList(),
                          sectionsSpace: 2,
                          centerSpaceRadius: 0,
                          pieTouchData: PieTouchData(
                            touchCallback: (FlTouchEvent event, pieTouchResponse) {
                              if (event is FlTapUpEvent &&
                                  pieTouchResponse?.touchedSection != null) {
                                final index = pieTouchResponse!
                                    .touchedSection!
                                    .touchedSectionIndex;
                                if (index >= 0 &&
                                    index < _categoryBreakdown.length) {
                                  final category = _categoryBreakdown[index];
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Row(
                                        children: [
                                          Icon(
                                            IconData(
                                              category['IconCode'],
                                              fontFamily: 'MaterialIcons',
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(category['Category']),
                                        ],
                                      ),
                                      content: Text(
                                        'Total Spent: ${NumberFormat.decimalPatternDigits(locale: 'fr_fr', decimalDigits: 2).format(category['Total'])} DH',
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: const Text('Close'),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                    // Legend
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: _categoryBreakdown.asMap().entries.map((entry) {
                        final index = entry.key;
                        final data = entry.value;
                        final colors = [
                          Colors.blue,
                          Colors.red,
                          Colors.green,
                          Colors.orange,
                          Colors.purple,
                          Colors.teal,
                          Colors.pink,
                          Colors.amber,
                          Colors.cyan,
                          Colors.indigo,
                        ];
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              color: colors[index % colors.length],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              data['Category'],
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),

          // Daily Spending Line Chart
          if (_dailySpending.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Column(
                  spacing: 20,
                  children: [
                    const Text(
                      'Daily Spending This Month',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    AspectRatio(
                      aspectRatio: 16 / 10,
                      child: LineChart(
                        LineChartData(
                          lineTouchData: LineTouchData(
                            touchTooltipData: LineTouchTooltipData(
                              getTooltipItems:
                                  (List<LineBarSpot> touchedSpots) {
                                    return touchedSpots.map((
                                      LineBarSpot touchedSpot,
                                    ) {
                                      return LineTooltipItem(
                                        NumberFormat.decimalPatternDigits(
                                          locale: 'fr_fr',
                                          decimalDigits: 2,
                                        ).format(touchedSpot.y),
                                        const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      );
                                    }).toList();
                                  },
                            ),
                          ),
                          titlesData: FlTitlesData(
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 30,
                                interval: 5,
                                getTitlesWidget: (value, meta) {
                                  return Text(
                                    value.toInt().toString(),
                                    style: const TextStyle(fontSize: 10),
                                  );
                                },
                              ),
                            ),
                            topTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                          borderData: FlBorderData(show: true),
                          lineBarsData: [
                            LineChartBarData(
                              spots: _dailySpending.map((data) {
                                return FlSpot(
                                  double.parse(data['Day']),
                                  data['Total'].toDouble(),
                                );
                              }).toList(),
                              isCurved: true,
                              barWidth: 3,
                              isStrokeCapRound: true,
                              color: Colors.blue,
                              dotData: FlDotData(
                                show: true,
                                getDotPainter: (spot, percent, barData, index) {
                                  return FlDotCirclePainter(
                                    radius: 4,
                                    color: Colors.blue,
                                    strokeWidth: 2,
                                    strokeColor: Colors.white,
                                  );
                                },
                              ),
                              belowBarData: BarAreaData(
                                show: true,
                                color: Colors.blue.withValues(alpha: 0.2),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Emergency Fund Cumulative Savings Trend
          if (_savingsTrend.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.only(
                  top: 20,
                  left: 10,
                  right: 10,
                  bottom: 10,
                ),
                child: Column(
                  spacing: 20,
                  children: [
                    const Text(
                      'Emergency Fund - Cumulative Savings',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    // Display current total
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.savings,
                            color: Colors.green,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Total Saved: ${NumberFormat.decimalPatternDigits(locale: 'fr_fr', decimalDigits: 2).format(_savingsTrend.last['Cumulative'])} DH',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AspectRatio(
                      aspectRatio: 16 / 10,
                      child: LineChart(
                        LineChartData(
                          lineTouchData: LineTouchData(
                            touchTooltipData: LineTouchTooltipData(
                              getTooltipItems:
                                  (List<LineBarSpot> touchedSpots) {
                                    return touchedSpots.map((
                                      LineBarSpot touchedSpot,
                                    ) {
                                      return LineTooltipItem(
                                        NumberFormat.decimalPatternDigits(
                                          locale: 'fr_fr',
                                          decimalDigits: 2,
                                        ).format(touchedSpot.y),
                                        const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      );
                                    }).toList();
                                  },
                            ),
                          ),
                          titlesData: FlTitlesData(
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 40,
                                getTitlesWidget: (value, meta) {
                                  final index = value.toInt();
                                  if (index >= 0 &&
                                      index < _savingsTrend.length) {
                                    final month = _savingsTrend[index]['Month'];
                                    // Show every 3rd month or first/last
                                    if (index % 3 == 0 ||
                                        index == _savingsTrend.length - 1) {
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          month, // Show YYYY-MM
                                          style: const TextStyle(fontSize: 9),
                                        ),
                                      );
                                    }
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            topTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                          borderData: FlBorderData(show: true),
                          lineBarsData: [
                            LineChartBarData(
                              spots: _savingsTrend.asMap().entries.map((entry) {
                                return FlSpot(
                                  entry.key.toDouble(),
                                  entry.value['Cumulative'].toDouble(),
                                );
                              }).toList(),
                              isCurved: true,
                              barWidth: 3,
                              isStrokeCapRound: true,
                              color: Colors.green,
                              dotData: FlDotData(
                                show: true,
                                getDotPainter: (spot, percent, barData, index) {
                                  return FlDotCirclePainter(
                                    radius: 4,
                                    color: Colors.green,
                                    strokeWidth: 2,
                                    strokeColor: Colors.white,
                                  );
                                },
                              ),
                              belowBarData: BarAreaData(
                                show: true,
                                color: Colors.green.withValues(alpha: 0.2),
                              ),
                            ),
                          ],
                          minY: 0,
                        ),
                      ),
                    ),
                    Text(
                      '${_savingsTrend.length} months of savings history',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),

          // Month-over-Month Bar Chart
          if (_monthComparison.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Column(
                  spacing: 20,
                  children: [
                    const Text(
                      'Monthly Comparison (Last 6 Months)',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    AspectRatio(
                      aspectRatio: 16 / 10,
                      child: BarChart(
                        BarChartData(
                          barTouchData: BarTouchData(
                            enabled: true,
                            touchTooltipData: BarTouchTooltipData(
                              getTooltipItem:
                                  (group, groupIndex, rod, rodIndex) {
                                    return BarTooltipItem(
                                      NumberFormat.decimalPatternDigits(
                                        locale: 'fr_fr',
                                        decimalDigits: 2,
                                      ).format(rod.toY),
                                      const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    );
                                  },
                            ),
                          ),
                          barGroups: _monthComparison.asMap().entries.map((
                            entry,
                          ) {
                            final index = entry.key;
                            final data = entry.value;
                            return BarChartGroupData(
                              x: index,
                              barRods: [
                                BarChartRodData(
                                  toY: data['Income'].toDouble(),
                                  color: Colors.green,
                                  width: 12,
                                ),
                                BarChartRodData(
                                  toY: data['Expenses'].toDouble(),
                                  color: Colors.red,
                                  width: 12,
                                ),
                              ],
                            );
                          }).toList(),
                          titlesData: FlTitlesData(
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 30,
                                getTitlesWidget: (value, meta) {
                                  final index = value.toInt();
                                  if (index >= 0 &&
                                      index < _monthComparison.length) {
                                    return Text(
                                      _monthComparison[index]['Month'],
                                      style: const TextStyle(fontSize: 9),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                            ),
                            topTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                          borderData: FlBorderData(show: true),
                        ),
                      ),
                    ),
                    // Legend
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              color: Colors.green,
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'Income',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Row(
                          children: [
                            Container(width: 16, height: 16, color: Colors.red),
                            const SizedBox(width: 4),
                            const Text(
                              'Expenses',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),

          const Text(
            'Budget vs Actuals by Category',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: _monthlyBudgetActual.length,
            itemBuilder: (context, index) {
              final data = _monthlyBudgetActual[index];
              final category = data['Category'];
              final budget = data['Budget'];
              final actual = data['Actual'];
              int iconCode = data["IconCode"];
              var icon = iconCode == 0
                  ? Icons.question_mark
                  : IconData(iconCode, fontFamily: 'MaterialIcons');
              final overBudget = actual > budget;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    spacing: 8,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        spacing: 12,
                        children: [
                          Icon(icon),
                          Text(
                            category,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Budget: ${NumberFormat.decimalPatternDigits(locale: 'fr_fr', decimalDigits: 2).format(budget)}DH',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.blueAccent,
                            ),
                          ),
                          Text(
                            'Actual: ${NumberFormat.decimalPatternDigits(locale: 'fr_fr', decimalDigits: 2).format(actual)}DH',
                            style: TextStyle(
                              fontSize: 16,
                              color: overBudget ? Colors.red : Colors.green,
                            ),
                          ),
                        ],
                      ),
                      LinearProgressIndicator(
                        value: actual / (budget == 0 ? 1 : budget),
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          overBudget ? Colors.red : Colors.green,
                        ),
                      ),
                      Text(
                        overBudget
                            ? 'Over budget by ${NumberFormat.decimalPatternDigits(locale: 'fr_fr', decimalDigits: 2).format(actual - budget)}DH'
                            : 'Remaining budget: ${NumberFormat.decimalPatternDigits(locale: 'fr_fr', decimalDigits: 2).format(budget - actual)}DH',
                        style: TextStyle(
                          fontSize: 14,
                          color: overBudget ? Colors.red : Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Top 10 Expenses
          if (_topExpenses.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'Top 10 Expenses',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _topExpenses.length,
              itemBuilder: (context, index) {
                final expense = _topExpenses[index];
                final amount = expense['Amount'];
                final comment = expense['Comment'];
                final date = expense['Date'];
                final category = expense['Category'];
                int iconCode = expense['IconCode'];
                var icon = iconCode == 0
                    ? Icons.question_mark
                    : IconData(iconCode, fontFamily: 'MaterialIcons');

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  elevation: 2,
                  child: ListTile(
                    leading: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, size: 24),
                        Text(
                          category,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    title: Text(
                      '${NumberFormat.decimalPatternDigits(locale: 'fr_fr', decimalDigits: 2).format(amount)} DH',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          comment,
                          style: const TextStyle(fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          date,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    trailing: Text(
                      '#${index + 1}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[400],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );

    if (widget.isSubView) return content;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          spacing: 10,
          children: [Icon(Icons.dashboard), Text('Charts')],
        ),
      ),
      body: content,
    );
  }
}
