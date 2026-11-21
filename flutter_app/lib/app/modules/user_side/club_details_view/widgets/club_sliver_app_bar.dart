import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/resources/common_widget/custom_network_image.dart';

class ClubSliverAppBar extends StatelessWidget {
  final String imageUrl;
  final Color bgColor;
  final ValueChanged<Rect?>? onShare;
  final VoidCallback? onRefresh;

  const ClubSliverAppBar({
    super.key,
    required this.imageUrl,
    required this.bgColor,
    this.onShare,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 320,
      pinned: true,
      backgroundColor: bgColor,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: InkWell(
          onTap: () => Get.back(),
          borderRadius: BorderRadius.circular(30),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
          ),
        ),
      ),
      actions: [
        if (onRefresh != null)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: InkWell(
              onTap: onRefresh,
              borderRadius: BorderRadius.circular(30),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
              ),
            ),
          ),
        if (onShare != null)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Builder(
              builder: (buttonContext) => InkWell(
                onTap: () {
                  final box = buttonContext.findRenderObject() as RenderBox?;
                  onShare!(
                    box == null
                        ? null
                        : box.localToGlobal(Offset.zero) & box.size,
                  );
                },
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.share, color: Colors.white, size: 18),
                ),
              ),
            ),
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            CustomNetworkImage(
              imageUrl: imageUrl,
              height: double.infinity,
              width: double.infinity,
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    bgColor.withValues(alpha: 0.8),
                    bgColor,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}