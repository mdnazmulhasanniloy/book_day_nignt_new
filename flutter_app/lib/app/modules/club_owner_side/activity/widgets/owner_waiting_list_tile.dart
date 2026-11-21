import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/resources/common_widget/custom_network_image.dart';
import '../../../../core/resources/common_widget/custom_text.dart';
import '../model/owner_waiting_list_model.dart';

class OwnerWaitingListTile extends StatelessWidget {
  const OwnerWaitingListTile({
    super.key,
    required this.entry,
    this.notifying = false,
    this.removing = false,
    this.onNotify,
    this.onRemove,
  });

  final OwnerWaitingListEntry entry;
  final bool notifying;
  final bool removing;
  final VoidCallback? onNotify;
  final VoidCallback? onRemove;

  static const _gold = Color(0xFFDCA73A);
  static const _card = Color(0xFF161616);

  @override
  Widget build(BuildContext context) {
    final user = entry.user;
    final contact = user.contactLine;
    final position = entry.position;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _Avatar(user: user),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomText(
                      text: user.displayName,
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      maxLine: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (contact.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      CustomText(
                        text: contact,
                        color: Colors.white54,
                        fontSize: 12,
                        maxLine: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _Chip(
                label: position == null ? '#' : '#$position',
                color: _gold,
                background: const Color(0xFF261D0A),
              ),
              const SizedBox(width: 6),
              _Chip(
                label: entry.status.label,
                color: entry.isNotified ? Colors.white70 : _gold,
                background: entry.isNotified
                    ? Colors.white.withValues(alpha: 0.08)
                    : const Color(0xFF261D0A),
              ),
            ],
          ),
          if (entry.startAt != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF261D0A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _gold.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.event_seat_outlined, size: 14, color: _gold),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Target: ${DateFormat('EEE, MMM d · h:mm a').format(entry.startAt!.toLocal())}${entry.guestCount != null && entry.guestCount! > 0 ? ' (${entry.guestCount} guests)' : ''}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: entry.isNotified ? 'Notified' : 'Notify',
                  gold: true,
                  enabled: !entry.isNotified && !notifying && !removing,
                  loading: notifying,
                  onTap: onNotify,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  label: 'Remove',
                  gold: false,
                  enabled: !removing && !notifying,
                  loading: removing,
                  onTap: onRemove,
                ),
              ),
            ],
          ),
          if (entry.createdAt != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Joined: ${DateFormat('MMM d, h:mm a').format(entry.createdAt!.toLocal())} · Standby queue',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ),
          ],
          const SizedBox(height: 4),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Notifying alerts this guest to book online. Tables are booked on a first-come basis.',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.user});

  final OwnerWaitingListUser user;

  @override
  Widget build(BuildContext context) {
    final url = user.profileAvatar;
    if (url != null && url.isNotEmpty) {
      return CustomNetworkImage(
        imageUrl: url,
        height: 46,
        width: 46,
        boxShape: BoxShape.circle,
      );
    }
    return CircleAvatar(
      radius: 23,
      backgroundColor: const Color(0xFF261D0A),
      child: CustomText(
        text: user.initials,
        color: const Color(0xFFDCA73A),
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: CustomText(
        text: label,
        color: color,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.gold,
    required this.enabled,
    required this.loading,
    this.onTap,
  });

  final String label;
  final bool gold;
  final bool enabled;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const goldColor = Color(0xFFDCA73A);
    final border = gold && enabled
        ? goldColor
        : Colors.white.withValues(alpha: 0.18);
    final fill = gold && enabled
        ? goldColor
        : Colors.transparent;
    final textColor = gold && enabled ? Colors.black : Colors.white54;
    return InkWell(
      onTap: enabled && !loading ? onTap : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: loading
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: gold && enabled ? Colors.black : Colors.white70,
                ),
              )
            : CustomText(
                text: label,
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
      ),
    );
  }
}
