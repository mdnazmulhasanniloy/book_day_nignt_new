import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/auth/account_gate.dart';
import '../../../../core/explore/model/event_offer_model.dart';
import '../../../../core/explore/repository/discovery_repository.dart';
import '../../../../core/resources/common_widget/compact_empty_state.dart';
import '../../../../core/resources/common_widget/custom_network_image.dart';
import '../../../../core/utils/custom_snack_bar.dart';
import '../../favorite/controllers/wishlist_controller.dart';
import '../../home/model/club_model.dart';
import '../views/club_details_view.dart';

const discoveryGold = Color(0xFFDCA73A);

ClubModel discoveryClub(Map<String, dynamic> row, {String type = 'Event'}) =>
    ClubModel(
      id: (row['id'] ?? row['eventId'] ?? '').toString(),
      title: (row['eventName'] ?? row['name'] ?? '').toString(),
      image: (row['thumbnail'] ?? row['image'] ?? '').toString(),
      location: row['location']?.toString() ?? '',
      rating: '',
      price: _discoveryPrice(row),
      type: type,
      isWishlist: row['isWishlist'] == true,
      startAt: DateTime.tryParse('${row['startAt']}'),
      endAt: DateTime.tryParse('${row['endAt']}'),
    );

String _discoveryPrice(Map<String, dynamic> row) {
  final tiers = EventTicketTierModel.listFrom(
    row['ticketTiers'] ?? row['tiers'],
  );
  final amount = tiers.isNotEmpty
      ? (tiers.expand((tier) => tier.flattened).map((tier) => tier.price).toList()
            ..sort())
          .first
      : num.tryParse('${row['eventPrice'] ?? row['price']}');
  if (amount == null) return '';
  if (amount == 0) return 'Free';
  final value = amount == amount.roundToDouble()
      ? amount.round().toString()
      : amount.toStringAsFixed(2);
  return '€$value';
}

String _httpLink(dynamic value) {
  final raw = value?.toString().trim() ?? '';
  final uri = Uri.tryParse(raw);
  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
    return '';
  }
  return raw;
}

Future<void> _openArtistLink(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) {
    CustomSnackBar.error(message: 'No playable link for this artist.');
    return;
  }
  try {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw StateError('Cannot open');
    }
  } catch (_) {
    CustomSnackBar.error(message: 'Could not open artist link.');
  }
}

