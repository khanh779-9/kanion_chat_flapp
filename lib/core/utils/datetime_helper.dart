import 'package:intl/intl.dart';

class DateTimeHelper {
  // Format cho chat list (giống Telegram)
  static String formatChatListTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    
    if (diff.inSeconds < 60) {
      return 'vừa xong';
    }
    
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} phút';
    }
    
    if (diff.inHours < 24 && now.day == dateTime.day) {
      return DateFormat('HH:mm').format(dateTime);
    }
    
    if (diff.inDays == 1 || (diff.inHours < 48 && now.day - dateTime.day == 1)) {
      return 'Hôm qua';
    }
    
    if (diff.inDays < 7) {
      return _vietnameseDayOfWeek(dateTime.weekday);
    }
    
    if (now.year == dateTime.year) {
      return DateFormat('dd/MM').format(dateTime);
    }
    
    return DateFormat('dd/MM/yy').format(dateTime);
  }

  // Format cho message trong chat
  static String formatMessageTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    
    if (diff.inDays == 0) {
      return DateFormat('HH:mm').format(dateTime);
    }
    
    if (diff.inDays == 1) {
      return 'Hôm qua ${DateFormat('HH:mm').format(dateTime)}';
    }
    
    if (diff.inDays < 7) {
      return '${_vietnameseDayOfWeek(dateTime.weekday)} ${DateFormat('HH:mm').format(dateTime)}';
    }
    
    return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
  }

  // Format cho message separator
  static String formatMessageSeparator(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    
    if (diff.inDays == 0) {
      return 'Hôm nay';
    }
    
    if (diff.inDays == 1) {
      return 'Hôm qua';
    }
    
    if (diff.inDays < 7) {
      return _vietnameseDayOfWeek(dateTime.weekday);
    }
    
    return DateFormat('dd/MM/yyyy').format(dateTime);
  }

  // Format last seen
  static String formatLastSeen(DateTime lastSeen) {
    final now = DateTime.now();
    final diff = now.difference(lastSeen);
    
    if (diff.inMinutes < 5) {
      return 'Đang hoạt động';
    }
    
    if (diff.inMinutes < 60) {
      return 'Hoạt động ${diff.inMinutes} phút trước';
    }
    
    if (diff.inHours < 24) {
      return 'Hoạt động ${diff.inHours} giờ trước';
    }
    
    if (diff.inDays == 1) {
      return 'Hoạt động hôm qua lúc ${DateFormat('HH:mm').format(lastSeen)}';
    }
    
    if (diff.inDays < 7) {
      return 'Hoạt động ${_vietnameseDayOfWeek(lastSeen.weekday)} lúc ${DateFormat('HH:mm').format(lastSeen)}';
    }
    
    return 'Hoạt động ${DateFormat('dd/MM/yyyy').format(lastSeen)}';
  }

  static String _vietnameseDayOfWeek(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Thứ 2';
      case DateTime.tuesday:
        return 'Thứ 3';
      case DateTime.wednesday:
        return 'Thứ 4';
      case DateTime.thursday:
        return 'Thứ 5';
      case DateTime.friday:
        return 'Thứ 6';
      case DateTime.saturday:
        return 'Thứ 7';
      case DateTime.sunday:
        return 'Chủ nhật';
      default:
        return '';
    }
  }

  // Check if two dates are same day
  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
