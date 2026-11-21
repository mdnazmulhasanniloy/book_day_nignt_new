import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/explore/repository/discovery_repository.dart';
import '../../../../core/resources/common_widget/custom_network_image.dart';
import '../../club_details_view/widgets/club_community_section.dart';

class OrganizerDetailsView extends StatefulWidget {
  const OrganizerDetailsView({super.key, required this.organizer});
  final Map<String, dynamic> organizer;
  @override
  State<OrganizerDetailsView> createState() => _OrganizerDetailsViewState();
}

class _OrganizerDetailsViewState extends State<OrganizerDetailsView> {
  late Map<String, dynamic> _data;
  bool _loading = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _data = Map.of(widget.organizer);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final body = await DiscoveryRepository().get(
        '/explore/${Uri.encodeComponent('${_data['id']}')}',
        params: {'type': 'CLUB'},
      );
      if (mounted) {
        setState(() => _data = {..._data, ...DiscoveryRepository.data(body)});
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not refresh organizer details');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = '${_data['name'] ?? ''}';
    final description = '${_data['description'] ?? ''}'.trim();
    final location = '${_data['location'] ?? ''}'.trim();
    final website = Uri.tryParse('${_data['website'] ?? ''}');
    final followers = _data['followerCount'];
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        title: const Text('Organizer'),
        backgroundColor: const Color(0xFF0D0D0D),
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        color: discoveryGold,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Center(
              child: CustomNetworkImage(
                imageUrl: '${_data['thumbnail'] ?? ''}',
                height: 112,
                width: 112,
                boxShape: BoxShape.circle,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 25,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (followers != null) ...[
              const SizedBox(height: 6),
              Text(
                '$followers followers',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ],
            ClubFollowButton(
              clubId: '${_data['id']}',
              onChanged: (following) {
                setState(() {
                  final count = int.tryParse('${_data['followerCount']}');
                  if (count != null) {
                    _data['followerCount'] = (count + (following ? 1 : -1))
                        .clamp(0, 1 << 31);
                  }
                });
              },
            ),
            if (_loading)
              const LinearProgressIndicator(
                color: discoveryGold,
                backgroundColor: Colors.white10,
              ),
            if (_error != null)
              TextButton(
                onPressed: _load,
                child: Text(
                  '$_error · Retry',
                  style: const TextStyle(color: discoveryGold),
                ),
              ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text(
                'About',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                description,
                style: const TextStyle(color: Colors.white60, height: 1.6),
              ),
            ],
            if (location.isNotEmpty) ...[
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    color: discoveryGold,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      location,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ],
            if (website != null &&
                ['https', 'http'].contains(website.scheme)) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () =>
                    launchUrl(website, mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.open_in_new, size: 17),
                label: Text(website.host),
                style: TextButton.styleFrom(foregroundColor: discoveryGold),
              ),
            ],
            if ('${_data['id']}'.trim().isNotEmpty) ...[
              ClubRemoteSection(
                clubId: '${_data['id']}',
                kind: 'upcoming',
                title: 'Upcoming events',
              ),
              ClubRemoteSection(
                clubId: '${_data['id']}',
                kind: 'past',
                title: 'Past events',
              ),
              ClubRemoteSection(
                clubId: '${_data['id']}',
                kind: 'artists',
                title: "They’ve played here",
              ),
            ],
          ],
        ),
      ),
    );
  }
}
