import 'package:flutter/material.dart';

import '../../../../core/resources/common_widget/theme_shimmer.dart';

class ExploreListShimmer extends StatelessWidget {
  const ExploreListShimmer({
    super.key,
    this.count = 3,
    this.showFavorite = true,
    this.compact = true,
    this.padding = const EdgeInsets.fromLTRB(20, 10, 20, 130),
    this.separatorHeight = 25,
  });

  final int count;
  final bool showFavorite;
  final bool compact;
  final EdgeInsetsGeometry padding;
  final double separatorHeight;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: padding,
      itemCount: count,
      separatorBuilder: (_, _) => SizedBox(height: separatorHeight),
      itemBuilder: (_, _) => ExploreEventCardShimmer(
        showFavorite: showFavorite,
        compact: compact,
      ),
    );
  }
}

class ExploreEventCardShimmer extends StatelessWidget {
  const ExploreEventCardShimmer({
    super.key,
    this.showFavorite = true,
    this.compact = true,
  });

  final bool showFavorite;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 240,
      decoration: BoxDecoration(
        color: ThemeShimmer.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 155,
            child: ColoredBox(color: ThemeShimmer.photo),
          ),
          if (showFavorite)
            const Positioned(
              top: 15,
              right: 15,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xE60E0E0E),
                  shape: BoxShape.circle,
                ),
                child: SizedBox.square(dimension: 38),
              ),
            ),
          ThemeShimmer(
            child: Stack(
              children: [
                if (showFavorite)
                  const Positioned(
                    top: 23,
                    right: 23,
                    child: ShimmerIcon(Icons.favorite_border, size: 22),
                  ),
                Positioned(
                  left: 15,
                  right: 15,
                  bottom: 15,
                  child: compact
                      ? const _CompactCardMeta()
                      : const _FavoriteCardMeta(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactCardMeta extends StatelessWidget {
  const _CompactCardMeta();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            ShimmerBone(width: 52, height: 22, radius: 20),
            SizedBox(width: 6),
            ShimmerIcon(Icons.star_rounded, size: 14),
            SizedBox(width: 4),
            ShimmerBone(width: 28, height: 12, radius: 4),
            Spacer(),
            ShimmerBone(width: 72, height: 22, radius: 20),
          ],
        ),
        SizedBox(height: 10),
        ShimmerBone(width: 210, height: 15, radius: 6),
        SizedBox(height: 8),
        Row(
          children: [
            ShimmerIcon(Icons.location_on_outlined, size: 16),
            SizedBox(width: 4),
            Expanded(child: ShimmerBone(height: 11, radius: 6)),
          ],
        ),
      ],
    );
  }
}

class _FavoriteCardMeta extends StatelessWidget {
  const _FavoriteCardMeta();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ShimmerBone(width: 64, height: 24, radius: 20),
        SizedBox(height: 10),
        ShimmerBone(width: 220, height: 16, radius: 6),
        SizedBox(height: 8),
        Row(
          children: [
            ShimmerIcon(Icons.location_on_outlined, size: 18),
            SizedBox(width: 4),
            Expanded(child: ShimmerBone(height: 12, radius: 6)),
            SizedBox(width: 8),
            ShimmerIcon(Icons.star, size: 16),
            SizedBox(width: 3),
            ShimmerBone(width: 28, height: 12, radius: 4),
            SizedBox(width: 8),
            ShimmerBone(width: 58, height: 12, radius: 4),
          ],
        ),
      ],
    );
  }
}

class ExploreCountShimmer extends StatelessWidget {
  const ExploreCountShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return const ThemeShimmer(
      child: ShimmerBone(width: 118, height: 14, radius: 6),
    );
  }
}
