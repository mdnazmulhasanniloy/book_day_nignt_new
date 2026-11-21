import 'package:bookdianight_app/app/core/explore/model/event_commerce_model.dart';
import 'package:bookdianight_app/app/core/explore/repository/event_commerce_repository.dart';
import 'package:bookdianight_app/app/core/explore/model/explore_api_model.dart';
import 'package:bookdianight_app/app/core/explore/model/explore_item_mapper.dart';
import 'package:bookdianight_app/app/modules/authentication/auth_repository/auth_repository.dart';
import 'package:bookdianight_app/app/core/network/end_point.dart';
import 'package:bookdianight_app/app/modules/club_owner_side/activity/model/club_api_model.dart';
import 'package:bookdianight_app/app/modules/club_owner_side/activity/model/club_upsert_model.dart';
import 'package:bookdianight_app/app/modules/club_owner_side/activity/model/event_api_model.dart';
import 'package:bookdianight_app/app/modules/club_owner_side/activity/model/owner_waiting_list_model.dart';
import 'package:bookdianight_app/app/modules/club_owner_side/activity/model/promo_api_model.dart';
import 'package:bookdianight_app/app/modules/club_owner_side/activity/repository/promo_repository.dart';
import 'package:bookdianight_app/app/modules/club_owner_side/ticket_scanner/repository/ticket_scanner_repository.dart';
import 'package:bookdianight_app/app/modules/club_owner_side/owner_home/repository/owner_stats_repository.dart';
import 'package:bookdianight_app/app/modules/user_side/booking/model/booking_detail_model.dart';
import 'package:bookdianight_app/app/modules/user_side/explore/controllers/explore_controller.dart';
import 'dart:async';
import 'dart:io';

import 'package:bookdianight_app/app/core/network/api_error_handler.dart';
import 'package:bookdianight_app/app/core/network/api_expection.dart';
import 'package:bookdianight_app/app/core/explore/repository/discovery_repository.dart';
import 'package:bookdianight_app/app/core/resources/app_const/app_const.dart';
import 'package:bookdianight_app/app/modules/notification/controller/notification_controller.dart';
import 'package:bookdianight_app/app/modules/notification/model/notification_model.dart';
import 'package:bookdianight_app/app/modules/notification/repository/notification_repository.dart';
import 'package:bookdianight_app/app/modules/user_side/club_details_view/repository/club_purchase_repository.dart'
    hide ClubPackageModel;
import 'package:bookdianight_app/app/modules/user_side/club_details_view/widgets/waiting_list_panel.dart';
import 'package:bookdianight_app/app/services/notification_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';

class QueueRepository extends DiscoveryRepository {
  bool waiting = false;
  final mutations = <String>[];
  final bodies = <Map<String, dynamic>>[];
  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? params,
  }) async => {
    'data': {
      'isWaiting': waiting,
      'position': waiting ? 2 : null,
      'entry': waiting ? {'status': 'PENDING'} : null,
    },
  };
  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    mutations.add(path);
    bodies.add(body);
    waiting = path.endsWith('/join');
    return {'success': true};
  }
}

class InboxRepository extends NotificationRepository {
  final read = Completer<void>();
  @override
  Future<int> fetchUnreadCount() async => 37;
  @override
  Future<void> markRead(String id) => read.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory storage;
  setUpAll(() async {
    storage = await Directory.systemTemp.createTemp('bookdianight-test-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => storage.path,
        );
    await GetStorage.init();
    GetStorage().writeInMemory(AppConst.accessToken, 'test-token');
  });
  // GetStorage keeps its file handle open until process exit on Windows.
  // The isolated directory is left to the operating system's temporary cleanup.

  test(
    'server unread count includes notifications outside loaded pages',
    () async {
      final controller = NotificationController(repository: InboxRepository());
      await controller.refreshUnreadCount();
      expect(controller.notifications, isEmpty);
      expect(controller.unreadCount, 37);
      expect(controller.badgeLabel, '9+');
    },
  );

  test('single read stays unread until the server confirms it', () async {
    final repository = InboxRepository();
    final controller = NotificationController(repository: repository);
    final item = NotificationModel.fromJson({
      'id': 'n1',
      'title': 'Table available',
      'isRead': false,
    });
    final pending = controller.markAsRead(item);
    expect(item.isRead, isFalse);
    repository.read.complete();
    await pending;
    expect(item.isRead, isTrue);
  });

