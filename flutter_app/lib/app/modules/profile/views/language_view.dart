import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/resources/common_widget/custom_app_bar.dart';
import '../../../core/resources/common_widget/custom_text.dart';
import '../controllers/profile_controller.dart';

class LanguageModel {
  final String name;
  final String nativeName;
  final String code;

  const LanguageModel({
    required this.name,
    required this.nativeName,
    required this.code,
  });
}

class LanguageView extends StatelessWidget {
  const LanguageView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ProfileController>();

    final List<LanguageModel> languages = const [
      LanguageModel(name: "English", nativeName: "English", code: "en"),
      LanguageModel(name: "Spanish", nativeName: "Español", code: "es"),
      LanguageModel(name: "French", nativeName: "Français", code: "fr"),
      LanguageModel(name: "German", nativeName: "Deutsch", code: "de"),
      LanguageModel(name: "Arabic", nativeName: "العربية", code: "ar"),
      LanguageModel(name: "Italian", nativeName: "Italiano", code: "it"),
      LanguageModel(name: "Portuguese", nativeName: "Português", code: "pt"),
      LanguageModel(name: "Dutch", nativeName: "Nederlands", code: "nl"),
    ];

    const Color primaryYellow = Color(0xFFDCA73A);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: const CustomAppBar(title: "Language"),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CustomText(
              text: "Select Language",
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.separated(
                itemCount: languages.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final lang = languages[index];
                  return Obx(() {
                    bool isSelected =
                        controller.selectedLanguage.value == lang.name ||
                        controller.selectedLanguage.value == lang.code;

                    return GestureDetector(
                      onTap: () {
                        controller.selectedLanguage.value = lang.name;
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF161616),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: isSelected
                                ? primaryYellow
                                : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              height: 38,
                              width: 38,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF261D0A)
                                    : Colors.white.withValues(alpha: 0.05),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.translate,
                                color:
                                    isSelected ? primaryYellow : Colors.white,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 15),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CustomText(
                                  text: lang.name,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                                const SizedBox(height: 2),
                                CustomText(
                                  text: lang.nativeName,
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ],
                            ),
                            const Spacer(),
                            Icon(
                              isSelected
                                  ? Icons.check_circle
                                  : Icons.radio_button_off,
                              color: isSelected ? primaryYellow : Colors.grey,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    );
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
