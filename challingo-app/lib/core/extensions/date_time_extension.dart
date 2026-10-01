import 'package:intl/intl.dart';

extension DateTimeExtension on DateTime? {
  String? get toRequest {
    if (this == null) return null;
    return DateFormat('yyyy-MM-dd').format(this!);
  }

  /// return true if device time is correct comparing with currentServerTime.
  bool isDeviceTimeCorrect(DateTime currentServerTime) {
    if (this == null) return false;

    final difference = this!.difference(currentServerTime);
    return (difference.inHours <= 2);
  }

  /// Relative "time ago" label (`5m`, `3h`, `2d`, …); falls back to a short
  /// date for older moments. Persian output when [locale] (or the current
  /// Intl locale) starts with `fa`.
  String getUntilNowMessage({String? locale}) {
    if (this == null) return '--';

    final lang = locale ?? Intl.getCurrentLocale();
    final isFa = lang.startsWith('fa');
    final now = DateTime.now().toUtc();
    final moment = this!.toUtc();
    final diff = now.difference(moment);

    if (diff.isNegative || diff.inSeconds < 60) {
      return isFa ? 'الان' : 'Just now';
    }

    final minutes = diff.inMinutes;
    if (minutes < 60) {
      return isFa ? '$minutes دقیقه پیش' : '${minutes}m';
    }

    final hours = diff.inHours;
    if (hours < 24) {
      return isFa ? '$hours ساعت پیش' : '${hours}h';
    }

    final days = diff.inDays;
    if (days < 7) {
      return isFa ? '$days روز پیش' : '${days}d';
    }

    if (days < 28) {
      final weeks = days ~/ 7;
      return isFa ? '$weeks هفته پیش' : '${weeks}w';
    }

    final local = moment.toLocal();
    final currentYear = DateTime.now().year;
    if (local.year == currentYear) {
      return DateFormat.MMMd(lang).format(local);
    }
    return DateFormat.yMMMd(lang).format(local);
  }
}