class DiscoveryEventTile extends StatelessWidget {
  const DiscoveryEventTile({
    super.key,
    required this.row,
    this.openOnTap = true,
    this.showFavorite = true,
  });
  final Map<String, dynamic> row;
  final bool openOnTap;
  final bool showFavorite;
  @override
  Widget build(BuildContext context) {
    final club = discoveryClub(row);
    final canOpen = openOnTap && club.id.isNotEmpty;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: canOpen
            ? () => Get.to(
                () => ClubDetailsView(clubModel: club),
                preventDuplicates: false,
                routeName: '/explore/event/${club.id}',
              )
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              CustomNetworkImage(
                imageUrl: club.image,
                height: 64,
                width: 58,
                borderRadius: BorderRadius.circular(10),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      club.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (club.startAt != null)
                          DateFormat(
                            'EEE, d MMM · h:mm a',
                          ).format(club.startAt!.toLocal()),
                        if (club.location.isNotEmpty) club.location,
                        if (club.price.isNotEmpty) club.price,
                      ].join('\n'),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (showFavorite) _DiscoveryHeart(club: club),
              if (canOpen)
                const Icon(Icons.chevron_right, color: discoveryGold),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiscoveryHeart extends StatelessWidget {
  const _DiscoveryHeart({required this.club});

  final ClubModel club;

  @override
  Widget build(BuildContext context) {
    final wishlist = Get.isRegistered<WishlistController>()
        ? Get.find<WishlistController>()
        : Get.put(WishlistController(), permanent: true);
    return Obx(() {
      final favorited = wishlist.isWishlisted(club);
      final busy = wishlist.isToggling(club);
      return IconButton(
        onPressed: busy || club.id.isEmpty ? null : () => wishlist.toggle(club),
        icon: Icon(
          favorited ? Icons.favorite : Icons.favorite_border,
          color: favorited ? discoveryGold : Colors.white54,
          size: 20,
        ),
      );
    });
  }
}

class ClubArtistCard extends StatelessWidget {
  const ClubArtistCard({
    super.key,
    required this.name,
    this.avatarUrl = '',
    this.linkUrl = '',
    this.verified = false,
  });

  final String name;
  final String avatarUrl;
  final String linkUrl;
  final bool verified;

  factory ClubArtistCard.fromMap(Map<String, dynamic> artist) {
    return ClubArtistCard(
      name: (artist['artistName'] ?? artist['name'] ?? '').toString(),
      avatarUrl: _httpLink(
        artist['artistAvatar'] ?? artist['avatar'] ?? artist['image'],
      ),
      linkUrl: _httpLink(artist['spotifyUrl']).isNotEmpty
          ? _httpLink(artist['spotifyUrl'])
          : _httpLink(artist['soundcloudUrl']),
      verified: artist['isVerified'] == true,
    );
  }

  factory ClubArtistCard.fromLineup(EventLineupArtistModel artist) {
    return ClubArtistCard(
      name: artist.artistName,
      avatarUrl: _httpLink(artist.artistAvatar),
      linkUrl: _httpLink(artist.externalUrl),
      verified: artist.isVerified,
    );
  }

  String get _initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'DJ';
    String first(String value) {
      if (value.isEmpty) return '';
      return String.fromCharCode(value.runes.first).toUpperCase();
    }

    if (parts.length == 1) {
      final runes = parts.first.runes.take(2).toList();
      return String.fromCharCodes(runes).toUpperCase();
    }
    return '${first(parts.first)}${first(parts.last)}';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 116,
      child: InkWell(
        onTap: linkUrl.isEmpty ? null : () => _openArtistLink(linkUrl),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                if (avatarUrl.isNotEmpty)
                  CustomNetworkImage(
                    imageUrl: avatarUrl,
                    height: 104,
                    width: 116,
                    borderRadius: BorderRadius.circular(12),
                  )
                else
                  Container(
                    height: 104,
                    width: 116,
                    decoration: BoxDecoration(
                      color: const Color(0xFF261D0A),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _initials,
                      style: const TextStyle(
                        color: discoveryGold,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                if (linkUrl.isNotEmpty)
                  const Positioned(
                    right: 4,
                    bottom: 4,
                    child: Icon(
                      Icons.play_circle_fill,
                      color: discoveryGold,
                      size: 28,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                ),
                if (verified) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.verified, color: discoveryGold, size: 16),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ClubCommunitySection extends StatelessWidget {
  const ClubCommunitySection({super.key, required this.clubId});
  final String clubId;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      ClubFollowButton(clubId: clubId),
      ClubRemoteSection(
        clubId: clubId,
        kind: 'upcoming',
        title: 'Upcoming events',
      ),
      ClubRemoteSection(clubId: clubId, kind: 'past', title: 'Past events'),
      ClubRemoteSection(
        clubId: clubId,
        kind: 'artists',
        title: "They’ve played here",
      ),
    ],
  );
}

class ClubFollowButton extends StatefulWidget {
  const ClubFollowButton({
    super.key,
    required this.clubId,
    this.onChanged,
    this.compact = false,
    this.dense = false,
  });
  final String clubId;
  final ValueChanged<bool>? onChanged;
  final bool compact;
  final bool dense;
  @override
  State<ClubFollowButton> createState() => _ClubFollowButtonState();
}

class _ClubFollowButtonState extends State<ClubFollowButton> {
  final _repository = DiscoveryRepository();
  bool? _following;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    if (!AccountGate.isSignedIn) {
      if (mounted) setState(() => _following = false);
      return;
    }
    try {
      final body = DiscoveryRepository.data(
        await _repository.get(
          '/clubs/${Uri.encodeComponent(widget.clubId)}/is-following',
        ),
      );
      if (mounted) {
        setState(() {
          _following = body['isFollowing'] == true;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load follow status');
    }
  }

  Future<void> _toggle() async {
    if (_busy || !await AccountGate.ensure() || !mounted) return;
    setState(() => _busy = true);
    try {
      // Re-read after login so a guest's default never overwrites a saved follow.
      await _load();
      if (_error != null || _following == null) return;
      if (_following!) {
        await _repository.unfollow(widget.clubId);
      } else {
        await _repository.post(
          '/clubs/${Uri.encodeComponent(widget.clubId)}/follow',
          {},
        );
      }
      if (mounted) {
        setState(() => _following = !_following!);
        widget.onChanged?.call(_following!);
      }
    } catch (_) {
      CustomSnackBar.error(
        message: 'Could not update following. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final following = _following == true;
    final loading = _busy || (_following == null && _error == null);
    if (widget.dense) {
      return TextButton(
        style: TextButton.styleFrom(
          foregroundColor: following ? discoveryGold : Colors.black,
          backgroundColor: following
              ? discoveryGold.withValues(alpha: .10)
              : discoveryGold,
          disabledForegroundColor: discoveryGold,
          disabledBackgroundColor: discoveryGold.withValues(alpha: .10),
          minimumSize: const Size(68, 30),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9),
            side: BorderSide(
              color: discoveryGold.withValues(alpha: following ? .35 : 0),
            ),
          ),
        ),
        onPressed: loading ? null : (_error != null ? _load : _toggle),
        child: loading
            ? const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: discoveryGold,
                ),
              )
            : Text(
                _error != null
                    ? 'Retry'
                    : following
                    ? 'Unfollow'
                    : 'Follow',
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 10,
                  height: 1,
                  fontWeight: FontWeight.w600,
                ),
              ),
      );
    }
    final action = FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: following
            ? discoveryGold.withValues(alpha: .12)
            : discoveryGold,
        foregroundColor: following ? discoveryGold : Colors.black,
        disabledBackgroundColor: discoveryGold.withValues(alpha: .12),
        disabledForegroundColor: discoveryGold,
        padding: EdgeInsets.symmetric(
          horizontal: widget.compact ? 8 : 14,
          vertical: widget.compact ? 6 : 12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: discoveryGold.withValues(alpha: following ? .4 : 0),
          ),
        ),
      ),
      onPressed: loading ? null : (_error != null ? _load : _toggle),
      icon: loading
          ? SizedBox(
              width: widget.compact ? 12 : 16,
              height: widget.compact ? 12 : 16,
              child: const CircularProgressIndicator(
                strokeWidth: 2,
                color: discoveryGold,
              ),
            )
          : Icon(
              _error != null
                  ? Icons.refresh_rounded
                  : following
                  ? Icons.check_rounded
                  : Icons.add_rounded,
              size: widget.compact ? 14 : 18,
            ),
      label: Text(
        loading
            ? 'Loading'
            : _error != null
            ? 'Retry'
            : following
            ? (widget.compact ? 'Unfollow' : 'Following')
            : 'Follow',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: widget.compact ? 11 : 13,
        ),
      ),
    );
    if (widget.compact) return action;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF191710),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: discoveryGold.withValues(alpha: following ? .35 : .18),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  following
                      ? 'You are following this club'
                      : 'Follow this club',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _error != null
                      ? 'Could not load follow status.'
                      : following
                      ? 'You are following updates from this club.'
                      : 'Follow the club for its latest updates.',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          action,
        ],
      ),
    );
  }
}

