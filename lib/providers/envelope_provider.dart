import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database_helper.dart';
import '../models/envelope.dart';
import '../models/transaction.dart' as model;
import '../models/payday.dart';
import '../models/allocation.dart';
import '../models/recurring_payday.dart';
import '../services/payday_service.dart';
import '../services/security/auth_service.dart';

class EnvelopeProvider extends ChangeNotifier {
  final AuthService _authService;
  DatabaseHelper get _db => _authService.dbHelper;

  EnvelopeProvider(this._authService);

  List<Envelope> _envelopes = [];
  final Map<int, List<model.Transaction>> _transactions = {};
  final Map<int, double> _totalFunding = {};
  final Map<int, double> _totalSpending = {};
  List<model.Transaction> _recentTransactions = [];
  List<Payday> _paydays = [];

  List<Envelope> get envelopes => _envelopes;
  List<model.Transaction> get recentTransactions => _recentTransactions;
  List<Payday> get paydays => _paydays;

  List<model.Transaction> getTransactions(int envelopeId) {
    return _transactions[envelopeId] ?? [];
  }

  double getTotalFunding(int envelopeId) {
    return _totalFunding[envelopeId] ?? 0.0;
  }

  double getTotalSpending(int envelopeId) {
    return _totalSpending[envelopeId] ?? 0.0;
  }

  double calculateRemaining(int envelopeId) {
    final funding = getTotalFunding(envelopeId);
    final spending = getTotalSpending(envelopeId);
    return funding - spending;
  }

  double getTotalPaydayIncome() {
    double total = 0;
    for (final p in _paydays) {
      total += p.amount;
    }
    return total;
  }

  double getTotalAllocatedToEnvelopes() {
    double total = 0;
    for (final e in _envelopes) {
      if (e.id != null) total += getTotalFunding(e.id!);
    }
    return total;
  }

  double calculateTotalBalance() {
    return getTotalPaydayIncome() - calculateTotalSpent();
  }

  double calculateTotalSpent() {
    double total = 0.0;
    for (final e in _envelopes) {
      if (e.id != null) total += getTotalSpending(e.id!);
    }
    return total;
  }

  double getUnallocated() {
    final bal = calculateTotalBalance();
    final allocated = getTotalAllocatedToEnvelopes();
    final unallocated = bal - allocated;
    return unallocated > 0 ? unallocated : 0;
  }