  test(
    'notification routing supports Swagger metadata and encoded FCM data',
    () {
      final item = NotificationModel.fromJson({
        'id': 'n2',
        'notificationType': 'CLUB_SEAT_AVAILABLE',
        'notificationTitle': 'Table Available!',
        'notificationDescription': 'A table opened up',
        'metaData': {'clubId': 'club-2'},
      });
      expect(item.title, 'Table Available!');
      expect(item.subtitle, 'A table opened up');
      expect(
        NotificationRouter.normalize(item.routingData)['clubId'],
        'club-2',
      );
      expect(
        NotificationRouter.normalize({
          'data': '{"orderId":"order-1","serviceType":"EVENT"}',
        })['orderId'],
        'order-1',
      );
      expect(
        NotificationRouter.normalize({'data': 'invalid'})['data'],
        'invalid',
      );
      final guestListNotif = NotificationRouter.normalize({
        'notificationType': 'GUEST_LIST_CONFIRMED',
        'metaData': {
          'eventId': 'event-123',
          'entryId': 'entry-456',
          'status': 'CONFIRMED',
          'arrivalTime': 'Before 11:30 PM',
          'serviceType': 'EVENT',
        },
      });
      expect(guestListNotif['eventId'], 'event-123');
      expect(guestListNotif['entryId'], 'entry-456');
      expect(guestListNotif['status'], 'CONFIRMED');
      expect(guestListNotif['arrivalTime'], 'Before 11:30 PM');
    },
  );

  test(
    'event organizer association is preserved without treating event ID as club ID',
    () {
      final event = ExploreDetailModel.fromJson({
        'id': 'event-1',
        'eventName': 'Live night',
        'clubId': 'club-1',
        'organizer': {
          'id': 'club-1',
          'name': 'Night organizers',
          'followerCount': 42,
        },
      });
      expect(event.clubId, 'club-1');
      expect(event.associatedClubId, 'club-1');
      expect(event.organizer?['id'], 'club-1');
      expect(event.organizer?['followerCount'], 42);
      final unlinked = ExploreDetailModel.fromJson({'id': 'event-2'});
      expect(unlinked.organizer, isNull);
      expect(unlinked.clubId, isNull);
    },
  );

  test('booking list reads eventStartAt from the order row', () {
    final item = ExploreItemModel.fromJson({
      'id': 'a8dd9b6e-d87d-471a-a285-8d59976781aa',
      'purchaseDate': '2026-10-26T14:14:54.591Z',
      'eventStartAt': '2026-10-31T12:00:00.000Z',
      'eventEndAt': '2026-10-31T14:00:00.000Z',
      'name': 'updated test',
      'type': 'EVENT',
      'price': 70,
    });
    expect(item.id, 'a8dd9b6e-d87d-471a-a285-8d59976781aa');
    expect(item.startAt, DateTime.parse('2026-10-31T12:00:00.000Z'));
    expect(item.endAt, DateTime.parse('2026-10-31T14:00:00.000Z'));
    expect(item.toClubModel().isEvent, isTrue);
  });

  test('explore event detail reads ticket tiers and lineup without inventing ids', () {
    final event = ExploreDetailModel.fromJson({
      'id': 'event-1',
      'eventName': 'Neon night',
      'ticketTiers': [
        {
          'id': 'tier-1',
          'tierName': 'Early Bird',
          'price': 25,
          'capacity': 100,
          'sortOrder': 1,
        },
        {'tierName': 'Sold', 'price': 40, 'capacity': 10, 'soldCount': 10},
      ],
      'lineup': [
        {'artistName': 'DJ Snake', 'isVerified': true},
      ],
      'musicGenres': ['Techno', 'House'],
    });
    expect(event.ticketTiers, hasLength(2));
    expect(
      event.ticketTiers.firstWhere((tier) => tier.tierName == 'Early Bird').id,
      'tier-1',
    );
    expect(
      event.ticketTiers.firstWhere((tier) => tier.tierName == 'Sold').isSoldOut,
      isTrue,
    );
    expect(event.lineup.single.artistName, 'DJ Snake');
    expect(event.musicGenres, ['Techno', 'House']);
    expect(
      ExploreDetailModel.fromJson({
        'id': 'priced',
        'eventPrice': 50,
        'ticketTiers': [
          {'tierName': 'Family package', 'price': 70, 'capacity': 20},
          {'tierName': 'Friends', 'price': 120, 'capacity': 10},
        ],
      }).startingPrice,
      70,
    );
  });

  test('promo update body sends null clubId and eventId to make it global', () {
    final body = PromoRepository.mutationBody(
      code: 'night25',
      discountType: 'PERCENTAGE',
      discountValue: 20,
      maxUses: 5,
      clubId: '',
      eventId: null,
      expiresAt: null,
      isActive: true,
      isUpdate: true,
    );
    expect(body['code'], 'NIGHT25');
    expect(body['discountValue'], 20);
    expect(body['clubId'], isNull);
    expect(body['eventId'], isNull);
    expect(body['expiresAt'], isNull);
    expect(body['isActive'], isTrue);
    expect(EndPoint.promoById('abc'), '/promo/abc');
  });