class ClubRemoteSection extends StatefulWidget {
  const ClubRemoteSection({
    super.key,
    required this.clubId,
    required this.kind,
    required this.title,
  });
  final String clubId, kind, title;
  @override
  State<ClubRemoteSection> createState() => _ClubRemoteSectionState();
}

class _ClubRemoteSectionState extends State<ClubRemoteSection> {
  final _repository = DiscoveryRepository();
  final _rows = <Map<String, dynamic>>[];
  bool _busy = false, _more = false;
  String? _error;
  int _page = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final artists = widget.kind == 'artists';
      final path =
          '/explore/club/${Uri.encodeComponent(widget.clubId)}/${artists ? 'artists' : 'events/${widget.kind}'}';
      final body = await _repository.get(
        path,
        params: artists ? null : {'page': _page + 1, 'limit': 5},
      );
      final rows = DiscoveryRepository.items(body['data']);
      final meta = body['meta'] is Map ? body['meta'] as Map : {};
      if (mounted) {
        setState(() {
          _rows.addAll(rows);
          _page++;
          _more =
              !artists &&
              rows.isNotEmpty &&
              _page < (int.tryParse('${meta['totalPages']}') ?? _page);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not load ${widget.title.toLowerCase()}');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        if (_rows.isEmpty && !_busy && _error == null)
          CompactEmptyState(
            icon: widget.kind == 'artists'
                ? Icons.headphones_outlined
                : widget.kind == 'past'
                ? Icons.history_rounded
                : Icons.event_outlined,
            title: widget.kind == 'artists'
                ? 'No artists yet'
                : widget.kind == 'past'
                ? 'No past events'
                : 'No upcoming events',
            message: widget.kind == 'artists'
                ? 'Artists will appear here when added.'
                : widget.kind == 'past'
                ? 'Previous events will appear here.'
                : 'New events will appear here.',
          ),
        if (widget.kind == 'artists' && _rows.isNotEmpty)
          SizedBox(
            height: 168,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _rows.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, index) =>
                  ClubArtistCard.fromMap(_rows[index]),
            ),
          )
        else
          ..._rows.map(
            (row) => DiscoveryEventTile(
              row: row,
              openOnTap: widget.kind != 'past',
              showFavorite: widget.kind != 'past',
            ),
          ),
        if (_busy)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: CircularProgressIndicator(
                color: discoveryGold,
                strokeWidth: 2,
              ),
            ),
          ),
        if (_error != null)
          TextButton(
            onPressed: _load,
            child: Text(
              '$_error · Retry',
              style: const TextStyle(color: discoveryGold),
            ),
          ),
        if (_more && !_busy)
          TextButton(
            onPressed: _load,
            child: const Text(
              'View more',
              style: TextStyle(color: discoveryGold),
            ),
          ),
      ],
    ),
  );
}

