import 'package:flutter/material.dart';

import '../controllers/owner_activity_controller.dart';
import 'add_club_view.dart';

class EditClubView extends StatelessWidget {
  const EditClubView({super.key, required this.item});

  final ActivityItemModel item;

  @override
  Widget build(BuildContext context) {
    return AddClubView(item: item);
  }
}
