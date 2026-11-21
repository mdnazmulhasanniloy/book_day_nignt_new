import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../core/resources/common_widget/custom_button.dart';
import '../../../../../core/resources/common_widget/custom_text.dart';
import '../../controllers/buy_ticker_controller.dart';

Future<void> showClubIntervalSheet({
  required BuildContext context,
  required BuyTickerController controller,
  required bool isStart,
  bool openOnTime = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => ClubIntervalSheet(
      controller: controller,
      isStart: isStart,
      openOnTime: openOnTime,
    ),
  );
}

class ClubIntervalSheet extends StatefulWidget {
  const ClubIntervalSheet({
    super.key,
    required this.controller,
    required this.isStart,
    required this.openOnTime,
  });

  final BuyTickerController controller;
  final bool isStart;
  final bool openOnTime;

  @override
  State<ClubIntervalSheet> createState() => _ClubIntervalSheetState();
}

class _ClubIntervalSheetState extends State<ClubIntervalSheet> {
  static const Color cardBg = Color(0xFF161616);
  static const Color gold = Color(0xFFDCA73A);

  late DateTime _focused;
  DateTime? _date;
  int? _hour12;
  int? _minute;
  bool? _isPm;
  late int _step;
  String? _sheetMessage;

  @override
  void initState() {
    super.initState();
    final source = widget.isStart
        ? widget.controller.clubStart.value
        : widget.controller.clubEnd.value;
    if (source == null ||
        widget.controller.isClubClosedOn(source, forEnd: !widget.isStart)) {
      _date = null;
      _focused = widget.controller.todayCst;
      _hour12 = null;
      _minute = null;
      _isPm = null;
      _step = 0;
    } else {
      _date = DateTime(source.year, source.month, source.day);
      _focused = _date!;
      _isPm = source.hour >= 12;
      _hour12 = source.hour % 12 == 0 ? 12 : source.hour % 12;
      _minute = _minuteNearest(source.minute);
      _step = widget.openOnTime ? 1 : 0;
    }
  }

  int _minuteNearest(int minute) => ((minute / 15).round() * 15) % 60;

  int get _hour24 {
    final hour12 = _hour12 ?? 12;
    final isPm = _isPm ?? false;
    if (hour12 == 12) return isPm ? 12 : 0;
    return isPm ? hour12 + 12 : hour12;
  }

  DateTime? get _draft {
    final date = _date;
    if (date == null || _hour12 == null || _minute == null || _isPm == null) {
      return null;
    }
    return DateTime(date.year, date.month, date.day, _hour24, _minute!);
  }

  void _showSheetMessage(String message) {
    setState(() => _sheetMessage = message);
  }

  void _save() {
    final draft = _draft;
    if (draft == null) {
      _showSheetMessage('Select a time.');
      return;
    }
    final controller = widget.controller;
    if (controller.isClubClosedOn(draft, forEnd: !widget.isStart)) {
      _showSheetMessage(
        'The club is closed on ${controller.weekdayName(draft)}.',
      );
      return;
    }
    if (widget.isStart) {
      if (!draft.isAfter(controller.nowCst)) {
        _showSheetMessage('Choose a later time.');
        return;
      }
      if (!controller.isTimeWithinOpeningHours(draft)) {
        final window = controller.openingWindowLabel(draft);
        _showSheetMessage(
          window.isEmpty
              ? 'Pick a time while the club is open.'
              : 'Pick a time while the club is open ($window).',
        );
        return;
      }
      controller.setClubStart(draft);
    } else {
      final start = controller.clubStart.value;
      if (start == null) {
        _showSheetMessage('Select a start date and time first.');
        return;
      }
      if (!draft.isAfter(start)) {
        _showSheetMessage('End time must be after the start time.');
        return;
      }
      if (!controller.isTimeWithinOpeningHours(draft)) {
        final window = controller.openingWindowLabel(draft);
        _showSheetMessage(
          window.isEmpty
              ? 'Pick a time while the club is open.'
              : 'Pick a time while the club is open ($window).',
        );
        return;
      }
      controller.setClubEnd(draft);
    }
    Navigator.of(context).pop();
  }

  DateTime get _firstVisibleDay {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (widget.isStart) return today;
    final start = widget.controller.clubStart.value;
    if (start == null) return today;
    final startDay = DateTime(start.year, start.month, start.day);
    return startDay.isAfter(today) ? startDay : today;
  }

