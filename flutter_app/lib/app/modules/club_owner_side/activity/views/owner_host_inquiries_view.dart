import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/explore/model/event_commerce_model.dart';
import '../../../../core/explore/repository/event_commerce_repository.dart';
import '../../../../core/network/api_expection.dart';
import '../../../../core/resources/common_widget/compact_empty_state.dart';
import '../../../../core/resources/common_widget/custom_button.dart';
import '../../../../core/resources/common_widget/custom_text.dart';
import '../repository/event_repository.dart';

const _gold = Color(0xFFDCA73A);
const _card = Color(0xFF161616);

class OwnerHostInquiriesView extends StatefulWidget {
  const OwnerHostInquiriesView({
    super.key,
    required this.eventId,
    this.eventTitle,
  });

  final String eventId;
  final String? eventTitle;

  @override
  State<OwnerHostInquiriesView> createState() => _OwnerHostInquiriesViewState();
}

class _OwnerHostInquiriesViewState extends State<OwnerHostInquiriesView> {
  final _repo = EventCommerceRepository();
  var _items = <EventHostInquiryModel>[];
  bool _loading = true;
  String? _error;
  String? _resolvedEventTitle;

  @override
  void initState() {
    super.initState();
    _resolvedEventTitle = widget.eventTitle;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final items = await _repo.eventHostInquiries(widget.eventId);

      if ((_resolvedEventTitle == null || _resolvedEventTitle!.isEmpty) &&
          widget.eventId.isNotEmpty) {
        try {
          final eventRepo = EventRepository();
          final ownEvents = await eventRepo.getOwnEvents(page: 1, limit: 50);
          final matched = ownEvents.data
              .firstWhereOrNull((e) => e.id == widget.eventId);
          if (matched != null && matched.eventName.isNotEmpty) {
            _resolvedEventTitle = matched.eventName;
          }
        } catch (_) {}
      }

      if (mounted) setState(() => _items = items);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error =
              clientErrorMessage(error, 'Could not load host inquiries'),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _resolvedEventTitle?.trim().isNotEmpty == true
        ? _resolvedEventTitle!
        : 'Host Inquiries';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CustomText(
              text: 'VIP Host Inquiries',
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
            if (title != 'Host Inquiries') ...[
              const SizedBox(height: 2),
              CustomText(
                text: title,
                color: Colors.white54,
                fontSize: 12,
                maxLine: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _gold))
          : _error != null
              ? CompactEmptyState.stacked(
                  icon: Icons.error_outline,
                  title: 'Could not load inquiries',
                  message: _error,
                  action: CustomButton(
                    title: 'Retry',
                    buttonColor: _gold,
                    titleColor: Colors.black,
                    isGradient: false,
                    borderRadius: 12,
                    paddingVertical: 10,
                    width: 110,
                    fontSize: 13,
                    onTap: _load,
                  ),
                )
              : _items.isEmpty
                  ? RefreshIndicator(
                      color: _gold,
                      backgroundColor: _card,
                      onRefresh: _load,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: MediaQuery.sizeOf(context).height * 0.7,
                            child: const CompactEmptyState.stacked(
                              icon: Icons.mark_chat_unread_outlined,
                              title: 'No host inquiries yet',
                              message:
                                  'Guest inquiries sent to assigned VIP hosts for this event will appear here.',
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      color: _gold,
                      backgroundColor: _card,
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                        itemCount: _items.length,
                        itemBuilder: (_, index) =>
                            _buildInquiryCard(_items[index]),
                      ),
                    ),
    );
  }

