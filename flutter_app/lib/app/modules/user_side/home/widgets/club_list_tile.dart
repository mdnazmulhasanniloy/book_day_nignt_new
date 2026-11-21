import '../../club_details_view/widgets/club_community_section.dart';
import '../../../../core/resources/common_widget/address_from_coordinates.dart';
import '../../../../core/resources/common_widget/custom_network_image.dart';
import '../../../../core/resources/common_widget/custom_text.dart';
import '../../../../core/utils/resource_const.dart';
import '../controllers/club_controller.dart';
import 'home_reuseble.dart';

class ClubListTile extends StatelessWidget {
  final ClubModel club;
  const ClubListTile({super.key, required this.club});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CustomNetworkImage(
                imageUrl: club.image,
                height: 80,
                width: 80,
                borderRadius: BorderRadius.circular(12),
              ),
              if (club.hasRating)
                Positioned(
                  top: 5,
                  right: 5,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .78),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: discoveryGold,
                          size: 11,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          club.rating,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            height: 1,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: CustomText(
                        text: club.title,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        maxLine: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (club.id.isNotEmpty)
                      ClubFollowButton(
                        key: ValueKey(club.id),
                        clubId: club.id,
                        dense: true,
                      ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      color: Colors.grey,
                      size: 12,
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: AddressFromCoordinates(
                        lat: club.latitude,
                        lng: club.longitude,
                        existingAddress: club.location,
                        color: Colors.grey,
                        fontSize: 10,
                        maxLine: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _buildTags()),
                    if (club.price.isNotEmpty)
                      CustomText(
                        text: "From ${club.price}",
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        maxLine: 1,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTags() {
    final tags = club.tags?.take(2).toList() ?? const <String>[];
    if (tags.isEmpty) return const SizedBox.shrink();

    return Row(
      children: [
        for (var index = 0; index < tags.length; index++) ...[
          Flexible(child: CommonComponents.buildBadge(tags[index])),
          if (index < tags.length - 1) const SizedBox(width: 5),
        ],
      ],
    );
  }
}