  bool _isDisabledDay(DateTime day) {
    final date = DateTime(day.year, day.month, day.day);
    if (date.isBefore(_firstVisibleDay)) return true;
    return widget.controller.isClubClosedOn(date, forEnd: !widget.isStart);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isStart ? 'Starts' : 'Ends';
    final stepTitle = _step == 0 ? 'Choose date' : 'Choose time';

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.82,
      decoration: const BoxDecoration(
        color: Color(0xFF0D0D0D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
            child: Row(
              children: [
                if (_step == 1)
                  IconButton(
                    onPressed: () => setState(() => _step = 0),
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      color: Colors.white,
                      size: 18,
                    ),
                  )
                else
                  const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomText(
                        text: title,
                        fontSize: 13,
                        color: gold,
                        fontWeight: FontWeight.w600,
                      ),
                      const SizedBox(height: 2),
                      CustomText(
                        text: stepTitle,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _stepDots(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: _step == 0 ? _dateStep() : _timeStep(),
            ),
          ),
          if (_sheetMessage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: CustomText(
                text: _sheetMessage!,
                fontSize: 12,
                color: const Color(0xFFFF6B6B),
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: CustomButton(
                title: _step == 0 ? 'Choose time' : 'Save',
                buttonColor: gold,
                titleColor: Colors.black,
                isGradient: false,
                borderRadius: 16,
                paddingVertical: 14,
                onTap: () {
                  if (_step == 0) {
                    if (_date == null) {
                      _showSheetMessage('Select a date.');
                      return;
                    }
                    if (widget.controller.isClubClosedOn(
                      _date!,
                      forEnd: !widget.isStart,
                    )) {
                      _showSheetMessage(
                        'The club is closed on ${widget.controller.weekdayName(_date!)}.',
                      );
                      return;
                    }
                    setState(() {
                      _sheetMessage = null;
                      _step = 1;
                    });
                    return;
                  }
                  _save();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _dot(active: _step == 0, label: 'Date'),
        Container(width: 28, height: 1, color: Colors.white24),
        _dot(active: _step == 1, label: 'Time'),
      ],
    );
  }

  Widget _dot({required bool active, required String label}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: active ? gold : Colors.white24,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          CustomText(
            text: label,
            fontSize: 12,
            color: active ? Colors.white : Colors.white38,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          ),
        ],
      ),
    );
  }

  Widget _dateStep() {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final daysInMonth = DateTime(_focused.year, _focused.month + 1, 0).day;
    final firstWeekday = DateTime(_focused.year, _focused.month, 1).weekday;
    final leading = firstWeekday - 1;
    final daysInPrev = DateTime(_focused.year, _focused.month, 0).day;
    final total = leading + daysInMonth;
    final today = _firstVisibleDay;
    final prevMonth = DateTime(_focused.year, _focused.month - 1, 1);
    final canGoBack = prevMonth.year > today.year ||
        (prevMonth.year == today.year && prevMonth.month >= today.month);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: canGoBack
                    ? () => setState(() {
                          _focused = DateTime(
                            _focused.year,
                            _focused.month - 1,
                            1,
                          );
                        })
                    : null,
                icon: Icon(
                  Icons.arrow_back_ios_new,
                  color: canGoBack ? Colors.white70 : Colors.white24,
                  size: 16,
                ),
              ),
              CustomText(
                text: DateFormat('MMMM yyyy').format(_focused),
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              IconButton(
                onPressed: () => setState(() {
                  _focused = DateTime(_focused.year, _focused.month + 1, 1);
                }),
                icon: const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white70,
                  size: 16,
                ),
              ),
            ],
          ),
          Row(
            children: [
              for (var i = 0; i < days.length; i++)
                Expanded(
                  child: Center(
                    child: CustomText(
                      text: days[i],
                      fontSize: 12,
                      color: widget.controller.isWeekdayAlwaysClosed(i + 1)
                          ? Colors.white24
                          : Colors.grey,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: total,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 6,
            ),
            itemBuilder: (context, index) {
              if (index < leading) {
                final prevDay = daysInPrev - (leading - 1 - index);
                return Center(
                  child: CustomText(
                    text: '$prevDay',
                    color: Colors.white24,
                  ),
                );
              }
              final dayNum = index - leading + 1;
              final current = DateTime(_focused.year, _focused.month, dayNum);
              final selected = _date != null &&
                  widget.controller.isSameDay(current, _date!);
              final past = current.isBefore(_firstVisibleDay);
              final closed = widget.controller.isClubClosedOn(
                current,
                forEnd: !widget.isStart,
              );
              final disabled = _isDisabledDay(current);
              return GestureDetector(
                onTap: disabled
                    ? () {
                        if (closed && !past) {
                          _showSheetMessage(
                            'Closed on ${widget.controller.weekdayName(current)}.',
                          );
                        }
                      }
                    : () => setState(() {
                          _date = current;
                          _sheetMessage = null;
                        }),
                child: Container(
                  decoration: BoxDecoration(
                    color: selected ? gold : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: CustomText(
                    text: '$dayNum',
                    color: selected
                        ? Colors.black
                        : (disabled ? Colors.white24 : Colors.white),
                    fontWeight:
                        selected ? FontWeight.bold : FontWeight.normal,
                    decoration: closed && !selected
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                    decorationColor: Colors.white24,
                    decorationThickness: 1.5,
                  ),
                ),
              );
            },
          ),
          if (widget.controller.closedWeekdayNames.isNotEmpty) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: CustomText(
                text:
                    'Closed: ${widget.controller.closedWeekdayNames.join(', ')}. Those days can’t be booked.',
                fontSize: 11,
                color: Colors.white38,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _timeStep() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 22),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              CustomText(
                text: _date == null
                    ? 'Select date'
                    : DateFormat('EEE, MMM d, yyyy').format(_date!),
                fontSize: 13,
                color: Colors.white54,
              ),
              if (_date != null &&
                  widget.controller.openingWindowLabel(_date!).isNotEmpty) ...[
                const SizedBox(height: 6),
                CustomText(
                  text:
                      'Open ${widget.controller.openingWindowLabel(_date!)}',
                  fontSize: 12,
                  color: gold,
                ),
              ],
              const SizedBox(height: 8),
              CustomText(
                text: (_hour12 == null || _minute == null || _isPm == null)
                    ? 'Select time'
                    : '$_hour12:${_minute!.toString().padLeft(2, '0')} ${_isPm! ? 'PM' : 'AM'}',
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: (_hour12 == null || _minute == null || _isPm == null)
                    ? Colors.white38
                    : Colors.white,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _pickerLabel('Hour'),
        const SizedBox(height: 8),
        _optionGrid(
          labels: List.generate(12, (index) => '${index + 1}'),
          selectedIndex: _hour12 == null ? -1 : _hour12! - 1,
          columns: 6,
          onTap: (index) => setState(() {
            _hour12 = index + 1;
            _minute ??= 0;
            _sheetMessage = null;
          }),
        ),
        const SizedBox(height: 16),
        _pickerLabel('Minute'),
        const SizedBox(height: 8),
        _optionGrid(
          labels: const ['00', '15', '30', '45'],
          selectedIndex: const [0, 15, 30, 45].indexOf(_minute ?? -1),
          columns: 4,
          onTap: (index) => setState(() {
            _minute = index * 15;
            _sheetMessage = null;
          }),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              _periodButton(
                'AM',
                _isPm == false,
                () => setState(() {
                  _isPm = false;
                  _sheetMessage = null;
                }),
              ),
              _periodButton(
                'PM',
                _isPm == true,
                () => setState(() {
                  _isPm = true;
                  _sheetMessage = null;
                }),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _pickerLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: CustomText(
        text: text,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.white70,
      ),
    );
  }

  Widget _optionGrid({
    required List<String> labels,
    required int selectedIndex,
    required int columns,
    required ValueChanged<int> onTap,
  }) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: labels.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        mainAxisExtent: 42,
      ),
      itemBuilder: (context, index) {
        final isSelected = index == selectedIndex;
        return GestureDetector(
          onTap: () => onTap(index),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? gold : cardBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: CustomText(
              text: labels[index],
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.black : Colors.white,
            ),
          ),
        );
      },
    );
  }

  Widget _periodButton(String label, bool selected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? gold : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.center,
          child: CustomText(
            text: label,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: selected ? Colors.black : Colors.white,
          ),
        ),
      ),
    );
  }
}
