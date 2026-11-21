import 'package:bookdianight_app/app/core/network/base_client.dart';
import 'package:bookdianight_app/app/core/network/end_point.dart';
import 'package:bookdianight_app/app/modules/profile/model/profile_model.dart';
import 'package:bookdianight_app/app/modules/authentication/model/sign_up_model.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class AuthRepository {
  final BaseClient _client = BaseClient();

  static String? sessionToken(Map<String, dynamic>? data) {
    if (data == null) return null;
    for (final key in ['token', 'accessToken']) {
      final value = data[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return null;
  }

  /// Sign Up API
  Future<SignUpResponseModel> signUp(SignUpRequestModel request) async {
    final response = await _client.post(
      endpoint: EndPoint.CREATE_ACCOUNT,
      body: request.toJson(),
    );
    return SignUpResponseModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  /// Login API
  Future<Response> login(Map<String, dynamic> body) async {
    return await _client.post(endpoint: EndPoint.LOGIN, body: body);
  }

  /// Social login. Body must match POST /auth/social (idToken + provider).
  Future<Response> socialLogin(Map<String, dynamic> body) async {
    return await _client.post(endpoint: EndPoint.socialLogin, body: body);
  }

  /// Verify OTP API (Email or Recover)
  Future<Response> verifyOtp({
    required String endpoint,
    required Map<String, dynamic> body,
    String? token,
  }) async {
    Map<String, dynamic> headers = {};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return await _client.post(endpoint: endpoint, body: body, headers: headers);
  }

  /// Resend OTP API (Signup flow)
  Future<Response> resendOtp({
    required Map<String, dynamic> body,
    String? token,
  }) async {
    Map<String, dynamic> headers = {};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return await _client.post(
      endpoint: EndPoint.RESEND_OTP,
      body: body,
      headers: headers,
    );
  }

  /// Resend Recover OTP API (Password recover flow)
  Future<Response> resendRecoverOtp({String? token}) async {
    Map<String, dynamic> headers = {};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return await _client.post(
      endpoint: EndPoint.FORGOT_PASSWORD_RESEND,
      body: {},
      headers: headers,
    );
  }

  /// Forgot Password - Find User & Send OTP
  Future<Response> forgotPassword(String email) async {
    return await _client.post(
      endpoint: EndPoint.FORGOT_PASSWORD,
      body: {"email": email},
    );
  }

  /// Reset Password API (Body: {"password": "newStrongPassword123!"})
  Future<Response> resetPassword({
    required Map<String, dynamic> body,
    String? token,
  }) async {
    Map<String, dynamic> headers = {};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return await _client.post(
      endpoint: EndPoint.RESET_PASSWORD,
      body: body,
      headers: headers,
    );
  }

  /// Check Auth API
  Future<Response> checkAuth({
    required String deviceIdentifier,
    required String platform,
    required double lat,
    required double lng,
    String? fcmToken,
    String? token,
  }) async {
    Map<String, dynamic> headers = {};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return await _client.post(
      endpoint: EndPoint.CHECK_AUTH,
      body: {
        'deviceIdentifier': deviceIdentifier,
        'platform': platform,
        'lat': lat,
        'lng': lng,
        if (fcmToken != null && fcmToken.trim().isNotEmpty)
          'fcmToken': fcmToken.trim(),
      },
      headers: headers,
    );
  }

  /// Logout API
  Future<Response> logout({
    required String deviceIdentifier,
    String? token,
  }) async {
    Map<String, dynamic> headers = {};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return await _client.post(
      endpoint: EndPoint.LOGOUT,
      body: {"deviceIdentifier": deviceIdentifier},
      headers: headers,
    );
  }

  /// Get User Profile API
  Future<ProfileResponseModel?> getProfile(String token) async {
    try {
      Map<String, dynamic> headers = {'Authorization': 'Bearer $token'};
      Response response = await _client.get(
        endpoint: EndPoint.PROFILE,
        headers: headers,
      );

      if (response.statusCode == 200 && response.data != null) {
        return ProfileResponseModel.fromJson(response.data);
      }
      return null;
    } catch (e) {
      debugPrint("AuthRepository getProfile error: $e");
      return null;
    }
  }
}
