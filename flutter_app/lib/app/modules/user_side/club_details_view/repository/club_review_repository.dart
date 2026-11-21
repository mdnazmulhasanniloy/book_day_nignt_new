import '../../../../core/local_storage/local_storage.dart';
import '../../../../core/network/base_client.dart';
import '../../../../core/network/end_point.dart';
import '../../../../core/resources/app_const/app_const.dart';
import '../model/club_review_model.dart';

class ClubReviewRepository {
  ClubReviewRepository({BaseClient? client}) : _client = client ?? BaseClient();

  final BaseClient _client;

  Map<String, dynamic> _authHeaders() {
    final token = LocalStorage.getData(key: AppConst.accessToken)?.toString();
    return {
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<ClubReviewsPage> fetchReviews({
    required String clubId,
    required int page,
    int limit = 10,
  }) async {
    final response = await _client.get(
      endpoint: EndPoint.clubReviews(clubId),
      params: {
        'page': page,
        'limit': limit,
      },
      headers: _authHeaders(),
    );
    final body = response.data;
    if (body is! Map) {
      throw const FormatException('Invalid reviews response');
    }
    return ClubReviewsPage.fromJson(Map<String, dynamic>.from(body));
  }

  Future<void> createReview({
    required String clubId,
    required int rating,
    required String review,
  }) async {
    await _client.post(
      endpoint: EndPoint.reviews,
      headers: _authHeaders(),
      body: {
        'clubId': clubId,
        'rating': rating,
        'review': review,
      },
    );
  }
}