  test('promo list keeps global codes when clubId and eventId are null', () {
    final promos = PromoListResponseModel.fromJson({
      'success': true,
      'message': 'Promo codes retrieved successfully',
      'meta': {'page': 1, 'limit': 20, 'total': 1, 'totalPages': 1},
      'data': [
        {
          'id': 'abb20f56-c3b9-49ca-b24c-4080daf53c4b',
          'code': 'NIGHT25',
          'discountType': 'PERCENTAGE',
          'discountValue': '20.00',
          'eventId': null,
          'clubId': null,
          'maxUses': 5,
          'usedCount': 0,
          'isActive': true,
        },
      ],
    });
    expect(promos.total, 1);
    expect(promos.totalPages, 1);
    expect(promos.data, hasLength(1));
    expect(promos.data.first.code, 'NIGHT25');
    expect(promos.data.first.discountValue, 20);
    expect(promos.data.first.discountLabel, '20% off');
    expect(promos.data.first.clubId, isEmpty);
    expect(promos.data.first.eventId, isEmpty);
    expect(promos.data.first.appliesToLabel, 'All clubs and events');
  });

  test('promo list reads percentage, fixed amount and usage', () {
    final promos = PromoListResponseModel.fromJson({
      'success': true,
      'data': [
        {
          'id': 'p1',
          'code': 'NIGHT10',
          'discountType': 'PERCENTAGE',
          'discountValue': '10.00',
          'maxUses': 100,
          'usedCount': 3,
          'club': {'id': 'c1', 'name': 'Starlight'},
        },
        {
          'code': 'FLAT5',
          'discountType': 'FIXED_AMOUNT',
          'discountValue': '5.00',
          'maxUses': 20,
          'eventName': 'Sample team sync',
        },
      ],
    });
    expect(promos.data, hasLength(2));
    expect(promos.data.first.discountLabel, '10% off');
    expect(promos.data.first.appliesToLabel, 'Club · Starlight');
    expect(promos.data.first.usedCount, 3);
    expect(promos.data.last.discountLabel, '€5 off');
    expect(promos.data.last.appliesToLabel, 'Event · Sample team sync');
  });

  test('owner event detail keeps club, tiers, lineup and genres', () {
    final event = EventDataModel.fromJson({
      'id': 'event-1',
      'eventName': 'updated test',
      'club': {'id': 'club-1', 'name': 'Starlight'},
      'ticketTiers': [
        {
          'tierName': 'Early Bird',
          'groupName': 'Pass 2 jours',
          'price': '20.00',
          'capacity': 50,
          'soldCount': 50,
          'sortOrder': 1,
          'isActive': false,
        },
      ],
      'lineup': [
        {'artistName': 'DJ Test'},
      ],
      'musicGenres': ['House', 'Techno'],
      'eventPrice': 50,
      'startAt': '2026-10-31T18:00:00.000Z',
      'endAt': '2026-10-31T20:00:00.000Z',
    });
    expect(event.clubId, 'club-1');
    expect(event.clubName, 'Starlight');
    expect(event.ticketTiers.single.tierName, 'Early Bird');
    expect(event.ticketTiers.single.groupName, 'Pass 2 jours');
    expect(event.ticketTiers.single.isSoldOut, isTrue);
    expect(event.ticketTiers.single.isActive, isFalse);
    expect(event.eventPrice, 50);
    expect(event.lineup.single.artistName, 'DJ Test');
    expect(event.musicGenres, ['House', 'Techno']);

    final wrapped = EventDataModel.fromJson({
      'id': 'event-2',
      'eventName': 'wrapped extras',
      'eventPrice': 40,
      'startAt': '2026-10-31T18:00:00.000Z',
      'endAt': '2026-10-31T20:00:00.000Z',
      'ticketTiers': {
        'data': [
          {'name': 'VIP', 'price': 90, 'capacity': 10},
        ],
      },
      'lineup': 'DJ A, DJ B',
    });
    expect(wrapped.ticketTiers.single.tierName, 'VIP');
    expect(wrapped.lineup.map((artist) => artist.artistName), ['DJ A', 'DJ B']);

    final ownerOmitsOffers = EventDataModel.fromJson({
      'id': '003a6ddf-ca5b-44a1-8faa-fe11c93c5908',
      'eventName': 'updated test',
      'eventPrice': '15',
      'startAt': '2026-10-31T12:00:00.000Z',
      'endAt': '2026-10-31T14:00:00.000Z',
    });
    final fromExplore = EventDataModel.fromJson({
      'id': '003a6ddf-ca5b-44a1-8faa-fe11c93c5908',
      'eventName': 'updated test',
      'eventPrice': '15',
      'startAt': '2026-10-31T12:00:00.000Z',
      'endAt': '2026-10-31T14:00:00.000Z',
      'ticketTiers': [
        {
          'id': '7cea0cdf-e4ce-4b49-9610-8b68f1d0826b',
          'tierName': 'Test ticket',
          'groupName': 'test group',
          'price': '15',
          'capacity': 5,
          'soldCount': 0,
          'sortOrder': 1,
          'isActive': true,
        },
      ],
      'lineup': [
        {
          'id': '1ac512ef-b646-4608-a0fd-183e8c14fca3',
          'artistName': 'Pritom',
          'spotifyUrl':
              'https://open.spotify.com/artist/037oCHf26WEq5mR05NoOO7',
          'sortOrder': 1,
        },
      ],
    });
    final merged = ownerOmitsOffers.withOffersFrom(fromExplore);
    expect(merged.ticketTiers.single.tierName, 'Test ticket');
    expect(merged.ticketTiers.single.groupName, 'test group');
    expect(merged.ticketTiers.single.price, 15);
    expect(merged.lineup.single.artistName, 'Pritom');
  });