class EventLineupStrip extends StatelessWidget {
  const EventLineupStrip({super.key, required this.artists});
  final List<EventLineupArtistModel> artists;

  @override
  Widget build(BuildContext context) {
    if (artists.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 168,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: artists.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, index) => ClubArtistCard.fromLineup(artists[index]),
      ),
    );
  }
}

class EventLineupRows extends StatelessWidget {
  const EventLineupRows({super.key, required this.artists});
  final List<EventLineupArtistModel> artists;

  @override
  Widget build(BuildContext context) {
    if (artists.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (var index = 0; index < artists.length; index++) ...[
          if (index > 0) const Divider(height: 20, color: Colors.white10),
          _EventLineupRow(artist: ClubArtistCard.fromLineup(artists[index])),
        ],
      ],
    );
  }
}

class _EventLineupRow extends StatelessWidget {
  const _EventLineupRow({required this.artist});
  final ClubArtistCard artist;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: artist.linkUrl.isEmpty
          ? null
          : () => _openArtistLink(artist.linkUrl),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            ClipOval(
              child: artist.avatarUrl.isNotEmpty
                  ? CustomNetworkImage(
                      imageUrl: artist.avatarUrl,
                      height: 44,
                      width: 44,
                      borderRadius: BorderRadius.circular(22),
                    )
                  : Container(
                      height: 44,
                      width: 44,
                      color: const Color(0xFF261D0A),
                      alignment: Alignment.center,
                      child: Text(
                        artist._initials,
                        style: const TextStyle(
                          color: discoveryGold,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      artist.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (artist.verified) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.verified, color: discoveryGold, size: 16),
                  ],
                ],
              ),
            ),
            if (artist.linkUrl.isNotEmpty) ...[
              const SizedBox(width: 8),
              if (artist.linkUrl.toLowerCase().contains('spotify'))
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1DB954).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF1DB954).withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.play_circle_fill,
                        color: Color(0xFF1DB954),
                        size: 14,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Spotify',
                        style: TextStyle(
                          color: Color(0xFF1DB954),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              else
                const Icon(
                  Icons.play_circle_fill,
                  color: discoveryGold,
                  size: 22,
                ),
            ],
          ],
        ),
      ),
    );
  }
}
