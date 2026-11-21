import 'package:intl/intl.dart';

class BookingDetailModel {
  const BookingDetailModel({
    required this.id,
    this.orderId = '',
    required this.clubId,
    required this.type,
    required this.name,
    required this.thumbnail,
    required this.latitude,
    required this.longitude,
    required this.location,
    required this.isVip,
    required this.rating,
    required this.startAt,
    required this.endAt,
    required this.guestCount,
    required this.packageName,
    this.tierName = '',
    required this.status,
    required this.grossAmount,
    required this.serviceCharge,
    required this.buyerTotal,
    required this.ticketState,
    required this.reviewState,
  });

  final String id;
  final String orderId;
  final String clubId;
  final String type;
  final String name;
  final String thumbnail;
  final double? latitude;
  final double? longitude;
  final String location;
  final bool isVip;
  final String rating;
  final DateTime? startAt;
  final DateTime? endAt;
  final int? guestCount;
  final String packageName;
  final String tierName;
  final String status;
  final double? grossAmount;
  final double? serviceCharge;
  final double? buyerTotal;
  final String ticketState;
  final String reviewState;

  bool get isEvent => type.toUpperCase() == 'EVENT';
  bool get ticketReady => ticketState.toUpperCase() == 'READY';
  bool get hasReview {
    switch (reviewState.toUpperCase()) {
      case 'REVIEWED':
      case 'SUBMITTED':
      case 'ALREADY_REVIEWED':
        return true;
      default:
        return false;
    }
  }

  String get dateLabel {
    final start = startAt;
    if (start == null) return '--';
    final end = endAt;
    if (end != null && !_sameDay(start, end)) {
      return '${_date(start)} – ${_date(end)}';
    }
    return _date(start);
  }

  String get timeLabel {
    final start = startAt;
    if (start == null) return '--';
    final startClock = _clock(start);
    final end = endAt;
    if (end == null) return startClock;
    return '$startClock – ${_clock(end)}';
  }

  String? get guestsLabel {
    final count = guestCount;
    if (count == null || count <= 0) return null;
    return '$count';
  }

  factory BookingDetailModel.fromJson(Map<String, dynamic> json) {
    final booking = json['booking'] is Map
        ? Map<String, dynamic>.from(json['booking'] as Map)
        : <String, dynamic>{};
    final slot = _slot(booking);
    final payment = booking['payment'] is Map
        ? Map<String, dynamic>.from(booking['payment'] as Map)
        : <String, dynamic>{};
    final rating = _toDouble(json['aggregateRating'] ?? json['review']);

    final nestedOrder = booking['order'] is Map
        ? Map<String, dynamic>.from(booking['order'] as Map)
        : const <String, dynamic>{};
    final topOrder = json['order'] is Map
        ? Map<String, dynamic>.from(json['order'] as Map)
        : nestedOrder;
    return BookingDetailModel(
      id: json['id']?.toString() ?? '',
      orderId: _text(
        json['orderId'],
        booking['orderId'],
        topOrder['id'],
        nestedOrder['id'],
      ),
      clubId: (json['clubId'] ?? '').toString(),
      type: (json['type'] ?? booking['serviceType'] ?? '').toString().toUpperCase(),
      name: _text(
        json['name'],
        json['eventName'],
        slot['eventName'],
        slot['clubName'],
      ),
      thumbnail: json['thumbnail']?.toString() ?? '',
      latitude: _toDouble(json['lat']),
      longitude: _toDouble(json['lng']),
      location: (json['location'] ?? slot['clubLocation'] ?? slot['eventLocation'] ?? '')
          .toString(),
      isVip: json['isVip'] == true,
      rating: rating != null && rating > 0 ? rating.toStringAsFixed(1) : '',
      startAt: _dateTime(
        slot['startAt'] ?? json['startAt'] ?? json['eventStartAt'],
      ),
      endAt: _dateTime(slot['endAt'] ?? json['endAt'] ?? json['eventEndAt']),
      guestCount: _toInt(
        slot['guestCount'] ??
            slot['personCount'] ??
            slot['ticketCount'] ??
            slot['quantity'] ??
            booking['guestCount'] ??
            booking['quantity'] ??
            booking['personCount'] ??
            json['guestCount'] ??
            json['quantity'] ??
            json['totalPersons'],
      ),
      packageName: _text(
        slot['packageName'],
        slot['tierName'],
        slot['moduleName'],
        slot['eventName'],
      ),
      tierName: _text(
        json['tierName'],
        json['moduleName'],
        booking['tierName'],
        booking['moduleName'],
      ).isNotEmpty
          ? _text(
              json['tierName'],
              json['moduleName'],
              booking['tierName'],
              booking['moduleName'],
            )
          : _text(
              slot['tierName'],
              slot['moduleName'],
              slot['packageName'],
              '',
            ),
      status: (booking['status'] ?? '').toString().toUpperCase(),
      grossAmount: _toDouble(payment['grossAmount']),
      serviceCharge: _toDouble(payment['serviceChargeAmount']),
      buyerTotal: _toDouble(payment['buyerTotal']),
      ticketState: (booking['ticketState'] ?? '').toString(),
      reviewState: (booking['reviewState'] ?? '').toString(),
    );
  }

  static Map<String, dynamic> _slot(Map<String, dynamic> booking) {
    for (final key in [
      'clubBooking',
      'eventBooking',
      'eventPurchase',
      'eventModulePurchase',
      'modulePurchase',
      'eventTicketPurchase',
      'ticketPurchase',
      'tierPurchase',
    ]) {
      final value = booking[key];
      if (value is Map) return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }

  static bool _sameDay(DateTime a, DateTime b) {
    final left = a.toUtc();
    final right = b.toUtc();
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  static String _date(DateTime value) {
    final utc = value.toUtc();
    final wall = DateTime(utc.year, utc.month, utc.day);
    return DateFormat('EEE, MMMM d, yyyy').format(wall);
  }

  static String _clock(DateTime value) {
    final utc = value.toUtc();
    final wall = DateTime(utc.year, utc.month, utc.day, utc.hour, utc.minute);
    return DateFormat('h:mm a').format(wall);
  }

  static String _text(dynamic a, dynamic b, dynamic c, dynamic d) {
    for (final value in [a, b, c, d]) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  static DateTime? _dateTime(dynamic value) {
    return DateTime.tryParse(value?.toString() ?? '');
  }

  static double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}

String formatEuro(num amount) {
  final value = amount.toDouble();
  if (value == value.roundToDouble()) {
    return '€${value.toStringAsFixed(0)}';
  }
  return '€${value.toStringAsFixed(2)}';
}
