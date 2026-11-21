import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/local_storage/local_storage.dart';
import '../core/network/base_client.dart';
import '../core/resources/app_const/app_const.dart';
import '../core/utils/custom_snack_bar.dart';

class MediaService {
  static final BaseClient _client = BaseClient();

  /// Uploads single or multiple image/video files to `/api/v1/media`
  /// Field name: "files"
  /// Returns list of uploaded media URLs, or null if failed.
  static Future<List<String>?> uploadMedia(
    List<File> files, {
    bool notifyOnError = true,
  }) async {
    if (files.isEmpty) return [];

    try {
      String? token = LocalStorage.getData(key: AppConst.accessToken);
      Map<String, dynamic> headers = {};
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      Response response = await _client.uploadMultipleFiles(
        endpoint: '/media',
        files: files,
        filesKey: 'files',
        headers: headers,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        dynamic data = response.data;
        if (data != null && data['data'] != null) {
          if (data['data'] is List) {
            return List<String>.from(data['data']);
          } else if (data['data']['urls'] is List) {
            return List<String>.from(data['data']['urls']);
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint("Media Upload Error: $e");
      if (notifyOnError) {
        CustomSnackBar.error(message: "Failed to upload media. Please try again.");
      }
      return null;
    }
  }

  /// Deletes media URLs using `DELETE /api/v1/media`
  /// Body: {"urls": ["url1", "url2"]}
  static Future<bool> deleteMedia(List<String> urls) async {
    if (urls.isEmpty) return true;

    try {
      String? token = LocalStorage.getData(key: AppConst.accessToken);
      Map<String, dynamic> headers = {
        'Content-Type': 'application/json',
      };
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      Response response = await _client.delete(
        endpoint: '/media',
        body: {"urls": urls},
        headers: headers,
      );

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      debugPrint("Media Delete Error: $e");
      return false;
    }
  }
}
