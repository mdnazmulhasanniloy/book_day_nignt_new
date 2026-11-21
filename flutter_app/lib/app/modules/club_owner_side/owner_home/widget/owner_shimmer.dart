import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class OwnerShimmer extends StatelessWidget {
  const OwnerShimmer({super.key, required this.child});

  final Widget child;

  static const card = Color(0xFF161616);
  static const bone = Color(0xFF2C2C2C);

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF2A2A2A),
      highlightColor: const Color(0xFF8C7340),
      period: const Duration(milliseconds: 1300),
      child: child,
    );
  }
}

class OwnerOverviewGridShimmer extends StatelessWidget {
  const OwnerOverviewGridShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Row(
          children: [
            Expanded(child: _OverviewCardShimmer()),
            SizedBox(width: 16),
            Expanded(child: _OverviewCardShimmer()),
          ],
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _OverviewCardShimmer()),
            SizedBox(width: 16),
            Expanded(child: _OverviewCardShimmer()),
          ],
        ),
      ],
    );
  }
}

class OwnerBookingListShimmer extends StatelessWidget {
  const OwnerBookingListShimmer({super.key, this.count = 2});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < count; i++) const _BookingCardShimmer(),
      ],
    );
  }
}

class OwnerPaymentListShimmer extends StatelessWidget {
  const OwnerPaymentListShimmer({super.key, this.count = 4});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < count; i++) const _PaymentCardShimmer(),
      ],
    );
  }
}

class OwnerChartShimmer extends StatelessWidget {
  const OwnerChartShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    const heights = <double>[
      28,
      36,
      24,
      42,
      32,
      48,
      70,
      40,
      88,
      34,
      26,
      44,
    ];
    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OwnerShimmer.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: OwnerShimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Bone(width: 148, height: 14, radius: 6),
            const SizedBox(height: 8),
            const _Bone(width: 200, height: 10, radius: 5),
            const Spacer(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final height in heights)
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: _Bone(width: 10, height: height, radius: 4),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewCardShimmer extends StatelessWidget {
  const _OverviewCardShimmer();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 124,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: OwnerShimmer.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const OwnerShimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Bone(width: 34, height: 34, radius: 8),
            SizedBox(height: 12),
            _Bone(width: 78, height: 18, radius: 6),
            SizedBox(height: 8),
            _Bone(width: 96, height: 10, radius: 5),
          ],
        ),
      ),
    );
  }
}

class _BookingCardShimmer extends StatelessWidget {
  const _BookingCardShimmer();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: OwnerShimmer.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const OwnerShimmer(
        child: Row(
          children: [
            _Bone(width: 70, height: 70, radius: 12),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Bone(width: 132, height: 14, radius: 6),
                  SizedBox(height: 10),
                  _Bone(width: 108, height: 10, radius: 5),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      _Bone(width: 46, height: 18, radius: 10),
                      SizedBox(width: 8),
                      _Bone(width: 34, height: 18, radius: 10),
                      SizedBox(width: 8),
                      _Bone(width: 28, height: 18, radius: 10),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentCardShimmer extends StatelessWidget {
  const _PaymentCardShimmer();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OwnerShimmer.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const OwnerShimmer(
        child: Row(
          children: [
            _Bone(width: 48, height: 48, radius: 12),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Bone(width: 120, height: 13, radius: 6),
                  SizedBox(height: 8),
                  _Bone(width: 168, height: 10, radius: 5),
                ],
              ),
            ),
            SizedBox(width: 8),
            _Bone(width: 64, height: 28, radius: 14),
          ],
        ),
      ),
    );
  }
}

class _Bone extends StatelessWidget {
  const _Bone({
    required this.width,
    required this.height,
    required this.radius,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: OwnerShimmer.bone,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
