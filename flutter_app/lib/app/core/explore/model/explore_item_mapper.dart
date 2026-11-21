import '../../../modules/user_side/home/model/club_model.dart';
import '../repository/explore_api_repository.dart';
import 'explore_api_model.dart';

extension ExploreItemMapper on ExploreItemModel {
  ClubModel toClubModel() {
    final isEvent = type.toUpperCase() == 'EVENT';
    // EVENT → `price`, CLUB → `priceRange.minPrice` (mapped to minimumPrice)
    final amount = isEvent ? price : minimumPrice;
    final priceLabel = amount == null ? '' : _formatMoney(amount);
    final locationLabel = (location ?? '').trim();
    final tags = <String>[if (isVip) 'VIP'];

    return ClubModel(
      id: id,
      image: image,
      title: name,
      location: locationLabel,
      rating: isEvent ? '' : _ratingLabel(review),
      price: priceLabel,
      type: _displayType(type),
      tags: tags.isEmpty ? null : tags,
      latitude: latitude,
      longitude: longitude,
      isWishlist: isWishlist,
      isVip: isVip,
      startAt: _usableDate(startAt),
      endAt: _usableDate(endAt),
    );
  }

  static String _displayType(String raw) {
    switch (raw.toUpperCase()) {
      case 'EVENT':
        return 'Event';
      case 'CLUB':
        return 'Club';
      default:
        return raw.isEmpty ? 'Club' : raw;
    }
  }

  static String _ratingLabel(double? review) {
    final value = review ?? 0;
    if (value == 0) return '0';
    return value.toStringAsFixed(1);
  }

  static DateTime? _usableDate(DateTime? value) {
    if (value == null || value.year < 2000) return null;
    return value;
  }

  static String _formatMoney(double amount) {
    final value = amount % 1 == 0
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(2);
    return '€$value';
  }
}

Future<List<ClubModel>> withEventSchedules(List<ClubModel> items) async {
  if (!items.any((item) => item.isEvent && item.startAt == null)) {
    return items;
  }
  final repository = ExploreApiRepository();
  return Future.wait(
    items.map((item) async {
      if (!item.isEvent || item.startAt != null) return item;
      try {
        final response = await repository.getExploreDetails(
          id: item.id,
          type: 'EVENT',
        );
        final detail = response.data;
        final start = detail?.startAt;
        if (detail == null || start == null || start.year < 2000) return item;
        return item.copyWith(startAt: start, endAt: detail.endAt);
      } catch (_) {
        return item;
      }
    }),
  );
}
