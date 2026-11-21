import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../rules/views/privacy_policy_view.dart';
import '../../../rules/views/terms_and_condition_view.dart';
import '../../booking/views/my_booking_view.dart';

import '../../../../core/auth/account_gate.dart';
import '../../../../core/explore/model/event_commerce_model.dart';
import '../../../../core/explore/model/event_offer_model.dart';
import '../../../../core/explore/model/explore_api_model.dart';
import '../../../../core/explore/repository/event_commerce_repository.dart';
import '../../../../core/local_storage/local_storage.dart';
import '../../../../core/network/api_expection.dart';
import '../../../../core/resources/app_const/app_const.dart';
import '../../../../core/resources/common_widget/custom_button.dart';
import '../../../../core/resources/common_widget/custom_network_image.dart';
import '../../../../core/resources/common_widget/custom_text.dart';
import '../../../../core/resources/common_widget/custom_text_field.dart';
import '../../../../core/utils/custom_snack_bar.dart';
import '../../../../core/utils/personal_details.dart';
import '../../../profile/controllers/profile_controller.dart';
import '../../explore/controllers/explore_controller.dart';
import '../controllers/buy_ticker_controller.dart';
import '../controllers/club_details_controller.dart';
import 'event_ticket_tier_sheet.dart';

const _gold = Color(0xFFDCA73A);
const _card = Color(0xFF1A1A1A);

class EventCommerceSection extends StatefulWidget {
  const EventCommerceSection({
    super.key,
    required this.controller,
    required this.detail,
  });

  final ClubDetailsController controller;
  final ExploreDetailModel detail;

  @override
  State<EventCommerceSection> createState() => _EventCommerceSectionState();
}

class _EventCommerceSectionState extends State<EventCommerceSection> {
  final _repo = EventCommerceRepository();

