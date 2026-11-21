class OwnerWaitingListUser {
  const OwnerWaitingListUser({
    this.id = '',
    this.name = '',
    this.email = '',
    this.phoneNumber = '',
    this.profileAvatar,
  });

  final String id;
  final String name;
  final String email;
  final String phoneNumber;
  final String? profileAvatar;

  String get displayName {
    final text = name.trim();
    return text.isEmpty ? 'Guest' : text;
  }

  String get contactLine {
    final mail = email.trim();
    if (mail.isNotEmpty) return mail;
    return phoneNumber.trim();
  }

  String get initials {
    final parts = displayName
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'G';
    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  factory OwnerWaitingListUser.fromJson(Map<String, dynamic> json) {
    final avatar = json['profileAvatar']?.toString().trim();
    return OwnerWaitingListUser(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phoneNumber: json['phoneNumber']?.toString() ?? '',
      profileAvatar: avatar == null || avatar.isEmpty ? null : avatar,
    );
  }
}

class OwnerWaitingListEntry {
  const OwnerWaitingListEntry({
    required this.id,
    this.userId = '',
    this.clubId = '',
    this.position,
    this.status = OwnerWaitingListStatus.pending,
    this.createdAt,
    this.startAt,
    this.guestCount,
    this.user = const OwnerWaitingListUser(),
  });

  final String id;
  final String userId;
  final String clubId;
  final int? position;
  final OwnerWaitingListStatus status;
  final DateTime? createdAt;
  final DateTime? startAt;
  final int? guestCount;
  final OwnerWaitingListUser user;

  bool get isNotified => status == OwnerWaitingListStatus.notified;

  OwnerWaitingListEntry copyWith({
    OwnerWaitingListStatus? status,
    int? position,
    DateTime? startAt,
    int? guestCount,
    OwnerWaitingListUser? user,
  }) {
    return OwnerWaitingListEntry(
      id: id,
      userId: userId,
      clubId: clubId,
      position: position ?? this.position,
      status: status ?? this.status,
      createdAt: createdAt,
      startAt: startAt ?? this.startAt,
      guestCount: guestCount ?? this.guestCount,
      user: user ?? this.user,
    );
  }

  factory OwnerWaitingListEntry.fromJson(Map<String, dynamic> json) {
    final user = json['user'] is Map
        ? OwnerWaitingListUser.fromJson(
            Map<String, dynamic>.from(json['user'] as Map),
          )
        : const OwnerWaitingListUser();
    return OwnerWaitingListEntry(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? user.id,
      clubId: json['clubId']?.toString() ?? '',
      position: _toInt(json['position']),
      status: OwnerWaitingListStatus.fromApi(json['status']),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      startAt: DateTime.tryParse(json['startAt']?.toString() ?? ''),
      guestCount: _toInt(json['guestCount']),
      user: user,
    );
  }
}

enum OwnerWaitingListStatus {
  pending,
  notified;

  static OwnerWaitingListStatus fromApi(dynamic value) {
    final raw = value?.toString().trim().toUpperCase() ?? '';
    if (raw == 'NOTIFIED') return OwnerWaitingListStatus.notified;
    return OwnerWaitingListStatus.pending;
  }

  String get label => this == OwnerWaitingListStatus.notified
      ? 'Notified'
      : 'Pending';
}

class OwnerWaitingListPage {
  const OwnerWaitingListPage({
    required this.data,
    this.page = 1,
    this.limit = 20,
    this.total = 0,
    this.totalPages = 1,
    this.message = '',
  });

  final List<OwnerWaitingListEntry> data;
  final int page;
  final int limit;
  final int total;
  final int totalPages;
  final String message;

  factory OwnerWaitingListPage.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'] is Map
        ? Map<String, dynamic>.from(json['meta'] as Map)
        : const <String, dynamic>{};
    final raw = json['data'];
    final rows = raw is List
        ? raw
              .whereType<Map>()
              .map(
                (row) => OwnerWaitingListEntry.fromJson(
                  Map<String, dynamic>.from(row),
                ),
              )
              .where((entry) => entry.id.isNotEmpty)
              .toList()
        : const <OwnerWaitingListEntry>[];
    return OwnerWaitingListPage(
      data: rows,
      page: _toInt(meta['page']) ?? 1,
      limit: _toInt(meta['limit']) ?? 20,
      total: _toInt(meta['total']) ?? 0,
      totalPages: _toInt(meta['totalPages']) ?? 1,
      message: json['message']?.toString() ?? '',
    );
  }
}

int? _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}
