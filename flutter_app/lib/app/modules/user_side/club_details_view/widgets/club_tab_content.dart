import 'package:flutter/material.dart';
import '../../../../core/resources/common_widget/custom_network_image.dart';
import '../../../../core/resources/common_widget/full_screen_image_viewer.dart';
import '../../../../core/resources/common_widget/custom_text.dart';
import '../model/club_review_model.dart';

class ClubTabContent {
  // Custom Tab Button
  static Widget buildTabButton({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
    required Color primaryColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? primaryColor : const Color(0xFF2A2A2A),
          ),
        ),
        child: CustomText(
          text: title,
          color: isSelected ? Colors.white : Colors.white70,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          fontSize: 12,
          maxLine: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  // 1. About Tab
  static Widget buildAboutTab(Color textGrey, {String? description}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CustomText(
          text: 'Description',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        const SizedBox(height: 12),
        CustomText(
          text:
              description ??
              'Get ready for a high-energy evening featuring live music, signature cocktails, VIP tables, and an unforgettable party crowd. Book your spot early and enjoy a seamless night out at one of the city\'s most exciting venues.\n\nJoin us for an unforgettable night filled with great music, energetic vibes, premium drinks, and a crowd ready to celebrate.',
          fontSize: 14,
          color: textGrey,
          height: 1.5,
        ),
      ],
    );
  }

  // 2. Address Tab
  static Widget buildAddressTab(
    Color cardBgColor,
    Color textGrey, {
    String venue = '32-37 Cowper St, London EC2A 4AP',
    String openingHours = 'Fri: 6 pm - 11 pm',
    String priceRange = '€191.00 person',
    String dressCode = 'Smart casual',
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _addressRow('Venue', venue, textGrey),
          const SizedBox(height: 16),
          _addressRow('Opening hours', openingHours, textGrey),
          const SizedBox(height: 16),
          _addressRow('Price range', priceRange, textGrey),
          const SizedBox(height: 16),
          _addressRow('Dress code', dressCode, textGrey),
        ],
      ),
    );
  }

  static Widget _addressRow(String label, String value, Color textGrey) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: CustomText(text: label, fontSize: 14, color: textGrey),
        ),
        Expanded(
          flex: 3,
          child: CustomText(
            text: value,
            fontSize: 14,
            color: Colors.white,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  // 3. Photos Tab
  static Widget buildPhotosTab(List<String> photos) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: photos.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () => FullScreenImageViewer.open(
            context,
            images: photos,
            initialIndex: index,
          ),
          child: CustomNetworkImage(
            imageUrl: photos[index],
            height: double.infinity,
            width: double.infinity,
            borderRadius: BorderRadius.circular(12),
          ),
        );
      },
    );
  }

  // 4. Tables Tab (New Added)
  static Widget buildTablesTab(
    List<Map<String, dynamic>> tables,
    Color primaryColor,
    Color cardBgColor,
  ) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: tables.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final table = tables[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: CustomText(
                      text: table['title'],
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      maxLine: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  CustomText(
                    text: table['price'],
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                    maxLine: 1,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              CustomText(
                text: 'Capacity: ${table['capacity']}',
                fontSize: 12,
                color: Colors.grey,
              ),
              const SizedBox(height: 12),
              ...table['features']
                  .map<Widget>(
                    (feature) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Container(
                            height: 4,
                            width: 4,
                            decoration: const BoxDecoration(
                              color: Colors.grey,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: CustomText(
                              text: feature,
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ],
          ),
        );
      },
    );
  }

  // 5. Reviews Tab
  static Widget buildReviewsTab(
    List<ClubReviewModel> reviews,
    Color primaryColor,
    Color textGrey, {
    bool isLoadingMore = false,
    VoidCallback? onLoadMore,
  }) {
    return Column(
      children: [
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: reviews.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final review = reviews[index];
            final name = review.reviewerName.isEmpty
                ? 'Guest'
                : review.reviewerName;
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFE1B144).withValues(alpha: 0.28),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ReviewerAvatar(
                        name: name,
                        avatar: review.reviewerAvatar,
                        color: primaryColor,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CustomText(
                              text: name,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              maxLine: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (review.dateLabel.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              CustomText(
                                text: review.dateLabel,
                                fontSize: 12,
                                color: textGrey,
                                maxLine: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(5, (starIndex) {
                          return Icon(
                            starIndex < review.rating
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            color: primaryColor,
                            size: 15,
                          );
                        }),
                      ),
                    ],
                  ),
                  if (review.review.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    CustomText(
                      text: review.review,
                      fontSize: 14,
                      color: Colors.white70,
                      height: 1.5,
                    ),
                  ],
                ],
              ),
            );
          },
        ),
        if (isLoadingMore)
          const Padding(
            padding: EdgeInsets.only(top: 20),
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFFE1B144),
              ),
            ),
          )
        else if (onLoadMore != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextButton(
              onPressed: onLoadMore,
              child: const CustomText(
                text: 'Load more',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFFE1B144),
              ),
            ),
          ),
      ],
    );
  }
}

class _ReviewerAvatar extends StatelessWidget {
  const _ReviewerAvatar({
    required this.name,
    required this.avatar,
    required this.color,
  });

  final String name;
  final String avatar;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final initial = name.isEmpty ? 'G' : name[0].toUpperCase();
    if (avatar.startsWith('http')) {
      return CustomNetworkImage(
        imageUrl: avatar,
        height: 36,
        width: 36,
        boxShape: BoxShape.circle,
        fit: BoxFit.cover,
      );
    }
    return CircleAvatar(
      radius: 18,
      backgroundColor: color.withValues(alpha: 0.18),
      child: CustomText(
        text: initial,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    );
  }
}
