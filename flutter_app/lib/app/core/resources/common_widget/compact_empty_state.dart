import 'package:flutter/material.dart';
import 'custom_text.dart';

class CompactEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final bool stacked;
  final Widget? action;

  /// Compact row for lists and sections.
  const CompactEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  }) : stacked = false;

  /// Centered empty for a full tab or screen.
  const CompactEmptyState.stacked({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  }) : stacked = true;

  static const _muted = Color(0xFF8A8A8A);

  @override
  Widget build(BuildContext context) {
    return stacked ? _buildStacked() : _buildInline();
  }

  Widget _buildStacked() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white24, size: 28),
          const SizedBox(height: 12),
          CustomText(
            text: title,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white70,
            textAlign: TextAlign.center,
          ),
          if (message != null) ...[
            const SizedBox(height: 6),
            CustomText(
              text: message!,
              fontSize: 12,
              color: _muted,
              textAlign: TextAlign.center,
              height: 1.4,
              maxLine: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: 16),
            action!,
          ],
        ],
      ),
    );
  }

  Widget _buildInline() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(icon, color: Colors.white24, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomText(
                      text: title,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white54,
                    ),
                    if (message != null) ...[
                      const SizedBox(height: 2),
                      CustomText(
                        text: message!,
                        fontSize: 12,
                        color: _muted,
                        height: 1.35,
                        maxLine: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (action != null) ...[
            const SizedBox(height: 12),
            action!,
          ],
        ],
      ),
    );
  }
}
