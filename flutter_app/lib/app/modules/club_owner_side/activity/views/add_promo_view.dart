import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/network/api_expection.dart';
import '../../../../core/resources/common_widget/custom_app_bar.dart';
import '../../../../core/resources/common_widget/custom_button.dart';
import '../../../../core/resources/common_widget/custom_text.dart';
import '../../../../core/resources/common_widget/custom_text_field.dart';
import '../../../../core/utils/custom_snack_bar.dart';
import '../model/club_api_model.dart';
import '../model/event_api_model.dart';
import '../model/promo_api_model.dart';
import '../repository/club_repository.dart';
import '../repository/event_repository.dart';
import '../repository/promo_repository.dart';

class AddPromoView extends StatefulWidget {
  const AddPromoView({super.key, this.existing});

  final PromoDataModel? existing;

  @override
  State<AddPromoView> createState() => _AddPromoViewState();
}

class _AddPromoViewState extends State<AddPromoView> {
  static const _background = Color(0xFF0D0D0D);
  static const _fieldColor = Color(0xFF161616);
  static const _primary = Color(0xFFDCA73A);

  final _code = TextEditingController();
  final _value = TextEditingController();
  final _maxUses = TextEditingController();
  final _promoRepository = PromoRepository();
  final _clubRepository = ClubRepository();
  final _eventRepository = EventRepository();

  String _discountType = 'PERCENTAGE';
  String? _clubId;
  String? _eventId;
  DateTime? _expiresAt;
  bool _isActive = true;
  bool _submitting = false;
  List<ClubDataModel> _clubs = const [];
  List<EventDataModel> _events = const [];

