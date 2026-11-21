import '../../../../core/local_storage/local_storage.dart';
import '../../../../core/network/base_client.dart';
import '../../../../core/network/end_point.dart';
import '../../../../core/resources/app_const/app_const.dart';

class TicketVerification {
  const TicketVerification({
    required this.message,
    required this.orderId,
    this.buyerName,
    this.status,
    this.checkedInAt,
    this.details = const {},
  });

  final String message;
  final String orderId;
  final String? buyerName;
  final String? status;
  final DateTime? checkedInAt;

  /// Any other primitive fields the backend returns, keyed by API name.
  final Map<String, String> details;

  static const _knownKeys = {'orderId', 'buyerName', 'status', 'checkedInAt'};

  factory TicketVerification.fromJson(Map<String, dynamic> json) {
    final raw = json['data'];
    final data = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    final details = <String, String>{};
    data.forEach((key, value) {
      if (_knownKeys.contains(key) || value == null) return;
      if (value is String || value is num || value is bool) {
        final text = value.toString().trim();
        if (text.isNotEmpty) details[key] = text;
      }
    });
    return TicketVerification(
      message: json['message']?.toString() ?? 'Ticket verified',
      orderId: data['orderId']?.toString() ?? '',
      buyerName: data['buyerName']?.toString(),
      status: data['status']?.toString(),
      checkedInAt: DateTime.tryParse(data['checkedInAt']?.toString() ?? '')
          ?.toLocal(),
      details: details,
    );
  }
}

class TicketScannerRepository {
  TicketScannerRepository({BaseClient? client})
    : _client = client ?? BaseClient();

  final BaseClient _client;

  static final _uuidPattern = RegExp(
    r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
  );

  /// QR payloads may be a bare order ID or a URL containing it.
  static String extractOrderId(String rawValue) {
    final value = rawValue.trim();
    return _uuidPattern.firstMatch(value)?.group(0) ?? value;
  }

  Future<TicketVerification> verifyTicket(String orderId) async {
    final token = LocalStorage.getData(key: AppConst.accessToken)?.toString();
    final response = await _client.post(
      endpoint: EndPoint.verifyTicket,
      body: {'orderId': orderId},
      headers: {
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
    );
    final body = response.data;
    if (body is! Map) {
      throw const FormatException('Invalid verify-ticket response');
    }
    final json = Map<String, dynamic>.from(body);
    if (json['success'] != true) {
      throw FormatException(
        json['message']?.toString() ?? 'Ticket could not be verified',
      );
    }
    return TicketVerification.fromJson(json);
  }
}
