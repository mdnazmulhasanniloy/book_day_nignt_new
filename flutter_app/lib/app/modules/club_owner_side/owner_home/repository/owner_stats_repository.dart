import 'package:intl/intl.dart';

import '../../../../core/local_storage/local_storage.dart';
import '../../../../core/network/base_client.dart';
import '../../../../core/network/end_point.dart';
import '../../../../core/resources/app_const/app_const.dart';

class OwnerStatsRepository {
  OwnerStatsRepository({BaseClient? client}) : _client = client ?? BaseClient();

  final BaseClient _client;

  Map<String, dynamic> _authHeaders() {
    final token = LocalStorage.getData(key: AppConst.accessToken)?.toString();
    return {
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<OwnerDashboardModel> fetchDashboard() async {
    final response = await _client.get(
      endpoint: EndPoint.ownerDashboard,
      headers: _authHeaders(),
    );
    return OwnerDashboardModel.fromJson(_body(response.data));
  }

  Future<OwnerEarningsModel> fetchEarnings({required int year}) async {
    final start = DateTime.utc(year, 1, 1);
    final end = DateTime.utc(year, 12, 31, 23, 59, 59);
    final response = await _client.get(
      endpoint: EndPoint.ownerEarnings,
      params: {
        'startDate': start.toIso8601String(),
        'endDate': end.toIso8601String(),
      },
      headers: _authHeaders(),
    );
    return OwnerEarningsModel.fromJson(_body(response.data));
  }

  static final Map<String, String> _eventNamesCache = {};
  static final Map<String, String> _clubNamesCache = {};

  static void recordEventName(String id, String name) {
    if (id.trim().isNotEmpty && name.trim().isNotEmpty) {
      _eventNamesCache[id.trim()] = name.trim();
    }
  }

  static void recordClubName(String id, String name) {
    if (id.trim().isNotEmpty && name.trim().isNotEmpty) {
      _clubNamesCache[id.trim()] = name.trim();
    }
  }

  Future<OwnerPaymentsPage> fetchPayments({
    String? type,
    String? clubId,
    String? eventId,
    required int page,
    int limit = 10,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (type != null && type.isNotEmpty) 'type': type,
      if (clubId != null && clubId.isNotEmpty) 'clubId': clubId,
      if (eventId != null && eventId.isNotEmpty) 'eventId': eventId,
    };
    final response = await _client.get(
      endpoint: EndPoint.ownerPayments,
      params: params,
      headers: _authHeaders(),
    );
    final pageData = OwnerPaymentsPage.fromJson(_body(response.data));
    final hasMissingNames = pageData.payments.any(
      (p) =>
          (p.eventName.isEmpty && p.eventId.isNotEmpty) ||
          (p.clubName.isEmpty && p.clubId.isNotEmpty),
    );

    if (hasMissingNames && _eventNamesCache.isEmpty) {
      try {
        final evRes = await _client.get(
          endpoint: EndPoint.events,
          params: {'page': 1, 'limit': 50},
          headers: _authHeaders(),
        );
        final evData = evRes.data;
        if (evData is Map && evData['data'] is List) {
          for (final row in evData['data']) {
            if (row is Map) {
              final id = row['id']?.toString() ?? '';
              final name =
                  (row['eventName'] ?? row['name'] ?? row['title'])
                      ?.toString() ??
                  '';
              recordEventName(id, name);
            }
          }
        }
      } catch (_) {}
    }

    final enrichedPayments = pageData.payments.map((p) {
      var ev = p.eventName;
      var cl = p.clubName;
      if (ev.isEmpty &&
          p.eventId.isNotEmpty &&
          _eventNamesCache.containsKey(p.eventId)) {
        ev = _eventNamesCache[p.eventId]!;
      }
      if (cl.isEmpty &&
          p.clubId.isNotEmpty &&
          _clubNamesCache.containsKey(p.clubId)) {
        cl = _clubNamesCache[p.clubId]!;
      }
      return p.copyWith(eventName: ev, clubName: cl);
    }).toList();

    return OwnerPaymentsPage(
      total: pageData.total,
      totalPages: pageData.totalPages,
      hasMore: pageData.hasMore,
      payments: enrichedPayments,
    );
  }

  Map<String, dynamic> _body(dynamic data) {
    if (data is Map) return Map<String, dynamic>.from(data);
    throw const FormatException('Invalid owner response');
  }
}

class OwnerRecentBooking {
  const OwnerRecentBooking({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.location,
    required this.type,
    required this.thumbnail,
    required this.review,
    required this.isVip,
    required this.minPrice,
  });

  final String id;
  final String name;
  final double? latitude;
  final double? longitude;
  final String location;
  final String type;
  final String thumbnail;
  final double? review;
  final bool isVip;
  final double? minPrice;

  bool get isEvent => type.toUpperCase() == 'EVENT';

  factory OwnerRecentBooking.fromJson(Map<String, dynamic> json) {
    final range = json['priceRange'] is Map
        ? Map<String, dynamic>.from(json['priceRange'] as Map)
        : <String, dynamic>{};
    return OwnerRecentBooking(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      latitude: _toDouble(json['lat']),
      longitude: _toDouble(json['lng']),
      location: json['location']?.toString() ?? '',
      type: json['type']?.toString().toUpperCase() ?? '',
      thumbnail: json['thumbnail']?.toString() ?? '',
      review: _toDouble(json['review']),
      isVip: json['isVip'] == true,
      minPrice: _toDouble(range['minPrice'] ?? json['price']),
    );
  }
}

class OwnerDashboardModel {
  const OwnerDashboardModel({
    required this.totalClubBookings,
    required this.totalEventTicketsSold,
    required this.totalEarnings,
    required this.thisMonthEarnings,
    required this.recentBookings,
  });

  final int totalClubBookings;
  final int totalEventTicketsSold;
  final double totalEarnings;
  final double thisMonthEarnings;
  final List<OwnerRecentBooking> recentBookings;

  factory OwnerDashboardModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map
        ? Map<String, dynamic>.from(json['data'] as Map)
        : <String, dynamic>{};
    final raw = data['recentBookings'];
    return OwnerDashboardModel(
      totalClubBookings: _toInt(data['totalClubBookings']),
      totalEventTicketsSold: _toInt(data['totalEventTicketsSold']),
      totalEarnings: _toDouble(data['totalEarnings']) ?? 0,
      thisMonthEarnings: _toDouble(data['thisMonthEarnings']) ?? 0,
      recentBookings: raw is List
          ? [
              for (final item in raw)
                if (item is Map)
                  OwnerRecentBooking.fromJson(Map<String, dynamic>.from(item)),
            ]
          : const [],
    );
  }
}

class OwnerMonthEarning {
  const OwnerMonthEarning({required this.month, required this.amount});

