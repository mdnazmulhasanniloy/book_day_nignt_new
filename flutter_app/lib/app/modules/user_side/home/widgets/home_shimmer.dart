import 'package:flutter/material.dart';

import '../../../../core/resources/common_widget/theme_shimmer.dart';
import 'home_reuseble.dart';

class HomeShimmer extends ThemeShimmer {
  const HomeShimmer({super.key, required super.child});

  static const Color bone = ThemeShimmer.bone;
  static const Color card = ThemeShimmer.card;
  static const Color photo = ThemeShimmer.photo;
  static const Color gold = ThemeShimmer.gold;
}

typedef _Bone = ShimmerBone;
typedef _IconBone = ShimmerIcon;

class HomeCarouselShimmer extends StatelessWidget {
  const HomeCarouselShimmer({
    super.key,
    this.count = 2,
    this.tonight = true,
  });

  final int count;
  final bool tonight;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: CommonComponents.homeCardHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: count,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, _) => HomeEventCardShimmer(tonight: tonight),
      ),
    );
  }
}

class HomeEventCardShimmer extends StatelessWidget {
  const HomeEventCardShimmer({super.key, this.tonight = true});

  final bool tonight;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: CommonComponents.homeCardWidth,
      height: CommonComponents.homeCardHeight,
      decoration: BoxDecoration(
        color: HomeShimmer.card,
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
            height: 108,
            child: ColoredBox(color: HomeShimmer.photo),
          ),
          if (tonight)
            const Positioned(
              top: 10,
              right: 10,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xE60E0E0E),
                  shape: BoxShape.circle,
                ),
                child: SizedBox.square(dimension: 34),
              ),
            ),
          HomeShimmer(
            child: Stack(
              children: [
                if (tonight)
                  const Positioned(
                    top: 17,
                    right: 17,
                    child: _IconBone(Icons.favorite_border, size: 20),
                  )
                else
                  const Positioned(
                    top: 10,
                    right: 10,
                    child: _Bone(width: 58, height: 22, radius: 8),
                  ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: tonight ? const _TonightMeta() : const _TrendingMeta(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TonightMeta extends StatelessWidget {
  const _TonightMeta();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _Bone(width: 48, height: 20, radius: 20),
            SizedBox(width: 6),
            _IconBone(Icons.star_rounded, size: 13),
            SizedBox(width: 3),
            _Bone(width: 22, height: 10, radius: 4),
            Spacer(),
            _Bone(width: 62, height: 20, radius: 20),
          ],
        ),
        SizedBox(height: 10),
        _Bone(width: 168, height: 13, radius: 6),
        SizedBox(height: 8),
        Row(
          children: [
            _IconBone(Icons.location_on_outlined, size: 14),
            SizedBox(width: 4),
            Expanded(child: _Bone(height: 10, radius: 6)),
          ],
        ),
      ],
    );
  }
}

class _TrendingMeta extends StatelessWidget {
  const _TrendingMeta();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _Bone(width: 176, height: 13, radius: 6),
        SizedBox(height: 8),
        Row(
          children: [
            _IconBone(Icons.calendar_today_outlined, size: 12),
            SizedBox(width: 6),
            _Bone(width: 128, height: 10, radius: 6),
          ],
        ),
        SizedBox(height: 7),
        Row(
          children: [
            _IconBone(Icons.location_on_outlined, size: 14),
            SizedBox(width: 4),
            Expanded(child: _Bone(height: 10, radius: 6)),
          ],
        ),
      ],
    );
  }
}

class HomePopularListShimmer extends StatelessWidget {
  const HomePopularListShimmer({super.key, this.count = 3});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < count; i++) ...[
          const HomePopularTileShimmer(),
          if (i < count - 1) const SizedBox(height: 15),
        ],
      ],
    );
  }
}

class HomePopularTileShimmer extends StatelessWidget {
  const HomePopularTileShimmer({super.key});

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
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: HomeShimmer.photo,
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: const Stack(
              children: [
                HomeShimmer(
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: EdgeInsets.all(6),
                      child: _Bone(width: 32, height: 16, radius: 7),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: HomeShimmer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: _Bone(height: 13, radius: 6)),
                      SizedBox(width: 10),
                      _Bone(width: 68, height: 24, radius: 16),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      _IconBone(Icons.location_on_outlined, size: 12),
                      SizedBox(width: 4),
                      Expanded(child: _Bone(height: 10, radius: 6)),
                    ],
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      _Bone(width: 46, height: 16, radius: 20),
                      SizedBox(width: 6),
                      _Bone(width: 54, height: 16, radius: 20),
                      Spacer(),
                      _Bone(width: 64, height: 12, radius: 6),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HomeVipListShimmer extends StatelessWidget {
  const HomeVipListShimmer({super.key, this.count = 2});

  final int count;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: count,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, _) => HomeVipCardShimmer(
          width: MediaQuery.sizeOf(context).width - 56,
        ),
      ),
    );
  }
}

class HomeVipCardShimmer extends StatelessWidget {
  const HomeVipCardShimmer({super.key, required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 180,
      decoration: BoxDecoration(
        color: HomeShimmer.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 108,
            child: ColoredBox(color: HomeShimmer.photo),
          ),
          HomeShimmer(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                children: [
                  const Spacer(),
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Bone(width: 150, height: 13, radius: 6),
                            SizedBox(height: 8),
                            _Bone(width: 88, height: 10, radius: 6),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      const _Bone(width: 118, height: 36, radius: 22),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
