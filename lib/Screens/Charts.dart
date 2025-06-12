import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../Helpers/DatabaseHelper.dart';

class CategoryExpensePieChart extends StatefulWidget {
  final DateTime date;
  const CategoryExpensePieChart(this.date,{super.key});

  @override
  State<CategoryExpensePieChart> createState() => _CategoryExpensePieChartState();
}

class _CategoryExpensePieChartState extends State<CategoryExpensePieChart> {
  List<Map<String, dynamic>> _monthlyExpense = [];
  List<Map<String, dynamic>> _monthlyIncome = [];
  List<Map<String, dynamic>> _monthlyBudgetActual = [];
  Map<String, dynamic> _expenseRemaining = {"TotalExpenses":0.0,"MaxSpend":0.0};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchCategoryExpenses();
  }

  Future<void> fetchCategoryExpenses() async {
    _monthlyExpense = await DatabaseHelper.select('''
      SELECT * FROM (
        SELECT strftime('%Y-%m', Date) as Month, SUM(Amount) as Total
        FROM Expense
        GROUP BY strftime('%Y-%m', Date)
        ORDER BY strftime('%Y-%m', Date) DESC
        LIMIT 10)
      ORDER BY Month
    ''');

    _monthlyIncome = await DatabaseHelper.select('''
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

    _monthlyBudgetActual = await DatabaseHelper.select('''
      SELECT 
          Category.Name AS Category,
          Category.IconCode,
          ABS(Category.Budget) AS Budget,
          IFNULL(SUM(ABS(Expense.Amount)), 0) AS Actual
      FROM Category LEFT JOIN Expense ON Category.Id = Expense.CategoryId
      WHERE CAST(strftime('%Y', Date) AS INTEGER) = ${widget.date.year} AND CAST(strftime('%m', Date) AS INTEGER) = ${widget.date.month} AND Category.Budget < 0
      GROUP BY Category.Id
      ORDER BY Category.Name;
    ''');

    _expenseRemaining = (await DatabaseHelper.select('''
      SELECT 
          SUM(CASE WHEN Amount >= 0 THEN Amount ELSE 0 END) AS MaxSpend,
          ABS(SUM(CASE WHEN Amount < 0 THEN Amount ELSE 0 END)) AS TotalExpenses
      FROM Expense
      WHERE CAST(strftime('%Y', Date) AS INTEGER) = ${widget.date.year} AND CAST(strftime('%m', Date) AS INTEGER) = ${widget.date.month}
    ''')).first;

    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {

    List<String> expMonths = [];
    var monthlyExpenseDataPoints = _monthlyExpense.asMap().entries.map((entry) {
      int index = entry.key;
      double total = entry.value['Total'].truncateToDouble();
      expMonths.add(entry.value['Month']); // Save month labels
      return FlSpot(index.toDouble(), total); // x: index, y: total
    }).toList();

    List<String> incMonths = [];
    var monthlyIncomeDataPoints = List<FlSpot>.empty(growable: true);
    var monthlyOutcomeDataPoints = List<FlSpot>.empty(growable: true);
    int index = 0;
    for(var row in _monthlyIncome){
      double income = row['Income'].truncateToDouble();
      double outcome = row['Outcome'].truncateToDouble();
      incMonths.add(row['Month']);
      monthlyIncomeDataPoints.add(FlSpot(index.toDouble(), income));
      monthlyOutcomeDataPoints.add(FlSpot(index.toDouble(), outcome));
      index++;
    }

    List<BarChartGroupData> barGroups = [];
    List<String> categories = [];
    _monthlyBudgetActual.asMap().entries.forEach((entry) {
      int index = entry.key;
      var data = entry.value;

      categories.add(data['Category']); // Save category names

      barGroups.add(
        BarChartGroupData(
          x: index,
          barRods: [
            // Budget Bar
            BarChartRodData(
              toY: data['Budget'].toDouble(),
              color: Colors.blue,
              width: 12,
            ),
            // Actual Bar
            BarChartRodData(
              toY: data['Actual'].toDouble(),
              color: Colors.green,
              width: 12,
            ),
          ],
          showingTooltipIndicators: [0, 1],
        ),
      );
    });

    final double totalExpenses = _expenseRemaining["TotalExpenses"];
    final double maxSpend = _expenseRemaining["MaxSpend"];
    double percentageUsed;
    double percentageLeft;

    percentageUsed = (totalExpenses / maxSpend) * 100;
    if (totalExpenses > maxSpend) {
      percentageLeft = 0;
    } else {
      percentageLeft = 100 - percentageUsed;
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          spacing: 10,
          children: [
            Icon(Icons.dashboard),
            Text('Charts')
          ]
        )
      ),
      body: isLoading ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(
        child: Column(
            spacing: 20,
            children: [
              Card(
                child: Padding(
                  padding: EdgeInsets.only(top: 20),
                  child: Column(
                    spacing: 20,
                    children: [
                      const Text(
                          'Monthly Income/Outcome Trends',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)
                      ),
                      AspectRatio(
                          aspectRatio: 16 / 13,
                          child: LineChart(
                              LineChartData(
                                  titlesData: FlTitlesData(
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true, // Keep the X-axis values
                                        reservedSize: 30,
                                        interval: 1,
                                        getTitlesWidget: (value, meta) {
                                          int index = value.toInt();
                                          if (index >= 0 && index < incMonths.length) {
                                            return Text(incMonths[index], style: const TextStyle(fontSize: 9));
                                          }
                                          return const SizedBox.shrink();
                                        },
                                      ),
                                    ),
                                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  ),
                                  borderData: FlBorderData(show: true, border: const Border(left: BorderSide(width: 20),right: BorderSide(width: 20))),
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
                                                  strokeColor: Colors.black
                                              );
                                            }
                                        )
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
                                                  strokeColor: Colors.black
                                              );
                                            }
                                        )
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
                                                  strokeColor: Colors.black
                                              );
                                            }
                                        )
                                    )
                                  ],
                                  extraLinesData: ExtraLinesData(
                                    horizontalLines: [
                                      HorizontalLine(y: 0, color: Colors.green, strokeWidth: 2),
                                    ],
                                  )
                              )
                          )
                      ),
                    ],
                  ),
                ),
              ),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    spacing: 5,
                    children: [
                      const Text(
                          'Expense vs Remaining Budget',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)
                      ),
                      AspectRatio(
                        aspectRatio: 16 / 10,
                        child: PieChart(
                          PieChartData(
                              sections: [
                                // Expenses Section
                                PieChartSectionData(
                                    color: Colors.red,
                                    value: percentageUsed,
                                    title: 'Expenses ${percentageUsed.toStringAsFixed(0)}%',
                                    titleStyle: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                    radius: 100
                                ),
                                // Remaining Section
                                PieChartSectionData(
                                    color: Colors.green,
                                    value: percentageLeft,
                                    title: 'Rest ${percentageLeft.toStringAsFixed(0)}%',
                                    titleStyle: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                    radius: 100
                                ),
                              ],
                              sectionsSpace: 2,
                              centerSpaceRadius: 0
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              ),
              const Text(
                'Budget vs Actuals by Category',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
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
                  var icon = iconCode == 0 ? Icons.question_mark : IconData(iconCode, fontFamily: 'MaterialIcons');
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
                                'Budget: ${budget.toStringAsFixed(2)}DH',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.blueAccent,
                                ),
                              ),
                              Text(
                                'Actual: ${actual.toStringAsFixed(2)}DH',
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
                                ? 'Over budget by ${(actual - budget).toStringAsFixed(2)}DH'
                                : 'Remaining budget: ${(budget - actual).toStringAsFixed(2)}DH',
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
              )
            ]
        ),
      )
    );
  }
}
