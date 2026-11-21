import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../../core/auth/account_gate.dart';
import '../../../../core/explore/repository/discovery_repository.dart';
import '../../../../core/local_storage/local_storage.dart';
import '../../../../core/network/api_expection.dart';
import '../../../../core/resources/common_widget/compact_empty_state.dart';
import '../../../../core/resources/common_widget/custom_network_image.dart';
import '../../../../core/utils/custom_snack_bar.dart';
import '../views/club_details_view.dart';
import '../views/view_ticket/select_date_time_view.dart';
import 'club_community_section.dart';

/// A club-wide queue: the API does not reserve a particular time or table.
class WaitingListPanel extends StatefulWidget {
  const WaitingListPanel({
    super.key,
    required this.clubId,
    this.canJoin = false,
    this.targetSlot,
    this.guestCount,
    this.startAt,
    this.repository,
    this.onChanged,
  });
  final String clubId;
  final bool canJoin;
  final String? targetSlot;
  final int? guestCount;
  final dynamic startAt;
  final DiscoveryRepository? repository;
  final VoidCallback? onChanged;
  @override
  State<WaitingListPanel> createState() => _WaitingListPanelState();
}

class _WaitingListPanelState extends State<WaitingListPanel> {
  late final _repository = widget.repository ?? DiscoveryRepository();
  Map<String, dynamic>? _status;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    if (!AccountGate.isSignedIn) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = DiscoveryRepository.data(
        await _repository.get(
          '/waiting-list/club/${Uri.encodeComponent(widget.clubId)}/status',
        ),
      );
      if (mounted) setState(() => _status = result);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = clientErrorMessage(
            error,
            'Could not load waiting status',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String get _savedSlot {
    final entry = _status?['entry'];
    final entryStart = entry is Map ? entry['startAt']?.toString() : null;
    final entryGuests = entry is Map ? entry['guestCount'] : null;

    final target = widget.targetSlot?.trim();
    if (target != null && target.isNotEmpty) {
      final guests = widget.guestCount != null && widget.guestCount! > 0
          ? ' · ${widget.guestCount} guests'
          : '';
      return '$target$guests';
    }

    if (entryStart != null && entryStart.isNotEmpty) {
      final dt = DateTime.tryParse(entryStart);
      if (dt != null) {
        final g = int.tryParse('$entryGuests');
        final guests = g != null && g > 0 ? ' · $g guests' : '';
        return '${DateFormat('EEE, MMM d · h:mm a').format(dt.toLocal())}$guests';
      }
    }

    return LocalStorage.getData(key: 'waiting_slot_${widget.clubId}')
            ?.toString() ??
        '';
  }

  Future<void> _change() async {
    if (_busy || !await AccountGate.ensure() || !mounted) return;
    await _load();
    if (!mounted || _error != null || _status == null) return;
    final waiting = _status!['isWaiting'] == true;
    if (!waiting && !widget.canJoin) return;
    setState(() => _busy = true);
    try {
      String? startIso;
      if (widget.startAt is DateTime) {
        startIso = (widget.startAt as DateTime).toUtc().toIso8601String();
      } else if (widget.startAt != null) {
        final s = widget.startAt.toString().trim();
        if (s.isNotEmpty) startIso = s;
      }

      final payload = waiting
          ? {'clubId': widget.clubId}
          : <String, dynamic>{
              'clubId': widget.clubId,
              if (startIso != null && startIso.isNotEmpty) 'startAt': startIso,
              if (widget.guestCount != null && widget.guestCount! > 0)
                'guestCount': widget.guestCount,
            };

      final body = await _repository.post(
        '/waiting-list/${waiting ? 'leave' : 'join'}',
        payload,
      );
      if (!waiting) {
        final slotToSave = _savedSlot;
        if (slotToSave.isNotEmpty) {
          LocalStorage.saveData(
            key: 'waiting_slot_${widget.clubId}',
            data: slotToSave,
          );
        }
        final data = DiscoveryRepository.data(body);
        if (mounted && data['position'] != null) {
          setState(() {
            _status = {
              'isWaiting': true,
              'position': data['position'],
              'entry': data,
            };
            _error = null;
          });
        }
      } else {
        LocalStorage.removeData(key: 'waiting_slot_${widget.clubId}');
      }
      await _load();
      if (mounted) widget.onChanged?.call();
    } catch (error) {
      CustomSnackBar.error(
        message: clientErrorMessage(
          error,
          'Could not update waiting list. Please try again.',
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final waiting = _status?['isWaiting'] == true;
    if (!widget.canJoin && !waiting && _error == null) {
      return const SizedBox.shrink();
    }
    final entry = _status?['entry'];
    final notified = entry is Map && entry['status'] == 'NOTIFIED';
    final position = _status?['position'];
    final slotText = _savedSlot;
    final title = notified
        ? 'Table Available! Alert Received'
        : waiting
        ? 'You’re on the standby list${position == null ? '' : ' · #$position'}'
        : 'No tables available for this selection';
    final action = _busy
        ? 'Updating…'
        : _error != null
        ? '$_error · Retry'
        : waiting
        ? 'Leave waiting list'
        : 'Join waiting list';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: discoveryGold.withValues(alpha: notified ? .5 : .28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF261D0A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  notified
                      ? Icons.notifications_active_rounded
                      : waiting
                      ? Icons.hourglass_top_rounded
                      : Icons.event_seat_outlined,
                  color: discoveryGold,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: discoveryGold,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          if (slotText.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.schedule, size: 14, color: discoveryGold),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Requested: $slotText',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                      maxLines: 3,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            notified
                ? 'A table has just become available at this club! Tables sell out fast on a first-come, first-served basis. Tap below to reserve your table now.'
                : waiting
                ? 'You are in the standby queue. When a table opens up, the venue will notify you so you can complete your booking. Notice: This standby alert does not hold an automatic reservation for your requested time.'
                : 'Get notified when any table frees up at this venue. Notice: Joining alerts you to book online on a first-come basis; it does not reserve a specific table or guarantee your selected time.',
            style: const TextStyle(color: Colors.white60, fontSize: 13, height: 1.4),
          ),
          if (notified) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  final club = discoveryClub({'id': widget.clubId}, type: 'Club');
                  Get.to(() => SelectDateTimeView(clubModel: club));
                },
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('Book Open Table Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: discoveryGold,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  textStyle: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _busy
                  ? null
                  : _error != null
                  ? _load
                  : _change,
              style: OutlinedButton.styleFrom(
                foregroundColor: discoveryGold,
                disabledForegroundColor: discoveryGold.withValues(alpha: .5),
                side: BorderSide(color: discoveryGold.withValues(alpha: .55)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(
                action,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MyWaitingListsView extends StatefulWidget {
  const MyWaitingListsView({super.key});
  @override
  State<MyWaitingListsView> createState() => _MyWaitingListsViewState();
}

class _MyWaitingListsViewState extends State<MyWaitingListsView> {
  final _repository = DiscoveryRepository();
  final _rows = <Map<String, dynamic>>[];
  bool _busy = false, _more = true;
  String? _error;
  int _page = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    if (!mounted) return;
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final next = refresh ? 1 : _page + 1;
    try {
      final body = await _repository.get(
        '/waiting-list/my',
        params: {'page': next, 'limit': 20},
      );
      final rows = DiscoveryRepository.items(body['data']);
      final meta = body['meta'] is Map ? body['meta'] as Map : {};
      if (mounted) {
        setState(() {
          if (refresh) _rows.clear();
          _rows.addAll(rows);
          _page = next;
          _more =
              rows.isNotEmpty &&
              next < (int.tryParse('${meta['totalPages']}') ?? next);
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = clientErrorMessage(
            error,
            'Could not load waiting lists',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0D0D0D),
    appBar: AppBar(
      title: const Text(
        'My waiting lists',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      centerTitle: true,
      iconTheme: const IconThemeData(color: Colors.white),
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      leading: IconButton(
        tooltip: 'Back',
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: Colors.white,
          size: 20,
        ),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      backgroundColor: const Color(0xFF0D0D0D),
      foregroundColor: Colors.white,
    ),
    body: RefreshIndicator(
      onRefresh: () => _load(refresh: true),
      color: discoveryGold,
      child: ListView(
        padding: const EdgeInsets.all(20),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (!_busy && _rows.isEmpty && _error == null)
            const CompactEmptyState.stacked(
              icon: Icons.hourglass_empty_rounded,
              title: 'No waiting lists',
              message: 'Join a waiting list from a club to see it here.',
            ),
          ..._rows.map(
            (row) => _MyWaitingListCard(
              key: ValueKey(row['clubId'] ?? row['id']),
              row: row,
              repository: _repository,
              onLeft: () => _load(refresh: true),
            ),
          ),
          if (_error != null)
            TextButton(
              onPressed: () => _load(refresh: _page == 0),
              child: Text(
                '$_error · Retry',
                style: const TextStyle(color: discoveryGold),
              ),
            ),
          if (_busy)
            const Center(
              child: CircularProgressIndicator(color: discoveryGold),
            ),
          if (_more && !_busy && _rows.isNotEmpty)
            TextButton(
              onPressed: _load,
              child: const Text(
                'View more',
                style: TextStyle(color: discoveryGold),
              ),
            ),
        ],
      ),
    ),
  );
}

class _MyWaitingListCard extends StatefulWidget {
  const _MyWaitingListCard({
    super.key,
    required this.row,
    required this.repository,
    required this.onLeft,
  });

  final Map<String, dynamic> row;
  final DiscoveryRepository repository;
  final VoidCallback onLeft;

  @override
  State<_MyWaitingListCard> createState() => _MyWaitingListCardState();
}

class _MyWaitingListCardState extends State<_MyWaitingListCard> {
  bool _busy = false;
  bool _notified = false;
  dynamic _position;

  Map<String, dynamic> get _club {
    final club = widget.row['club'];
    return club is Map
        ? Map<String, dynamic>.from(club)
        : <String, dynamic>{};
  }

  Map<String, dynamic> get _entry {
    final entry = widget.row['entry'];
    return entry is Map
        ? Map<String, dynamic>.from(entry)
        : <String, dynamic>{};
  }

  String get clubId {
    final id = '${widget.row['clubId'] ?? _club['id'] ?? ''}'.trim();
    return id;
  }

  String get _name {
    final name = '${_club['name'] ?? widget.row['clubName'] ?? ''}'.trim();
    return name.isEmpty ? 'Club' : name;
  }

  String get _location => '${_club['location'] ?? ''}'.trim();

  String get _image {
    final thumb = '${_club['thumbnail'] ?? _club['image'] ?? ''}'.trim();
    return thumb;
  }

  @override
  void initState() {
    super.initState();
    _position = widget.row['position'] ?? _entry['position'];
    _notified =
        '${widget.row['status'] ?? _entry['status']}'.toUpperCase() ==
        'NOTIFIED';
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    if (clubId.isEmpty) return;
    try {
      final result = DiscoveryRepository.data(
        await widget.repository.get(
          '/waiting-list/club/${Uri.encodeComponent(clubId)}/status',
        ),
      );
      if (!mounted) return;
      setState(() {
        _position = result['position'] ?? _position;
        final entry = result['entry'];
        if (entry is Map) {
          _notified = '${entry['status']}'.toUpperCase() == 'NOTIFIED';
        }
      });
    } catch (_) {}
  }

  String get _savedSlot {
    final startAtRaw = widget.row['startAt'] ?? _entry['startAt'];
    final guestCountRaw = widget.row['guestCount'] ?? _entry['guestCount'];
    if (startAtRaw != null && startAtRaw.toString().isNotEmpty) {
      final dt = DateTime.tryParse(startAtRaw.toString());
      if (dt != null) {
        final g = int.tryParse('$guestCountRaw');
        final guests = g != null && g > 0 ? ' · $g guests' : '';
        return '${DateFormat('EEE, MMM d · h:mm a').format(dt.toLocal())}$guests';
      }
    }
    return LocalStorage.getData(key: 'waiting_slot_$clubId')?.toString() ?? '';
  }

  Future<void> _leave() async {
    if (_busy || clubId.isEmpty) return;
    if (!await AccountGate.ensure() || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.repository.post('/waiting-list/leave', {'clubId': clubId});
      LocalStorage.removeData(key: 'waiting_slot_$clubId');
      widget.onLeft();
    } catch (error) {
      CustomSnackBar.error(
        message: clientErrorMessage(
          error,
          'Could not leave waiting list. Please try again.',
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openClub() {
    if (clubId.isEmpty) return;
    final club = discoveryClub({
      'id': clubId,
      'name': _name,
      'thumbnail': _image,
      'location': _location,
    }, type: 'Club');
    Get.to(
      () => ClubDetailsView(clubModel: club),
      preventDuplicates: false,
      routeName: '/explore/club/$clubId',
    );
  }

  @override
  Widget build(BuildContext context) {
    final positionLabel = _position == null ? '' : '#$_position';
    final statusLabel = _notified
        ? 'Table may be available'
        : positionLabel.isEmpty
        ? 'You’re on the waiting list'
        : 'You’re on the waiting list · $positionLabel';
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: discoveryGold.withValues(alpha: _notified ? .5 : .28),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: clubId.isEmpty ? null : _openClub,
              borderRadius: BorderRadius.circular(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _WaitingListThumb(imageUrl: _image),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                _name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  height: 1.25,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _QueueBadge(
                              label: _notified
                                  ? 'Ready'
                                  : positionLabel.isEmpty
                                  ? 'Waiting'
                                  : positionLabel,
                              highlighted: _notified,
                            ),
                          ],
                        ),
                        if (_location.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                color: Colors.white54,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  _location,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (_savedSlot.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: Icon(
                                  Icons.schedule,
                                  color: discoveryGold,
                                  size: 13,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Requested: $_savedSlot',
                                  maxLines: 2,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          statusLabel,
                          style: const TextStyle(
                            color: discoveryGold,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Divider(color: Colors.white10, height: 1),
            const SizedBox(height: 10),
            Text(
              _notified
                  ? 'A table is now free! Tables are booked fast on a first-come, first-served basis. Tap "Book Open Table Now" to reserve.'
                  : 'You are on the standby list. When a table opens up, you will be notified to book online. Notice: Joining does not reserve a specific table or guarantee your requested time.',
              style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
            ),
            if (_notified) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final club = discoveryClub({
                      'id': clubId,
                      'name': _name,
                      'thumbnail': _image,
                      'location': _location,
                    }, type: 'Club');
                    Get.to(() => SelectDateTimeView(clubModel: club));
                  },
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Book Open Table Now'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: discoveryGold,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    textStyle: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _busy ? null : _leave,
                style: OutlinedButton.styleFrom(
                  foregroundColor: discoveryGold,
                  disabledForegroundColor: discoveryGold.withValues(alpha: .5),
                  side: BorderSide(
                    color: discoveryGold.withValues(alpha: .55),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: _busy
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: discoveryGold,
                        ),
                      )
                    : const Text(
                        'Leave waiting list',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WaitingListThumb extends StatelessWidget {
  const _WaitingListThumb({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return Container(
        height: 88,
        width: 88,
        decoration: BoxDecoration(
          color: const Color(0xFF261D0A),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(
          Icons.nightlife_rounded,
          color: discoveryGold,
          size: 32,
        ),
      );
    }
    return CustomNetworkImage(
      imageUrl: imageUrl,
      height: 88,
      width: 88,
      borderRadius: BorderRadius.circular(14),
      fit: BoxFit.cover,
    );
  }
}

class _QueueBadge extends StatelessWidget {
  const _QueueBadge({required this.label, required this.highlighted});

  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: highlighted ? const Color(0xFF261D0A) : Colors.white10,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: highlighted
              ? discoveryGold.withValues(alpha: .55)
              : Colors.white12,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: highlighted ? discoveryGold : Colors.white70,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
