import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/local_storage/local_storage.dart';
import '../../../core/network/base_client.dart';
import '../../../core/network/end_point.dart';
import '../../../core/resources/app_const/app_const.dart';
import '../../../core/resources/common_widget/custom_app_bar.dart';
import '../../../core/resources/common_widget/custom_text.dart';
import '../../../core/utils/html_to_text.dart';

class TermsAndConditionView extends StatefulWidget {
  const TermsAndConditionView({super.key});

  @override
  State<TermsAndConditionView> createState() => _TermsAndConditionViewState();
}

class _TermsAndConditionViewState extends State<TermsAndConditionView> {
  String? apiContent;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTerms();
  }

  Future<void> _fetchTerms() async {
    try {
      String? token = LocalStorage.getData(key: AppConst.accessToken);
      Map<String, dynamic> headers = {};
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      Response response = await BaseClient().get(
        endpoint: EndPoint.TERMS,
        headers: headers,
      );

      if (mounted) {
        setState(() {
          isLoading = false;
          dynamic resData = response.data;
          if (resData != null && resData['success'] == true) {
            var contentObj = resData['data']?['legalContent'];
            if (contentObj != null && contentObj['content'] != null) {
              apiContent = htmlToPlainText(contentObj['content'].toString());
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: const CustomAppBar(title: 'Terms and Conditions'),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFDCA73A)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: apiContent != null && apiContent!.isNotEmpty
                  ? CustomText(
                      text: apiContent!,
                      fontSize: 14,
                      color: Colors.white,
                      height: 1.6,
                    )
                  : const Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 50.0),
                        child: CustomText(
                          text: "Content is currently unavailable.",
                          fontSize: 14,
                          color: Colors.grey,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
            ),
    );
  }
}
