import 'package:flutter/material.dart';
import '../../../../core/explore/repository/discovery_repository.dart';
import '../../../../core/resources/common_widget/compact_empty_state.dart';
import '../../club_details_view/widgets/club_community_section.dart';
import '../widgets/trending_event_card.dart';
import 'organizers_view.dart';

class TrendingEventsView extends StatefulWidget {
  const TrendingEventsView({
    super.key,
    this.initialBlowingUp = const [],
    this.initialToday = const [],
    this.initialTomorrow = const [],
    this.initialOrganizers = const [],
    this.initialGenres = const [],
  });

  final List<Map<String, dynamic>> initialBlowingUp;
  final List<Map<String, dynamic>> initialToday;
  final List<Map<String, dynamic>> initialTomorrow;
  final List<Map<String, dynamic>> initialOrganizers;
  final List<String> initialGenres;

  @override
  State<TrendingEventsView> createState() => _TrendingEventsViewState();
}

class _TrendingEventsViewState extends State<TrendingEventsView> {
  late List<Map<String, dynamic>> _blowingUp;
  late List<Map<String, dynamic>> _today;
  late List<Map<String, dynamic>> _tomorrow;
  late List<Map<String, dynamic>> _organizers;
  late List<String> _genres;
  String _genre = '';
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _blowingUp = List.of(widget.initialBlowingUp);
    _today = List.of(widget.initialToday);
    _tomorrow = List.of(widget.initialTomorrow);
    _organizers = List.of(widget.initialOrganizers);
    _genres = List.of(widget.initialGenres);
    if (_empty) _refresh();
  }

  bool get _empty =>
      _blowingUp.isEmpty &&
      _today.isEmpty &&
      _tomorrow.isEmpty &&
      _organizers.isEmpty;

  List<Map<String, dynamic>> get _visibleBlowingUp =>
      DiscoveryRepository.eventsMatchingGenre(_blowingUp, _genre);

  List<Map<String, dynamic>> get _visibleToday =>
      DiscoveryRepository.eventsMatchingGenre(_today, _genre);

  List<Map<String, dynamic>> get _visibleTomorrow =>
      DiscoveryRepository.eventsMatchingGenre(_tomorrow, _genre);

  Future<void> _refresh() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = DiscoveryRepository.data(
        await DiscoveryRepository().get('/explore/feed'),
      );
      if (mounted) {
        setState(() {
          _blowingUp = DiscoveryRepository.items(data['blowingUp']);
          _today = DiscoveryRepository.items(data['today']);
          _tomorrow = DiscoveryRepository.items(data['tomorrow']);
          _organizers = DiscoveryRepository.items(data['popularOrganizers']);
          _genres = DiscoveryRepository.strings(data['genres']);
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load live events');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hot = _visibleBlowingUp;
    final today = _visibleToday;
    final tomorrow = _visibleTomorrow;
    final eventsEmpty = hot.isEmpty && today.isEmpty && tomorrow.isEmpty;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Trending events',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: RefreshIndicator(
        color: discoveryGold,
        onRefresh: _refresh,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cardHeight =
                200 +
                ((MediaQuery.textScalerOf(context).scale(14) / 14).clamp(
                          1.0,
                          2.0,
                        ) -
                        1) *
                    80;
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (_loading)
                  const LinearProgressIndicator(color: discoveryGold),
                if (_error != null)
                  TextButton(
                    onPressed: _refresh,
                    child: Text(
                      '$_error · Retry',
                      style: const TextStyle(color: discoveryGold),
                    ),
                  ),
                if (_genres.isNotEmpty) ...[
                  SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _genres.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (_, index) {
                        final genre = _genres[index];
                        final selected = _genre == genre;
                        return ChoiceChip(
                          label: Text(genre),
                          selected: selected,
                          onSelected: (_) => setState(
                            () => _genre = selected ? '' : genre,
                          ),
                          selectedColor: discoveryGold,
                          backgroundColor: const Color(0xFF1A1A1A),
                          labelStyle: TextStyle(
                            color: selected ? Colors.black : Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                          side: BorderSide(
                            color: selected ? discoveryGold : Colors.white12,
                          ),
                          showCheckmark: false,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
                if (_empty && !_loading && _error == null)
                  const CompactEmptyState.stacked(
                    icon: Icons.event_outlined,
                    title: 'No live events',
                    message: 'Feed events and clubs will appear here.',
                  ),
                if (!_empty && eventsEmpty && _genre.isNotEmpty)
                  CompactEmptyState(
                    icon: Icons.event_outlined,
                    title: 'No $_genre events',
                    message: 'Tap the genre again to see all.',
                  ),
                if (hot.isNotEmpty)
                  _FeedGroup(
                    title: 'Trending now',
                    child: Column(
                      children: [
                        for (final event in hot)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: SizedBox(
                              height: cardHeight,
                              child: TrendingEventCard(
                                event: event,
                                width: constraints.maxWidth - 40,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                if (today.isNotEmpty)
                  _FeedGroup(
                    title: 'Happening today',
                    child: Column(
                      children: [
                        for (final row in today) DiscoveryEventTile(row: row),
                      ],
                    ),
                  ),
                if (tomorrow.isNotEmpty)
                  _FeedGroup(
                    title: 'Happening tomorrow',
                    child: Column(
                      children: [
                        for (final row in tomorrow)
                          DiscoveryEventTile(row: row),
                      ],
                    ),
                  ),
                if (_organizers.isNotEmpty)
                  _FeedGroup(
                    title: 'Clubs to follow',
                    child: Column(
                      children: [
                        for (final club in _organizers)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: ClubFollowCard(club: club),
                          ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FeedGroup extends StatelessWidget {
  const _FeedGroup({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
