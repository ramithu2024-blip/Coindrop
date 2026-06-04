/// Centralized user-facing strings for CoinDrop.
/// All UI text lives here for future multilingual support.
class AppStrings {
  AppStrings._();

  // ---------------------------------------------------------------------------
  // Onboarding — Welcome
  // ---------------------------------------------------------------------------
  static const String welcomeTitle = 'Welcome to CoinDrop';
  static const String welcomeSubtitle = 'A simple envelope budget.\nNo cloud, no sign-up.';
  static const String welcomeCta = 'Get Started';

  // ---------------------------------------------------------------------------
  // Onboarding — Pain Point selection
  // ---------------------------------------------------------------------------
  static const String painPointTitle = 'What brings you here?';
  static const String painPointSubtitle = 'Pick what fits best.';
  static const String painPointSpend = 'I lose track of my spending';
  static const String painPointConfusing = 'Budgeting feels confusing';
  static const String painPointControl = 'I want financial control';
  static const String painPointCloud = 'I don\'t trust cloud apps';
  static const String painPointCta = 'Continue';

  // ---------------------------------------------------------------------------
  // Onboarding — Theme / Appearance
  // ---------------------------------------------------------------------------
  static const String appearanceTitle = 'Choose your look';
  static const String appearanceSubtitle = 'Pick a theme and accent color.';
  static const String appearanceCashAccent = 'Cash icon accent';
  static const String appearanceCustomColors = 'Custom envelope colors';
  static const String appearanceAccent = 'Accent Color';
  static const String appearanceCta = 'Continue';

  // ---------------------------------------------------------------------------
  // Onboarding — Security (PIN)
  // ---------------------------------------------------------------------------
  static const String pinCreateTitle = 'Create a PIN';
  static const String pinCreateSubtitle = 'Your PIN unlocks your vault.\nThere is no recovery — keep it safe.';
  static const String pinConfirmTitle = 'Confirm your PIN';
  static const String pinConfirmSubtitle = 'Enter the same PIN again.';
  static const String pinCtaInitial = 'Continue';
  static const String pinCtaConfirm = 'Confirm & Continue';
  static const String pinCtaLoading = 'Securing vault...';
  static const String pinBack = 'Back';
  static const String pinErrorLength = 'PIN must be 4 digits';
  static const String pinErrorMismatch = 'PIN entries do not match';
  static const String pinBiometricLabel = 'Enable fingerprint unlock';

  // ---------------------------------------------------------------------------
  // Onboarding — Currency
  // ---------------------------------------------------------------------------
  static const String currencyTitle = 'Choose your currency';
  static const String currencySubtitle = 'Select your preferred currency format.';
  static const String currencyCta = 'Continue';

  // ---------------------------------------------------------------------------
  // Onboarding — Payday Setup
  // ---------------------------------------------------------------------------
  static const String paydayTitle = 'Do you receive regular pay?';
  static const String paydayYes = 'Yes';
  static const String paydayNo = 'No, manual';
  static const String paydayAmountHint = '0.00';
  static const String paydayFrequency = 'Frequency';
  static const String paydayWeekly = 'Weekly';
  static const String paydayFortnightly = 'Fortnightly';
  static const String paydayMonthly = 'Monthly';
  static const String paydayCustom = 'Custom';
  static const String paydayDayOfWeek = 'Day of Week';
  static const String paydayDayOfMonth = 'Day of Month';
  static const String paydayCustomHint = 'e.g. Every 2 weeks on Friday';
  static const String paydayNoteHint = 'Paycheck note (optional)';
  static const String paydayCta = 'Continue';

  // ---------------------------------------------------------------------------
  // Onboarding — Starting Balance
  // ---------------------------------------------------------------------------
  static const String balanceTitle = 'Starting Balance';
  static const String balanceSubtitle = 'What is your current available balance?';
  static const String balanceHint = '0.00';
  static const String balanceFooter = 'Added once as your opening balance. Add more later.';
  static const String balanceSkip = 'Start Fresh';
  static const String balanceSet = 'Set Balance';

  // ---------------------------------------------------------------------------
  // Onboarding — Envelope Setup
  // ---------------------------------------------------------------------------
  static const String envelopeTitle = 'Set Up Envelopes';
  static const String envelopeSubtitle = 'Envelopes split your money into categories.';
  static const String envelopeRecommended = 'Recommended';
  static const String envelopeCreateOwn = 'Create my own';
  static const String envelopeCtaRecommended = 'Create Envelopes';
  static const String envelopeCtaSkip = 'Skip — I\'ll add later';
  static const String envelopeTemplateLabel = 'Template';
  static const String envelopeListTitle = 'Envelopes to create:';
  static const String envelopeZeroFooter = 'All envelopes start at \$0. Fund them after setup.';
  static const String envelopeCustomHint = 'Enter envelope names, separated by commas';
  static const String envelopeTemplateBasic = 'Basic Living';
  static const String envelopeTemplateStudent = 'Student Budget';
  static const String envelopeTemplateMinimal = 'Minimal Control';

  // ---------------------------------------------------------------------------
  // Onboarding — Finish
  // ---------------------------------------------------------------------------
  static const String finishTitle = 'You\'re All Set!';
  static const String finishSubtitle = 'Your vault is ready.\nStart budgeting.';
  static const String finishTutorial = 'Quick Tutorial';
  static const String finishSetup = 'Finish Setup';

