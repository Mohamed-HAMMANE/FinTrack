# FinTrack Enhancement Roadmap

This document outlines potential improvements and new features for the FinTrack personal finance app.

---

## ✅ Completed Features

### Enhanced Search & Filtering ✓
- Multi-filter system (category, date range, amount type)
- Combined filters with real-time updates
- Search by comment, category name, or amount
- Completed: 2025-01-XX

### Budget Alerts & Notifications ✓
- Real-time budget warnings while entering expenses
- Visual warnings at 75%, 90%, and 100% budget usage
- Confirmation dialog when exceeding budget
- Projected budget impact display
- Completed: 2025-01-XX

### Enhanced Charts & Visualizations ✓
- Date range selector with presets (This Month, Last 30 Days, etc.)
- Category breakdown pie chart with tap interactions
- Daily spending line chart
- Month-over-month bar chart comparison
- Emergency Fund cumulative savings trend
- Top 10 expenses list
- French number formatting throughout
- Completed: 2025-01-XX

---

## 🎯 Priority 1: Quick Wins (High Impact, Low Effort)

### 1. Expense Templates
**Description**: Save frequently used expenses as templates for one-tap adding
**Benefit**: Dramatically reduces time for repetitive expenses (daily coffee, parking, etc.)
**Effort**: 4 hours
**Implementation**:
- New table: `ExpenseTemplate` (name, categoryId, defaultAmount)
- Quick access button on add expense screen
- Template management in settings

### 2. Bottom Navigation Bar
**Description**: Replace hamburger menu with bottom navigation
**Benefit**: Modern UX pattern, faster navigation, follows Material Design standards
**Effort**: 3 hours
**Implementation**:
- Bottom nav with 4-5 tabs: Home, Add, Charts, Categories, Settings
- Remove drawer menu
- Maintain current screen functionality

### 3. Undo Functionality
**Description**: Allow undo for delete operations
**Benefit**: Prevents accidental data loss, better UX
**Effort**: 4 hours
**Implementation**:
- Soft delete flag in database
- Snackbar with "Undo" button after deletion
- Cleanup job for permanently deleting old soft-deleted items

### 4. Database Query Optimization
**Description**: Load only needed data instead of fetching all expenses
**Benefit**: Major performance improvement, especially with large datasets
**Effort**: 3 hours
**Implementation**:
- Add date/category filters to `Expense.getAll()`
- Use SQL WHERE clauses instead of Dart filtering
- Add composite indexes: (categoryId, date)

### 5. Refactor Funcs.dart
**Description**: Replace 8,900-line icon map with icon picker package
**Benefit**: Faster IDE, smaller bundle size, better icon selection UX
**Effort**: 2 hours
**Implementation**:
- Replace with `flutter_iconpicker` package
- Split remaining utilities into logical files
- Remove hardcoded icon map

---

## 💡 Priority 2: Major Features (High Impact, Medium Effort)

### 6. Recurring Transactions
**Description**: Auto-create repeating income/expenses (salary, rent, subscriptions)
**Benefit**: Eliminate manual entry for predictable transactions, more complete tracking
**Effort**: 12 hours
**Implementation**:
- New table: `RecurringExpense` (frequency, nextDate, endDate)
- Background job to generate transactions
- Management screen to view/edit/disable recurring items
- Notification when recurring expense created

### 7. Multiple Accounts/Wallets
**Description**: Track different payment methods separately (cash, bank, credit cards)
**Benefit**: More realistic financial tracking, accurate account balances
**Effort**: 16 hours
**Implementation**:
- New table: `Account` (name, type, initialBalance, currentBalance)
- Link expenses to accounts
- Account selector on expense entry
- Transfer transactions between accounts (without affecting totals)
- Account balance history

### 8. Receipt Attachments
**Description**: Attach photos to expenses
**Benefit**: Complete documentation, warranty tracking, tax purposes
**Effort**: 10 hours
**Implementation**:
- Camera integration with `image_picker`
- Store in app directory (not public)
- Thumbnail in expense list
- Full-screen gallery view
- Delete with expense

### 9. Export to CSV/Excel
**Description**: Generate CSV reports from filtered expenses
**Benefit**: Tax reporting, external analysis, sharing with accountant
**Effort**: 6 hours
**Implementation**:
- Export filtered expenses to CSV
- Include all fields (date, category, amount, comment)
- Share via system share dialog
- Format options (date format, decimal separator)

---

## 📊 Priority 3: Analytics & Insights (Medium Impact, Medium Effort)

### 10. Spending Predictions
**Description**: Forecast end-of-month spending based on current trends
**Benefit**: Early warning system, helps course-correction
**Effort**: 6 hours
**Implementation**:
- Calculate daily average spending
- Project to month end
- Show on home screen: "On track to spend X this month"
- Warning if projection exceeds budget

### 11. Comparison Views
**Description**: Side-by-side comparison of different periods
**Benefit**: Understand spending trends and progress
**Effort**: 5 hours
**Implementation**:
- This month vs last month
- This year vs last year
- Category comparison across months
- Income/expense trend over time

### 12. Spending Insights
**Description**: Automated analysis and suggestions
**Benefit**: Passive insights without manual analysis
**Effort**: 8 hours
**Implementation**:
- "You spent 30% more on dining this month"
- "Your grocery spending decreased by $50"
- "Top spending category: Transportation"
- Weekly summary notifications

---

## 🏗️ Priority 4: Technical Improvements (Medium Impact, High Effort)

