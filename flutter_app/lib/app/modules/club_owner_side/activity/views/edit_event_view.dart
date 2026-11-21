import 'package:flutter/material.dart';

import '../controllers/owner_activity_controller.dart';
import 'add_event_view.dart';

class EditEventView extends StatelessWidget {
  const EditEventView({super.key, required this.item});

  final ActivityItemModel item;

  @override
  Widget build(BuildContext context) {
    return AddEventView(item: item);
  }
}