  final int month;
  final double amount;

  String get label {
    const names = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    if (month < 1 || month > 12) return '$month';
    return names[month - 1];
  }
}

class OwnerEarningsModel {
  const OwnerEarningsModel({
    required this.last7DaysRevenue,
    required this.todayRevenue,
    required this.todayTotalClubBookings,
    required this.todayTotalEventTicketsSold,
    required this.selectedYear,
    required this.months,
    required this.availableYears,
  });

  final double last7DaysRevenue;
  final double todayRevenue;
  final int todayTotalClubBookings;
  final int todayTotalEventTicketsSold;
  final int selectedYear;
  final List<OwnerMonthEarning> months;
  final List<int> availableYears;

  factory OwnerEarningsModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map
        ? Map<String, dynamic>.from(json['data'] as Map)
        : <String, dynamic>{};
    final today = data['todayOverview'] is Map
        ? Map<String, dynamic>.from(data['todayOverview'] as Map)
        : <String, dynamic>{};
    final monthly = data['monthlyEarning'] is Map
        ? Map<String, dynamic>.from(data['monthlyEarning'] as Map)
        : <String, dynamic>{};
    final rawMonths = monthly['data'];
    final rawYears = monthly['availableYears'];
    return OwnerEarningsModel(
      last7DaysRevenue: _toDouble(today['last7DaysRevenue']) ?? 0,
      todayRevenue: _toDouble(today['todayRevenue']) ?? 0,
      todayTotalClubBookings: _toInt(today['todayTotalClubBookings']),
      todayTotalEventTicketsSold: _toInt(today['todayTotalEventTicketsSold']),
      selectedYear: _toInt(monthly['selectedYear']),
      months: rawMonths is List
          ? [
              for (final item in rawMonths)
                if (item is Map)
                  OwnerMonthEarning(
                    month: _toInt(
                      Map<String, dynamic>.from(item)['month'],
                    ),
                    amount:
                        _toDouble(
                          Map<String, dynamic>.from(item)['amount'],
                        ) ??
                        0,
                  ),
            ]
          : const [],
      availableYears: rawYears is List
          ? rawYears.map(_toInt).where((year) => year > 0).toList()
          : const [],
    );
  }
}