  test('4xx client errors surface the server message', () {
    expect(
      ApiErrorHandler.extractErrorMessage({
        'success': false,
        'message': 'Club not found or inactive',
        'traceId': 't1',
      }),
      'Club not found or inactive',
    );
    expect(
      ApiErrorHandler.extractErrorMessage({
        'success': false,
        'message': 'Request body validation failed',
        'errors': [
          {'field': 'clubId', 'message': 'clubId must be a UUID'},
        ],
      }),
      'clubId: clubId must be a UUID',
    );
    expect(
      clientErrorMessage(
        UnauthorizedException(
          'Invalid Credential,Check Your Email And Password',
          401,
        ),
        'Login failed. Please try again.',
      ),
      'Invalid Credential,Check Your Email And Password',
    );
    expect(
      clientErrorMessage(
        ValidationException('Club not found or inactive', 404),
        'Could not update waiting list. Please try again.',
      ),
      'Club not found or inactive',
    );
    expect(
      clientErrorMessage(
        ServerException('Internal Server Error'),
        'Could not update waiting list. Please try again.',
      ),
      'Could not update waiting list. Please try again.',
    );
  });

  test('auth session prefers login token over accessToken', () {
    expect(
      AuthRepository.sessionToken({'token': 'login-jwt', 'accessToken': 'old'}),
      'login-jwt',
    );
    expect(AuthRepository.sessionToken({'token': 'legacy'}), 'legacy');
  });

  test('explore query sends categoryType, dateFilter, genres and isFree', () {
    final params = const ExploreQueryModel(
      type: 'EVENT',
      categoryType: 'FESTIVAL',
      dateFilter: 'this_weekend',
      genre: 'Techno,House',
      city: 'Dhaka',
      isFree: true,
      maximumPrice: 0,
    ).toQueryParameters();
    expect(params['type'], 'EVENT');
    expect(params['categoryType'], 'FESTIVAL');
    expect(params['dateFilter'], 'this_weekend');
    expect(params['genres'], 'Techno,House');
    expect(params['city'], 'Dhaka');
    expect(params['isFree'], true);
    expect(params.containsKey('maxPrice'), isFalse);
    expect(params.containsKey('date'), isFalse);
  });

  test('this weekend uses Saturday of the current week', () {
    expect(
      ExploreController.weekendSaturday(DateTime(2026, 10, 26)),
      DateTime(2026, 10, 31),
    );
  });

  test('door QR payload is the raw order UUID', () {
    const id = '003a6ddf-aaaa-bbbb-cccc-1234567890ab';
    expect(TicketScannerRepository.extractOrderId(id), id);
    expect(
      TicketScannerRepository.extractOrderId(
        'https://bookdianight.localbox.online/ticket/$id',
      ),
      id,
    );
  });

  test('purchase result prefers top-level orderId over bookingId', () {
    final purchase = ClubPurchaseResult.fromJson({
      'orderId': 'order-uuid',
      'bookingId': 'booking-uuid',
      'order': {'id': 'nested-order', 'buyerTotal': '85.50', 'currency': 'EUR'},
      'booking': {'id': 'nested-booking'},
    });
    expect(purchase.orderId, 'order-uuid');
    expect(purchase.bookingId, 'booking-uuid');
    expect(purchase.orderId, isNot(purchase.bookingId));
  });

  test('module purchase keeps orderId for payment intent', () {
    final purchase = ClubPurchaseResult.fromJson({
      'orderId': 'module-order-uuid',
      'eventModulePurchase': {'id': 'module-purchase-uuid'},
      'order': {'id': 'nested-order', 'buyerTotal': '150.00', 'currency': 'EUR'},
    });
    expect(purchase.orderId, 'module-order-uuid');
    expect(purchase.bookingId, 'module-purchase-uuid');
    expect(EndPoint.paymentIntent, '/payment/intent');
    expect(EndPoint.purchaseModule, '/purchase/module');
  });

