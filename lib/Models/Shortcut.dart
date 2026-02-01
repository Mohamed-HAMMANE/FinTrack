import 'package:flutter/material.dart';

class Shortcut {
  final String categoryName;
  final String comment;
  final double amount;
  final IconData? icon;

  const Shortcut({
    required this.categoryName,
    required this.comment,
    required this.amount,
    this.icon,
  });

  static List<Shortcut> get defaults => [
    // Transportation
    const Shortcut(
      categoryName: 'Transportation',
      comment: 'Train 🚆',
      amount: -15.0,
    ),
    const Shortcut(
      categoryName: 'Transportation',
      comment: 'Tolls',
      amount: -50.0,
    ),
    const Shortcut(
      categoryName: 'Transportation',
      comment: 'Taxi 🚕',
      amount: -8.0,
    ),
    const Shortcut(
      categoryName: 'Transportation',
      comment: 'Taxi 🚕',
      amount: -10.0,
    ),
    const Shortcut(
      categoryName: 'Transportation',
      comment: 'Grand taxi 🚖',
      amount: -5.0,
    ),
    const Shortcut(
      categoryName: 'Transportation',
      comment: 'Grand taxi 🚖',
      amount: -8.0,
    ),
    const Shortcut(
      categoryName: 'Transportation',
      comment: 'Grand taxi 🚖',
      amount: -7.0,
    ),
    const Shortcut(
      categoryName: 'Transportation',
      comment: 'Gas ⛽️',
      amount: -100.0,
    ),
    const Shortcut(
      categoryName: 'Transportation',
      comment: 'Gas ⛽️',
      amount: -200.0,
    ),

    // Family
    const Shortcut(categoryName: 'Family', comment: 'Needs', amount: -100.0),
    const Shortcut(categoryName: 'Family', comment: 'Meat 🥩', amount: -50.0),
    const Shortcut(categoryName: 'Family', comment: 'Bread 🍞', amount: -2.5),
    const Shortcut(categoryName: 'Family', comment: 'Grocery', amount: -200.0),

    // Me
    const Shortcut(categoryName: 'Me', comment: 'Coffee ☕️', amount: -5.0),
    const Shortcut(
      categoryName: 'Me',
      comment: 'Coffee capsules',
      amount: -65.0,
    ),
    const Shortcut(categoryName: 'Me', comment: 'Breakfast', amount: -13.0),
    const Shortcut(categoryName: 'Me', comment: 'Lunch', amount: -40.0),

    // Bank
    const Shortcut(
      categoryName: 'Bank',
      comment: 'COMMISSION DE TENUE DE COMPTE',
      amount: -15.4,
    ),
    const Shortcut(categoryName: 'Bank', comment: 'COMMISSION', amount: -40.0),
    const Shortcut(
      categoryName: 'Bank',
      comment: 'TAXE SUR VALEUR AJOUTEE',
      amount: -4.0,
    ),
    const Shortcut(
      categoryName: 'Bank',
      comment: 'Self-Transfer: Personal Reimbursement',
      amount: -16.5,
    ),
    const Shortcut(
      categoryName: 'Bank',
      comment: 'FRAIS DE TENUE DE COMPTE 100335573',
      amount: -11.0,
    ),

    // Housing
    const Shortcut(
      categoryName: 'Housing',
      comment: 'Mortgage insurance',
      amount: -228.4,
    ),
    const Shortcut(
      categoryName: 'Housing',
      comment: 'Mortgage',
      amount: -3900.2,
    ),

    // Cell Phone
    const Shortcut(
      categoryName: 'Cell Phone',
      comment: 'Recharge',
      amount: -10.0,
    ),
    const Shortcut(
      categoryName: 'Cell Phone',
      comment: 'Subscription',
      amount: -89.25,
    ),

    // Work (Income)
    const Shortcut(categoryName: 'Work', comment: 'Salary', amount: 10546.26),
    const Shortcut(categoryName: 'Work', comment: 'Bonus', amount: 1840.0),
    const Shortcut(categoryName: 'Work', comment: 'Bonus', amount: 2400.0),

    // Wifi
    const Shortcut(categoryName: 'Wifi', comment: 'Bill', amount: -375.0),
  ];
}