  ExploreDetailModel get detail => widget.detail;
  bool get _closed => detail.bookingsClosed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (detail.moodTags.isNotEmpty) ...[
          const SizedBox(height: 24),
          const _SectionTitle('Mood'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in detail.moodTags)
                GestureDetector(
                  onTap: () => _filterMood(tag),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF261D0A),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _gold.withValues(alpha: 0.35)),
                    ),
                    child: CustomText(
                      text: tag,
                      color: _gold,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ],
        if (detail.modules.isNotEmpty) ...[
          const SizedBox(height: 24),
          const _SectionTitle('VIP'),
          const SizedBox(height: 12),
          for (final module in detail.modules)
            _ModuleCard(
              module: module,
              bookingsClosed: _closed,
              onBook: () => _bookModule(module),
              onQuote: () => _openQuote(module),
            ),
        ],
        if (detail.guestList != null) ...[
          const SizedBox(height: 24),
          const _SectionTitle('Guest list'),
          const SizedBox(height: 12),
          _GuestListCard(
            guestList: detail.guestList!,
            bookingsClosed: _closed,
            onJoin: () => _openGuestListJoin(),
            onFallback: _onFallback,
          ),
        ],
        if (detail.hosts.isNotEmpty) ...[
          const SizedBox(height: 24),
          const _SectionTitle('VIP hosts'),
          const SizedBox(height: 12),
          for (final host in detail.hosts)
            _HostCard(host: host, onContact: () => _openHostContact(host)),
        ],
        if (detail.lineup.isNotEmpty) ...[
          const SizedBox(height: 24),
          const _SectionTitle('Lineup'),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                for (var index = 0; index < detail.lineup.length; index++) ...[
                  if (index > 0) const Divider(height: 20, color: Colors.white10),
                  _LineupFollowRow(
                    artist: detail.lineup[index],
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  void _filterMood(String tag) {
    if (!Get.isRegistered<ExploreController>()) return;
    final explore = Get.find<ExploreController>();
    explore.selectedCategory.value = 'Event';
    explore.selectedMood.value = tag;
    explore.moodController.text = tag;
    explore.fetchVenues(refresh: true);
    CustomSnackBar.success(message: 'Showing events for $tag');
  }

  Future<void> _bookModule(EventVipModuleModel module) async {
    if (_closed || !module.canBook) return;
    if (!await AccountGate.ensure() || !mounted) return;
    final guests = await _askGuestCount(max: module.maxGuests);
    if (guests == null || !mounted) return;
    final ticker = Get.isRegistered<BuyTickerController>()
        ? Get.find<BuyTickerController>()
        : Get.put(BuyTickerController());
    final paid = await ticker.payForModule(
      eventId: widget.controller.seedClub.id,
      moduleId: module.id,
      guestCount: guests,
    );
    if (paid && mounted) {
      _showModuleBookingSuccessDialog(module);
    }
  }



  void _showModuleBookingSuccessDialog(EventVipModuleModel module) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF161616),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _gold.withValues(alpha: 0.3)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 28),
                const Icon(Icons.check_circle, color: Color(0xFFE1B144), size: 72),
                const SizedBox(height: 20),
                const CustomText(
                  text: 'VIP Booking Confirmed!',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                const SizedBox(height: 12),
                CustomText(
                  text: 'You have successfully booked "${module.name}". Your reservation and entry QR code are ready in My Bookings.',
                  fontSize: 14,
                  color: Colors.white70,
                  textAlign: TextAlign.center,
                  height: 1.45,
                ),
                const SizedBox(height: 28),
                CustomButton(
                  title: 'View in My Bookings',
                  buttonColor: _gold,
                  titleColor: Colors.black,
                  isGradient: false,
                  borderRadius: 16,
                  onTap: () {
                    Get.back();
                    Get.to(() => const MyBookingsView());
                  },
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () => Get.back(),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: CustomText(
                      text: 'Close',
                      fontSize: 14,
                      color: Colors.white54,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<int?> _askGuestCount({required int max}) {
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161616),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _GuestCountSheet(max: max),
    );
  }

  Future<void> _openQuote(EventVipModuleModel module) async {
    if (_closed) return;
    if (!await AccountGate.ensure() || !mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161616),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ContactFormSheet(
        title: 'Request a quote',
        extraLabel: 'Guests',
        onSubmit: (name, email, phone, extra, message) async {
          await _repo.requestQuote(
            eventId: widget.controller.seedClub.id,
            moduleId: module.id,
            name: name,
            email: email,
            phone: phone,
            guestCount: int.tryParse(extra) ?? 1,
            message: message,
            date: widget.detail.startAt,
          );
        },
      ),
    );
  }

  Future<void> _openGuestListJoin() async {
    if (_closed) return;
    if (!await AccountGate.ensure() || !mounted) return;
    final config = detail.guestList;
    if (config == null || !config.isOpen) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161616),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _GuestListJoinSheet(
        arrivalTimes: config.arrivalTimes,
        idRequired: config.idRequired,
        onSubmit: (payload) async {
          await _repo.joinGuestList(
            eventId: widget.controller.seedClub.id,
            name: payload.$1,
            email: payload.$2,
            phone: payload.$3,
            menCount: payload.$4,
            womenCount: payload.$5,
            otherCount: payload.$6,
            arrivalTime: payload.$7,
            acceptedTerms: true,
          );
        },
      ),
    );
  }

  Future<void> _onFallback(EventGuestListFallback fallback) async {
    if (_closed) return;
    if (fallback.isTicket) {
      await openEventTicketFlow(
        context: context,
        controller: widget.controller,
        preferredTierId: fallback.id,
      );
      return;
    }
    if (fallback.isModule) {
      EventVipModuleModel? module;
      for (final item in detail.modules) {
        if (item.id == fallback.id) {
          module = item;
          break;
        }
      }
      if (module != null) await _bookModule(module);
    }
  }

  Future<void> _openHostContact(EventHostModel host) async {
    if (!await AccountGate.ensure() || !mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161616),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ContactFormSheet(
        title: 'Contact ${host.name}',
        onSubmit: (name, email, phone, extra, message) async {
          await _repo.contactHost(
            hostId: host.id,
            eventId: widget.controller.seedClub.id,
            name: name,
            email: email,
            phone: phone,
            message: message,
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return CustomText(
      text: text,
      color: Colors.white,
      fontSize: 16,
      fontWeight: FontWeight.w600,
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.module,
    required this.bookingsClosed,
    required this.onBook,
    required this.onQuote,
  });

  final EventVipModuleModel module;
  final bool bookingsClosed;
  final VoidCallback onBook;
  final VoidCallback onQuote;

  @override
  Widget build(BuildContext context) {
    final extras = [
      ...module.includedExtras,
      ...module.optionalExtras,
    ];
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (module.image != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CustomNetworkImage(
                  imageUrl: module.image!,
                  height: 140,
                  width: double.infinity,
                ),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomText(
                      text: module.name,
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                    if (module.venueArea.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      CustomText(
                        text: module.venueArea,
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ],
                  ],
                ),
              ),
              if (module.priceLabel.isNotEmpty) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF261D0A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _gold.withValues(alpha: 0.5),
                    ),
                  ),
                  child: CustomText(
                    text: module.priceLabel,
                    color: _gold,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
          if (module.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            CustomText(
              text: module.description,
              color: const Color(0xFFA0A0A0),
              fontSize: 13,
              maxLine: 4,
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (module.maxGuests > 0) _chip('${module.maxGuests} guests'),
              if (!module.isSoldOut && module.remaining > 0)
                _chip('${module.remaining} left'),
              if (module.minSpend.trim().isNotEmpty &&
                  module.minSpend != '0.00')
                _chip('Min €${module.minSpend}'),
              if (module.deposit.trim().isNotEmpty && module.deposit != '0.00')
                _chip('Deposit €${module.deposit}'),
              for (final extra in extras.take(4)) _chip(extra),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  title: module.canBook && !bookingsClosed
                      ? 'Book now'
                      : (module.isSoldOut ? 'Sold out' : 'Unavailable'),
                  isGradient: false,
                  buttonColor: module.canBook && !bookingsClosed
                      ? _gold
                      : const Color(0xFF2A2A2A),
                  titleColor: module.canBook && !bookingsClosed
                      ? Colors.black
                      : (module.isSoldOut ? const Color(0xFFFF6B6B) : Colors.white54),
                  paddingVertical: 12,
                  borderRadius: 14,
                  fontSize: 13,
                  onTap: module.canBook && !bookingsClosed ? onBook : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: CustomButton(
                  title: 'Request quote',
                  isGradient: false,
                  buttonColor: Colors.transparent,
                  border: Border.all(color: _gold),
                  titleColor: _gold,
                  paddingVertical: 12,
                  borderRadius: 14,
                  fontSize: 13,
                  onTap: bookingsClosed ? null : onQuote,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, {bool isSoldOut = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: isSoldOut
            ? const Color(0xFF381515)
            : Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
        border: isSoldOut
            ? Border.all(color: const Color(0xFFFF5252).withValues(alpha: 0.4))
            : null,
      ),
      child: CustomText(
        text: label,
        color: isSoldOut ? const Color(0xFFFF7B7B) : Colors.white70,
        fontSize: 11,
        fontWeight: isSoldOut ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }
}

class _GuestListCard extends StatelessWidget {
  const _GuestListCard({
    required this.guestList,
    required this.bookingsClosed,
    required this.onJoin,
    required this.onFallback,
  });

  final EventGuestListModel guestList;
  final bool bookingsClosed;
  final VoidCallback onJoin;
  final ValueChanged<EventGuestListFallback> onFallback;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomText(
            text: guestList.isOpen ? 'Open for this event' : 'Guest list closed',
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          if (guestList.dressCode.isNotEmpty) ...[
            const SizedBox(height: 6),
            CustomText(
              text: 'Dress code: ${guestList.dressCode}',
              color: Colors.white70,
              fontSize: 13,
            ),
          ],
          if (guestList.notes.isNotEmpty) ...[
            const SizedBox(height: 6),
            CustomText(
              text: guestList.notes,
              color: const Color(0xFFA0A0A0),
              fontSize: 13,
              maxLine: 4,
            ),
          ],
          const SizedBox(height: 10),
          Builder(
            builder: (context) {
              final hasExplicitLimits =
                  (guestList.remainingTotal != null && guestList.remainingTotal! > 0) ||
                  (guestList.remainingMale != null && guestList.remainingMale! > 0) ||
                  (guestList.remainingFemale != null && guestList.remainingFemale! > 0);
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (guestList.remainingTotal != null && guestList.remainingTotal! > 0)
                    _info('${guestList.remainingTotal} spots left'),
                  if (guestList.remainingMale != null && guestList.remainingMale! > 0)
                    _info('${guestList.remainingMale} men left'),
                  if (guestList.remainingFemale != null && guestList.remainingFemale! > 0)
                    _info('${guestList.remainingFemale} women left'),
                  if (!hasExplicitLimits) ...[
                    _info('Open Entry', isHighlight: true),
                    _info('Free RSVP', isHighlight: true),
                  ],
                  if (guestList.idRequired) _info('ID required'),
                ],
              );
            },
          ),
          if (guestList.isOpen && !bookingsClosed) ...[
            const SizedBox(height: 14),
            CustomButton(
              title: 'Join guest list',
              isGradient: false,
              buttonColor: _gold,
              titleColor: Colors.black,
              borderRadius: 14,
              paddingVertical: 12,
              onTap: onJoin,
            ),
          ],
          if (!guestList.isOpen && guestList.fallbacks.isNotEmpty) ...[
            const SizedBox(height: 14),
            const CustomText(
              text: 'Paid options',
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            const SizedBox(height: 8),
            for (final fallback in guestList.fallbacks)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: CustomButton(
                  title: fallback.label.isEmpty ? fallback.type : fallback.label,
                  isGradient: false,
                  buttonColor: Colors.transparent,
                  border: Border.all(color: _gold),
                  titleColor: _gold,
                  borderRadius: 14,
                  paddingVertical: 12,
                  onTap: bookingsClosed ? null : () => onFallback(fallback),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _info(String label, {bool isHighlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isHighlight
            ? _gold.withValues(alpha: 0.14)
            : Colors.white.withValues(alpha: 0.07),
        border: isHighlight
            ? Border.all(color: _gold.withValues(alpha: 0.45), width: 0.8)
            : null,
        borderRadius: BorderRadius.circular(20),
      ),
      child: CustomText(
        text: label,
        color: isHighlight ? _gold : Colors.white70,
        fontSize: 11,
        fontWeight: isHighlight ? FontWeight.w600 : FontWeight.w400,
      ),
    );
  }
}

class _HostCard extends StatelessWidget {
  const _HostCard({required this.host, required this.onContact});

  final EventHostModel host;
  final VoidCallback onContact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipOval(
                child: host.photo != null
                    ? CustomNetworkImage(
                        imageUrl: host.photo!,
                        height: 48,
                        width: 48,
                      )
                    : Container(
                        height: 48,
                        width: 48,
                        color: const Color(0xFF261D0A),
                        alignment: Alignment.center,
                        child: CustomText(
                          text: host.name.isEmpty
                              ? 'H'
                              : host.name[0].toUpperCase(),
                          color: _gold,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: CustomText(
                            text: host.name,
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            maxLine: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (host.isVerified) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.verified, color: _gold, size: 16),
                        ],
                      ],
                    ),
                    if (host.role.isNotEmpty)
                      CustomText(
                        text: host.role,
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (host.bio.isNotEmpty) ...[
            const SizedBox(height: 10),
            CustomText(
              text: host.bio,
              color: const Color(0xFFA0A0A0),
              fontSize: 13,
              maxLine: 4,
            ),
          ],
          if (host.officialPricesNote.isNotEmpty) ...[
            const SizedBox(height: 6),
            CustomText(
              text: host.officialPricesNote,
              color: _gold,
              fontSize: 12,
            ),
          ],
          const SizedBox(height: 12),
          CustomButton(
            title: 'Request info',
            isGradient: false,
            buttonColor: Colors.transparent,
            border: Border.all(color: _gold),
            titleColor: _gold,
            borderRadius: 14,
            paddingVertical: 12,
            onTap: onContact,
          ),
        ],
      ),
    );
  }
}

class _LineupFollowRow extends StatelessWidget {
  const _LineupFollowRow({
    required this.artist,
  });

  final EventLineupArtistModel artist;

  Future<void> _openSpotify(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) {
      CustomSnackBar.error(message: 'Invalid Spotify link');
      return;
    }
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('Cannot launch');
      }
    } catch (_) {
      CustomSnackBar.error(message: 'Could not open Spotify');
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatar = artist.artistAvatar.trim();
    final spotifyLink = artist.spotifyUrl.trim().isNotEmpty
        ? artist.spotifyUrl.trim()
        : artist.externalUrl.trim();

    return InkWell(
      onTap: spotifyLink.isNotEmpty ? () => _openSpotify(spotifyLink) : null,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            ClipOval(
              child: avatar.isNotEmpty
                  ? CustomNetworkImage(imageUrl: avatar, height: 44, width: 44)
                  : Container(
                      height: 44,
                      width: 44,
                      color: const Color(0xFF261D0A),
                      alignment: Alignment.center,
                      child: CustomText(
                        text: artist.artistName.isEmpty
                            ? 'DJ'
                            : artist.artistName[0].toUpperCase(),
                        color: _gold,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: CustomText(
                      text: artist.artistName,
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      maxLine: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (artist.isVerified) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.verified, color: _gold, size: 16),
                  ],
                ],
              ),
            ),
            if (spotifyLink.isNotEmpty) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _openSpotify(spotifyLink),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1DB954).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF1DB954).withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(
                        Icons.play_circle_fill_rounded,
                        color: Color(0xFF1DB954),
                        size: 15,
                      ),
                      SizedBox(width: 5),
                      CustomText(
                        text: 'Spotify',
                        color: Color(0xFF1DB954),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GuestCountSheet extends StatefulWidget {
  const _GuestCountSheet({required this.max});

  final int max;

  @override
  State<_GuestCountSheet> createState() => _GuestCountSheetState();
}

class _GuestCountSheetState extends State<_GuestCountSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: '1',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final parsed = int.tryParse(_controller.text.trim()) ?? 0;
    if (parsed < 1) {
      CustomSnackBar.error(message: 'Enter at least 1 guest');
      return;
    }
    if (widget.max > 0 && parsed > widget.max) {
      CustomSnackBar.error(
        message: 'This module allows up to ${widget.max} guests',
      );
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!mounted) return;
    Navigator.of(context).pop(parsed);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CustomText(
            text: 'Guests',
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
          const SizedBox(height: 12),
          CustomTextField(
            hint: widget.max > 0 ? '1–${widget.max}' : 'Guest count',
            controller: _controller,
            keyboardType: TextInputType.number,
            fillColor: const Color(0xFF1E1E1E),
            filled: true,
          ),
          const SizedBox(height: 16),
          CustomButton(
            title: 'Continue',
            isGradient: false,
            buttonColor: _gold,
            titleColor: Colors.black,
            borderRadius: 16,
            onTap: _continue,
          ),
        ],
      ),
    );
  }
}

