import 'package:intl/intl.dart';

class NotificationModel {
  NotificationModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.when,
    required this.group,
    this.isRead = false,
    this.routingData = const {},
  });

  final String id;
  final String title;
  final String subtitle;
  final String time;
  final String when;
  final String group;
  bool isRead;
  final Map<String, dynamic> routingData;

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final created = DateTime.tryParse(json['createdAt']?.toString() ?? '');
    final local = created?.toLocal();
    final title = _text(json, const [
      'notificationTitle',
      'title',
      'subject',
      'heading',
    ]);
    final subtitle = _text(json, const [
      'notificationDescription',
      'description',
      'body',
      'message',
      'content',
      'text',
    ]);
    final type = _text(json, const ['notificationType', 'type']);
    return NotificationModel(
      id: json['id']?.toString() ?? '',
      title: title.isNotEmpty
          ? title
          : (type.isNotEmpty ? _readableType(type) : 'Notification'),
      subtitle: subtitle,
      time: local == null ? '' : DateFormat('h:mm a').format(local),
      when: local == null
          ? ''
          : DateFormat('MMM d, yyyy · h:mm a').format(local),
      group: local == null ? 'Earlier' : _groupLabel(local),
      isRead: json['isRead'] == true,
      routingData: Map<String, dynamic>.from(json),
    );
  }

  static String _text(Map<String, dynamic> json, List<String> keys) {
    final value = _match(json, keys);
    if (value != null) return value;
    final meta = json['metaData'] ?? json['metadata'];
    if (meta is Map) {
      return _match(Map<String, dynamic>.from(meta), keys) ?? '';
    }
    return '';
  }

  static String? _match(Map<String, dynamic> json, List<String> keys) {
    final lowered = <String, dynamic>{
      for (final entry in json.entries)
        entry.key.toString().toLowerCase(): entry.value,
    };
    for (final key in keys) {
      final value = lowered[key.toLowerCase()];
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && text != 'null') return text;
    }
    return null;
  }

  static String _readableType(String raw) {
    final words = raw
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .trim()
        .split(RegExp(r'\s+'));
    if (words.isEmpty) return 'Notification';
    return words
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  static String _groupLabel(DateTime local) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    if (day == today) return 'Today';
    if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return DateFormat('MMM d, yyyy').format(local);
  }
}
