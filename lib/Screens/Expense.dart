import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../Helpers/Funcs.dart';
import '../Models/Category.dart';
import '../Models/Expense.dart';

class ExpenseState extends StatefulWidget {
  final Expense? expense;
  final List<Expense> expenses;
  const ExpenseState(this.expenses,{super.key,this.expense});

  @override
  State<ExpenseState> createState() => _ExpenseState();
}

class _ExpenseState extends State<ExpenseState> {

  DateTime _selectedDate = DateTime.now();
  //List<Category> _categories = [];
  bool _isLoading = true;

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  final List<DropdownMenuItem<Category>> _categoriesDropDown = List.empty(growable: true);
  late Category _currentCategory;
  bool _isIncome = false;
  bool _somethingAdded = false;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    final categories = await Category.getAll();
    if(categories.isNotEmpty) _currentCategory = categories[0];

    _categoriesDropDown.clear();
    for(var pt in categories){
      _categoriesDropDown.add(DropdownMenuItem(value: pt, child: Text(pt.name)));
    }

    if(widget.expense != null){
      _currentCategory = categories.where((c) => c.id == widget.expense!.category.id).single;
      var amount = widget.expense!.amount;
      if(amount < 0) {
        _amountController.text = (amount*-1).toString();
      }
      else{
        _amountController.text = amount.toString();
        _isIncome = true;
      }
      _commentController.text = widget.expense!.comment;
      _selectedDate = widget.expense!.date;
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    String formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
    return WillPopScope(
        onWillPop: onWillPop,
        child: Scaffold(
            key: _scaffoldKey,
            appBar: AppBar(title: Text("FinTrack : ${widget.expense == null ? 'Add expense':'Edit expense'}")),
            body: _isLoading ? Center(child: Text("No data ...")) : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  DropdownButtonFormField(
                    value: _currentCategory,
                    items: _categoriesDropDown,
                    onChanged: (selectedCategory) {
                      setState(() {
                        _currentCategory = selectedCategory!;
                      });
                    },
                    decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Category'
                    )
                  ),
                  const SizedBox(height: 15.0),
                  TextFormField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Amount',
                      suffixIcon: Icon(Icons.numbers),
                      hintText: 'Amount',
                    ),
                    validator: (value) {
                      if (!Func.isNumeric(value)) {
                        return "Required field";
                      } else if(double.parse(value!) <= 0) {
                        return "Greater than 0";
                      }
                      return null;
                    }
                  ),
                  const SizedBox(height: 15.0),
                  TextFormField(
                    controller: _commentController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Comment',
                      suffixIcon: Icon(Icons.message),
                      hintText: 'Comment',
                    ),
                    validator: (value) => Func.isNull(value) ? "Required field" : null,
                    minLines: 4,
                    keyboardType: TextInputType.multiline,
                    maxLines: null,
                  ),
                  const SizedBox(height: 15.0),
                  ListTile(
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Checkbox(
                              value: _isIncome,
                              onChanged: (bool? value) {
                                setState(() => _isIncome = value == true);
                              }
                            ),
                            const Text("Income ?"),
                          ],
                        ),
                        ElevatedButton(
                          onPressed: () => _pickDate(context),
                          style: ButtonStyle(side: WidgetStateProperty.all(BorderSide(color: Colors.white))),
                          child: Row(
                            spacing: 5,
                            children: [
                              Icon(Icons.calendar_month),
                              Text(
                                formattedDate,
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        )
                      ],
                    )
                  )
                ],
              ),
            ),
            floatingActionButton: _isLoading ? const Icon(Icons.downloading) : FloatingActionButton.extended(
              heroTag: "btn1",
              icon: const Icon(Icons.check),
              onPressed: () async {
                if (_formKey.currentState!.validate()){
                  setState(() {
                    _isLoading = true;
                  });
                  var obj = Expense(
                    id: widget.expense == null ? 0 : widget.expense!.id,
                    amount: (_isIncome ? 1 : -1)*double.parse(_amountController.value.text),
                    date: _selectedDate,
                    comment: _commentController.text,
                    category: _currentCategory
                  );
                  await obj.save();
                  if(widget.expense == null){
                    widget.expenses.insert(0,obj);
                  }
                  else{
                    widget.expense!.amount = obj.amount;
                    widget.expense!.date = obj.date;
                    widget.expense!.comment = obj.comment;
                    widget.expense!.category = obj.category;
                  }
                  _amountController.clear();
                  _commentController.clear();
                  _somethingAdded = true;

                  await Func.updateWidgetData(widget.expenses);


                  if(mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('${(widget.expense == null ? 'Added' : 'Updated')} successfully.'),
                            duration: const Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            backgroundColor: Colors.green
                        )
                    );
                  }

                  setState(() {
                    _isLoading = false;
                  });
                }
              },
              label: const Text('Validate')
            ),
            floatingActionButtonLocation: FloatingActionButtonLocation.miniEndFloat
        )
    );
  }

  Future<bool> onWillPop() {
    Navigator.of(context).pop(_somethingAdded);
    return Future.value(true);
  }

  Future<void> _pickDate(BuildContext context) async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (pickedDate != null && pickedDate != _selectedDate) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

}
