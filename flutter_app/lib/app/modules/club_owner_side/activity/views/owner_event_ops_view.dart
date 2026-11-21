import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/explore/model/event_commerce_model.dart';
import '../../../../core/explore/repository/event_commerce_repository.dart';
import '../../../../core/network/api_expection.dart';
import '../../../../core/resources/common_widget/compact_empty_state.dart';
import '../../../../core/resources/common_widget/custom_button.dart';
import '../../../../core/resources/common_widget/custom_text.dart';
import '../../../../core/resources/common_widget/custom_text_field.dart';
import '../../../../core/resources/common_widget/status_badge.dart';
import '../../../../core/utils/custom_snack_bar.dart';
import '../controllers/owner_activity_controller.dart';
import '../repository/event_repository.dart';

export 'owner_host_inquiries_view.dart';

const _gold = Color(0xFFDCA73A);
const _card = Color(0xFF161616);

class OwnerEventOpsTiles extends StatefulWidget {
  const OwnerEventOpsTiles({
    super.key,
    required this.eventId,
    this.eventName = '',
    this.startAt,
    this.endAt,
    this.bookingsClosed = false,
    this.hostIds = const [],
    this.onBookingsClosed,
    this.onHostAssigned,
    this.onHostUnassigned,
    this.onOpsChanged,
  });

  final String eventId;
  final String eventName;
  final DateTime? startAt;
  final DateTime? endAt;
  final bool bookingsClosed;
  final List<String> hostIds;
  final ValueChanged<bool>? onBookingsClosed;
  final ValueChanged<String>? onHostAssigned;
  final ValueChanged<String>? onHostUnassigned;
  final VoidCallback? onOpsChanged;

  @override
  State<OwnerEventOpsTiles> createState() => _OwnerEventOpsTilesState();
}

class _OwnerEventOpsTilesState extends State<OwnerEventOpsTiles> {
  final _repo = EventCommerceRepository();
  late bool _closed = widget.bookingsClosed;
  bool _busy = false;
  bool _exporting = false;
  bool _duplicating = false;
  int _pendingGuestListCount = 0;
  int _modulesCount = 0;
  int _pendingQuotesCount = 0;
  int _inquiriesCount = 0;

  @override
  void initState() {
    super.initState();
    _loadBadges();
  }