class OwnerPaymentItem {
  const OwnerPaymentItem({
    required this.id,
    required this.type,
    required this.clubId,
    required this.eventId,
    required this.title,
    required this.customerName,
    required this.createdAt,
    required this.amount,
    this.eventName = '',
    this.clubName = '',
    this.tierName = '',
  });

  final String id;
  final String type;
  final String clubId;
  final String eventId;
  final String title;
  final String customerName;
  final DateTime? createdAt;
  final double amount;
  final String eventName;
  final String clubName;
  final String tierName;

  String get amountLabel => '+${formatOwnerEuro(amount)}';

  String get customerLabel =>
      customerName.trim().isEmpty ? 'Guest' : customerName.trim();

  String get typeLabel => type == 'EVENT' ? 'Event' : 'Club';

  String get venueName => eventName.isNotEmpty
      ? eventName
      : (clubName.isNotEmpty ? clubName : '');

  String get dateLabel {
    final created = createdAt;
    if (created == null) return '--';
    return DateFormat('EEE, MMM d, yyyy · h:mm a').format(created.toLocal());
  }

  String get subtitle {
    final venue = venueName;
    final prefix = venue.isNotEmpty ? '$venue • ' : '';
    return '$prefix$customerLabel • $dateLabel';
  }

  OwnerPaymentItem copyWith({
    String? id,
    String? type,
    String? clubId,
    String? eventId,
    String? title,
    String? customerName,
    DateTime? createdAt,
    double? amount,
    String? eventName,
    String? clubName,
    String? tierName,
  }) {
    return OwnerPaymentItem(
      id: id ?? this.id,
      type: type ?? this.type,
      clubId: clubId ?? this.clubId,
      eventId: eventId ?? this.eventId,
      title: title ?? this.title,
      customerName: customerName ?? this.customerName,
      createdAt: createdAt ?? this.createdAt,
      amount: amount ?? this.amount,
      eventName: eventName ?? this.eventName,
      clubName: clubName ?? this.clubName,
      tierName: tierName ?? this.tierName,
    );
  }

  factory OwnerPaymentItem.fromJson(Map<String, dynamic> json) {
    final eventObj = json['event'] is Map ? json['event'] as Map : null;
    final clubObj = json['club'] is Map ? json['club'] as Map : null;

    final parsedEventName = (json['eventName'] ??
            json['eventTitle'] ??
            eventObj?['name'] ??
            eventObj?['title'] ??
            eventObj?['eventName'])
        ?.toString() ??
        '';

    final parsedClubName = (json['clubName'] ??
            clubObj?['name'] ??
            clubObj?['title'] ??
            clubObj?['clubName'])
        ?.toString() ??
        '';

    final parsedTier = (json['tierName'] ??
            json['moduleName'] ??
            json['packageName'] ??
            json['ticketTierName'])
        ?.toString() ??
        '';

    return OwnerPaymentItem(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString().toUpperCase() ?? '',
      clubId: json['clubId']?.toString() ?? '',
      eventId: json['eventId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      customerName: json['customerName']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      amount: _toDouble(json['amount']) ?? 0,
      eventName: parsedEventName,
      clubName: parsedClubName,
      tierName: parsedTier,
    );
  }
}

class OwnerPaymentsPage {
  const OwnerPaymentsPage({
    required this.total,
    required this.totalPages,
    required this.hasMore,
    required this.payments,
  });

  final int total;
  final int totalPages;
  final bool hasMore;
  final List<OwnerPaymentItem> payments;

  factory OwnerPaymentsPage.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'] is Map
        ? Map<String, dynamic>.from(json['meta'] as Map)
        : <String, dynamic>{};
    final links = meta['links'] is Map
        ? Map<String, dynamic>.from(meta['links'] as Map)
        : <String, dynamic>{};
    final raw = json['data'];
    final nextPage = links['nextPage'];
    return OwnerPaymentsPage(
      total: _toInt(meta['total']),
      totalPages: _toInt(meta['totalPages']),
      hasMore: nextPage is String && nextPage.trim().isNotEmpty,
      payments: raw is List
          ? [
              for (final item in raw)
                if (item is Map)
                  OwnerPaymentItem.fromJson(Map<String, dynamic>.from(item)),
            ]
          : const [],
    );
  }
}

String formatOwnerEuro(num amount) {
  final value = amount.toDouble();
  if (value == value.roundToDouble()) {
    return '€${value.toStringAsFixed(0)}';
  }
  return '€${value.toStringAsFixed(2)}';
}

double? _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

int _toInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
