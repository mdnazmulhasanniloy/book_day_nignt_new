import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/auth/account_gate.dart';
import '../../../../core/explore/repository/discovery_repository.dart';
import '../../../../core/resources/common_widget/compact_empty_state.dart';
import '../../../../core/resources/common_widget/custom_network_image.dart';
import '../../club_details_view/views/club_details_view.dart';
import '../../club_details_view/widgets/club_community_section.dart';

class ClubFollowCard extends StatefulWidget {
  const ClubFollowCard({
    super.key,
    required this.club,
    this.onReturn,
    this.openDetails = true,
    this.onFollowChanged,
  });
  final Map<String, dynamic> club;
  final VoidCallback? onReturn;
  final bool openDetails;
  final ValueChanged<bool>? onFollowChanged;

  @override
  State<ClubFollowCard> createState() => _ClubFollowCardState();
}

class _ClubFollowCardState extends State<ClubFollowCard> {
  int _followRevision = 0;

  @override
  Widget build(BuildContext context) {
    final club = discoveryClub(widget.club, type: 'Club');
    final followers = int.tryParse('${widget.club['followerCount']}');
    return Material(
      color: const Color(0xFF161616),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: club.id.isEmpty || !widget.openDetails
            ? null
            : () async {
                await Get.to(() => ClubDetailsView(clubModel: club));
                if (!mounted) return;
                setState(() => _followRevision++);
                widget.onReturn?.call();
              },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: .08)),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: discoveryGold.withValues(alpha: .45),
                      ),
                    ),
                    child: CustomNetworkImage(
                      imageUrl: club.image,
                      height: 48,
                      width: 48,
                      boxShape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          club.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(
                              Icons.people_outline_rounded,
                              size: 15,
                              color: discoveryGold,
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                followers == null
                                    ? 'Club'
                                    : '$followers followers',
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (club.location.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Text(
                            club.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (club.id.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    ClubFollowButton(
                      key: ValueKey('${club.id}_$_followRevision'),
                      clubId: club.id,
                      compact: true,
                      onChanged: (following) {
                        if (!mounted) return;
                        setState(() {
                          final count =
                              int.tryParse('${widget.club['followerCount']}') ??
                              0;
                          widget.club['followerCount'] =
                              (count + (following ? 1 : -1)).clamp(0, 1 << 31);
                        });
                        widget.onFollowChanged?.call(following);
                      },
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ClubFollowingView extends StatefulWidget {
  const ClubFollowingView({
    super.key,
    this.popularOnly = false,
    this.followingOnly = false,
  });
  final bool popularOnly;
  final bool followingOnly;
  @override
  State<ClubFollowingView> createState() => _ClubFollowingViewState();
}

class _ClubFollowingViewState extends State<ClubFollowingView> {
  final _repository = DiscoveryRepository();
  final _rows = <Map<String, dynamic>>[];
  bool _following = false, _loading = false, _more = false;
  String? _error;
  int _page = 0, _request = 0;

  @override
  void initState() {
    super.initState();
    _following = widget.followingOnly;
    _load(refresh: true);
  }

  Future<void> _load({bool refresh = false}) async {
    final request = ++_request;
    final following = _following;
    final page = refresh ? 1 : _page + 1;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final body = await _repository.get(
        following ? '/me/following' : '/explore/feed',
        params: following ? {'page': page, 'limit': 20} : null,
      );
      final rows = following
          ? DiscoveryRepository.items(body['data'])
          : DiscoveryRepository.items(
              DiscoveryRepository.data(body)['popularOrganizers'],
            );
      final normalized = rows
          .map(
            (row) => row['club'] is Map
                ? Map<String, dynamic>.from(row['club'] as Map)
                : row,
          )
          .toList();
      final meta = body['meta'] is Map ? body['meta'] as Map : {};
      if (!mounted || request != _request) return;
      setState(() {
        if (refresh) _rows.clear();
        _rows.addAll(normalized);
        _page = page;
        _more =
            following &&
            rows.isNotEmpty &&
            page < (int.tryParse('${meta['totalPages']}') ?? page);
      });
    } catch (_) {
      if (mounted && request == _request) {
        setState(() => _error = 'Could not load clubs');
      }
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _select(bool following) async {
    if (following && !await AccountGate.ensure()) return;
    if (!mounted || _following == following) return;
    setState(() {
      _following = following;
      _rows.clear();
    });
    await _load(refresh: true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      iconTheme: const IconThemeData(color: Colors.white),
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        tooltip: 'Back',
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: Colors.white,
          size: 20,
        ),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      title: Text(
        widget.followingOnly
            ? 'Following Clubs'
            : widget.popularOnly
            ? 'Clubs to follow'
            : 'Clubs',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    body: Column(
      children: [
        if (!widget.popularOnly && !widget.followingOnly)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(
              children: [
                for (final following in [false, true]) ...[
                  if (following) const SizedBox(width: 10),
                  Expanded(
                    child: ChoiceChip(
                      label: SizedBox(
                        width: double.infinity,
                        child: Text(
                          following ? 'Following' : 'Discover',
                          textAlign: TextAlign.center,
                        ),
                      ),
                      selected: _following == following,
                      onSelected: (_) => _select(following),
                      selectedColor: discoveryGold,
                      backgroundColor: const Color(0xFF161616),
                      labelStyle: TextStyle(
                        color: _following == following
                            ? Colors.black
                            : Colors.white70,
                      ),
                      showCheckmark: false,
                    ),
                  ),
                ],
              ],
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            color: discoveryGold,
            onRefresh: () => _load(refresh: true),
            child: ListView.separated(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 32),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: _rows.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, index) {
                if (index < _rows.length) {
                  final club = _rows[index];
                  return ClubFollowCard(
                    key: ValueKey(club['id']),
                    club: club,
                    onFollowChanged: (following) {
                      if (_following && !following && mounted) {
                        setState(
                          () => _rows.removeWhere(
                            (row) => row['id'] == club['id'],
                          ),
                        );
                      }
                    },
                    onReturn: () {
                      if (mounted) _load(refresh: true);
                    },
                  );
                }
                if (_loading) {
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: CircularProgressIndicator(color: discoveryGold),
                    ),
                  );
                }
                if (_error != null) {
                  return TextButton(
                    onPressed: () => _load(refresh: _page == 0),
                    child: Text(
                      '$_error · Retry',
                      style: const TextStyle(color: discoveryGold),
                    ),
                  );
                }
                if (_rows.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: CompactEmptyState.stacked(
                      icon: _following
                          ? Icons.favorite_border_rounded
                          : Icons.storefront_outlined,
                      title: _following
                          ? 'No clubs followed yet'
                          : 'No clubs yet',
                      message: _following
                          ? 'Follow a club from its details to see it here.'
                          : 'Clubs will appear here when available.',
                    ),
                  );
                }
                if (_more) {
                  return TextButton(
                    onPressed: () => _load(),
                    child: const Text(
                      'Load more',
                      style: TextStyle(color: discoveryGold),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ],
    ),
  );
}
