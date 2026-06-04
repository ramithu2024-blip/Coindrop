import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../models/recurring_payday.dart';
import '../models/payday.dart';
import '../models/allocation.dart';
import '../models/transaction.dart' as model;

class PaydayService {
  final DatabaseHelper _db;

  PaydayService(this._db);

  Future<void> processRecurringPaydays() async {
    final rules = await _db.getRecurringPaydays(enabledOnly: true);
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);

    for (final rule in rules) {
      if (await _shouldProcess(rule, now)) {
        await _processRule(rule, todayStr);
      }
    }
  }

  Future<bool> _shouldProcess(RecurringPayday rule, DateTime now) async {
    if (rule.lastProcessedDate == null) return true;

    final lastDate = DateTime.tryParse(rule.lastProcessedDate!);
    if (lastDate == null) return true;

    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final lastStr = DateFormat('yyyy-MM-dd').format(lastDate);
    final todayDate = DateTime(now.year, now.month, now.day);

    if (todayStr == lastStr) return false;

    if (rule.frequency == 'weekly') {
      if (rule.weekday == null) return false;
      if (todayDate.weekday != rule.weekday) return false;
      return lastDate.isBefore(todayDate.subtract(const Duration(days: 6)));
    } else if (rule.frequency == 'fortnightly') {
      if (rule.weekday == null) return false;
      if (todayDate.weekday != rule.weekday) return false;
      return lastDate.isBefore(todayDate.subtract(const Duration(days: 13)));
    } else if (rule.frequency == 'monthly') {
      if (rule.monthDay == null) return false;
      if (todayDate.day != rule.monthDay) return false;
      return lastDate.year < now.year ||
          (lastDate.year == now.year && lastDate.month < now.month);
    }

    return false;
  }

  Future<void> _processRule(RecurringPayday rule, String dateStr) async {
    final note = rule.note.isNotEmpty ? rule.note : 'Auto Payday';
    final fullDateStr = '${dateStr}T09:00:00';

    final payday = Payday(
      amount: rule.amount,
      note: note,
      date: fullDateStr,
    );

    final paydayId = await _db.insertPayday(payday);

    final isAutoDivide = await _isAutoDivideEnabled();
    if (isAutoDivide) {
      final allocations = await _buildAutoAllocations(rule.amount);
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
          note: 'Payday: $note',
          date: fullDateStr,
          type: 'funding',
        );
        await _db.insertTransaction(txn);
      }
    }

    await _db.updateRecurringPayday(
      rule.copyWith(lastProcessedDate: dateStr),
    );
  }

  Future<bool> _isAutoDivideEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('auto_divide_enabled') ?? false;
  }

  Future<List<Allocation>> _buildAutoAllocations(double totalAmount) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('alloc_percentages');
    if (raw == null || raw.isEmpty) return [];

    Map<int, double> percentages;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      percentages =
          decoded.map((k, v) => MapEntry(int.parse(k), (v as num).toDouble()));
    } catch (_) {
      return [];
    }

    if (percentages.isEmpty) return [];

    final result = <Allocation>[];
    double allocated = 0;
    final entries = percentages.entries.toList();

    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final pct = entry.value / 100;
      final amount = i == entries.length - 1
          ? totalAmount - allocated
          : totalAmount * pct;

      if (amount > 0.01) {
        result.add(Allocation(
          paydayId: 0,
          envelopeId: entry.key,
          amount: amount,
        ));
        allocated += amount;
      }
    }

    return result;
  }
}