  test('quote and host contact require lowercase message', () {
    final quote = EventCommerceRepository.quoteBody(
      eventId: 'event-1',
      moduleId: 'module-1',
      name: 'Sofia',
      email: 'sofia@example.com',
      phone: '+390415238912',
      guestCount: 8,
      message: 'Need a skybar for 8',
      date: DateTime.utc(2026, 11, 30, 20),
    );
    expect(quote['message'], 'Need a skybar for 8');
    expect(quote.containsKey('Message'), isFalse);
    expect(quote['date'], '2026-11-30T20:00:00.000Z');
    expect(
      () => EventCommerceRepository.quoteBody(
        eventId: 'event-1',
        moduleId: 'module-1',
        name: 'Sofia',
        email: 'sofia@example.com',
        phone: '+390415238912',
        guestCount: 8,
        message: '  ',
      ),
      throwsArgumentError,
    );

    final contact = EventCommerceRepository.hostContactBody(
      name: 'Sofia',
      email: 'sofia@example.com',
      phone: '+390415238912',
      message: 'Can we arrange a water taxi?',
    );
    expect(contact['message'], 'Can we arrange a water taxi?');
    expect(contact.containsKey('Message'), isFalse);
    expect(EndPoint.hostContact('host-1'), '/hosts/host-1/contact');
    expect(EndPoint.eventHosts('event-1'), '/event/event-1/hosts');
    expect(
      '${EndPoint.eventHosts('event-1')}/host-1',
      '/event/event-1/hosts/host-1',
    );
    expect(
      EventQuoteModel.fromJson({
        'id': 'q1',
        'Message': 'Need a skybar for 8',
      }).message,
      'Need a skybar for 8',
    );
  });

  test('booking detail keeps orderId for the door QR', () {
    final detail = BookingDetailModel.fromJson({
      'id': 'booking-1',
      'orderId': '003a6ddf-aaaa-bbbb-cccc-1234567890ab',
      'booking': {'status': 'UPCOMING', 'ticketState': 'READY'},
    });
    expect(detail.orderId, '003a6ddf-aaaa-bbbb-cccc-1234567890ab');
    expect(detail.ticketReady, isTrue);
    expect(
      BookingDetailModel.fromJson({
        'id': 'booking-1',
        'eventId': 'event-1',
        'booking': {'status': 'UPCOMING', 'ticketState': 'READY'},
      }).orderId,
      isEmpty,
    );
  });

  test('club follow never uses organizer or event IDs as club IDs', () {
    final event = ExploreDetailModel.fromJson({
      'id': 'event-1',
      'organizer': {'id': 'owner-1', 'name': 'Owner'},
    });
    expect(event.associatedClubId, isNull);
    final linked = ExploreDetailModel.fromJson({
      'id': 'event-1',
      'club': {'id': 'club-1', 'name': 'Club'},
    });
    expect(linked.associatedClubId, 'club-1');
  });

