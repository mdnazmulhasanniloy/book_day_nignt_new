import '../../../../core/local_storage/local_storage.dart';
import '../../../../core/network/base_client.dart';
import '../../../../core/network/end_point.dart';
import '../../../../core/resources/app_const/app_const.dart';
import '../model/club_api_model.dart';
import '../model/club_upsert_model.dart';

class ClubRepository {
  ClubRepository({BaseClient? client}) : _client = client ?? BaseClient();

  final BaseClient _client;

  Future<ClubMutationResponseModel> createClub(
    ClubUpsertRequestModel request,
  ) async {
    final response = await _client.post(
      endpoint: EndPoint.clubs,
      body: request.toJson(isUpdate: false),
      headers: _authorizedHeaders,
    );
    return ClubMutationResponseModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<ClubListResponseModel> getOwnClubs({
    int page = 1,
    int limit = 10,
    bool? isActive,
  }) async {
    String endpoint = '${EndPoint.clubs}?page=$page&limit=$limit';
    if (isActive != null) {
      endpoint += '&isActive=$isActive';
    }
    final response = await _client.get(
      endpoint: endpoint,
      headers: _authorizedHeaders,
    );
    return ClubListResponseModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<ClubDetailResponseModel> getClubDetail(String id) async {
    final response = await _client.get(
      endpoint: EndPoint.clubById(id),
      headers: _authorizedHeaders,
    );
    return ClubDetailResponseModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<ClubMutationResponseModel> updateClub({
    required String id,
    required ClubUpsertRequestModel request,
  }) async {
    final response = await _client.put(
      endpoint: EndPoint.clubById(id),
      body: request.toJson(isUpdate: true),
      headers: _authorizedHeaders,
    );
    return ClubMutationResponseModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Map<String, dynamic> get _authorizedHeaders {
    final token = LocalStorage.getData(key: AppConst.accessToken)?.toString();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }
}