  @override
  void didUpdateWidget(OwnerEventOpsTiles oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bookingsClosed != widget.bookingsClosed) {
      _closed = widget.bookingsClosed;
    }
    if (oldWidget.eventId != widget.eventId) {
      _loadBadges();
    }
  }

  Future<void> _loadBadges() async {
    if (widget.eventId.isEmpty) return;
    try {
      final results = await Future.wait([
        _repo
            .guestListEntries(widget.eventId)
            .catchError((_) => <EventGuestListEntry>[]),
        _repo
            .ownerModules(widget.eventId)
            .catchError((_) => <EventVipModuleModel>[]),
        _repo
            .ownerQuotes(eventId: widget.eventId)
            .catchError((_) => <EventQuoteModel>[]),
        _repo
            .eventHostInquiries(widget.eventId)
            .catchError((_) => <EventHostInquiryModel>[]),
      ]);
      if (!mounted) return;
      final guestEntries = results[0] as List<EventGuestListEntry>;
      final modules = results[1] as List<EventVipModuleModel>;
      final quotes = results[2] as List<EventQuoteModel>;
      final inquiries = results[3] as List<EventHostInquiryModel>;

      setState(() {
        _pendingGuestListCount = guestEntries.where((e) {
          final s = e.status.trim().toUpperCase();
          return s == 'PENDING' ||
              (s != 'CONFIRMED' && s != 'APPROVED' && s != 'REJECTED');
        }).length;
        _modulesCount = modules.length;
        _pendingQuotesCount = quotes.where((q) {
          final s = q.status.trim().toUpperCase();
          return s == 'PENDING' ||
              s == 'NEW' ||
              (s != 'ANSWERED' && s != 'CLOSED' && s != 'REJECTED');
        }).length;
        _inquiriesCount = inquiries.length;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CustomText(
          text: 'Manage',
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        const SizedBox(height: 12),
        if (_closed)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF261D0A),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _gold.withValues(alpha: 0.35)),
            ),
            child: const CustomText(
              text:
                  'Bookings are closed. Guests cannot buy tickets, VIP, or send quotes. Tap Open bookings to sell again.',
              color: _gold,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        _tile(
          'VIP modules',
          Icons.weekend_outlined,
          () {
            _openOps(() => OwnerModulesView(eventId: widget.eventId));
          },
          badge: _modulesCount > 0
              ? _badgePill(
                  '$_modulesCount',
                  color: Colors.white.withValues(alpha: 0.08),
                  textColor: Colors.white70,
                )
              : null,
        ),
        _tile(
          'Guest list',
          Icons.people_outline,
          () {
            _openOps(() => OwnerGuestListAdminView(eventId: widget.eventId));
          },
          badge: _pendingGuestListCount > 0
              ? _badgePill(
                  '$_pendingGuestListCount pending',
                  color: _gold.withValues(alpha: 0.18),
                  textColor: _gold,
                  borderColor: _gold.withValues(alpha: 0.4),
                )
              : null,
        ),
        _tile(
          'Hosts',
          Icons.badge_outlined,
          () {
            _openOps(
              () => OwnerHostsView(
                eventId: widget.eventId,
                eventTitle: widget.eventName,
                assignedHostIds: widget.hostIds,
                onHostAssigned: widget.onHostAssigned,
                onHostUnassigned: widget.onHostUnassigned,
              ),
            );
          },
          badge: _inquiriesCount > 0
              ? _badgePill(
                  '$_inquiriesCount new',
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.18),
                  textColor: const Color(0xFF4CAF50),
                  borderColor: const Color(0xFF4CAF50).withValues(alpha: 0.4),
                )
              : null,
        ),
        _tile(
          'Quotes',
          Icons.request_quote_outlined,
          () {
            _openOps(
              () => OwnerQuotesView(
                eventId: widget.eventId,
                eventTitle: widget.eventName,
              ),
            );
          },
          badge: _pendingQuotesCount > 0
              ? _badgePill(
                  '$_pendingQuotesCount new',
                  color: const Color(0xFF29B6F6).withValues(alpha: 0.18),
                  textColor: const Color(0xFF29B6F6),
                  borderColor: const Color(0xFF29B6F6).withValues(alpha: 0.4),
                )
              : null,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: CustomButton(
                title: 'Duplicate',
                isLoading: _duplicating,
                isGradient: false,
                buttonColor: Colors.transparent,
                border: Border.all(color: _gold),
                titleColor: _gold,
                paddingVertical: 12,
                borderRadius: 14,
                fontSize: 13,
                onTap: _duplicating
                    ? null
                    : () => _confirmAndDuplicate(context, widget.eventId),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: CustomButton(
                title: _closed ? 'Open bookings' : 'Close bookings',
                isLoading: _busy,
                isGradient: false,
                buttonColor: _closed ? _gold : Colors.transparent,
                border: Border.all(color: _closed ? _gold : Colors.white24),
                titleColor: _closed ? Colors.black : Colors.white70,
                paddingVertical: 12,
                borderRadius: 14,
                fontSize: 13,
                onTap: _busy ? null : () => _toggleBookings(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        CustomButton(
          title: 'Export bookings',
          isLoading: _exporting,
          isGradient: false,
          buttonColor: Colors.transparent,
          border: Border.all(color: Colors.white24),
          titleColor: Colors.white70,
          paddingVertical: 12,
          borderRadius: 14,
          fontSize: 13,
          onTap: _exporting ? null : _export,
        ),
      ],
    );
  }

  Widget _tile(String title, IconData icon, VoidCallback onTap, {Widget? badge}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(icon, color: _gold, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: CustomText(
                  text: title,
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (badge != null) ...[
                badge,
                const SizedBox(width: 8),
              ],
              const Icon(Icons.chevron_right, color: Colors.white38),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badgePill(
    String text, {
    required Color color,
    required Color textColor,
    Color? borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: borderColor != null
            ? Border.all(color: borderColor, width: 0.8)
            : null,
      ),
      child: CustomText(
        text: text,
        color: textColor,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Future<void> _openOps(Widget Function() page) async {
    await Get.to(page);
    _loadBadges();
    widget.onOpsChanged?.call();
  }

  Future<void> _confirmAndDuplicate(BuildContext context, String id) async {
    final eventTitle =
        widget.eventName.isNotEmpty ? widget.eventName : 'this event';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const CustomText(
          text: 'Duplicate Event?',
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        content: CustomText(
          text:
              'Are you sure you want to duplicate "$eventTitle"? A copy of this event, its ticket tiers, and VIP modules will be created.',
          color: Colors.white70,
          fontSize: 14,
          height: 1.4,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const CustomText(
              text: 'Cancel',
              color: Colors.white54,
              fontSize: 14,
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const CustomText(
              text: 'Duplicate',
              color: _gold,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _duplicating = true);
    try {
      await EventCommerceRepository().duplicateEvent(id);
      CustomSnackBar.success(message: 'Event duplicated successfully');
      if (Get.isRegistered<OwnerActivityController>()) {
        await Get.find<OwnerActivityController>().refreshCurrentType();
      }
      widget.onOpsChanged?.call();
    } catch (error) {
      CustomSnackBar.error(
        message: clientErrorMessage(error, 'Could not duplicate event'),
      );
    } finally {
      if (mounted) setState(() => _duplicating = false);
    }
  }

  Future<void> _toggleBookings(BuildContext context) async {
    final closing = !_closed;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: CustomText(
          text: closing ? 'Close bookings?' : 'Open bookings?',
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        content: CustomText(
          text: closing
              ? 'Guests will not be able to buy tickets, VIP modules, or request quotes until you open bookings again.'
              : 'Guests will be able to buy and request quotes again.',
          color: Colors.white70,
          fontSize: 14,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              closing ? 'Close' : 'Open',
              style: const TextStyle(
                color: _gold,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await EventCommerceRepository().closeEventBookings(
        widget.eventId,
        closed: closing,
      );
      if (!mounted) return;
      setState(() => _closed = closing);
      widget.onBookingsClosed?.call(closing);
      widget.onOpsChanged?.call();
      CustomSnackBar.success(
        message: closing
            ? 'Bookings closed. Tap Open bookings to sell again.'
            : 'Bookings are open again.',
      );
    } catch (error) {
      CustomSnackBar.error(
        message: clientErrorMessage(
          error,
          closing ? 'Could not close bookings' : 'Could not open bookings',
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export() async {
    final now = DateTime.now().toUtc();
    var from = widget.startAt?.toUtc() ?? now.subtract(const Duration(days: 30));
    var to = widget.endAt?.toUtc() ?? now;
    if (to.isBefore(from)) {
      final swap = from;
      from = to;
      to = swap;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const CustomText(
          text: 'Export bookings?',
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        content: CustomText(
          text:
              'Downloads ticket and VIP module bookings for this event from ${_exportDay(from)} to ${_exportDay(to)}. Opens in the browser.',
          color: Colors.white70,
          fontSize: 14,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Export',
              style: TextStyle(color: _gold, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _exporting = true);
    try {
      final url = await EventCommerceRepository().exportBookings(
        type: 'EVENT',
        from: from,
        to: to,
        eventId: widget.eventId,
      );
      if (url == null || url.isEmpty) {
        CustomSnackBar.error(message: 'No export URL returned');
        return;
      }
      final uri = Uri.tryParse(url);
      if (uri == null) {
        CustomSnackBar.error(message: 'Invalid export URL');
        return;
      }
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      CustomSnackBar.success(message: 'Opening bookings export');
    } catch (error) {
      CustomSnackBar.error(
        message: clientErrorMessage(error, 'Could not export bookings'),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  String _exportDay(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}

class OwnerModulesView extends StatefulWidget {
  const OwnerModulesView({super.key, required this.eventId});
  final String eventId;

  @override
  State<OwnerModulesView> createState() => _OwnerModulesViewState();
}

class _OwnerModulesViewState extends State<OwnerModulesView> {
  final _repo = EventCommerceRepository();
  var _items = <EventVipModuleModel>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _repo.ownerModules(widget.eventId);
      if (mounted) setState(() => _items = items);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = clientErrorMessage(error, 'Could not load modules'),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const CustomText(
          text: 'VIP modules',
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: () async {
              final saved = await Get.to(
                () => OwnerModuleFormView(eventId: widget.eventId),
              );
              if (saved == true) _load();
            },
            icon: const Icon(Icons.add, color: _gold),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _gold))
          : _error != null
          ? CompactEmptyState.stacked(
              icon: Icons.error_outline,
              title: 'Could not load modules',
              message: _error,
            )
          : _items.isEmpty
          ? const CompactEmptyState.stacked(
              icon: Icons.weekend_outlined,
              title: 'No modules yet',
              message: 'Add a VIP module for this event.',
            )
          : RefreshIndicator(
              color: _gold,
              backgroundColor: _card,
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                itemCount: _items.length,
                itemBuilder: (_, index) {
                  final item = _items[index];
                  final allExtras = [
                    ...item.includedExtras,
                    ...item.optionalExtras,
                  ];
                  final hasMinSpend = item.minSpend.trim().isNotEmpty &&
                      item.minSpend != '0.00' &&
                      item.minSpend != '0';
                  final hasDeposit = item.deposit.trim().isNotEmpty &&
                      item.deposit != '0.00' &&
                      item.deposit != '0';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header: Name, Area, Price, Status
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CustomText(
                                    text: item.name,
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  if (item.venueArea.trim().isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.place_outlined,
                                          size: 12,
                                          color: Colors.white38,
                                        ),
                                        const SizedBox(width: 3),
                                        Expanded(
                                          child: CustomText(
                                            text: item.venueArea.trim(),
                                            color: Colors.white54,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (item.priceLabel.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF261D0A),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: _gold.withValues(alpha: 0.5),
                                      ),
                                    ),
                                    child: CustomText(
                                      text: item.priceLabel,
                                      color: _gold,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                if (!item.isSoldOut &&
                                    (item.isUnavailable ||
                                        item.statusKey == 'LIMITED')) ...[
                                  const SizedBox(height: 4),
                                  _statusBadge(item),
                                ],
                              ],
                            ),
                          ],
                        ),

                        // Structured Specs Box (Guests, Inventory, Min spend, Deposit) - Full visibility, no clipping
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(top: 10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.05),
                            ),
                          ),
                          child: Wrap(
                            spacing: 18,
                            runSpacing: 8,
                            children: [
                              if (item.maxGuests > 0)
                                _infoItem(
                                  icon: Icons.group_outlined,
                                  label: 'Guests',
                                  value: '${item.maxGuests} max',
                                ),
                              _infoItem(
                                icon: Icons.inventory_2_outlined,
                                label: 'Inventory',
                                value: item.isSoldOut
                                    ? 'Sold out'
                                    : (item.quantity > 0
                                        ? '${item.remaining}/${item.quantity} left'
                                        : (item.remaining > 0
                                            ? '${item.remaining} left'
                                            : 'Available')),
                                valueColor: item.isSoldOut
                                    ? const Color(0xFFFF6B6B)
                                    : Colors.white,
                              ),
                              if (hasMinSpend)
                                _infoItem(
                                  icon: Icons.euro_outlined,
                                  label: 'Min Spend',
                                  value: '€${item.minSpend}',
                                ),
                              if (hasDeposit)
                                _infoItem(
                                  icon:
                                      Icons.account_balance_wallet_outlined,
                                  label: 'Deposit',
                                  value: '€${item.deposit}',
                                ),
                            ],
                          ),
                        ),

                        // Full Description (no truncation or ellipsis)
                        if (item.description.trim().isNotEmpty) ...[
                          const SizedBox(height: 10),
                          CustomText(
                            text: item.description.trim(),
                            color: const Color(0xFFA0A0A0),
                            fontSize: 12,
                            height: 1.45,
                          ),
                        ],

                        // Full Extras / Perks (all perks displayed, no ellipsis)
                        if (allExtras.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: Icon(
                                  Icons.stars_outlined,
                                  size: 14,
                                  color: _gold,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: CustomText(
                                  text: allExtras.join('  •  '),
                                  color: Colors.white70,
                                  fontSize: 11,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ],

                        const SizedBox(height: 14),
                        Row(
                          children: [
                            _mini('Edit', () async {
                              final saved = await Get.to(
                                () => OwnerModuleFormView(
                                  eventId: widget.eventId,
                                  existing: item,
                                ),
                              );
                              if (saved == true) _load();
                            }),
                            const SizedBox(width: 8),
                            _mini('Duplicate', () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: _card,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  title: const CustomText(
                                    text: 'Duplicate Module?',
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  content: CustomText(
                                    text:
                                        'Are you sure you want to duplicate "${item.name}"?',
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(ctx).pop(false),
                                      child: const CustomText(
                                        text: 'Cancel',
                                        color: Colors.white54,
                                        fontSize: 14,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(ctx).pop(true),
                                      child: const CustomText(
                                        text: 'Duplicate',
                                        color: _gold,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed != true) return;
                              try {
                                await _repo.duplicateModule(
                                  eventId: widget.eventId,
                                  moduleId: item.id,
                                );
                                CustomSnackBar.success(
                                  message: 'Module duplicated',
                                );
                                await _load();
                              } catch (error) {
                                CustomSnackBar.error(
                                  message: clientErrorMessage(
                                    error,
                                    'Could not duplicate',
                                  ),
                                );
                              }
                            }),
                            const SizedBox(width: 8),
                            _mini('Delete', () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: _card,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  title: const CustomText(
                                    text: 'Delete Module?',
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  content: CustomText(
                                    text:
                                        'Are you sure you want to delete "${item.name}"? This action cannot be undone.',
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(ctx).pop(false),
                                      child: const CustomText(
                                        text: 'Cancel',
                                        color: Colors.white54,
                                        fontSize: 14,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(ctx).pop(true),
                                      child: const CustomText(
                                        text: 'Delete',
                                        color: Color(0xFFE57373),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed != true) return;
                              try {
                                await _repo.deleteModule(
                                  eventId: widget.eventId,
                                  moduleId: item.id,
                                );
                                CustomSnackBar.success(
                                  message: 'Module deleted',
                                );
                                await _load();
                              } catch (error) {
                                CustomSnackBar.error(
                                  message: clientErrorMessage(
                                    error,
                                    'Could not delete',
                                  ),
                                );
                              }
                            }, danger: true),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _statusBadge(EventVipModuleModel item) {
    if (item.isSoldOut) return const SizedBox.shrink();

    Color textColor;
    Color bgColor;
    Color borderColor;

    if (item.isUnavailable) {
      textColor = Colors.white54;
      bgColor = const Color(0xFF222222);
      borderColor = Colors.white24;
    } else if (item.statusKey == 'LIMITED') {
      textColor = const Color(0xFFFFB74D);
      bgColor = const Color(0xFF33230A);
      borderColor = const Color(0xFFFFB74D).withValues(alpha: 0.35);
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: CustomText(
        text: item.statusLabel,
        color: textColor,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _infoItem({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.white38),
        const SizedBox(width: 4),
        CustomText(
          text: '$label: ',
          color: Colors.white38,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
        CustomText(
          text: value,
          color: valueColor ?? Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ],
    );
  }

  Widget _mini(String title, VoidCallback onTap, {bool danger = false}) {
    return Expanded(
      child: CustomButton(
        title: title,
        isGradient: false,
        buttonColor: Colors.transparent,
        border: Border.all(color: danger ? const Color(0xFFE57373) : _gold),
        titleColor: danger ? const Color(0xFFE57373) : _gold,
        paddingVertical: 10,
        borderRadius: 12,
        fontSize: 12,
        onTap: onTap,
      ),
    );
  }
}

class OwnerModuleFormView extends StatefulWidget {
  const OwnerModuleFormView({super.key, required this.eventId, this.existing});
  final String eventId;
  final EventVipModuleModel? existing;

  @override
  State<OwnerModuleFormView> createState() => _OwnerModuleFormViewState();
}

class _OwnerModuleFormViewState extends State<OwnerModuleFormView> {
  final name = TextEditingController();
  final description = TextEditingController();
  final price = TextEditingController();
  final guests = TextEditingController();
  final quantity = TextEditingController();
  final area = TextEditingController();
  final included = TextEditingController();
  final optional = TextEditingController();
  String status = 'AVAILABLE';
  bool busy = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      name.text = existing.name;
      description.text = existing.description;
      price.text = existing.startingPrice;
      guests.text = existing.maxGuests.toString();
      quantity.text = existing.quantity.toString();
      area.text = existing.venueArea;
      included.text = existing.includedExtras.join(', ');
      optional.text = existing.optionalExtras.join(', ');
      status = existing.statusKey;
    }
  }

  @override
  void dispose() {
    name.dispose();
    description.dispose();
    price.dispose();
    guests.dispose();
    quantity.dispose();
    area.dispose();
    included.dispose();
    optional.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: CustomText(
          text: widget.existing == null ? 'Add module' : 'Edit module',
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          CustomTextField(
            label: 'Module Name',
            hint: 'e.g. Noble Table',
            labelColor: Colors.white,
            controller: name,
            filled: true,
            fillColor: _card,
          ),
          const SizedBox(height: 14),
          CustomTextField(
            label: 'Description',
            hint: 'Describe VIP perks, table location and inclusions',
            labelColor: Colors.white,
            controller: description,
            filled: true,
            fillColor: _card,
            maxLines: 3,
          ),
          const SizedBox(height: 14),
          CustomTextField(
            label: 'Starting Price (€)',
            hint: 'e.g. 1000.00',
            labelColor: Colors.white,
            controller: price,
            filled: true,
            fillColor: _card,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 14),
          CustomTextField(
            label: 'Max Guests Capacity',
            hint: 'e.g. 6',
            labelColor: Colors.white,
            controller: guests,
            filled: true,
            fillColor: _card,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 14),
          CustomTextField(
            label: 'Total Quantity',
            hint: 'Total tables or passes (e.g. 10)',
            labelColor: Colors.white,
            controller: quantity,
            filled: true,
            fillColor: _card,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 14),
          CustomTextField(
            label: 'Venue Area',
            hint: 'e.g. Grand Salon, Main Floor, Balcony',
            labelColor: Colors.white,
            controller: area,
            filled: true,
            fillColor: _card,
          ),
          const SizedBox(height: 14),
          CustomTextField(
            label: 'Included Extras',
            hint: 'Comma-separated (e.g. Reserved table, 2x Champagne bottles)',
            labelColor: Colors.white,
            controller: included,
            filled: true,
            fillColor: _card,
          ),
          const SizedBox(height: 14),
          CustomTextField(
            label: 'Optional Extras',
            hint: 'Comma-separated (e.g. Dedicated butler, VIP Fast-track)',
            labelColor: Colors.white,
            controller: optional,
            filled: true,
            fillColor: _card,
          ),
          const SizedBox(height: 16),
          const CustomText(
            text: 'Availability Status',
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final value in [
                'AVAILABLE',
                'LIMITED',
                'SOLD_OUT',
                'UNAVAILABLE'
              ])
                ChoiceChip(
                  label: Text(value.replaceAll('_', ' ')),
                  selected: status == value,
                  selectedColor: _gold,
                  labelStyle: TextStyle(
                    color: status == value ? Colors.black : Colors.white,
                    fontWeight:
                        status == value ? FontWeight.bold : FontWeight.normal,
                  ),
                  backgroundColor: _card,
                  onSelected: (_) => setState(() => status = value),
                ),
            ],
          ),
          const SizedBox(height: 24),
          CustomButton(
            title: 'Save',
            isLoading: busy,
            isGradient: false,
            buttonColor: _gold,
            titleColor: Colors.black,
            borderRadius: 16,
            onTap: busy ? null : _save,
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (name.text.trim().isEmpty) {
      CustomSnackBar.error(message: 'Name is required');
      return;
    }
    setState(() => busy = true);
    try {
      await EventCommerceRepository().saveModule(
        eventId: widget.eventId,
        module: EventVipModuleModel(
          id: widget.existing?.id ?? '',
          eventId: widget.eventId,
          name: name.text.trim(),
          description: description.text.trim(),
          startingPrice: price.text.trim(),
          maxGuests: int.tryParse(guests.text.trim()) ?? 0,
          quantity: int.tryParse(quantity.text.trim()) ?? 0,
          venueArea: area.text.trim(),
          includedExtras: _split(included.text),
          optionalExtras: _split(optional.text),
          status: status,
          minSpend: widget.existing?.minSpend ?? '0.00',
          deposit: widget.existing?.deposit ?? '0.00',
          currency: widget.existing?.currency ?? 'EUR',
          remaining: widget.existing?.remaining ?? 0,
          sortOrder: widget.existing?.sortOrder ?? 0,
          isActive: true,
        ),
      );
      if (mounted) Get.back(result: true);
    } catch (error) {
      CustomSnackBar.error(
        message: clientErrorMessage(error, 'Could not save module'),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  List<String> _split(String value) => value
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

class OwnerGuestListAdminView extends StatefulWidget {
  const OwnerGuestListAdminView({super.key, required this.eventId});
  final String eventId;

  @override
  State<OwnerGuestListAdminView> createState() => _OwnerGuestListAdminViewState();
}

class _OwnerGuestListAdminViewState extends State<OwnerGuestListAdminView> {
  final _repo = EventCommerceRepository();
  var _items = <EventGuestListEntry>[];
  bool _loading = true;
  String? _error;
  bool _open = true;
  int _selectedTab = 0; // 0: Requests, 1: Approved

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _repo.guestListEntries(widget.eventId);
      final config = await _repo.fetchGuestList(widget.eventId);
      if (mounted) {
        setState(() {
          _items = items;
          if (config != null) {
            _open = config.isOpen;
          }
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = clientErrorMessage(error, 'Could not load entries'),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingEntries = _items.where((e) {
      final s = e.status.trim().toUpperCase();
      return s == 'PENDING' ||
          (s != 'CONFIRMED' && s != 'APPROVED' && s != 'REJECTED');
    }).toList();

    final approvedEntries = _items.where((e) {
      final s = e.status.trim().toUpperCase();
      return s == 'CONFIRMED' || s == 'APPROVED';
    }).toList();

    final rejectedEntries = _items.where((e) {
      final s = e.status.trim().toUpperCase();
      return s == 'REJECTED';
    }).toList();

    final confirmedHeadcount = approvedEntries.fold<int>(
      0,
      (sum, e) => sum + e.menCount + e.womenCount + e.otherCount,
    );
    final confirmedMen = approvedEntries.fold<int>(
      0,
      (sum, e) => sum + e.menCount,
    );
    final confirmedWomen = approvedEntries.fold<int>(
      0,
      (sum, e) => sum + e.womenCount,
    );
    final confirmedOthers = approvedEntries.fold<int>(
      0,
      (sum, e) => sum + e.otherCount,
    );
    final pendingCount = pendingEntries.length;
    final List<EventGuestListEntry> currentList;
    if (_selectedTab == 0) {
      currentList = pendingEntries;
    } else if (_selectedTab == 1) {
      currentList = approvedEntries;
    } else {
      currentList = rejectedEntries;
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const CustomText(
          text: 'Guest list',
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          SwitchListTile(
            value: _open,
            activeThumbColor: _gold,
            title: const CustomText(
              text: 'Guest list open',
              color: Colors.white,
              fontSize: 14,
            ),
            onChanged: (value) async {
              final prev = _open;
              setState(() => _open = value);
              try {
                await _repo.upsertGuestList(
                  eventId: widget.eventId,
                  config: EventGuestListModel(isOpen: value),
                );
                CustomSnackBar.success(
                  message: value
                      ? 'Guest list is now open'
                      : 'Guest list is now closed',
                );
              } catch (error) {
                if (mounted) setState(() => _open = prev);
                CustomSnackBar.error(
                  message:
                      clientErrorMessage(error, 'Could not update guest list'),
                );
              }
            },
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.people_alt_outlined,
                          color: _gold,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        CustomText(
                          text: '$confirmedHeadcount Confirmed Guests',
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: pendingCount > 0
                            ? _gold.withValues(alpha: 0.16)
                            : Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: pendingCount > 0
                            ? Border.all(
                                color: _gold.withValues(alpha: 0.4),
                                width: 0.8,
                              )
                            : null,
                      ),
                      child: CustomText(
                        text: pendingCount > 0
                            ? '$pendingCount pending'
                            : '0 pending',
                        color: pendingCount > 0 ? _gold : Colors.white60,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _demographicChip(
                      'Men: $confirmedMen',
                      Icons.male,
                      const Color(0xFF64B5F6),
                    ),
                    _demographicChip(
                      'Women: $confirmedWomen',
                      Icons.female,
                      const Color(0xFFF06292),
                    ),
                    _demographicChip(
                      'Others: $confirmedOthers',
                      Icons.transgender,
                      const Color(0xFFBA68C8),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF1F1F1F),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _tabPill(
                    title: 'Requests (${pendingEntries.length})',
                    isSelected: _selectedTab == 0,
                    onTap: () => setState(() => _selectedTab = 0),
                  ),
                ),
                Expanded(
                  child: _tabPill(
                    title: 'Approved (${approvedEntries.length})',
                    isSelected: _selectedTab == 1,
                    onTap: () => setState(() => _selectedTab = 1),
                  ),
                ),
                Expanded(
                  child: _tabPill(
                    title: 'Rejected (${rejectedEntries.length})',
                    isSelected: _selectedTab == 2,
                    onTap: () => setState(() => _selectedTab = 2),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _gold))
                : _error != null
                ? CompactEmptyState.stacked(
                    icon: Icons.error_outline,
                    title: 'Could not load entries',
                    message: _error,
                  )
                : currentList.isEmpty
                ? CompactEmptyState.stacked(
                    icon: _selectedTab == 0
                        ? Icons.mark_email_read_outlined
                        : _selectedTab == 1
                        ? Icons.people_outline
                        : Icons.person_off_outlined,
                    title: _selectedTab == 0
                        ? 'No pending requests'
                        : _selectedTab == 1
                        ? 'No approved guests yet'
                        : 'No rejected requests',
                    message: _selectedTab == 0
                        ? 'All guest list requests have been processed.'
                        : _selectedTab == 1
                        ? 'Approved guests will appear here.'
                        : 'Rejected requests will appear here.',
                  )
                : RefreshIndicator(
                    color: _gold,
                    backgroundColor: _card,
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                      itemCount: currentList.length,
                      itemBuilder: (_, index) {
                        final item = currentList[index];
                        final isConfirmed =
                            item.status.trim().toUpperCase() == 'CONFIRMED' ||
                            item.status.trim().toUpperCase() == 'APPROVED';
                        final isRejected =
                            item.status.trim().toUpperCase() == 'REJECTED';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _card,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isConfirmed
                                  ? const Color(0xFF2E7D32).withValues(alpha: 0.4)
                                  : isRejected
                                      ? const Color(0xFFC62828).withValues(alpha: 0.4)
                                      : Colors.white.withValues(alpha: 0.06),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: CustomText(
                                      text: item.name,
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  StatusBadge(
                                    status: isConfirmed ? 'CONFIRMED' : item.status,
                                    label: isConfirmed ? 'Confirmed' : null,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.email_outlined,
                                    size: 13,
                                    color: Colors.white54,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: CustomText(
                                      text: item.email,
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (item.phone.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.phone_outlined,
                                      size: 13,
                                      color: Colors.white54,
                                    ),
                                    const SizedBox(width: 4),
                                    CustomText(
                                      text: item.phone,
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  if (item.arrivalTime.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.06),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.access_time,
                                            size: 12,
                                            color: _gold,
                                          ),
                                          const SizedBox(width: 4),
                                          CustomText(
                                            text: item.arrivalTime,
                                            color: _gold,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ],
                                      ),
                                    ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.06),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: CustomText(
                                      text: item.otherCount > 0
                                          ? 'Party: ${item.menCount} Men · ${item.womenCount} Women · ${item.otherCount} Others'
                                          : 'Party: ${item.menCount} Men · ${item.womenCount} Women',
                                      color: Colors.white70,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                              if (_selectedTab == 0) ...[
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: CustomButton(
                                        title: 'Approve',
                                        isGradient: false,
                                        buttonColor: _gold,
                                        titleColor: Colors.black,
                                        paddingVertical: 10,
                                        borderRadius: 12,
                                        fontSize: 12,
                                        onTap: () =>
                                            _setStatus(item, 'CONFIRMED'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: CustomButton(
                                        title: 'Reject',
                                        isGradient: false,
                                        buttonColor: Colors.transparent,
                                        border: Border.all(
                                          color: const Color(0xFFE57373),
                                        ),
                                        titleColor: const Color(0xFFE57373),
                                        paddingVertical: 10,
                                        borderRadius: 12,
                                        fontSize: 12,
                                        onTap: () =>
                                            _setStatus(item, 'REJECTED'),
                                      ),
                                    ),
                                  ],
                                ),
                              ] else if (_selectedTab == 1) ...[
                                const SizedBox(height: 12),
                                CustomButton(
                                  title: 'Reject from list',
                                  isGradient: false,
                                  buttonColor: Colors.transparent,
                                  border: Border.all(
                                    color: const Color(0xFFE57373).withValues(alpha: 0.6),
                                  ),
                                  titleColor: const Color(0xFFE57373),
                                  paddingVertical: 10,
                                  borderRadius: 12,
                                  fontSize: 12,
                                  onTap: () => _confirmAndReject(item),
                                ),
                              ] else if (_selectedTab == 2) ...[
                                const SizedBox(height: 12),
                                CustomButton(
                                  title: 'Re-approve',
                                  isGradient: false,
                                  buttonColor: _gold,
                                  titleColor: Colors.black,
                                  paddingVertical: 10,
                                  borderRadius: 12,
                                  fontSize: 12,
                                  onTap: () =>
                                      _setStatus(item, 'CONFIRMED'),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _demographicChip(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 0.7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          CustomText(
            text: text,
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ],
      ),
    );
  }

  Widget _tabPill({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? _gold : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: CustomText(
          text: title,
          color: isSelected ? Colors.black : Colors.white70,
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }

  Future<void> _confirmAndReject(EventGuestListEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const CustomText(
          text: 'Reject Guest?',
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        content: CustomText(
          text:
              'Are you sure you want to remove "${entry.name}" from the approved guest list?',
          color: Colors.white70,
          fontSize: 14,
          height: 1.4,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const CustomText(
              text: 'Cancel',
              color: Colors.white54,
              fontSize: 14,
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const CustomText(
              text: 'Reject',
              color: Color(0xFFE57373),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _setStatus(entry, 'REJECTED');
    }
  }

  Future<void> _setStatus(EventGuestListEntry entry, String status) async {
    try {
      await _repo.updateGuestListEntry(
        eventId: widget.eventId,
        entryId: entry.id,
        status: status,
      );
      CustomSnackBar.success(
        message: status.toUpperCase() == 'CONFIRMED'
            ? 'Guest confirmed on the list'
            : 'Guest entry rejected',
      );
      await _load();
    } catch (error) {
      CustomSnackBar.error(
        message: clientErrorMessage(error, 'Could not update entry'),
      );
    }
  }
}

class OwnerHostsView extends StatefulWidget {
  const OwnerHostsView({
    super.key,
    required this.eventId,
    this.eventTitle,
    this.initialTab = 0,
    this.assignedHostIds = const [],
    this.onHostAssigned,
    this.onHostUnassigned,
  });
  final String eventId;
  final String? eventTitle;
  final int initialTab;
  final List<String> assignedHostIds;
  final ValueChanged<String>? onHostAssigned;
  final ValueChanged<String>? onHostUnassigned;

  @override
  State<OwnerHostsView> createState() => _OwnerHostsViewState();
}

class _OwnerHostsViewState extends State<OwnerHostsView> {
  final _repo = EventCommerceRepository();
  late int _selectedTab = widget.initialTab;
  var _items = <EventHostModel>[];
  var _inquiries = <EventHostInquiryModel>[];
  late final Set<String> _assigned = {...widget.assignedHostIds};
  bool _loading = true;
  String? _error;
  String? _assigningId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _repo.ownerHosts(),
        _repo
            .eventHostInquiries(widget.eventId)
            .catchError((_) => <EventHostInquiryModel>[]),
      ]);
      final items = results[0] as List<EventHostModel>;
      final inquiries = results[1] as List<EventHostInquiryModel>;
      final assigned = <String>{...widget.assignedHostIds};
      try {
        final attached = await _repo.eventHosts(widget.eventId);
        assigned.addAll(
          attached.map((host) => host.id).where((id) => id.isNotEmpty),
        );
      } catch (_) {
        // Keep known ids if event-hosts request is unavailable.
        assigned.addAll(_assigned);
      }
      if (mounted) {
        setState(() {
          _items = items;
          _inquiries = inquiries;
          _assigned
            ..clear()
            ..addAll(assigned);
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = clientErrorMessage(error, 'Could not load hosts'),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: CustomText(
          text: widget.eventTitle?.isNotEmpty == true
              ? 'Hosts · ${widget.eventTitle}'
              : 'Hosts',
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_selectedTab == 0)
            IconButton(
              onPressed: () async {
                final saved = await Get.to(() => const OwnerHostFormView());
                if (saved == true) _load();
              },
              icon: const Icon(Icons.add, color: _gold),
            )
          else
            IconButton(
              onPressed: _load,
              icon: const Icon(Icons.refresh, color: _gold),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _gold))
                : _error != null
                    ? CompactEmptyState.stacked(
                        icon: Icons.error_outline,
                        title: _selectedTab == 0
                            ? 'Could not load hosts'
                            : 'Could not load inquiries',
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
                    : _selectedTab == 0
                        ? _buildHostsTab()
                        : _buildInquiriesTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _selectedTab = 0),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _selectedTab == 0 ? _gold : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: CustomText(
                  text: 'Assigned Hosts (${_assigned.length})',
                  color: _selectedTab == 0 ? Colors.black : Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _selectedTab = 1),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _selectedTab == 1 ? _gold : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CustomText(
                      text: 'Inquiries',
                      color: _selectedTab == 1 ? Colors.black : Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    if (_inquiries.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _selectedTab == 1 ? Colors.black : _gold,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: CustomText(
                          text: '${_inquiries.length}',
                          color: _selectedTab == 1 ? _gold : Colors.black,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHostsTab() {
    if (_items.isEmpty) {
      return const CompactEmptyState.stacked(
        icon: Icons.badge_outlined,
        title: 'No hosts yet',
      );
    }
    return RefreshIndicator(
      color: _gold,
      backgroundColor: _card,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        itemCount: _items.length,
        itemBuilder: (_, index) {
          final host = _items[index];
          final assigned = _assigned.contains(host.id);
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(16),
              border: assigned
                  ? Border.all(color: _gold.withValues(alpha: 0.4))
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: CustomText(
                        text: host.name,
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (assigned)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF261D0A),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const CustomText(
                          text: 'Assigned',
                          color: _gold,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
                if (host.role.isNotEmpty)
                  CustomText(
                    text: host.role,
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                const SizedBox(height: 12),
                CustomButton(
                  title: assigned
                      ? 'Assigned (Tap to remove)'
                      : 'Assign to event',
                  isLoading: _assigningId == host.id,
                  isGradient: false,
                  buttonColor: assigned ? Colors.transparent : _gold,
                  border: assigned
                      ? Border.all(color: _gold.withValues(alpha: 0.6))
                      : null,
                  titleColor: assigned ? _gold : Colors.black,
                  paddingVertical: 10,
                  borderRadius: 12,
                  fontSize: 13,
                  onTap: assigned
                      ? () => _confirmUnassign(host)
                      : () async {
                          setState(() => _assigningId = host.id);
                          try {
                            await _repo.assignHostToEvent(
                              eventId: widget.eventId,
                              hostId: host.id,
                            );
                            if (!mounted) return;
                            setState(() => _assigned.add(host.id));
                            widget.onHostAssigned?.call(host.id);
                            CustomSnackBar.success(
                              message:
                                  '${host.name} is assigned to this event',
                            );
                          } catch (error) {
                            CustomSnackBar.error(
                              message: clientErrorMessage(
                                error,
                                'Could not assign host',
                              ),
                            );
                          } finally {
                            if (mounted) {
                              setState(() => _assigningId = null);
                            }
                          }
                        },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInquiriesTab() {
    if (_inquiries.isEmpty) {
      return RefreshIndicator(
        color: _gold,
        backgroundColor: _card,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.6,
              child: const CompactEmptyState.stacked(
                icon: Icons.mark_chat_unread_outlined,
                title: 'No host inquiries yet',
                message:
                    'Guest inquiries sent to assigned VIP hosts will appear here.',
              ),
            ),
          ],
        ),
      );
    }

    final hostMap = {for (final h in _items) h.id: h};

    return RefreshIndicator(
      color: _gold,
      backgroundColor: _card,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        itemCount: _inquiries.length,
        itemBuilder: (_, index) =>
            _buildInquiryCard(_inquiries[index], hostMap),
      ),
    );
  }

  Widget _buildInquiryCard(
    EventHostInquiryModel item,
    Map<String, EventHostModel> hostMap,
  ) {
    final host = hostMap[item.hostId];
    final hostName = item.hostName.isNotEmpty
        ? item.hostName
        : (host?.name.isNotEmpty == true ? host!.name : 'Assigned Host');
    final cleanPhone = item.customerPhone.replaceAll(RegExp(r'[^0-9+]'), '');
    final hasPhone = item.customerPhone.trim().isNotEmpty;
    final hasEmail = item.customerEmail.trim().isNotEmpty;
    final guestName = item.customerName.trim().isNotEmpty
        ? item.customerName.trim()
        : 'Guest';

    return Container(
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
          // Header: Guest Avatar, Name, Host Tag, Time
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF261D0A),
                  shape: BoxShape.circle,
                  border: Border.all(color: _gold.withValues(alpha: 0.5)),
                ),
                alignment: Alignment.center,
                child: CustomText(
                  text: guestName[0].toUpperCase(),
                  color: _gold,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomText(
                      text: guestName,
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                    const SizedBox(height: 2),
                    CustomText(
                      text: 'Host: $hostName',
                      color: _gold,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ],
                ),
              ),
              if (item.createdAt != null)
                CustomText(
                  text: DateFormat('MMM d, h:mm a')
                      .format(item.createdAt!.toLocal()),
                  color: Colors.white38,
                  fontSize: 11,
                ),
            ],
          ),

          // Message (Clean & direct, without nested heavy box)
          if (item.message.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(8),
              ),
              child: CustomText(
                text: item.message.trim(),
                color: Colors.white.withValues(alpha: 0.88),
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ],

          // Contact details line (Phone & Email inline)
          if (hasPhone || hasEmail) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (hasPhone) ...[
                  const Icon(Icons.phone_outlined,
                      size: 13, color: Colors.white54),
                  const SizedBox(width: 4),
                  CustomText(
                    text: item.customerPhone.trim(),
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                  if (hasEmail) const SizedBox(width: 12),
                ],
                if (hasEmail) ...[
                  const Icon(Icons.mail_outline_rounded,
                      size: 13, color: Colors.white54),
                  const SizedBox(width: 4),
                  Expanded(
                    child: CustomText(
                      text: item.customerEmail.trim(),
                      color: Colors.white70,
                      fontSize: 12,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ],

          // Quick Action buttons row
          if (hasPhone || hasEmail) ...[
            const SizedBox(height: 12),
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
                      paddingVertical: 8,
                      borderRadius: 10,
                      fontSize: 12,
                      onTap: () => _launchUri('https://wa.me/$cleanPhone'),
                    ),
                  ),
                if (hasPhone && cleanPhone.isNotEmpty)
                  const SizedBox(width: 8),
                if (hasPhone)
                  Expanded(
                    child: CustomButton(
                      title: 'Call',
                      isGradient: false,
                      buttonColor: Colors.transparent,
                      border: Border.all(color: _gold),
                      titleColor: _gold,
                      paddingVertical: 8,
                      borderRadius: 10,
                      fontSize: 12,
                      onTap: () =>
                          _launchUri('tel:${item.customerPhone.trim()}'),
                    ),
                  ),
                if (!hasPhone && hasEmail)
                  Expanded(
                    child: CustomButton(
                      title: 'Email',
                      isGradient: false,
                      buttonColor: Colors.transparent,
                      border: Border.all(color: _gold),
                      titleColor: _gold,
                      paddingVertical: 8,
                      borderRadius: 10,
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

  Future<void> _launchUri(String uriString) async {
    try {
      final uri = Uri.parse(uriString);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (_) {}
  }

  Future<void> _confirmUnassign(EventHostModel host) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const CustomText(
          text: 'Remove host?',
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        content: CustomText(
          text: 'Do you want to remove "${host.name}" from this event?',
          color: Colors.white70,
          fontSize: 14,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const CustomText(text: 'Cancel', color: Colors.white54),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const CustomText(
              text: 'Remove',
              color: Color(0xFFFF5252),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _assigningId = host.id);
    try {
      await _repo.unassignHostFromEvent(
        eventId: widget.eventId,
        hostId: host.id,
      );
      if (!mounted) return;
      setState(() => _assigned.remove(host.id));
      widget.onHostUnassigned?.call(host.id);
      CustomSnackBar.success(
        message: '${host.name} removed from this event',
      );
    } catch (error) {
      CustomSnackBar.error(
        message: clientErrorMessage(error, 'Could not remove host'),
      );
    } finally {
      if (mounted) setState(() => _assigningId = null);
    }
  }
}

class OwnerHostFormView extends StatefulWidget {
  const OwnerHostFormView({super.key});

  @override
  State<OwnerHostFormView> createState() => _OwnerHostFormViewState();
}

class _OwnerHostFormViewState extends State<OwnerHostFormView> {
  final name = TextEditingController();
  final role = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final whatsapp = TextEditingController();
  final bio = TextEditingController();
  bool busy = false;

  @override
  void dispose() {
    name.dispose();
    role.dispose();
    email.dispose();
    phone.dispose();
    whatsapp.dispose();
    bio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const CustomText(
          text: 'Add host',
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          CustomTextField(hint: 'Name', controller: name, filled: true, fillColor: _card),
          const SizedBox(height: 10),
          CustomTextField(hint: 'Role', controller: role, filled: true, fillColor: _card),
          const SizedBox(height: 10),
          CustomTextField(hint: 'Email', controller: email, filled: true, fillColor: _card),
          const SizedBox(height: 10),
          CustomTextField(hint: 'Phone', controller: phone, filled: true, fillColor: _card),
          const SizedBox(height: 10),
          CustomTextField(hint: 'WhatsApp', controller: whatsapp, filled: true, fillColor: _card),
          const SizedBox(height: 10),
          CustomTextField(hint: 'Bio', controller: bio, filled: true, fillColor: _card, maxLines: 3),
          const SizedBox(height: 20),
          CustomButton(
            title: 'Save',
            isLoading: busy,
            isGradient: false,
            buttonColor: _gold,
            titleColor: Colors.black,
            borderRadius: 16,
            onTap: busy ? null : _save,
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (name.text.trim().isEmpty) {
      CustomSnackBar.error(message: 'Name is required');
      return;
    }
    setState(() => busy = true);
    try {
      await EventCommerceRepository().saveHost(
        EventHostModel(
          name: name.text.trim(),
          role: role.text.trim(),
          email: email.text.trim(),
          phone: phone.text.trim(),
          whatsapp: whatsapp.text.trim(),
          bio: bio.text.trim(),
        ),
      );
      if (mounted) Get.back(result: true);
    } catch (error) {
      CustomSnackBar.error(
        message: clientErrorMessage(error, 'Could not save host'),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

class OwnerQuotesView extends StatefulWidget {
  const OwnerQuotesView({
    super.key,
    this.eventId,
    this.eventTitle,
  });

  final String? eventId;
  final String? eventTitle;

  @override
  State<OwnerQuotesView> createState() => _OwnerQuotesViewState();
}

class _OwnerQuotesViewState extends State<OwnerQuotesView> {
  final _repo = EventCommerceRepository();
  var _items = <EventQuoteModel>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _repo.ownerQuotes(eventId: widget.eventId);
      final scoped = widget.eventId != null && widget.eventId!.isNotEmpty
          ? items
              .where((q) => q.eventId.isEmpty || q.eventId == widget.eventId)
              .toList()
          : items;

      final eventRepo = EventRepository();
      final eventNames = <String, String>{};
      if (widget.eventTitle != null && widget.eventId != null) {
        eventNames[widget.eventId!] = widget.eventTitle!;
      }
      try {
        final ownEvents = await eventRepo.getOwnEvents(page: 1, limit: 50);
        for (final ev in ownEvents.data) {
          if (ev.id.isNotEmpty && ev.eventName.isNotEmpty) {
            eventNames[ev.id] = ev.eventName;
          }
        }
      } catch (_) {}

      final moduleNames = <String, String>{};
      final eventsToFetch = scoped
          .where(
            (q) =>
                q.moduleName.isEmpty &&
                q.moduleId.isNotEmpty &&
                q.eventId.isNotEmpty,
          )
          .map((q) => q.eventId)
          .toSet();

      for (final eid in eventsToFetch) {
        try {
          final modules = await _repo.ownerModules(eid);
          for (final m in modules) {
            if (m.id.isNotEmpty && m.name.isNotEmpty) {
              moduleNames[m.id] = m.name;
            }
          }
        } catch (_) {}
      }

      final enriched = scoped.map((q) {
        var updated = q;
        if (updated.eventName.isEmpty && eventNames.containsKey(updated.eventId)) {
          updated = updated.copyWith(eventName: eventNames[updated.eventId]);
        }
        if (updated.moduleName.isEmpty &&
            moduleNames.containsKey(updated.moduleId)) {
          updated = updated.copyWith(moduleName: moduleNames[updated.moduleId]);
        }
        return updated;
      }).toList();

      if (mounted) setState(() => _items = enriched);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = clientErrorMessage(error, 'Could not load quotes'),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const CustomText(
          text: 'VIP Quote Requests',
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _gold))
          : _error != null
          ? CompactEmptyState.stacked(
              icon: Icons.error_outline,
              title: 'Could not load quotes',
              message: _error,
            )
          : _items.isEmpty
          ? const CompactEmptyState.stacked(
              icon: Icons.request_quote_outlined,
              title: 'No quotes yet',
              message: 'VIP quote inquiries from customers will appear here.',
            )
          : RefreshIndicator(
              color: _gold,
              backgroundColor: _card,
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                itemCount: _items.length,
                itemBuilder: (_, index) => _buildQuoteCard(_items[index]),
              ),
            ),
    );
  }

  Widget _buildQuoteCard(EventQuoteModel item) {
    final status = item.status.trim().toUpperCase();
    final isNew = status == 'NEW' || status.isEmpty;
    final isReplied = status == 'REPLIED';
    final isClosed = status == 'CLOSED';

    Color statusColor;
    Color statusBgColor;
    String statusLabel;

    if (isReplied) {
      statusColor = const Color(0xFF4CAF50);
      statusBgColor = const Color(0xFF4CAF50).withValues(alpha: 0.15);
      statusLabel = 'REPLIED';
    } else if (isClosed) {
      statusColor = Colors.white54;
      statusBgColor = Colors.white.withValues(alpha: 0.08);
      statusLabel = 'CLOSED';
    } else {
      statusColor = _gold;
      statusBgColor = _gold.withValues(alpha: 0.15);
      statusLabel = 'NEW';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isNew ? _gold.withValues(alpha: 0.35) : Colors.white10,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Avatar, Name, Created time, Status badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF261D0A),
                  shape: BoxShape.circle,
                  border: Border.all(color: _gold.withValues(alpha: 0.5)),
                ),
                alignment: Alignment.center,
                child: CustomText(
                  text: item.name.trim().isNotEmpty
                      ? item.name.trim()[0].toUpperCase()
                      : 'Q',
                  color: _gold,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomText(
                      text: item.name.trim().isNotEmpty ? item.name.trim() : 'Guest',
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      maxLine: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.createdAt != null) ...[
                      const SizedBox(height: 3),
                      CustomText(
                        text: DateFormat('MMM d, yyyy · h:mm a').format(item.createdAt!.toLocal()),
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBgColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                ),
                child: CustomText(
                  text: statusLabel,
                  color: statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (item.eventName.isNotEmpty ||
              item.moduleName.isNotEmpty ||
              widget.eventTitle != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.event_outlined, color: _gold, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: CustomText(
                      text: [
                        if (item.eventName.isNotEmpty)
                          item.eventName
                        else if (widget.eventTitle != null)
                          widget.eventTitle!,
                        if (item.moduleName.isNotEmpty) item.moduleName,
                      ].join(' • '),
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      maxLine: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          const Divider(height: 1, color: Colors.white10),
          const SizedBox(height: 14),

          // Contact details chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (item.guestCount > 0)
                _infoChip(
                  icon: Icons.people_outline_rounded,
                  label: '${item.guestCount} guests',
                  accent: true,
                ),
              if (item.phone.trim().isNotEmpty) ...[
                _infoChip(
                  icon: Icons.phone_outlined,
                  label: item.phone.trim(),
                  onTap: () => _launchUri('tel:${item.phone.trim()}'),
                ),
                _infoChip(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'WhatsApp',
                  accent: true,
                  onTap: () {
                    final cleanPhone = item.phone.replaceAll(RegExp(r'[^0-9]'), '');
                    _launchUri('https://wa.me/$cleanPhone');
                  },
                ),
              ],
              if (item.email.trim().isNotEmpty)
                _infoChip(
                  icon: Icons.mail_outline_rounded,
                  label: item.email.trim(),
                  onTap: () => _launchUri('mailto:${item.email.trim()}'),
                ),
            ],
          ),

          // Message section
          if (item.message.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF101010),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.format_quote_rounded,
                    color: _gold,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: CustomText(
                      text: item.message.trim(),
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Action buttons
          const SizedBox(height: 16),
          if (isNew) ...[
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    title: 'Accept',
                    isGradient: false,
                    buttonColor: _gold,
                    titleColor: Colors.black,
                    paddingVertical: 11,
                    borderRadius: 12,
                    fontSize: 13,
                    onTap: () => _status(item.id, 'REPLIED'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: CustomButton(
                    title: 'Reject',
                    isGradient: false,
                    buttonColor: Colors.transparent,
                    border: Border.all(
                      color: const Color(0xFFE57373),
                    ),
                    titleColor: const Color(0xFFE57373),
                    paddingVertical: 11,
                    borderRadius: 12,
                    fontSize: 13,
                    onTap: () => _status(item.id, 'CLOSED'),
                  ),
                ),
              ],
            ),
          ] else if (isReplied) ...[
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline, color: Color(0xFF4CAF50), size: 16),
                        SizedBox(width: 6),
                        CustomText(
                          text: 'Accepted & Replied',
                          color: Color(0xFF4CAF50),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                CustomButton(
                  title: 'Close Quote',
                  isGradient: false,
                  buttonColor: Colors.transparent,
                  border: Border.all(color: Colors.white24),
                  titleColor: Colors.white70,
                  paddingVertical: 10,
                  width: 120,
                  borderRadius: 12,
                  fontSize: 12,
                  onTap: () => _status(item.id, 'CLOSED'),
                ),
              ],
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.archive_outlined, color: Colors.white38, size: 16),
                  SizedBox(width: 6),
                  CustomText(
                    text: 'This quote request is closed',
                    color: Colors.white38,
                    fontSize: 12,
                  ),
                ],
              ),
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
        color: accent ? _gold.withValues(alpha: 0.12) : const Color(0xFF1E1E1E),
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
            const Icon(Icons.open_in_new_rounded, size: 12, color: Colors.white38),
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

  Future<void> _status(String id, String status) async {
    try {
      await _repo.updateQuoteStatus(id, status);
      final label = status == 'REPLIED' ? 'Quote accepted' : 'Quote closed';
      CustomSnackBar.success(message: label);
      await _load();
    } catch (error) {
      CustomSnackBar.error(
        message: clientErrorMessage(error, 'Could not update quote'),
      );
    }
  }
}
