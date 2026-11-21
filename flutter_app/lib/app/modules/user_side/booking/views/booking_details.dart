import 'dart:io';

import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../club_details_view/views/view_ticket/entry_qr_code_view.dart';

import '../../../../core/utils/custom_snack_bar.dart';

import '../../../../core/resources/common_widget/custom_app_bar.dart'
    show CustomAppBar;
import '../../../../core/resources/common_widget/custom_button.dart';
import '../../../../core/resources/common_widget/custom_text.dart';
import '../../../../core/resources/common_widget/custom_text_field.dart';
import '../../../../core/utils/resource_const.dart';
import '../../explore/widget/club_event_card.dart';
import '../../home/model/club_model.dart';
import '../controllers/booking_controller.dart';
import '../controllers/booking_details_controller.dart';
import '../model/booking_detail_model.dart';

class BookingDetailsView extends StatefulWidget {
  final BookingModel booking;
  final bool showTicket;
  const BookingDetailsView({
    super.key,
    required this.booking,
    this.showTicket = false,
  });

  @override
  State<BookingDetailsView> createState() => _BookingDetailsViewState();
}

class _BookingDetailsViewState extends State<BookingDetailsView> {
  late final BookingDetailsController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.put(
      BookingDetailsController(seed: widget.booking),
      tag: widget.booking.club.id,
    );
  }

  @override
  void dispose() {
    Get.delete<BookingDetailsController>(tag: widget.booking.club.id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: const CustomAppBar(title: 'Booking Details'),
      body: Obx(() {
        if (controller.isLoading.value && controller.detail.value == null) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color(0xFFE1B144),
              strokeWidth: 2,
            ),
          );
        }

        final detail = controller.detail.value;
        final club = detail == null
            ? widget.booking.club
            : _clubFromDetail(detail);
        final status = _status(detail, widget.booking.status);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              if (widget.showTicket) ...[
                _buildDoorQrCard(),
                const SizedBox(height: 20),
              ],
              ClubEventCard(
                club: club,
                isFavoriteBadgeShow: false,
                ratingAsBadge: true,
              ),
              if (_canReview(detail, status)) ...[
                const SizedBox(height: 20),
                _buildReviewCard(),
              ],
              const SizedBox(height: 25),
              _buildSummaryCard('Booking summary', _summaryRows(detail)),
              const SizedBox(height: 20),
              _buildSummaryCard('Price breakdown', _priceRows(detail)),
              if (!widget.showTicket) ...[
                const SizedBox(height: 20),
                _buildDoorQrCard(),
              ],
              if (status == BookingStatus.canceled) ...[
                const SizedBox(height: 28),
                const Center(
                  child: CustomText(
                    text: 'Booking Canceled',
                    color: Colors.red,
                    fontSize: 16,
                  ),
                ),
              ],
            ],
          ),
        );
      }),
    );
  }

  Map<String, String> _summaryRows(BookingDetailModel? detail) {
    if (detail == null) {
      return {
        'Venue': widget.booking.venue,
        'Date': widget.booking.date,
        'Time': widget.booking.time,
      };
    }
    final rows = <String, String>{
      if (detail.location.trim().isNotEmpty) 'Venue': detail.location.trim(),
      'Date': detail.dateLabel,
      'Time': detail.timeLabel,
    };
    if (detail.isEvent) {
      if (detail.tierName.trim().isNotEmpty) {
        rows['Ticket / Tier'] = detail.tierName.trim();
      } else if (detail.packageName.trim().isNotEmpty &&
          detail.packageName.trim() != detail.name.trim()) {
        rows['Ticket / Tier'] = detail.packageName.trim();
      }
      if (detail.guestsLabel != null) {
        rows['Tickets'] = detail.guestsLabel!;
      }
    } else {
      if (detail.packageName.trim().isNotEmpty) {
        rows['Package'] = detail.packageName.trim();
      }
      if (detail.guestsLabel != null) {
        rows['Guests'] = detail.guestsLabel!;
      }
    }
    return rows;
  }

  Map<String, String> _priceRows(BookingDetailModel? detail) {
    if (detail == null) {
      return {
        'Price': widget.booking.price,
        'Total': widget.booking.total,
      };
    }
    return {
      if (detail.grossAmount != null) 'Price': formatEuro(detail.grossAmount!),
      if (detail.serviceCharge != null)
        'Service charge': formatEuro(detail.serviceCharge!),
      if (detail.buyerTotal != null) 'Total': formatEuro(detail.buyerTotal!),
    };
  }

  Widget _buildDoorQrCard() {
    return Obx(() {
      final orderId = controller.doorOrderId;
      if (orderId.isEmpty) return const SizedBox.shrink();
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: _detailCardDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CustomText(
              text: 'Entry QR',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            const SizedBox(height: 16),
            _DoorQrBlock(orderId: orderId),
            const SizedBox(height: 18),
            const Divider(height: 1, color: Color(0x47E1B144)),
            const SizedBox(height: 16),
            Obx(() {
              final ready = controller.detail.value?.ticketReady == true;
              final downloading = controller.isTicketLoading.value;
              return CustomButton(
                title: ready ? 'Download ticket PDF' : 'PDF not ready yet',
                buttonColor: const Color(0xFFE1B144),
                isGradient: false,
                borderRadius: 14,
                paddingVertical: 12,
                isLoading: downloading,
                onTap: !ready || downloading
                    ? null
                    : () async {
                        final bytes = await controller.downloadTicket();
                        final detail = controller.detail.value;
                        if (bytes == null || detail == null) return;
                        await saveTicketToDevice(
                          bytes,
                          'BookdiaNight-${detail.id}.pdf',
                        );
                      },
              );
            }),
          ],
        ),
      );
    });
  }

  Widget _buildSummaryCard(
    String title,
    Map<String, String> items,
  ) {
    final entries = items.entries.toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
      decoration: _detailCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomText(
            text: title,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < entries.length; i++) ...[
            if (entries[i].key == 'Total')
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Divider(
                  height: 1,
                  color: _cardGold.withValues(alpha: 0.28),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  CustomText(
                    text: entries[i].key,
                    color: Colors.white60,
                    fontSize: 13,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CustomText(
                      text: entries[i].value,
                      color: entries[i].key == 'Total' ? _cardGold : Colors.white,
                      textAlign: TextAlign.right,
                      fontWeight: entries[i].key == 'Total'
                          ? FontWeight.w700
                          : FontWeight.w500,
                      fontSize: entries[i].key == 'Total' ? 15 : 13,
                      maxLine: 2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static const _cardGold = Color(0xFFE1B144);

  BoxDecoration get _detailCardDecoration => BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cardGold.withValues(alpha: 0.28)),
      );

  bool _canReview(BookingDetailModel? detail, BookingStatus status) {
    if (controller.reviewed.value) return false;
    if (status != BookingStatus.completed || detail?.hasReview == true) {
      return false;
    }
    final type = (detail?.type ?? widget.booking.club.type).toUpperCase();
    return type == 'CLUB';
  }

  Widget _buildReviewCard() {
    return DecoratedBox(
      decoration: _detailCardDecoration,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _showReviewSheet(),
              child: const Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CustomText(
                          text: 'How was your visit?',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        SizedBox(height: 4),
                        CustomText(
                          text: 'Tap a star to rate this club',
                          fontSize: 13,
                          color: Colors.white60,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFFE1B144),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                for (var i = 0; i < 5; i++)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _showReviewSheet(rating: i + 1),
                    child: const Padding(
                      padding: EdgeInsets.fromLTRB(0, 4, 6, 2),
                      child: Icon(
                        Icons.star_border_rounded,
                        color: Color(0xFFE1B144),
                        size: 32,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  ClubModel _clubFromDetail(BookingDetailModel detail) {
    final amount = detail.buyerTotal ?? detail.grossAmount;
    return ClubModel(
      id: detail.id,
      image: detail.thumbnail,
      title: detail.name,
      location: detail.location,
      rating: detail.rating,
      price: amount == null ? '' : formatEuro(amount),
      type: detail.isEvent ? 'Event' : 'Club',
      latitude: detail.latitude,
      longitude: detail.longitude,
      isVip: detail.isVip,
      tags: detail.isVip ? const ['VIP'] : null,
    );
  }

  BookingStatus _status(BookingDetailModel? detail, BookingStatus fallback) {
    switch (detail?.status) {
      case 'COMPLETED':
        return BookingStatus.completed;
      case 'CANCELED':
      case 'CANCELLED':
        return BookingStatus.canceled;
      case 'UPCOMING':
        return BookingStatus.upcoming;
      default:
        return fallback;
    }
  }

  void _showReviewSheet({int rating = 0}) {
    Get.bottomSheet(
      _WriteReviewSheet(
        initialRating: rating,
        onSubmit: (selected, note) => controller.submitReview(
          rating: selected,
          review: note,
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }
}

class _WriteReviewSheet extends StatefulWidget {
  const _WriteReviewSheet({
    this.initialRating = 0,
    required this.onSubmit,
  });

  final int initialRating;
  final Future<bool> Function(int rating, String review) onSubmit;

  @override
  State<_WriteReviewSheet> createState() => _WriteReviewSheetState();
}

class _WriteReviewSheetState extends State<_WriteReviewSheet> {
  final _comment = TextEditingController();
  var _rating = 0;
  var _needsRating = false;
  var _submitting = false;

  @override
  void initState() {
    super.initState();
    _rating = widget.initialRating.clamp(0, 5);
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    final maxHeight = media.size.height - keyboard - media.padding.top - 12;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: Color(0xFF141414),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: Color(0x47E1B144))),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              16 + (keyboard == 0 ? media.padding.bottom : 0),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 16),
                const CustomText(
                  text: 'Write a review',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                const SizedBox(height: 4),
                const CustomText(
                  text: 'How was your experience?',
                  fontSize: 13,
                  color: Colors.white60,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final selected = index < _rating;
                    return GestureDetector(
                      onTap: () => setState(() {
                        _rating = index + 1;
                        _needsRating = false;
                      }),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 6,
                        ),
                        child: Icon(
                          selected
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: selected
                              ? _BookingDetailsViewState._cardGold
                              : Colors.white38,
                          size: 34,
                        ),
                      ),
                    );
                  }),
                ),
                if (_needsRating)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 6),
                    child: CustomText(
                      text: 'Select a rating',
                      fontSize: 12,
                      color: Color(0xFFE1B144),
                    ),
                  ),
                const SizedBox(height: 8),
                CustomTextField(
                  controller: _comment,
                  hint: 'Share what you liked',
                  maxLines: 3,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  filled: true,
                  fillColor: const Color(0xFF1C1C1C),
                  borderColor: Colors.white24,
                  focusColor: const Color(0xFFE1B144),
                ),
                const SizedBox(height: 16),
                CustomButton(
                  title: 'Submit Review',
                  isLoading: _submitting,
                  onTap: () async {
                    if (_rating == 0) {
                      setState(() => _needsRating = true);
                      return;
                    }
                    if (_submitting) return;
                    setState(() => _submitting = true);
                    final submitted = await widget.onSubmit(
                      _rating,
                      _comment.text.trim(),
                    );
                    if (!mounted) return;
                    if (submitted) {
                      Get.back();
                      return;
                    }
                    setState(() => _submitting = false);
                  },
                ),
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }
}

class _DoorQrBlock extends StatelessWidget {
  const _DoorQrBlock({required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Center(
          child: GestureDetector(
            onTap: () => Get.to(
              () => EntryQrCodeView(orderId: orderId, showHomeButton: false),
            ),
            child: Container(
              height: 168,
              width: 168,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: BarcodeWidget(
                barcode: Barcode.qrCode(),
                data: orderId,
                color: Colors.black,
                drawText: false,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        const CustomText(
          text: 'Scan this code at the door',
          color: Colors.white70,
          fontSize: 13,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

const _filesChannel = MethodChannel('bookdianight/files');
var _savingTicket = false;

Future<void> saveTicketToDevice(Uint8List bytes, String fileName) async {
  if (_savingTicket) return;
  _savingTicket = true;
  try {
    if (!Platform.isAndroid) {
      CustomSnackBar.error(message: 'Saving the ticket is available on Android');
      return;
    }
    if (bytes.isEmpty) {
      CustomSnackBar.error(message: 'Could not save the ticket');
      return;
    }
    final savedName = _downloadFileName(fileName);
    final payload = bytes;
    if (payload.isEmpty) {
      CustomSnackBar.error(message: 'Could not save the ticket');
      return;
    }
    final saved = await _filesChannel.invokeMethod<String>('saveToDownloads', {
      'name': savedName,
      'bytes': payload,
    });
    if (saved == null || saved.isEmpty) {
      CustomSnackBar.error(message: 'Could not save the ticket');
      return;
    }
    debugPrint('Ticket written to $saved');
    CustomSnackBar.success(message: 'Ticket saved to Downloads');
  } catch (error) {
    debugPrint('Ticket save failed: $error');
    CustomSnackBar.error(message: 'Could not save the ticket');
  } finally {
    _savingTicket = false;
  }
}

String _downloadFileName(String fileName) {
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final trimmed = fileName.trim();
  if (trimmed.toLowerCase().endsWith('.pdf')) {
    return trimmed.replaceFirst(
      RegExp(r'\.pdf$', caseSensitive: false),
      '-$stamp.pdf',
    );
  }
  return 'BookdiaNight-ticket-$stamp.pdf';
}