  // ---------------------------------------------------------------------------
  // Tutorial
  // ---------------------------------------------------------------------------
  static const String tutorialStep0Title = 'Your Balance';
  static const String tutorialStep0Body = 'Your total money shows at the top. Add income when you get paid.';
  static const String tutorialStep1Title = 'Envelopes';
  static const String tutorialStep1Body = 'Envelopes split your money into categories. Tap one to see details.';
  static const String tutorialStep2Title = 'Quick Actions';
  static const String tutorialStep2Body = 'Tap + to add an envelope. Tap \$ to allocate paydays.';
  static const String tutorialNext = 'Next';
  static const String tutorialFinish = 'Open Dashboard';

  // ---------------------------------------------------------------------------
  // Dashboard — Money Reality Check
  static const String dashboardAvailable = 'Available';
  static const String dashboardAllocated = 'Allocated';
  static const String dashboardUnassigned = 'Unassigned';
  static const String dashboardSpentMonth = 'Spent / Month';
  static const String dashboardEnvelopes = 'Envelopes';
  static const String dashboardLastPay = 'Last Pay';
  static const String dashboardRealityCheck = 'Money Reality Check';
  static const String dashboardDaysUntilPayday = 'days until payday';
  static const String dashboardSpendingFaster = 'Spending is trending % faster than last month';
  static const String dashboardOverSpent = 'You\'ve spent more than available';
  static const String dashboardRecentTransactions = 'Recent Transactions';
  static const String dashboardNavDashboard = 'Dashboard';
  static const String dashboardNavInsights = 'Insights';
  static const String dashboardNavPaydays = 'Paydays';
  static const String dashboardExportJson = 'Export to JSON';
  static const String dashboardExportCsv = 'Export to CSV';
  static const String dashboardSetAlloc = 'Set Allocation %';
  static const String dashboardNewEnvelope = 'Envelope';
  static const String dashboardPaycheckConfirmed = 'Paycheck confirmed';
  static const String dashboardPaycheckLater = 'You can confirm your payday later';
  static const String dashboardExportedTo = 'Exported to';

  // Dashboard — Empty States
  static const String dashboardEmptyTitle = 'No envelopes yet';
  static const String dashboardEmptyBody = 'Tap + to create your first envelope.\nThen use the \$ button for a payday.';

  // Dashboard — Payday Reminder
  static const String paydayReminderTitle = 'Did you receive your payday today?';
  static const String paydayReminderYes = 'Yes, allocate now';
  static const String paydayReminderNotYet = 'Not yet';
  static const String paydayMissedTitle = 'Missed payday reminder';
  static const String paydayMissedSubtitle = 'was due yesterday';
  static const String paydayMissedCta = 'Confirm';

  // ---------------------------------------------------------------------------
  // Spending Guard
  // ---------------------------------------------------------------------------
  static const String spendingGuardLow = 'Low Budget';
  static const String spendingGuardLowBody = 'You have less than 20% left in this envelope.';
  static const String spendingGuardSpendAnyway = 'Spend Anyway';
  static const String spendingGuardGoBack = 'Go Back';
  static const String spendingGuardInsufficient = 'Insufficient balance!';

  // ---------------------------------------------------------------------------
  // Envelope Detail
  // ---------------------------------------------------------------------------
  static const String envelopeDetailRemaining = 'Remaining';
  static const String envelopeDetailFunded = 'Total Funded';
  static const String envelopeDetailSpent = 'Spent';
  static const String envelopeDetailAvgDay = 'Avg / day';
  static const String envelopeDetailDaysUntilDepleted = 'days until depleted';
  static const String envelopeDetailRunningOut = 'Running out this week';
  static const String envelopeDetailQuickAdd = 'Add Money';
  static const String envelopeDetailSpend = 'Spend';

  // ---------------------------------------------------------------------------
  // General
  // ---------------------------------------------------------------------------
  static const String continueLabel = 'Continue';
  static const String cancel = 'Cancel';
  static const String save = 'Save';
  static const String delete = 'Delete';
  static const String confirm = 'Confirm';
  static const String error = 'Error';
  static const String success = 'Success';
  static const String loading = 'Loading...';
  static const String exportData = 'Export Data';
  static const String importData = 'Import Data';
  static const String settings = 'Settings';
  static const String security = 'Security';
  static const String back = 'Back';

  // ---------------------------------------------------------------------------
  // Expired Build
  // ---------------------------------------------------------------------------
  static const String expiredTitle = 'This build has expired';
  static const String expiredBody = 'Export your data to continue using CoinDrop.';
  static const String expiredExport = 'Export Data';
  static const String expiredCheckUpdate = 'Check for updates';

  // ---------------------------------------------------------------------------
  // Envelope Templates (for recommended creation)
  // ---------------------------------------------------------------------------
  static const List<String> templateBasicLiving = ['Groceries', 'Bills', 'Transport', 'Savings', 'Fun'];
  static const List<String> templateStudentBudget = ['Food', 'Transport', 'Study', 'Savings', 'Entertainment'];
  static const List<String> templateMinimalControl = ['Essentials', 'Bills', 'Savings'];

  static List<String> templateFor(String key) {
    switch (key) {
      case 'student':
        return templateStudentBudget;
      case 'minimal':
        return templateMinimalControl;
      default:
        return templateBasicLiving;
    }
  }
}