  Widget _buildInquiryCard(EventHostInquiryModel item) {
    final cleanPhone = item.customerPhone.replaceAll(RegExp(r'[^0-9]'), '');
    final hasPhone = item.customerPhone.trim().isNotEmpty;
    final hasEmail = item.customerEmail.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Avatar, Name, Created time, Host Pill
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF261D0A),
                  shape: BoxShape.circle,
                  border: Border.all(color: _gold.withValues(alpha: 0.5)),
                ),
                alignment: Alignment.center,
                child: CustomText(
                  text: item.customerName.trim().isNotEmpty
                      ? item.customerName.trim()[0].toUpperCase()
                      : 'G',
                  color: _gold,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomText(
                      text: item.customerName.trim().isNotEmpty
                          ? item.customerName.trim()
                          : 'Guest',
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      maxLine: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.createdAt != null) ...[
                      const SizedBox(height: 3),
                      CustomText(
                        text: DateFormat('MMM d, yyyy · h:mm a')
                            .format(item.createdAt!.toLocal()),
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ],
                  ],
                ),
              ),
              if (item.hostName.trim().isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _gold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _gold.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.badge_outlined,
                        color: _gold,
                        size: 13,
                      ),
                      const SizedBox(width: 5),
                      CustomText(
                        text: item.hostName.trim(),
                        color: _gold,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        maxLine: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 14),
          const Divider(height: 1, color: Colors.white10),
          const SizedBox(height: 14),

          // Message section
          if (item.message.trim().isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.format_quote_rounded,
                        color: _gold,
                        size: 16,
                      ),
                      SizedBox(width: 6),
                      CustomText(
                        text: 'Message from Guest',
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  CustomText(
                    text: item.message.trim(),
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Contact details chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (hasPhone) ...[
                _infoChip(
                  icon: Icons.phone_outlined,
                  label: item.customerPhone.trim(),
                  onTap: () => _launchUri('tel:${item.customerPhone.trim()}'),
                ),
                if (cleanPhone.isNotEmpty)
                  _infoChip(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: 'WhatsApp',
                    accent: true,
                    onTap: () => _launchUri('https://wa.me/$cleanPhone'),
                  ),
              ],
              if (hasEmail)
                _infoChip(
                  icon: Icons.mail_outline_rounded,
                  label: item.customerEmail.trim(),
                  onTap: () => _launchUri('mailto:${item.customerEmail.trim()}'),
                ),
            ],
          ),

          // Direct call / WhatsApp action bar
          if (hasPhone || hasEmail) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                if (hasPhone && cleanPhone.isNotEmpty)
                  Expanded(
                    child: CustomButton(
                      title: 'WhatsApp',
                      isGradient: false,
                      buttonColor: const Color(0xFF1B5E20),
                      border: Border.all(color: const Color(0xFF4CAF50)),
                      titleColor: Colors.white,
                      paddingVertical: 10,
                      borderRadius: 12,
                      fontSize: 12,
                      onTap: () => _launchUri('https://wa.me/$cleanPhone'),
                    ),
                  ),
                if (hasPhone && cleanPhone.isNotEmpty && hasPhone)
                  const SizedBox(width: 8),
                if (hasPhone)
                  Expanded(
                    child: CustomButton(
                      title: 'Call',
                      isGradient: false,
                      buttonColor: Colors.transparent,
                      border: Border.all(color: _gold),
                      titleColor: _gold,
                      paddingVertical: 10,
                      borderRadius: 12,
                      fontSize: 12,
                      onTap: () =>
                          _launchUri('tel:${item.customerPhone.trim()}'),
                    ),
                  ),
                if (!hasPhone && hasEmail)
                  Expanded(
                    child: CustomButton(
                      title: 'Send Email',
                      isGradient: false,
                      buttonColor: Colors.transparent,
                      border: Border.all(color: _gold),
                      titleColor: _gold,
                      paddingVertical: 10,
                      borderRadius: 12,
                      fontSize: 12,
                      onTap: () =>
                          _launchUri('mailto:${item.customerEmail.trim()}'),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoChip({
    required IconData icon,
    required String label,
    bool accent = false,
    VoidCallback? onTap,
  }) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color:
            accent ? _gold.withValues(alpha: 0.12) : const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: accent ? _gold.withValues(alpha: 0.35) : Colors.white10,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: accent ? _gold : Colors.white60),
          const SizedBox(width: 6),
          Flexible(
            child: CustomText(
              text: label,
              fontSize: 12,
              color: accent ? _gold : Colors.white70,
              maxLine: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 6),
            const Icon(Icons.open_in_new_rounded,
                size: 12, color: Colors.white38),
          ],
        ],
      ),
    );

    if (onTap == null) return chip;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: chip,
    );
  }

  Future<void> _launchUri(String uriString) async {
    try {
      final uri = Uri.parse(uriString);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (_) {}
  }
}
