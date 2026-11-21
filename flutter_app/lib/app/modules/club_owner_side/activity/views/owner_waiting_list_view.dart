import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/resources/common_widget/compact_empty_state.dart';
import '../../../../core/resources/common_widget/custom_text.dart';
import '../../../../core/resources/common_widget/theme_shimmer.dart';
import '../controllers/owner_waiting_list_controller.dart';
import '../model/owner_waiting_list_model.dart';
import '../widgets/owner_waiting_list_tile.dart';

class OwnerWaitingListView extends StatefulWidget {
  const OwnerWaitingListView({
    super.key,
    required this.clubId,
    this.clubName = '',
  });

  final String clubId;
  final String clubName;

  @override
  State<OwnerWaitingListView> createState() => _OwnerWaitingListViewState();
}

class _OwnerWaitingListViewState extends State<OwnerWaitingListView> {
  static const _gold = Color(0xFFDCA73A);
  late final OwnerWaitingListController _controller;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    if (Get.isRegistered<OwnerWaitingListController>(tag: widget.clubId)) {
      Get.delete<OwnerWaitingListController>(tag: widget.clubId);
    }
    _controller = Get.put(
      OwnerWaitingListController(clubId: widget.clubId),
      tag: widget.clubId,
    );
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    if (Get.isRegistered<OwnerWaitingListController>(tag: widget.clubId)) {
      Get.delete<OwnerWaitingListController>(tag: widget.clubId);
    }
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 240) {
      _controller.fetch();
    }
  }

  Future<void> _confirmRemove(OwnerWaitingListEntry entry) async {
    final name = entry.user.displayName;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161616),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const CustomText(
          text: 'Remove from queue?',
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        content: CustomText(
          text: '$name will be removed from this club waiting list.',
          color: Colors.white70,
          fontSize: 14,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Remove',
              style: TextStyle(
                color: Color(0xFFE57373),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) await _controller.remove(entry);
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = widget.clubName.trim();
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        surfaceTintColor: Colors.transparent,
        title: Column(
          children: [
            const CustomText(
              text: 'Waiting list',
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
            if (subtitle.isNotEmpty)
              CustomText(
                text: subtitle,
                color: Colors.white54,
                fontSize: 12,
              ),
          ],
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Obx(() {
        if (_controller.isLoading.value && _controller.entries.isEmpty) {
          return const _QueueShimmer();
        }
        if (_controller.entries.isEmpty) {
          return RefreshIndicator(
            color: _gold,
            backgroundColor: const Color(0xFF161616),
            onRefresh: () => _controller.fetch(refresh: true),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.18),
                _emptyState(),
              ],
            ),
          );
        }
        return RefreshIndicator(
          color: _gold,
          backgroundColor: const Color(0xFF161616),
          onRefresh: () => _controller.fetch(refresh: true),
          child: ListView.builder(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            itemCount:
                _controller.entries.length +
                (_controller.isLoadingMore.value ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= _controller.entries.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _gold,
                      ),
                    ),
                  ),
                );
              }
              final entry = _controller.entries[index];
              return OwnerWaitingListTile(
                entry: entry,
                notifying: _controller.notifyingIds.contains(entry.id),
                removing: _controller.removingIds.contains(entry.id),
                onNotify: () => _controller.notify(entry),
                onRemove: () => _confirmRemove(entry),
              );
            },
          ),
        );
      }),
    );
  }

  Widget _emptyState() {
    if (_controller.forbidden.value) {
      return CompactEmptyState.stacked(
        icon: Icons.lock_outline,
        title: "You don't own this club",
        message: _controller.errorMessage.value.isEmpty
            ? 'Only the club owner can manage this queue.'
            : _controller.errorMessage.value,
      );
    }
    if (_controller.notFound.value) {
      return CompactEmptyState.stacked(
        icon: Icons.storefront_outlined,
        title: 'Club not found',
        message: _controller.errorMessage.value.isEmpty
            ? 'This club is no longer available.'
            : _controller.errorMessage.value,
      );
    }
    if (_controller.errorMessage.value.isNotEmpty) {
      return CompactEmptyState.stacked(
        icon: Icons.error_outline,
        title: 'Could not load queue',
        message: _controller.errorMessage.value,
        action: TextButton(
          onPressed: () => _controller.fetch(refresh: true),
          child: const CustomText(
            text: 'Retry',
            color: _gold,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    return const CompactEmptyState.stacked(
      icon: Icons.hourglass_empty,
      title: 'No one is waiting',
      message: 'Guests who join this club queue will appear here.',
    );
  }
}

class _QueueShimmer extends StatelessWidget {
  const _QueueShimmer();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      itemCount: 6,
      itemBuilder: (_, _) => const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: ThemeShimmer(
          child: ShimmerBone(height: 118, radius: 18),
        ),
      ),
    );
  }
}