### 13. State Management (Provider/Riverpod)
**Description**: Replace setState with proper state management
**Benefit**: Better performance, less prop drilling, easier maintenance
**Effort**: 20 hours
**Implementation**:
- Choose Riverpod for type safety
- Create providers for expenses, categories, settings
- Refactor all screens to use providers
- Remove callback chains and manual refresh logic

### 14. Repository Pattern
**Description**: Separate business logic from UI and database
**Benefit**: Better architecture, testability, maintainability
**Effort**: 16 hours
**Implementation**:
- Create repository layer (ExpenseRepository, CategoryRepository)
- Move database calls from models to repositories
- Separate models from database logic
- Service layer for business rules

### 15. Database Encryption
**Description**: Encrypt SQLite database for security
**Benefit**: Protect sensitive financial data from unauthorized access
**Effort**: 12 hours
**Implementation**:
- Migrate to `sqflite_sqlcipher`
- Password setup flow on first launch
- Biometric unlock option
- Encrypt backup files

### 16. Comprehensive Error Handling
**Description**: Replace silent failures with proper error UI
**Benefit**: Better debugging, clear user feedback
**Effort**: 8 hours
**Implementation**:
- Create error classes (DatabaseError, ValidationError)
- Error dialog/snackbar for user feedback
- Logging for debugging
- Retry mechanisms for failed operations

### 17. Pagination & Lazy Loading
**Description**: Load expenses in chunks instead of all at once
**Benefit**: Handles large datasets efficiently
**Effort**: 6 hours
**Implementation**:
- Implement lazy loading in expense list
- Load more on scroll
- Efficient queries with LIMIT/OFFSET

---

## 🚀 Priority 5: Advanced Features (Lower Priority)

### 18. Tags System
**Description**: Multi-tag expenses for flexible categorization
**Benefit**: One expense can belong to multiple contexts (e.g., "Business" + "Food")
**Effort**: 10 hours
**Implementation**:
- New table: `Tag`, junction table: `ExpenseTag`
- Tag management screen
- Tag selector on expense form
- Filter by tags

### 19. Goals & Savings Tracking
**Description**: Set financial goals with progress tracking
**Benefit**: Motivates saving behavior, visual progress
**Effort**: 12 hours
**Implementation**:
- New table: `SavingsGoal` (name, targetAmount, deadline, currentAmount)
- Goal creation screen
- Progress visualization (circular progress, thermometer)
- Contribution tracking
- Goal completion celebrations

### 20. Smart Auto-Categorization
**Description**: Machine learning to suggest categories based on patterns
**Benefit**: Reduces manual categorization after learning phase
**Effort**: 20 hours
**Implementation**:
- Analyze comment patterns (e.g., "Starbucks" → Coffee)
- Suggest category when adding expense
- Learn from user corrections
- Confidence threshold for auto-applying

### 21. Split Transactions
**Description**: Divide one transaction across multiple categories
**Benefit**: Accurate tracking for shopping trips with mixed purchases
**Effort**: 8 hours
**Implementation**:
- Allow splitting amount across categories
- Parent transaction with child splits
- Sum validation (splits must equal total)
- Visual breakdown in expense detail

### 22. Geolocation Tagging
**Description**: Automatically capture location when adding expense
**Benefit**: Context for transactions, location-based insights
**Effort**: 6 hours
**Implementation**:
- Request location permission
- Capture lat/long with expense
- Reverse geocode to address
- Map view of expenses
- "Spending near [location]" insights

### 23. Budget Rollover
**Description**: Carry unused budget to next month
**Benefit**: Encourages saving, more flexible budgeting
**Effort**: 5 hours
**Implementation**:
- Toggle setting per category
- Calculate rollover amount monthly
- Adjust budget display to show base + rollover
- Visual indication of rollover

### 24. Voice Input
**Description**: Voice command to add expenses
**Benefit**: Hands-free entry while shopping
**Effort**: 10 hours
**Implementation**:
- Speech recognition with `speech_to_text`
- Parse amount, category, comment
- Confirmation dialog before saving
- Handle ambiguous inputs

### 25. Currency Support & Conversion
**Description**: Multi-currency support with exchange rates
**Benefit**: Track foreign transactions accurately
**Effort**: 12 hours
**Implementation**:
- Currency selector per expense
- Exchange rate API integration
- Convert to base currency for totals
- Historical exchange rates

### 26. Backup to Cloud
**Description**: Automatic backup to Google Drive or Dropbox
**Benefit**: Never lose data, multi-device sync potential
**Effort**: 15 hours
**Implementation**:
- OAuth integration for cloud providers
- Automatic encrypted backups
- Restore from cloud
- Conflict resolution for multi-device

---

## 📋 Recommended Implementation Order

### Phase 1: Foundation (1-2 weeks)
1. Refactor Funcs.dart
2. Database query optimization
3. Bottom navigation
4. Undo functionality

### Phase 2: Quick Value (2 weeks)
5. Expense templates
6. Export to CSV
7. Spending predictions

### Phase 3: Major Features (4 weeks)
8. Recurring transactions
9. Multiple accounts
10. Receipt attachments
11. Comparison views

### Phase 4: Architecture (3 weeks)
12. State management (Riverpod)
13. Repository pattern
14. Database encryption
15. Comprehensive error handling
16. Pagination

### Phase 5: Advanced (4+ weeks)
17. Tags system
18. Goals tracking
19. Smart categorization
20. Split transactions
21. Additional advanced features as desired

---

## 🎯 Notes

- All enhancements maintain the personal, local-first nature of the app
- No external dependencies or cloud requirements (except optional cloud backup)
- Focus on practical improvements for daily financial management
- Maintain current simplicity while adding power features
- Keep performance and privacy as top priorities

---

**Last Updated**: 2025-01-11
