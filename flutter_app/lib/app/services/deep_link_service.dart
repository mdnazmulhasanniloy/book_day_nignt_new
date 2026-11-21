import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import '../config/flavor_config.dart';
import '../core/local_storage/local_storage.dart';
import '../core/resources/app_const/app_const.dart';
import '../modules/user_side/club_details_view/views/club_details_view.dart';
import '../modules/user_side/home/model/club_model.dart';

/// Builds share links (`<host>/explore/club/<id>`, `<host>/explore/event/<id>`)
/// and opens the matching details screen when such a link launches or resumes
/// the app. Older `/club/<id>` and `/event/<id>` links still parse.
///
/// The host must match the associated domain in `ios/Runner/Runner.entitlements`
/// and the App Links intent filter in `AndroidManifest.xml`.
class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;
  ClubModel? _pending;
  bool _userReady = false;

  static String get shareHost {
    final configured = dotenv.env['SHARE_BASE_URL']?.trim() ?? '';
    final base = configured.isNotEmpty ? configured : AppConfig.baseUrl;
    return Uri.parse(base).origin;
  }

  static String linkFor(ClubModel club) {
    final segment = club.isEvent ? 'event' : 'club';
    return '$shareHost/explore/$segment/${club.id}';
  }

  void init() {
    _subscription ??= _appLinks.uriLinkStream.listen(
      _onLink,
      onError: (Object error) => debugPrint('Deep link error: $error'),
    );
  }

  /// Called once the guest dashboard is on screen; opens a link that arrived
  /// during launch or before login.
  void onUserDashboardReady() {
    _userReady = true;
    final club = _pending;
    _pending = null;
    if (club != null) _open(club);
  }

  void onLoggedOut() => _userReady = false;

  Future<void> share(ClubModel club, {Rect? origin}) async {
    if (club.id.isEmpty) return;
    final lines = <String>[
      club.title.trim().isEmpty
          ? 'Check this out on BookdiaNight'
          : 'Check out ${club.title.trim()} on BookdiaNight',
      if (club.location.trim().isNotEmpty) club.location.trim(),
      linkFor(club),
    ];
    await SharePlus.instance.share(
      ShareParams(
        text: lines.join('\n'),
        subject: club.title.trim().isEmpty ? 'BookdiaNight' : club.title.trim(),
        sharePositionOrigin: origin,
      ),
    );
  }

  void _onLink(Uri uri) {
    final club = _parse(uri);
    if (club == null) return;
    if (_userReady && _isGuestLoggedIn) {
      _open(club);
    } else {
      _pending = club;
    }
  }

  bool get _isGuestLoggedIn {
    final token = LocalStorage.getData(key: AppConst.accessToken);
    final role = LocalStorage.getData(key: AppConst.role);
    return token != null && token.toString().isNotEmpty && role != 'CLUB_OWNER';
  }

  ClubModel? _parse(Uri uri) {
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.length < 2) return null;
    final kind = segments[segments.length - 2].toLowerCase();
    final id = segments.last.trim();
    if (id.isEmpty || (kind != 'club' && kind != 'event')) return null;
    return ClubModel(
      id: id,
      image: '',
      title: '',
      location: '',
      rating: '',
      price: '',
      type: kind == 'event' ? 'Event' : 'Club',
    );
  }

  void _open(ClubModel club) {
    Get.to(
      () => ClubDetailsView(clubModel: club),
      preventDuplicates: false,
    );
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