  double getTotalSpentThisMonth() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    double total = 0.0;
    for (final e in _envelopes) {
      if (e.id == null) continue;
      final txns = _transactions[e.id!] ?? [];
      for (final t in txns) {
        if (!t.isSpending) continue;
        final tDate = DateTime.parse(t.date);
        if (tDate.isAfter(start) && tDate.isBefore(end)) {
          total += t.amount;
        }
      }
    }
    return total;
  }

  double getTotalSpentLastMonth() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month - 1, 1);
    final end = DateTime(now.year, now.month, 1);
    double total = 0.0;
    for (final e in _envelopes) {
      if (e.id == null) continue;
      final txns = _transactions[e.id!] ?? [];
      for (final t in txns) {
        if (!t.isSpending) continue;
        final tDate = DateTime.parse(t.date);
        if (tDate.isAfter(start) && tDate.isBefore(end)) {
          total += t.amount;
        }
      }
    }
    return total;
  }

  double getTotalAvailable() => calculateTotalBalance();

  /// Returns daily spend rate this month.
  double getDailySpendRate() {
    final total = getTotalSpentThisMonth();
    final now = DateTime.now();
    final daysElapsed = now.day;
    if (daysElapsed == 0) return 0;
    return total / daysElapsed;
  }

  /// Returns > 0 if spending is trending faster (percentage increase).
  /// Returns 0 if there's no previous data to compare.
  double getSpendingTrendPercent() {
    final lastMonth = getTotalSpentLastMonth();
    if (lastMonth <= 0) return 0;
    final now = DateTime.now();
    final daysInLastMonth = DateTime(now.year, now.month, 0).day;
    final lastDailyRate = lastMonth / daysInLastMonth;
    final currentDailyRate = getDailySpendRate();
    if (lastDailyRate <= 0) return 0;
    return ((currentDailyRate - lastDailyRate) / lastDailyRate) * 100;
  }

  double getAverageDailySpend(int envelopeId) {
    final txns = _transactions[envelopeId] ?? [];
    if (txns.isEmpty) return 0;
    final spendingTxns = txns.where((t) => t.isSpending).toList();
    if (spendingTxns.isEmpty) return 0;
    final total = spendingTxns.fold<double>(0, (s, t) => s + t.amount);
    final dates = spendingTxns.map((t) => DateTime.parse(t.date)).toList()..sort();
    final first = dates.first;
    final last = dates.last;
    final days = last.difference(first).inDays;
    if (days < 1) return total;
    return total / days;
  }

  int getDaysUntilDepleted(int envelopeId) {
    final remaining = calculateRemaining(envelopeId);
    if (remaining <= 0) return 0;
    final dailySpend = getAverageDailySpend(envelopeId);
    if (dailySpend <= 0) return 999;
    return (remaining / dailySpend).ceil();
  }

  int getDaysUntilPayday(RecurringPayday? rule) {
    if (rule == null) return 999;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (rule.frequency == 'weekly') {
      final target = rule.weekday ?? DateTime.monday;
      var diff = target - today.weekday;
      if (diff <= 0) diff += 7;
      return diff;
    } else if (rule.frequency == 'fortnightly') {
      final target = rule.weekday ?? DateTime.monday;
      var diff = target - today.weekday;
      if (diff <= 0) diff += 14;
      return diff;
    } else if (rule.frequency == 'monthly') {
      final target = rule.monthDay ?? 1;
      var daysUntil = target - today.day;
      if (daysUntil <= 0) {
        final nextMonth = DateTime(now.year, now.month + 1, target);
        daysUntil = nextMonth.difference(today).inDays;
      }
      return daysUntil;
    }
    return 999;
  }

  Future<double> getLastPaycheckAmount() async {
    return await _db.getLastPaycheckAmount();
  }

  String? get lastPaydayDate {
    if (_paydays.isEmpty) return null;
    final latest = _paydays.reduce((a, b) => a.date.compareTo(b.date) > 0 ? a : b);
    return latest.date;
  }

  Future<void> loadEnvelopes() async {
    _envelopes = await _db.getEnvelopes();
    for (final envelope in _envelopes) {
      if (envelope.id != null) {
        await _loadTransactions(envelope.id!);
      }
    }
    _recentTransactions = _buildRecentTransactions();
    _paydays = await _db.getPaydays();
    notifyListeners();
  }

  List<model.Transaction> _buildRecentTransactions() {
    final all = <model.Transaction>[];
    for (final tList in _transactions.values) {
      all.addAll(tList);
    }
    all.sort((a, b) => b.date.compareTo(a.date));
    return all.take(5).toList();
  }

  Future<void> _loadTransactions(int envelopeId) async {
    final transactions = await _db.getTransactions(envelopeId);
    _transactions[envelopeId] = transactions;
    _totalFunding[envelopeId] = await _db.getTotalFunding(envelopeId);
    _totalSpending[envelopeId] = await _db.getTotalSpending(envelopeId);
  }

  bool get hasMoney => calculateTotalBalance() > 0;

  Future<int> addEnvelope(Envelope envelope) async {
    final id = await _db.insertEnvelope(envelope);
    final newEnvelope = envelope.copyWith(id: id);
    _envelopes.insert(0, newEnvelope);

    await _loadTransactions(id);
    _recentTransactions = _buildRecentTransactions();
    notifyListeners();
    return id;
  }

  Future<void> updateEnvelope(Envelope envelope) async {
    await _db.updateEnvelope(envelope);
    final index = _envelopes.indexWhere((e) => e.id == envelope.id);
    if (index != -1) _envelopes[index] = envelope;
    notifyListeners();
  }

  Future<void> addFunding(int envelopeId, double amount, String note) async {
    final txn = model.Transaction(
      envelopeId: envelopeId,
      amount: amount,
      note: note,
      date: DateTime.now().toIso8601String(),
      type: 'funding',
    );
    await _db.insertTransaction(txn);
    await _loadTransactions(envelopeId);
    _recentTransactions = _buildRecentTransactions();
    notifyListeners();
  }

  Future<void> addTransaction(model.Transaction transaction) async {
    await _db.insertTransaction(transaction);
    await _loadTransactions(transaction.envelopeId);
    _recentTransactions = _buildRecentTransactions();
    notifyListeners();
  }

  Future<void> deleteTransaction(int transactionId, int envelopeId) async {
    await _db.deleteTransaction(transactionId);
    await _loadTransactions(envelopeId);
    _recentTransactions = _buildRecentTransactions();
    notifyListeners();
  }

  Future<void> deleteEnvelope(int id) async {
    await _db.deleteEnvelope(id);
    _envelopes.removeWhere((e) => e.id == id);
    _transactions.remove(id);
    _totalFunding.remove(id);
    _totalSpending.remove(id);
    _recentTransactions = _buildRecentTransactions();
    notifyListeners();
  }

  // --- Payday & Allocation ---

  Future<void> addPayday(Payday payday, List<Allocation> allocations) async {
    final paydayId = await _db.insertPayday(payday);
    for (final alloc in allocations) {
      final a = Allocation(
        paydayId: paydayId,
        envelopeId: alloc.envelopeId,
        amount: alloc.amount,
      );
      await _db.insertAllocation(a);

      final txn = model.Transaction(
        envelopeId: alloc.envelopeId,
        amount: alloc.amount,
        note: 'Payday: ${payday.note.isNotEmpty ? payday.note : 'Salary'}',
        date: payday.date,
        type: 'funding',
      );
      await _db.insertTransaction(txn);
    }
    await loadEnvelopes();
  }

  Future<void> deletePayday(int paydayId) async {
    await _db.deletePayday(paydayId);
    await loadEnvelopes();
  }

  Future<Map<String, dynamic>> getPaydayDetails(int paydayId) async {
    final payday = await _db.getPayday(paydayId);
    final allocs = await _db.getAllocationsWithEnvelope(paydayId);
    double allocated = 0;
    for (final a in allocs) {
      allocated += (a['amount'] as num).toDouble();
    }
    return {
      'payday': payday,
      'allocations': allocs,
      'allocated': allocated,
      'remaining': (payday?.amount ?? 0) - allocated,
    };
  }

  // --- Auto Allocate Percentages ---

  Future<void> saveAllocationPercentages(Map<int, double> percentages) async {
    final prefs = await SharedPreferences.getInstance();
    final data = percentages.map((k, v) => MapEntry(k.toString(), v));
    await prefs.setString('alloc_percentages', jsonEncode(data));
  }

  Future<Map<int, double>> loadAllocationPercentages() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('alloc_percentages');
    if (raw == null) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded
        .map((k, v) => MapEntry(int.parse(k), (v as num).toDouble()));
  }

  // --- Filtering & Search ---

  Future<List<model.Transaction>> searchTransactions(String query) async {
    return await _db.searchTransactions(query);
  }

  Future<List<model.Transaction>> getFilteredTransactions(
    int envelopeId,
    DateTime? startDate,
    DateTime? endDate,
  ) async {
    return await _db.getFilteredTransactions(envelopeId, startDate, endDate);
  }

  // --- Analytics ---

  Future<List<Map<String, dynamic>>> getSpendingByEnvelope(
    DateTime start, DateTime end,
  ) async {
    return await _db.getSpendingByEnvelope(start, end);
  }

  Future<List<Map<String, dynamic>>> getWeeklySpending(int weeks) async {
    return await _db.getWeeklySpending(weeks);
  }

  Future<int> getTransactionCount(int? envelopeId) async {
    return await _db.getTransactionCount(envelopeId);
  }

  Future<double> getAverageSpend() async {
    return await _db.getAverageSpend();
  }

  Future<Map<String, dynamic>> getAnalytics() async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    final totalSpent = await _db.getTotalSpentInRange(monthStart, monthEnd);
    final count = await _db.getTransactionCount(null);
    final avg = count > 0 ? totalSpent / count : 0.0;
    final spendingByEnv = await _db.getSpendingByEnvelope(monthStart, monthEnd);

    String largestEnvelope = 'N/A';
    double largestAmount = 0;
    for (final env in spendingByEnv) {
      if ((env['total'] as num).toDouble() > largestAmount) {
        largestAmount = (env['total'] as num).toDouble();
        largestEnvelope = env['name'] as String;
      }
    }

    return {
      'totalSpentThisMonth': totalSpent,
      'transactionCount': count,
      'averageSpend': avg,
      'largestEnvelope': largestEnvelope,
      'spendingByEnvelope': spendingByEnv,
    };
  }

  // --- Export ---

  String exportToJson() {
    final data = {
      'envelopes': _envelopes.map((e) => e.toMap()).toList(),
      'transactions': _transactions.values
          .expand((list) => list)
          .map((t) => t.toJson())
          .toList(),
      'paydays': _paydays.map((p) => p.toJson()).toList(),
    };
    return const JsonEncoder.withIndent(null).convert(data);
  }

  String exportToCsv() {
    final buffer = StringBuffer('Type,Envelope,Amount,Note,Date\n');
    for (final entry in _transactions.entries) {
      final envelope = _envelopes.firstWhere(
        (e) => e.id == entry.key,
        orElse: () =>
            Envelope(name: 'Unknown', initialAmount: 0, createdAt: ''),
      );
      for (final t in entry.value) {
        final note = t.note.contains(',') ? '"${t.note}"' : t.note;
        buffer.writeln(
            '${t.type},${envelope.name},${t.amount.toStringAsFixed(2)},$note,${t.date}');
      }
    }
    return buffer.toString();
  }

  // --- Dashboard Metrics ---

  double getBankBalance() => getUnallocated();

  double getNetWorth() => calculateTotalBalance();

  // --- Recurring Paydays ---

  Future<List<RecurringPayday>> getRecurringPaydays() async {
    return await _db.getRecurringPaydays();
  }

  Future<int> addRecurringPayday(RecurringPayday rule) async {
    final id = await _db.insertRecurringPayday(rule);
    return id;
  }

  Future<void> updateRecurringPayday(RecurringPayday rule) async {
    await _db.updateRecurringPayday(rule);
  }

  Future<void> deleteRecurringPayday(int id) async {
    await _db.deleteRecurringPayday(id);
  }

  Future<void> processRecurringPaydays() async {
    final service = PaydayService(_authService.dbHelper);
    await service.processRecurringPaydays();
    await loadEnvelopes();
  }

  // --- Auto Divide ---

  Future<bool> isAutoDivideEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('auto_divide_enabled') ?? false;
  }

  Future<void> setAutoDivideEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_divide_enabled', enabled);
  }

  // --- Clear All Data ---

  void clearCache() {
    _envelopes = [];
    _transactions.clear();
    _totalFunding.clear();
    _totalSpending.clear();
    _recentTransactions.clear();
    _paydays.clear();
    notifyListeners();
  }

  Future<void> clearAllData() async {
    await _db.deleteAllEnvelopes();
    await _db.deleteAllPaydays();
    _envelopes.clear();
    _transactions.clear();
    _totalFunding.clear();
    _totalSpending.clear();
    _recentTransactions.clear();
    _paydays.clear();
    notifyListeners();
  }
}
