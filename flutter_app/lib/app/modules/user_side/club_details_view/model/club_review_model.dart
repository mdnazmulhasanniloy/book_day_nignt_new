import 'package:intl/intl.dart';

class ClubReviewModel {
  const ClubReviewModel({
    required this.id,
    required this.rating,
    required this.review,
    required this.createdAt,
    required this.reviewerName,
    required this.reviewerAvatar,
  });

  final String id;
  final int rating;
  final String review;
  final DateTime? createdAt;
  final String reviewerName;
  final String reviewerAvatar;

  String get dateLabel {
    final created = createdAt;
    if (created == null) return '';
    return DateFormat('MMM d, yyyy · h:mm a').format(created.toLocal());
  }

  factory ClubReviewModel.fromJson(Map<String, dynamic> json) {
    final reviewer = json['reviewer'] is Map
        ? Map<String, dynamic>.from(json['reviewer'] as Map)
        : <String, dynamic>{};
    final rating = json['rating'];
    final stars = rating is num
        ? rating.round()
        : int.tryParse(rating?.toString() ?? '') ?? 0;
    return ClubReviewModel(
      id: json['id']?.toString() ?? '',
      rating: stars.clamp(0, 5),
      review: (json['review'] ?? '').toString().trim(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      reviewerName: (reviewer['name'] ?? '').toString().trim(),
      reviewerAvatar: (reviewer['avatar'] ?? '').toString().trim(),
    );
  }
}

class ClubReviewsPage {
  const ClubReviewsPage({
    required this.averageRating,
    required this.total,
    required this.totalPages,
    required this.hasMore,
    required this.reviews,
  });

  final double averageRating;
  final int total;
  final int totalPages;
  final bool hasMore;
  final List<ClubReviewModel> reviews;

  factory ClubReviewsPage.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'] is Map
        ? Map<String, dynamic>.from(json['meta'] as Map)
        : <String, dynamic>{};
    final links = meta['links'] is Map
        ? Map<String, dynamic>.from(meta['links'] as Map)
        : <String, dynamic>{};
    final data = json['data'] is Map
        ? Map<String, dynamic>.from(json['data'] as Map)
        : <String, dynamic>{};
    final rawReviews = data['reviews'];
    final totalPages = _toInt(meta['totalPages']);
    final nextPage = links['nextPage'];
    final reviews = <ClubReviewModel>[];
    if (rawReviews is List) {
      for (final item in rawReviews) {
        if (item is Map) {
          reviews.add(
            ClubReviewModel.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }
    return ClubReviewsPage(
      averageRating: _toDouble(data['averageRating']) ?? 0,
      total: _toInt(meta['total']),
      totalPages: totalPages,
      hasMore: nextPage is String && nextPage.trim().isNotEmpty,
      reviews: reviews,
    );
  }

  static double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
