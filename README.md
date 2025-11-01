# FinTrack

Personal finance management app built with Flutter for tracking my daily expenses, income, and budgets.

## About

This is a personal project I use to manage my financial status. It helps me track where my money goes, stay within budget, and visualize my spending patterns over time.

## Key Features

- **Expense & Income Tracking**: Record all transactions with amounts, dates, comments, and categories
- **Budget Management**: Set monthly budgets per category with visual progress indicators
- **Category Organization**: Custom categories with icons and reorderable layout
- **Financial Overview**: Dashboard showing daily, monthly, and all-time financial summaries
- **Data Visualization**: Charts displaying income/outcome trends, budget vs actuals, and spending breakdowns
- **Biometric Security**: Fingerprint/face unlock protection for savings data
- **Home Screen Widget**: Quick view of financial totals without opening the app
- **Search & Filter**: Find expenses by text or filter by category/date
- **Backup & Restore**: Export/import database to prevent data loss
- **Dark Mode**: Light and dark theme support

## Tech Stack

- **Framework**: Flutter 3.9.2+
- **Language**: Dart
- **Database**: SQLite (local storage)
- **Platform**: Android
- **Key Libraries**:
  - `sqflite` - Local database
  - `fl_chart` - Charts and graphs
  - `local_auth` - Biometric authentication
  - `home_widget` - Android widget support

## Database Schema

### Category
- Name, Budget, Order, IconCode
- Tracks spending categories with monthly budgets

### Expense
- Amount (positive for income, negative for expenses)
- Date, Comment, CategoryId
- All transactions linked to categories

## Currency

Uses Moroccan Dirham (DH) with French number formatting.

## Development

```bash
# Install dependencies
flutter pub get

# Run the app
flutter run

# Build APK
flutter build apk --release
```

## Notes

- All data is stored locally on device
- No cloud sync or external services
- Database backups saved to Downloads folder
- Designed for personal use only
