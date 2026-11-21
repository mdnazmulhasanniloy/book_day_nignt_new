import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ThemeShimmer extends StatelessWidget {
  const ThemeShimmer({super.key, required this.child});

  final Widget child;

  static const Color bone = Color(0xFF3E3E3E);
  static const Color card = Color(0xFF141414);
  static const Color photo = Color(0xFF1F1F1F);
  static const Color gold = Color(0xFFE1B144);

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: bone,
      highlightColor: const Color(0xFFC9A44A),
      period: const Duration(milliseconds: 1400),
      child: child,
    );
  }
}

class ShimmerBone extends StatelessWidget {
  const ShimmerBone({
    super.key,
    this.width,
    this.height,
    this.radius = 8,
  });

  final double? width;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: ThemeShimmer.bone,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class ShimmerIcon extends StatelessWidget {
  const ShimmerIcon(this.icon, {super.key, this.size = 16});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Icon(icon, size: size, color: ThemeShimmer.bone);
  }
}
