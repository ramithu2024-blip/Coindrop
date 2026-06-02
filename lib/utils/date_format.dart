import 'package:intl/intl.dart';

String formatDate(String dateStr) {
  final date = DateTime.parse(dateStr);
  return DateFormat('MMM dd, yyyy').format(date);
}

String formatDateTime(String dateStr) {
  final date = DateTime.parse(dateStr);
  return DateFormat('MMM dd, yyyy – hh:mm a').format(date);
}

String formatDateShort(String dateStr) {
  final date = DateTime.parse(dateStr);
  final now = DateTime.now();
  final diff = now.difference(date);

  if (diff.inDays == 0) return 'Today';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return DateFormat('MMM dd').format(date);
}

String monthYearKey(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}';
}

String weekKey(DateTime date) {
  final monday = date.subtract(Duration(days: date.weekday - 1));
  return '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
}