  bool get _isEdit => (widget.existing?.id ?? '').trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _code.text = existing.code;
      _discountType = existing.isPercentage ? 'PERCENTAGE' : 'FIXED_AMOUNT';
      _value.text = existing.discountValue == existing.discountValue.roundToDouble()
          ? existing.discountValue.toInt().toString()
          : existing.discountValue.toString();
      if (existing.maxUses > 0) _maxUses.text = '${existing.maxUses}';
      _clubId = existing.clubId.isEmpty ? null : existing.clubId;
      _eventId = existing.eventId.isEmpty ? null : existing.eventId;
      _expiresAt = existing.expiresAt;
      _isActive = existing.isActive;
    }
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    try {
      final clubs = await _clubRepository.getOwnClubs(limit: 50);
      final events = await _eventRepository.getOwnEvents(limit: 50);
      if (!mounted) return;
      setState(() {
        _clubs = clubs.data;
        _events = events.data;
      });
    } catch (_) {}
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 3650)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: _primary,
            onPrimary: Colors.black,
            surface: _fieldColor,
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;
    setState(() => _expiresAt = DateTime(date.year, date.month, date.day, 23, 59, 59));
  }

  bool get _isPercentage => _discountType == 'PERCENTAGE';

  Future<void> _submit() async {
    final code = _code.text.trim();
    final discountValue = double.tryParse(_value.text.trim()) ?? 0;
    final maxUses = int.tryParse(_maxUses.text.trim()) ?? 0;
    if (code.isEmpty) {
      CustomSnackBar.error(message: 'Enter a promo code');
      return;
    }
    if (discountValue <= 0) {
      CustomSnackBar.error(
        message: _isPercentage
            ? 'Enter a percentage between 1 and 100'
            : 'Enter a fixed euro amount greater than 0',
      );
      return;
    }
    if (_isPercentage && discountValue > 100) {
      CustomSnackBar.error(message: 'Percentage cannot be more than 100');
      return;
    }
    if (maxUses <= 0) {
      CustomSnackBar.error(message: 'Max uses is required');
      return;
    }
    setState(() => _submitting = true);
    try {
      final promo = _isEdit
          ? await _promoRepository.updatePromo(
              id: widget.existing!.id,
              code: code,
              discountType: _discountType,
              discountValue: discountValue,
              maxUses: maxUses,
              clubId: _clubId,
              eventId: _eventId,
              expiresAt: _expiresAt,
              isActive: _isActive,
            )
          : await _promoRepository.createPromo(
              code: code,
              discountType: _discountType,
              discountValue: discountValue,
              maxUses: maxUses,
              clubId: _clubId,
              eventId: _eventId,
              expiresAt: _expiresAt,
            );
      CustomSnackBar.success(
        message: _isEdit ? 'Promo code updated' : 'Promo code created',
      );
      if (!mounted) return;
      Get.back(
        result: PromoDataModel(
          id: promo.id.isNotEmpty ? promo.id : (widget.existing?.id ?? ''),
          code: promo.code.isNotEmpty ? promo.code : code.toUpperCase(),
          discountType: promo.discountType.isNotEmpty
              ? promo.discountType
              : _discountType,
          discountValue: promo.discountValue > 0
              ? promo.discountValue
              : discountValue,
          maxUses: promo.maxUses > 0 ? promo.maxUses : maxUses,
          usedCount: promo.usedCount,
          clubId: promo.clubId.isNotEmpty ? promo.clubId : (_clubId ?? ''),
          eventId: promo.eventId.isNotEmpty ? promo.eventId : (_eventId ?? ''),
          clubName: promo.clubName.isNotEmpty
              ? promo.clubName
              : (_selectedClubName ?? ''),
          eventName: promo.eventName.isNotEmpty
              ? promo.eventName
              : (_selectedEventName ?? ''),
          expiresAt: promo.expiresAt ?? _expiresAt,
          isActive: promo.isActive,
        ),
      );
    } catch (error) {
      CustomSnackBar.error(
        message: clientErrorMessage(
          error,
          error
              .toString()
              .replaceFirst('Bad state: ', '')
              .replaceFirst('Exception: ', ''),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String? get _selectedClubName {
    for (final club in _clubs) {
      if (club.id == _clubId) return club.name;
    }
    return null;
  }

  String? get _selectedEventName {
    for (final event in _events) {
      if (event.id == _eventId) return event.eventName;
    }
    return null;
  }

  @override
  void dispose() {
    _code.dispose();
    _value.dispose();
    _maxUses.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: CustomAppBar(
        title: _isEdit ? 'Edit Promo Code' : 'Create Promo Code',
        backgroundColor: _background,
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: SizedBox(
            height: 52,
            child: CustomButton(
              title: _isEdit ? 'Save changes' : 'Create Promo',
              isLoading: _submitting,
              buttonColor: _primary,
              isGradient: false,
              borderRadius: 16,
              paddingVertical: 0,
              titleColor: Colors.black,
              onTap: _submit,
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CustomTextField(
              controller: _code,
              label: 'Code',
              hint: 'HALLOWEEN25',
              labelColor: Colors.white,
              filled: true,
              fillColor: _fieldColor,
              isBorder: false,
            ),
            const SizedBox(height: 14),
            const CustomText(
              text: 'Discount type',
              fontSize: 13,
              color: Colors.white70,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _typeChip('PERCENTAGE', 'Percentage'),
                const SizedBox(width: 10),
                _typeChip('FIXED_AMOUNT', 'Fixed amount'),
              ],
            ),
            const SizedBox(height: 8),
            CustomText(
              text: _isPercentage
                  ? 'Percentage: 20 means 20% off the ticket price.'
                  : 'Fixed amount: 10 means €10 off the ticket price.',
              fontSize: 12,
              color: Colors.white54,
            ),
            const SizedBox(height: 14),
            CustomTextField(
              controller: _value,
              label: _isPercentage ? 'Discount %' : 'Discount amount (€)',
              hint: _isPercentage ? '20' : '10',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              labelColor: Colors.white,
              filled: true,
              fillColor: _fieldColor,
              isBorder: false,
              prefixIcon: Icon(
                _isPercentage ? Icons.percent : Icons.euro,
                color: Colors.white38,
                size: 18,
              ),
            ),
            const SizedBox(height: 14),
            CustomTextField(
              controller: _maxUses,
              label: 'Max uses',
              hint: '100',
              keyboardType: TextInputType.number,
              labelColor: Colors.white,
              filled: true,
              fillColor: _fieldColor,
              isBorder: false,
            ),
            const SizedBox(height: 14),
            _optionTile(
              label: 'Expires',
              value: _expiresAt == null
                  ? 'No expiry'
                  : '${_expiresAt!.day}/${_expiresAt!.month}/${_expiresAt!.year}',
              onTap: _pickExpiry,
              onClear: _expiresAt == null
                  ? null
                  : () => setState(() => _expiresAt = null),
            ),
            if (_isEdit) ...[
              const SizedBox(height: 14),
              _optionTile(
                label: 'Active',
                value: _isActive ? 'Yes' : 'No',
                onTap: () => setState(() => _isActive = !_isActive),
              ),
            ],
            const SizedBox(height: 18),
            const CustomText(
              text: 'Limit to club (optional)',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
            const SizedBox(height: 8),
            ..._clubs.map(
              (club) => _selectTile(
                title: club.name,
                selected: _clubId == club.id,
                onTap: () => setState(
                  () => _clubId = _clubId == club.id ? null : club.id,
                ),
              ),
            ),
            const SizedBox(height: 18),
            const CustomText(
              text: 'Limit to event (optional)',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
            const SizedBox(height: 8),
            ..._events.map(
              (event) => _selectTile(
                title: event.eventName,
                selected: _eventId == event.id,
                onTap: () => setState(
                  () => _eventId = _eventId == event.id ? null : event.id,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeChip(String value, String label) {
    final selected = _discountType == value;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _discountType = value),
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF261D0A) : _fieldColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? _primary : Colors.transparent,
              ),
            ),
            child: Center(
              child: CustomText(
                text: label,
                color: selected ? _primary : Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _optionTile({
    required String label,
    required String value,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: _fieldColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: CustomText(text: label, color: Colors.white54, fontSize: 13),
            ),
            CustomText(text: value, color: Colors.white, fontSize: 13),
            if (onClear != null) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.close_rounded, color: Colors.white38, size: 18),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _selectTile({
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _fieldColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? _primary : Colors.transparent),
          ),
          child: Row(
            children: [
              Expanded(
                child: CustomText(text: title, color: Colors.white, fontSize: 14),
              ),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? _primary : Colors.white38,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
