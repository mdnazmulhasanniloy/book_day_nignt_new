import '../../config/flavor_config.dart';

class EndPoint {
  static String get BASE_URL =>
      AppConfig.isProduction ? AppConfig.baseUrl : AppConfig.localBaseUrl;

  // ─── Auth ───────────────────────────────────────────────────────────────────
  static const String CREATE_ACCOUNT = '/auth/signup';
  static const String VERIFY_EMAIL = '/auth/verify';
  static const String RESEND_OTP = '/auth/resend';
  static const String LOGIN = '/auth/login';
  static const String GOOGLE_LOGIN = '/auth/google';
  static const String socialLogin = '/auth/social';
  static const String CHECK_AUTH = '/auth/check';
  static const String LOGOUT = '/auth/logout';

  // ─── Recover Password ───────────────────────────────────────────────────────
  static const String FORGOT_PASSWORD = '/recover/find';
  static const String FORGOT_PASSWORD_VERIFY = '/recover/verify';
  static const String FORGOT_PASSWORD_RESEND = '/recover/resend';
  static const String RESET_PASSWORD = '/recover/reset';

  // ─── Profile ────────────────────────────────────────────────────────────────
  static const String PROFILE = '/profile';
  static const String DELETE_ACCOUNT = '/profile';
  static const String CHANGE_PASSWORD = '/change-password';

  // ─── Legal Rules ────────────────────────────────────────────────────────────
  static const String TERMS = '/terms';
  static const String PRIVACY = '/privacy';
  static const String ABOUT_US = '/about-us';

  // ─── Media ──────────────────────────────────────────────────────────────────
  static const String MEDIA = '/media';

  // Explore
  static const String explore = '/explore';
  static String exploreById(String id) => '$explore/$id';

  // Wishlist
  static const String wishlist = '/wishlist';
  static String removeWishlist(String type, String id) =>
      '$wishlist/${type.trim().toUpperCase()}/$id';

  // Purchase / payment
  static const String clubAvailability = '/purchase/club/availability';
  static const String purchaseClub = '/purchase/club';
  static const String purchaseEvent = '/purchase/event';
  static const String purchaseModule = '/purchase/module';
  static const String paymentIntent = '/payment/intent';
  static const String serviceCharge = '/service-charge';
  static const String bookings = '/bookings';
  static String bookingById(String id) => '$bookings/$id';
  static String bookingTicket(String id) => '$bookings/$id/ticket';
  static String bookingTicketFile(String id) => '$bookings/$id/ticket/file';

  static const String exploreGenres = '/explore/genres';
  static const String exploreFeed = '/explore/feed';

  static const String notifications = '/notifications';
  static const String notificationsReadAll = '/notifications/read-all';

  static const String reviews = '/reviews';
  static String clubReviews(String clubId) => '$reviews/$clubId';

  static const String promo = '/promo';
  static String promoById(String id) => '$promo/${id.trim()}';
  static const String promoValidate = '/promo/validate';

  // Club
  static const String clubs = '/club';
  static String clubById(String id) => '$clubs/$id';

  static const String waitingList = '/waiting-list';
  static String waitingListClub(String clubId) =>
      '$waitingList/club/${Uri.encodeComponent(clubId.trim())}';
  static String waitingListNotify(String entryId) =>
      '$waitingList/${entryId.trim()}/notify';
  static String waitingListEntry(String entryId) =>
      '$waitingList/${entryId.trim()}';

  // Stripe Connect
  static const String connectOnboarding = '/connect/onboarding';
  static const String connectStatus = '/connect/status';

  static const String ownerDashboard = '/owner/dashboard';
  static const String ownerEarnings = '/owner/earnings';
  static const String ownerPayments = '/owner/payments';
  static const String verifyTicket = '/owner/verify-ticket';

  // Event
  static const String events = '/event';
  static String eventById(String id) => '$events/$id';
  static String eventDuplicate(String id) => '$events/${id.trim()}/duplicate';
  static String eventBookingsClose(String id) =>
      '$events/${id.trim()}/bookings/close';
  static String eventModules(String eventId) =>
      '$events/${eventId.trim()}/modules';
  static String eventModuleById(String eventId, String id) =>
      '${eventModules(eventId)}/${id.trim()}';
  static String eventModulesReorder(String eventId) =>
      '${eventModules(eventId)}/reorder';
  static String eventModuleDuplicate(String eventId, String id) =>
      '${eventModuleById(eventId, id)}/duplicate';
  static String eventGuestList(String eventId) =>
      '$events/${eventId.trim()}/guest-list';
  static String eventGuestListJoin(String eventId) =>
      '${eventGuestList(eventId)}/join';
  static String eventGuestListEntries(String eventId) =>
      '${eventGuestList(eventId)}/entries';
  static String eventGuestListEntry(String eventId, String id) =>
      '${eventGuestListEntries(eventId)}/${id.trim()}';
  static String eventHosts(String eventId) => '$events/${eventId.trim()}/hosts';
  static String eventHostInquiries(String eventId) =>
      '$events/${eventId.trim()}/host-inquiries';
  static String clubHosts(String clubId) => '$clubs/${clubId.trim()}/hosts';

  static String artistFollow(String artistId) =>
      '/artists/${artistId.trim()}/follow';
  static const String meArtists = '/me/artists';

  static const String quotes = '/quotes';
  static String quoteById(String id) => '$quotes/${id.trim()}';

  static const String hosts = '/hosts';
  static String hostById(String id) => '$hosts/${id.trim()}';
  static String hostContact(String id) => '${hostById(id)}/contact';

  static const String ownerBookingsExport = '/owner/bookings/export';
}