  testWidgets('joining shows queue position, then leaving clears membership', (
    tester,
  ) async {
    final repository = QueueRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WaitingListPanel(
            clubId: 'club-1',
            canJoin: true,
            startAt: DateTime.utc(2026, 11, 27, 22, 0, 0),
            guestCount: 4,
            repository: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Join waiting list'));
    await tester.pumpAndSettle();
    expect(find.textContaining('#2'), findsOneWidget);
    expect(find.text('Leave waiting list'), findsOneWidget);
    expect(repository.bodies.first, {
      'clubId': 'club-1',
      'startAt': '2026-11-27T22:00:00.000Z',
      'guestCount': 4,
    });
    await tester.tap(find.text('Leave waiting list'));
    await tester.pumpAndSettle();
    expect(find.text('Join waiting list'), findsOneWidget);
    expect(repository.mutations, ['/waiting-list/join', '/waiting-list/leave']);
    expect(tester.takeException(), isNull);
  });

  test('owner waiting-list routes use entry id, never guest /my or /status', () {
    expect(
      EndPoint.waitingListClub('club-1'),
      '/waiting-list/club/club-1',
    );
    expect(EndPoint.waitingListClub('club-1').contains('/status'), isFalse);
    expect(
      EndPoint.waitingListNotify('entry-9'),
      '/waiting-list/entry-9/notify',
    );
    expect(EndPoint.waitingListEntry('entry-9'), '/waiting-list/entry-9');
    expect(EndPoint.waitingList.contains('/my'), isFalse);
  });

  test('owner waiting-list page parses nested user, position, and status', () {
    final page = OwnerWaitingListPage.fromJson({
      'success': true,
      'message': 'Waiting list retrieved successfully',
      'meta': {'page': 1, 'limit': 20, 'total': 1, 'totalPages': 1},
      'data': [
        {
          'id': 'entry-1',
          'userId': 'user-2',
          'clubId': 'club-3',
          'position': 1,
          'status': 'PENDING',
          'createdAt': '2026-11-01T03:14:27.540Z',
          'startAt': '2026-11-27T22:00:00.000Z',
          'guestCount': 4,
          'user': {
            'id': 'user-2',
            'name': 'Lorenzo',
            'email': 'tilib60678@hudzer.com',
            'phoneNumber': '+393515974949',
            'profileAvatar': null,
          },
        },
      ],
    });
    expect(page.total, 1);
    expect(page.totalPages, 1);
    expect(page.data, hasLength(1));
    final entry = page.data.single;
    expect(entry.id, 'entry-1');
    expect(entry.userId, 'user-2');
    expect(entry.id, isNot(entry.userId));
    expect(entry.position, 1);
    expect(entry.status, OwnerWaitingListStatus.pending);
    expect(entry.startAt, DateTime.utc(2026, 11, 27, 22, 0, 0));
    expect(entry.guestCount, 4);
    expect(entry.user.displayName, 'Lorenzo');
    expect(entry.user.contactLine, 'tilib60678@hudzer.com');
    expect(entry.user.profileAvatar, isNull);
  });

  test('owner waiting-list notify payload flips NOTIFIED on the entry id', () {
    final notified = OwnerWaitingListEntry.fromJson({
      'id': 'entry-1',
      'userId': 'user-2',
      'clubId': 'club-3',
      'position': 1,
      'status': 'NOTIFIED',
      'createdAt': '2026-11-01T03:14:27.540Z',
      'user': {
        'id': 'user-2',
        'name': 'Lorenzo',
        'email': 'tilib60678@hudzer.com',
        'phoneNumber': '+393515974949',
        'profileAvatar': 'https://cdn.example/a.png',
      },
    });
    expect(notified.id, 'entry-1');
    expect(notified.isNotified, isTrue);
    expect(notified.status.label, 'Notified');
    expect(notified.user.profileAvatar, 'https://cdn.example/a.png');
    expect(notified.user.initials, 'L');
  });

  testWidgets(
    'club profile never offers joining without unavailable inventory',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WaitingListPanel(
              clubId: 'club-1',
              repository: QueueRepository(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Join waiting list'), findsNothing);
    },
  );

  test('event detail parses nested tiers, modules, guest list, hosts and artist', () {
    final event = ExploreDetailModel.fromJson({
      'id': 'event-1',
      'bookingsClosed': false,
      'moodTags': ['dark', 'warehouse'],
      'ticketTiers': [
        {
          'id': 'parent-uuid',
          'tierName': 'Service VIP',
          'price': '110.00',
          'soldOut': false,
          'children': [
            {
              'id': 'child-uuid',
              'tierName': 'Service Child',
              'price': '75.00',
              'soldOut': false,
              'children': [],
            },
            {
              'id': 'sold-uuid',
              'tierName': 'Service SoldOut',
              'price': '95.00',
              'capacity': 1,
              'soldCount': 1,
              'soldOut': true,
              'children': [],
            },
          ],
        },
      ],
      'modules': [
        {
          'id': 'module-uuid',
          'name': 'VIP Skybar',
          'startingPrice': '150.00',
          'status': 'AVAILABLE',
          'remaining': 5,
          'isActive': true,
        },
      ],
      'guestList': {
        'isOpen': false,
        'fallbacks': [
          {'type': 'TICKET_TIER', 'id': 'child-uuid', 'label': 'General'},
        ],
      },
      'hosts': [
        {'id': 'host-uuid', 'name': 'Marco', 'isVerified': true},
      ],
      'lineup': [
        {
          'id': 'lineup-uuid',
          'artistId': 'artist-uuid',
          'artistName': 'Phase6 DJ Nova',
          'artist': {
            'id': 'artist-uuid',
            'name': 'Phase6 DJ Nova',
            'followerCount': 1,
            'isVerified': true,
          },
        },
      ],
    });
    expect(event.ticketTiers.single.children, hasLength(2));
    expect(event.ticketTiers.single.children.last.isSoldOut, isTrue);
    expect(event.startingPrice, 75);
    expect(event.modules.single.canBook, isTrue);
    final soldOutModule = EventVipModuleModel.fromJson({
      'id': 'sold-mod',
      'name': 'Noble Table',
      'status': 'SOLD_OUT',
      'remaining': 0,
      'quantity': 2,
    });
    expect(soldOutModule.isSoldOut, isTrue);
    expect(soldOutModule.canBook, isFalse);
    expect(soldOutModule.statusLabel, 'Sold out');
    expect(event.guestList?.isOpen, isFalse);
    expect(event.guestList?.fallbacks.single.isTicket, isTrue);
    expect(event.hosts.single.name, 'Marco');
    expect(event.lineup.single.followId, 'artist-uuid');
    expect(event.moodTags, ['dark', 'warehouse']);
    expect(event.bookingsClosed, isFalse);
  });

  test('phase 2-6 routes keep purchase orderId and follow artist id', () {
    expect(EndPoint.purchaseModule, '/purchase/module');
    expect(EndPoint.artistFollow('artist-9'), '/artists/artist-9/follow');
    expect(EndPoint.meArtists, '/me/artists');
    expect(EndPoint.quotes, '/quotes');
    expect(EndPoint.eventGuestListJoin('e1'), '/event/e1/guest-list/join');
    expect(EndPoint.eventModules('e1'), '/event/e1/modules');
    expect(EndPoint.eventDuplicate('e1'), '/event/e1/duplicate');
    expect(
      EndPoint.eventBookingsClose('e1'),
      '/event/e1/bookings/close',
    );
    expect(
      const ExploreQueryModel(type: 'EVENT', mood: 'phase6mood')
          .toQueryParameters()['mood'],
      'phase6mood',
    );
  });

  test('club PUT creates packages without id and removes with isActive false', () {
    final open = DateTime(1970, 1, 1, 20);
    final close = DateTime(1970, 1, 1, 2);
    final body = ClubUpsertRequestModel(
      name: 'Test Club',
      description: 'Desc',
      location: 'Rome',
      thumbnail: 'https://img',
      images: const [],
      dressCode: 'Smart',
      isRecurring: true,
      isVip: true,
      latitude: 1,
      longitude: 2,
      isActive: false,
      openingHours: [
        ClubOpeningHourModel(
          dayOfWeek: 0,
          isClosed: true,
          openTime: open,
          closeTime: close,
          closesNextDay: true,
        ),
        ClubOpeningHourModel(
          id: 'hour-1',
          dayOfWeek: 1,
          isClosed: false,
          openTime: open,
          closeTime: close,
          closesNextDay: true,
        ),
      ],
      packages: [
        ClubPackageModel(
          id: 'vip-id',
          name: 'VIP',
          description: 'Keep',
          capacity: 4,
          price: 100,
          currency: 'EUR',
          features: ['Sofa'],
          sortOrder: 0,
        ),
        ClubPackageModel(
          name: 'New outdoor',
          description: 'Create',
          capacity: 2,
          price: 50,
          currency: 'EUR',
          features: ['View'],
          sortOrder: 1,
        ),
        ClubPackageModel(
          id: 'outdoor-id',
          name: 'Outdoor',
          description: 'Remove',
          capacity: 6,
          price: 80,
          currency: 'EUR',
          features: ['Garden'],
          sortOrder: 2,
          isActive: false,
        ),
      ],
    ).toJson(isUpdate: true);

    expect(body['isActive'], isFalse);
    expect(body['packages'][0]['id'], 'vip-id');
    expect(body['packages'][0]['isActive'], isTrue);
    expect(body['packages'][1].containsKey('id'), isFalse);
    expect(body['packages'][1]['isActive'], isTrue);
    expect(body['packages'][2]['id'], 'outdoor-id');
    expect(body['packages'][2]['isActive'], isFalse);
    expect(body['openingHours'][0].containsKey('id'), isFalse);
    expect(body['openingHours'][1]['id'], 'hour-1');
    expect(
      ClubUpsertRequestModel(
        name: 'Test Club',
        description: 'Desc',
        location: 'Rome',
        thumbnail: 'https://img',
        images: const [],
        dressCode: 'Smart',
        isRecurring: true,
        isVip: true,
        latitude: 1,
        longitude: 2,
        openingHours: const [],
        packages: [],
      ).toJson(isUpdate: false).containsKey('isActive'),
      isFalse,
    );
    expect(
      ClubDataModel.fromJson({
        'id': 'c1',
        'deactivatedAt': '2026-11-01T10:00:00.000Z',
        'isActive': false,
      }).isActive,
      isFalse,
    );
    expect(
      ClubDataModel.fromJson({
        'id': 'c1',
        'name': 'List stub',
      }).activeFlagPresent,
      isFalse,
    );
    expect(
      ClubDataModel.fromJson({
        'id': 'c1',
        'deactivatedAt': '2026-11-01T09:24:04.288Z',
      }).isActive,
      isFalse,
    );
    expect(
      ClubMutationResponseModel.fromJson({
        'success': true,
        'message': 'Club updated successfully',
        'data': {
          'id': 'c1',
          'deactivatedAt': '2026-11-01T09:24:04.288Z',
        },
      }).isActive,
      isFalse,
    );
    expect(
      EventCommerceRepository.exportUrlFrom({
        'success': true,
        'message': 'Bookings export ready',
        'data': {
          'downloadUrl':
              'https://cdn.example/exports/bookings.csv',
          'count': 0,
        },
      }),
      'https://cdn.example/exports/bookings.csv',
    );
  });

  test('guest list, quote and payment models parse enriched and backend fields', () {
    // Guest list isEnabled / isOpen compatibility
    final glEnabled = EventGuestListModel.fromJson({'isEnabled': true});
    final glOpen = EventGuestListModel.fromJson({'isOpen': true});
    final glClosed = EventGuestListModel.fromJson({'isEnabled': false, 'isOpen': false});
    expect(glEnabled.isOpen, isTrue);
    expect(glOpen.isOpen, isTrue);
    expect(glClosed.isOpen, isFalse);

    // Quote model enriched fields
    final quote = EventQuoteModel.fromJson({
      'id': 'q1',
      'eventId': 'ev-1',
      'moduleId': 'mod-1',
      'name': 'Ziaul',
      'eventName': 'Midnight Mirage',
      'moduleName': 'Guest Pass',
      'status': 'REPLIED',
    });
    expect(quote.eventName, 'Midnight Mirage');
    expect(quote.moduleName, 'Guest Pass');
    expect(quote.status, 'REPLIED');

    // Owner payment item venue and tier resolution
    final payment = OwnerPaymentItem.fromJson({
      'id': 'p1',
      'type': 'EVENT',
      'title': 'Guest Pass',
      'customerName': 'Ziaul Hoque',
      'amount': '96.00',
      'eventName': 'Midnight Mirage',
      'tierName': 'Guest Pass',
      'createdAt': '2026-11-01T17:50:00Z',
    });
    expect(payment.eventName, 'Midnight Mirage');
    expect(payment.tierName, 'Guest Pass');
    expect(payment.venueName, 'Midnight Mirage');
    expect(payment.subtitle, contains('Midnight Mirage • Ziaul Hoque'));

    // Event VIP module toPayload excludes 'id' so backend PUT validation does not fail with 422
    const module = EventVipModuleModel(
      id: 'mod-123',
      name: 'Guest Pass',
      startingPrice: '120.00',
    );
    expect(module.toPayload().containsKey('id'), isFalse);
    expect(module.toPayload(includeId: true)['id'], 'mod-123');

    // Guest list entry parses party demographics including otherCount
    final entry = EventGuestListEntry.fromJson({
      'id': 'entry-1',
      'name': 'Riad',
      'email': 'riad@example.com',
      'menCount': 2,
      'womenCount': 3,
      'otherCount': 1,
      'arrivalTime': 'Before 11:30 PM',
      'status': 'CONFIRMED',
    });
    expect(entry.menCount, 2);
    expect(entry.womenCount, 3);
    expect(entry.otherCount, 1);
    expect(entry.arrivalTime, 'Before 11:30 PM');
    expect(entry.status, 'CONFIRMED');

    // Guest list model parses used breakdown including other
    final guestListWithUsed = EventGuestListModel.fromJson({
      'isEnabled': true,
      'used': {
        'men': 5,
        'women': 4,
        'other': 1,
        'total': 10,
      },
    });
    expect(guestListWithUsed.used?.men, 5);
    expect(guestListWithUsed.used?.women, 4);
    expect(guestListWithUsed.used?.other, 1);
    expect(guestListWithUsed.used?.total, 10);
  });

  test('host inquiry model, endpoint, and routing payload parsing', () {
    expect(
      EndPoint.eventHostInquiries('ev-123'),
      '/event/ev-123/host-inquiries',
    );

    final item = EventHostInquiryModel.fromJson({
      'id': 'inq-99',
      'hostId': 'host-1',
      'hostName': 'Sofia bellini',
      'customerName': 'John Doe',
      'customerEmail': 'john@example.com',
      'customerPhone': '+1234567890',
      'message': 'Interested in booking table 5 with bottle service',
      'createdAt': '2026-11-03T09:30:00.000Z',
      'eventId': 'ev-123',
    });

    expect(item.id, 'inq-99');
    expect(item.hostId, 'host-1');
    expect(item.hostName, 'Sofia bellini');
    expect(item.customerName, 'John Doe');
    expect(item.customerEmail, 'john@example.com');
    expect(item.customerPhone, '+1234567890');
    expect(item.message, 'Interested in booking table 5 with bottle service');
    expect(item.createdAt?.toUtc().hour, 9);
    expect(item.eventId, 'ev-123');

    final list = EventHostInquiryModel.listFrom([
      {'id': 'inq-1', 'customerName': 'Alice'},
      {'id': 'inq-2', 'customerName': 'Bob'},
      {'id': ''},
      'not-a-map',
    ]);
    expect(list.length, 2);
    expect(list.first.customerName, 'Alice');

    final normalized = NotificationRouter.normalize({
      'notificationType': 'HOST_INQUIRY',
      'metadata': {
        'eventId': 'ev-abc',
        'hostId': 'host-xyz',
        'inquiryId': 'inq-100',
        'customerPhone': '+123456',
        'customerEmail': 'guest@test.com',
      },
    });
    expect(normalized['notificationType'], 'HOST_INQUIRY');
    expect(normalized['eventId'], 'ev-abc');
    expect(normalized['hostId'], 'host-xyz');
    expect(normalized['inquiryId'], 'inq-100');
    expect(normalized['customerPhone'], '+123456');
    expect(normalized['customerEmail'], 'guest@test.com');
  });
}
