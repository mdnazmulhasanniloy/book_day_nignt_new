import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/network/api_expection.dart';
import '../../../../core/resources/common_widget/custom_button.dart';
import '../../../../core/resources/common_widget/custom_text.dart';
import '../repository/ticket_scanner_repository.dart';

class TicketScannerView extends StatefulWidget {
  const TicketScannerView({super.key});

  @override
  State<TicketScannerView> createState() => _TicketScannerViewState();
}

class _TicketScannerViewState extends State<TicketScannerView>
    with SingleTickerProviderStateMixin {
  static const _gold = Color(0xFFE1B144);
  static const _frameSize = 260.0;

  final _repository = TicketScannerRepository();
  final _scanner = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );
  late final AnimationController _lineController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  bool _isVerifying = false;

  @override
  void dispose() {
    _lineController.dispose();
    _scanner.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isVerifying) return;
    final raw = capture.barcodes
        .map((barcode) => barcode.rawValue)
        .firstWhere(
          (value) => value != null && value.trim().isNotEmpty,
          orElse: () => null,
        );
    if (raw == null) return;

    setState(() => _isVerifying = true);
    HapticFeedback.mediumImpact();
    await _scanner.pause();

    final orderId = TicketScannerRepository.extractOrderId(raw);
    TicketVerification? result;
    String? error;
    try {
      result = await _repository.verifyTicket(orderId);
    } on ApiException catch (e) {
      error = e.message;
    } on FormatException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Could not verify this ticket. Please try again.';
    }

    if (!mounted) return;
    setState(() => _isVerifying = false);
    await _showResult(result: result, error: error);
    if (!mounted) return;
    await _scanner.start();
  }

  Future<void> _showResult({TicketVerification? result, String? error}) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF161616),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _VerificationResultSheet(result: result, error: error),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _scanner,
            onDetect: _onDetect,
            errorBuilder: (context, error) => _CameraError(error: error),
          ),
          const _ScannerOverlay(frameSize: _frameSize),
          Center(
            child: SizedBox(
              width: _frameSize,
              height: _frameSize,
              child: _isVerifying
                  ? const Center(
                      child: CircularProgressIndicator(color: _gold),
                    )
                  : AnimatedBuilder(
                      animation: _lineController,
                      builder: (_, _) => Align(
                        alignment: Alignment(0, _lineController.value * 2 - 1),
                        child: Container(
                          height: 2,
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: _gold,
                            boxShadow: [
                              BoxShadow(
                                color: _gold.withValues(alpha: 0.6),
                                blurRadius: 12,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      _CircleIconButton(
                        icon: Icons.close_rounded,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      const Expanded(
                        child: CustomText(
                          text: 'Scan Ticket',
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      ValueListenableBuilder<MobileScannerState>(
                        valueListenable: _scanner,
                        builder: (_, state, _) {
                          final torchOn = state.torchState == TorchState.on;
                          return _CircleIconButton(
                            icon: torchOn
                                ? Icons.flash_on_rounded
                                : Icons.flash_off_rounded,
                            active: torchOn,
                            onTap: state.torchState == TorchState.unavailable
                                ? null
                                : _scanner.toggleTorch,
                          );
                        },
                      ),
                    ],
                  ),
                  const Spacer(),
                  CustomText(
                    text: _isVerifying
                        ? 'Verifying ticket...'
                        : 'Align the ticket QR code inside the frame',
                    fontSize: 14,
                    color: Colors.white70,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerOverlay extends StatelessWidget {
  const _ScannerOverlay({required this.frameSize});

  final double frameSize;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(painter: _ScannerOverlayPainter(frameSize)),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  _ScannerOverlayPainter(this.frameSize);

  final double frameSize;

  static const _radius = 24.0;
  static const _cornerLength = 36.0;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: frameSize,
      height: frameSize,
    );
    final frameRRect = RRect.fromRectAndRadius(
      frame,
      const Radius.circular(_radius),
    );

    final dimPath = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(frameRRect);
    canvas.drawPath(
      dimPath,
      Paint()..color = Colors.black.withValues(alpha: 0.6),
    );

    final cornerPaint = Paint()
      ..color = const Color(0xFFE1B144)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final l = frame.left, t = frame.top, r = frame.right, b = frame.bottom;
    const c = _cornerLength, rad = _radius;
    final corners = Path()
      ..moveTo(l, t + c)
      ..lineTo(l, t + rad)
      ..arcToPoint(Offset(l + rad, t), radius: const Radius.circular(rad))
      ..lineTo(l + c, t)
      ..moveTo(r - c, t)
      ..lineTo(r - rad, t)
      ..arcToPoint(Offset(r, t + rad), radius: const Radius.circular(rad))
      ..lineTo(r, t + c)
      ..moveTo(r, b - c)
      ..lineTo(r, b - rad)
      ..arcToPoint(Offset(r - rad, b), radius: const Radius.circular(rad))
      ..lineTo(r - c, b)
      ..moveTo(l + c, b)
      ..lineTo(l + rad, b)
      ..arcToPoint(Offset(l, b - rad), radius: const Radius.circular(rad))
      ..lineTo(l, b - c);
    canvas.drawPath(corners, cornerPaint);
  }

  @override
  bool shouldRepaint(_ScannerOverlayPainter oldDelegate) =>
      oldDelegate.frameSize != frameSize;
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active
          ? const Color(0xFFE1B144)
          : Colors.white.withValues(alpha: 0.12),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            icon,
            color: active ? Colors.black : Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.no_photography_outlined,
                color: Color(0xFFE1B144),
                size: 44,
              ),
              const SizedBox(height: 12),
              CustomText(
                text: denied
                    ? 'Camera access is off. Allow camera access in Settings to scan tickets.'
                    : 'Camera could not be started. Please try again.',
                fontSize: 14,
                color: Colors.white70,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VerificationResultSheet extends StatelessWidget {
  const _VerificationResultSheet({this.result, this.error});

  final TicketVerification? result;
  final String? error;

  static const _gold = Color(0xFFE1B144);
  static const _green = Color(0xFF34C759);
  static const _red = Color(0xFFFF453A);

  String _humanize(String key) {
    final spaced = key.replaceAllMapped(
      RegExp(r'(?<=[a-z0-9])([A-Z])'),
      (m) => ' ${m.group(1)}',
    );
    return spaced[0].toUpperCase() + spaced.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final success = result != null;
    final accent = success ? _green : _red;
    final rows = <MapEntry<String, String>>[
      if (success) ...[
        if (result!.orderId.isNotEmpty) MapEntry('Order ID', result!.orderId),
        if (result!.status != null) MapEntry('Status', result!.status!),
        if (result!.checkedInAt != null)
          MapEntry(
            'Checked in',
            DateFormat('dd MMM yyyy, hh:mm a').format(result!.checkedInAt!),
          ),
        for (final entry in result!.details.entries)
          MapEntry(_humanize(entry.key), entry.value),
      ],
    ];

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                success ? Icons.check_rounded : Icons.close_rounded,
                color: accent,
                size: 36,
              ),
            ),
            const SizedBox(height: 14),
            CustomText(
              text: success ? 'Ticket verified' : 'Verification failed',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            CustomText(
              text: success
                  ? (result!.buyerName?.isNotEmpty == true
                        ? result!.buyerName!
                        : result!.message)
                  : (error ?? 'Could not verify this ticket.'),
              fontSize: 14,
              color: Colors.white70,
              textAlign: TextAlign.center,
              maxLine: 3,
            ),
            if (rows.isNotEmpty) ...[
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F1F1F),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    for (final row in rows)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: CustomText(
                                text: row.key,
                                fontSize: 13,
                                color: Colors.white54,
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: CustomText(
                                text: row.value,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                                textAlign: TextAlign.right,
                                maxLine: 2,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            CustomButton(
              title: 'Scan next ticket',
              buttonColor: _gold,
              titleColor: Colors.black,
              isGradient: false,
              borderRadius: 14,
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
