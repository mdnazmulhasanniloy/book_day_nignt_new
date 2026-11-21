import 'package:flutter/material.dart';
import '../../home/model/club_model.dart';
import 'club_details_view.dart';

/// Event entry point, sharing the existing details presentation and checkout.
class EventDetailsView extends StatelessWidget {
  const EventDetailsView({
    super.key,
    required this.clubModel,
    this.isFavorite,
    this.initialTab,
  });
  final ClubModel clubModel;
  final bool? isFavorite;
  final String? initialTab;

  @override
  Widget build(BuildContext context) => VenueDetailsView(
    clubModel: clubModel,
    isFavorite: isFavorite,
    initialTab: initialTab,
  );
}