class _ContactFormSheet extends StatefulWidget {
  const _ContactFormSheet({
    required this.title,
    required this.onSubmit,
    this.extraLabel,
  });

  final String title;
  final String? extraLabel;
  final Future<void> Function(
    String name,
    String email,
    String phone,
    String extra,
    String message,
  )
  onSubmit;

  @override
  State<_ContactFormSheet> createState() => _ContactFormSheetState();
}

class _ContactFormSheetState extends State<_ContactFormSheet> {
  final name = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final extra = TextEditingController();
  final message = TextEditingController();
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _fillFromProfile();
  }

  void _fillFromProfile() {
    try {
      final profile = Get.isRegistered<ProfileController>()
          ? Get.find<ProfileController>()
          : Get.put(ProfileController());

      void apply() {
        if (!mounted) return;
        final pName = profile.userName.value.trim().isNotEmpty
            ? profile.userName.value.trim()
            : (profile.userModel.value?.name?.trim() ?? '');
        final pEmail = profile.userEmail.value.trim().isNotEmpty
            ? profile.userEmail.value.trim()
            : (profile.userModel.value?.email?.trim() ??
                LocalStorage.getData(key: AppConst.savedEmail)
                    ?.toString()
                    .trim() ??
                '');
        final pPhone = profile.userPhone.value.trim().isNotEmpty
            ? profile.userPhone.value.trim()
            : (profile.userModel.value?.phoneNumber?.trim() ?? '');

        if (name.text.isEmpty && pName.isNotEmpty) {
          name.text = pName;
        }
        if (email.text.isEmpty && pEmail.isNotEmpty) {
          email.text = pEmail;
        }
        if (phone.text.isEmpty && pPhone.isNotEmpty) {
          phone.text = pPhone;
        }
      }

      apply();

      if (profile.userName.value.isEmpty && profile.userEmail.value.isEmpty) {
        profile.fetchUserProfile().then((_) => apply()).catchError((_) {});
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    phone.dispose();
    extra.dispose();
    message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomText(
              text: widget.title,
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              hint: 'Name',
              controller: name,
              fillColor: const Color(0xFF1E1E1E),
              filled: true,
            ),
            const SizedBox(height: 10),
            CustomTextField(
              hint: 'Email',
              controller: email,
              keyboardType: TextInputType.emailAddress,
              fillColor: const Color(0xFF1E1E1E),
              filled: true,
            ),
            const SizedBox(height: 10),
            CustomTextField(
              hint: 'Phone',
              controller: phone,
              keyboardType: TextInputType.phone,
              fillColor: const Color(0xFF1E1E1E),
              filled: true,
            ),
            if (widget.extraLabel != null) ...[
              const SizedBox(height: 10),
              CustomTextField(
                hint: widget.extraLabel!,
                controller: extra,
                keyboardType: TextInputType.number,
                fillColor: const Color(0xFF1E1E1E),
                filled: true,
              ),
            ],
            const SizedBox(height: 10),
            CustomTextField(
              hint: 'Message',
              controller: message,
              maxLines: 3,
              fillColor: const Color(0xFF1E1E1E),
              filled: true,
            ),
            const SizedBox(height: 16),
            CustomButton(
              title: 'Send',
              isLoading: busy,
              isGradient: false,
              buttonColor: _gold,
              titleColor: Colors.black,
              borderRadius: 16,
              onTap: busy ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (name.text.trim().isEmpty ||
        email.text.trim().isEmpty ||
        phone.text.trim().isEmpty ||
        message.text.trim().isEmpty) {
      CustomSnackBar.error(
        message: 'Please fill name, email, phone and message',
      );
      return;
    }
    setState(() => busy = true);
    try {
      await widget.onSubmit(
        name.text.trim(),
        email.text.trim(),
        phone.text.trim(),
        extra.text.trim(),
        message.text.trim(),
      );
      FocusManager.instance.primaryFocus?.unfocus();
      if (mounted) Navigator.of(context).pop();
      CustomSnackBar.success(
        message: 'Inquiry sent! Host will contact you shortly.',
      );
    } catch (error) {
      CustomSnackBar.error(
        message: clientErrorMessage(error, 'Could not send'),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

class _GuestListJoinSheet extends StatefulWidget {
  const _GuestListJoinSheet({
    required this.arrivalTimes,
    required this.idRequired,
    required this.onSubmit,
  });

  final List<String> arrivalTimes;
  final bool idRequired;
  final Future<void> Function(
    (String, String, String, int, int, int, String?) payload,
  )
  onSubmit;

  @override
  State<_GuestListJoinSheet> createState() => _GuestListJoinSheetState();
}

class _GuestListJoinSheetState extends State<_GuestListJoinSheet> {
  final name = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final men = TextEditingController(text: '1');
  final women = TextEditingController(text: '0');
  final others = TextEditingController(text: '0');
  String? arrival;
  bool terms = false;
  bool busy = false;
  late final List<String> _effectiveTimes;

  @override
  void initState() {
    super.initState();
    _effectiveTimes = widget.arrivalTimes.isNotEmpty
        ? widget.arrivalTimes
        : const [
            'Before 11:00 PM',
            'Before 11:30 PM',
            'Before Midnight',
            'Before 1:00 AM',
            'Anytime',
          ];
    arrival = _effectiveTimes.first;
    _fillFromProfile();
  }

  void _fillFromProfile() {
    try {
      final profile = Get.isRegistered<ProfileController>()
          ? Get.find<ProfileController>()
          : Get.put(ProfileController());

      void apply() {
        if (!mounted) return;
        final pName = profile.userName.value.trim().isNotEmpty
            ? profile.userName.value.trim()
            : (profile.userModel.value?.name?.trim() ?? '');
        final pEmail = profile.userEmail.value.trim().isNotEmpty
            ? profile.userEmail.value.trim()
            : (profile.userModel.value?.email?.trim() ??
                LocalStorage.getData(key: AppConst.savedEmail)
                    ?.toString()
                    .trim() ??
                '');
        final pPhone = profile.userPhone.value.trim().isNotEmpty
            ? profile.userPhone.value.trim()
            : (profile.userModel.value?.phoneNumber?.trim() ?? '');

        if (name.text.isEmpty && pName.isNotEmpty) {
          name.text = pName;
        }
        if (email.text.isEmpty && pEmail.isNotEmpty) {
          email.text = pEmail;
        }
        if (phone.text.isEmpty && pPhone.isNotEmpty) {
          phone.text = pPhone;
        }

        if (profile.userGender.value != null &&
            men.text == '1' &&
            women.text == '0' &&
            others.text == '0') {
          if (profile.userGender.value == Gender.female) {
            men.text = '0';
            women.text = '1';
          } else if (profile.userGender.value == Gender.other) {
            men.text = '0';
            others.text = '1';
          }
        }
      }

      apply();

      if (profile.userName.value.isEmpty && profile.userEmail.value.isEmpty) {
        profile.fetchUserProfile().then((_) => apply()).catchError((_) {});
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    phone.dispose();
    men.dispose();
    women.dispose();
    others.dispose();
    super.dispose();
  }

  Widget _fieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: CustomText(
        text: label,
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Center(
              child: CustomText(
                text: 'Join guest list',
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 18),
            _fieldLabel('Full Name'),
            CustomTextField(
              hint: 'Enter your full name',
              controller: name,
              fillColor: const Color(0xFF1E1E1E),
              filled: true,
            ),
            const SizedBox(height: 14),
            _fieldLabel('Email Address'),
            CustomTextField(
              hint: 'Enter your email address',
              controller: email,
              keyboardType: TextInputType.emailAddress,
              fillColor: const Color(0xFF1E1E1E),
              filled: true,
            ),
            const SizedBox(height: 14),
            _fieldLabel('Phone Number'),
            CustomTextField(
              hint: 'Enter your phone number',
              controller: phone,
              keyboardType: TextInputType.phone,
              fillColor: const Color(0xFF1E1E1E),
              filled: true,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _fieldLabel('Men'),
                      CustomTextField(
                        hint: '0',
                        controller: men,
                        keyboardType: TextInputType.number,
                        fillColor: const Color(0xFF1E1E1E),
                        filled: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _fieldLabel('Women'),
                      CustomTextField(
                        hint: '0',
                        controller: women,
                        keyboardType: TextInputType.number,
                        fillColor: const Color(0xFF1E1E1E),
                        filled: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _fieldLabel('Others'),
                      CustomTextField(
                        hint: '0',
                        controller: others,
                        keyboardType: TextInputType.number,
                        fillColor: const Color(0xFF1E1E1E),
                        filled: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _fieldLabel('Preferred Arrival Time'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final time in _effectiveTimes)
                  ChoiceChip(
                    label: Text(time),
                    selected: arrival == time,
                    selectedColor: _gold,
                    labelStyle: TextStyle(
                      color: arrival == time ? Colors.black : Colors.white,
                      fontWeight: arrival == time
                          ? FontWeight.w700
                          : FontWeight.normal,
                    ),
                    backgroundColor: const Color(0xFF1E1E1E),
                    onSelected: (_) => setState(() => arrival = time),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => setState(() => terms = !terms),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: Checkbox(
                      value: terms,
                      onChanged: (value) =>
                          setState(() => terms = value == true),
                      activeColor: _gold,
                      checkColor: Colors.black,
                      side: const BorderSide(color: Colors.white38, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: 'I agree to the ',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          height: 1.35,
                        ),
                        children: [
                          TextSpan(
                            text: 'Privacy Policy',
                            style: const TextStyle(
                              color: _gold,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap =
                                  () => Get.to(() => const PrivacyPolicyView()),
                          ),
                          const TextSpan(text: ' and '),
                          TextSpan(
                            text: 'Terms and Conditions',
                            style: const TextStyle(
                              color: _gold,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () =>
                                  Get.to(() => const TermsAndConditionView()),
                          ),
                          if (widget.idRequired)
                            const TextSpan(
                              text: ' (and will bring a valid ID)',
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            CustomButton(
              title: 'Submit',
              isLoading: busy,
              isGradient: false,
              buttonColor: _gold,
              titleColor: Colors.black,
              borderRadius: 16,
              onTap: busy ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!terms) {
      CustomSnackBar.error(
        message: 'Please agree to the Privacy Policy and Terms and Conditions',
      );
      return;
    }
    if (name.text.trim().isEmpty ||
        email.text.trim().isEmpty ||
        phone.text.trim().isEmpty) {
      CustomSnackBar.error(message: 'Please fill name, email and phone');
      return;
    }
    final menCount = int.tryParse(men.text.trim()) ?? 0;
    final womenCount = int.tryParse(women.text.trim()) ?? 0;
    final othersCount = int.tryParse(others.text.trim()) ?? 0;
    if (menCount + womenCount + othersCount <= 0) {
      CustomSnackBar.error(message: 'Please specify at least 1 guest');
      return;
    }
    setState(() => busy = true);
    try {
      await widget.onSubmit((
        name.text.trim(),
        email.text.trim(),
        phone.text.trim(),
        menCount,
        womenCount,
        othersCount,
        arrival,
      ));
      if (mounted) Navigator.of(context).pop();
      CustomSnackBar.success(message: 'You’re on the guest list');
    } catch (error) {
      CustomSnackBar.error(
        message: clientErrorMessage(error, 'Could not join guest list'),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}
