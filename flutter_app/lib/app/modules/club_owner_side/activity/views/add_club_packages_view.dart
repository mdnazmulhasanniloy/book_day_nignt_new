import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/resources/common_widget/custom_app_bar.dart';
import '../../../../core/resources/common_widget/custom_button.dart';
import '../../../../core/resources/common_widget/custom_text.dart';
import '../../../../core/resources/common_widget/custom_text_field.dart';
import '../../../../core/utils/custom_snack_bar.dart';
import '../../../../services/media_service.dart';
import '../controllers/owner_activity_controller.dart';
import '../model/club_upsert_model.dart';
import '../repository/club_repository.dart';

class AddClubPackagesView extends StatefulWidget {
  const AddClubPackagesView({super.key, required this.draft});

  final ClubDraftModel draft;

  @override
  State<AddClubPackagesView> createState() => _AddClubPackagesViewState();
}

class _AddClubPackagesViewState extends State<AddClubPackagesView> {
  final packageNameController = TextEditingController();
  final packageDescriptionController = TextEditingController();
  final capacityController = TextEditingController();
  final priceController = TextEditingController();
  final featureInputController = TextEditingController();
  final features = <String>[].obs;
  final packages = <ClubPackageModel>[].obs;
  final List<ClubPackageModel> _deactivatedPackages = [];
  final ClubRepository _repository = ClubRepository();

  int? _editingIndex;
  bool _isPublishing = false;

  bool get _hasPackageInput =>
      packageNameController.text.trim().isNotEmpty ||
      packageDescriptionController.text.trim().isNotEmpty ||
      capacityController.text.trim().isNotEmpty ||
      priceController.text.trim().isNotEmpty ||
      features.isNotEmpty;

  @override
  void initState() {
    super.initState();
    packages.assignAll(
      widget.draft.existingPackages.where((package) => package.isActive),
    );
    _deactivatedPackages.addAll(
      widget.draft.existingPackages.where((package) => !package.isActive),
    );
  }

  void _addFeature() {
    final feature = featureInputController.text.trim();
    if (feature.isEmpty) return;
    if (!features.any((item) => item.toLowerCase() == feature.toLowerCase())) {
      features.add(feature);
    }
    featureInputController.clear();
  }

  bool _savePackage() {
    _addFeature();
    final name = packageNameController.text.trim();
    final description = packageDescriptionController.text.trim();
    final capacity = int.tryParse(capacityController.text.trim());
    final price = double.tryParse(priceController.text.trim());

    if (name.isEmpty) {
      CustomSnackBar.error(message: 'Please enter package name');
      return false;
    }
    if (description.isEmpty) {
      CustomSnackBar.error(message: 'Please enter package description');
      return false;
    }
    if (capacity == null || capacity < 1) {
      CustomSnackBar.error(message: 'Capacity must be at least 1');
      return false;
    }
    if (price == null || price < 0) {
      CustomSnackBar.error(message: 'Please enter a valid price');
      return false;
    }
    if (features.isEmpty) {
      CustomSnackBar.error(message: 'Add at least one package feature');
      return false;
    }

    final editingIndex = _editingIndex;
    final existing = editingIndex == null ? null : packages[editingIndex];
    final package = ClubPackageModel(
      id: existing?.id,
      name: name,
      description: description,
      capacity: capacity,
      price: price,
      currency: 'EUR',
      features: List.unmodifiable(features),
      sortOrder: editingIndex ?? packages.length,
      isActive: existing?.isActive ?? true,
    );

    if (editingIndex == null) {
      packages.add(package);
    } else {
      packages[editingIndex] = package;
      packages.refresh();
    }
    _clearPackageForm();
    return true;
  }

  void _editPackage(int index) {
    final package = packages[index];
    setState(() => _editingIndex = index);
    packageNameController.text = package.name;
    packageDescriptionController.text = package.description;
    capacityController.text = package.capacity.toString();
    priceController.text = package.price.toStringAsFixed(2);
    features.assignAll(package.features);
  }

  void _removePackage(int index) {
    final removedPackage = packages[index];
    if (widget.draft.isEditing && removedPackage.id != null) {
      _deactivatedPackages.removeWhere(
        (package) => package.id == removedPackage.id,
      );
      _deactivatedPackages.add(removedPackage.copyWith(isActive: false));
    }
    packages.removeAt(index);
    for (var i = 0; i < packages.length; i++) {
      packages[i] = packages[i].copyWith(sortOrder: i);
    }
    packages.refresh();
    if (_editingIndex == index) _clearPackageForm();
  }

  void _clearPackageForm() {
    packageNameController.clear();
    packageDescriptionController.clear();
    capacityController.clear();
    priceController.clear();
    featureInputController.clear();
    features.clear();
    setState(() => _editingIndex = null);
  }

  Future<void> _publish() async {
    if (_isPublishing) return;
    if (_hasPackageInput && !_savePackage()) return;
    if (packages.isEmpty) {
      CustomSnackBar.error(message: 'Please add at least one package');
      return;
    }

    setState(() => _isPublishing = true);
    final newlyUploadedUrls = <String>[];
    try {
      var thumbnailUrl = widget.draft.existingThumbnail;
      if (widget.draft.thumbnailFile != null) {
        final uploaded = await MediaService.uploadMedia([
          widget.draft.thumbnailFile!,
        ]);
        if (uploaded == null || uploaded.isEmpty) {
          throw StateError('Thumbnail upload failed');
        }
        thumbnailUrl = uploaded.first;
        newlyUploadedUrls.addAll(uploaded);
      }

      final imageUrls = <String>[...widget.draft.existingImages];
      if (widget.draft.galleryFiles.isNotEmpty) {
        final uploaded = await MediaService.uploadMedia(
          widget.draft.galleryFiles,
        );
        if (uploaded == null ||
            uploaded.length != widget.draft.galleryFiles.length) {
          throw StateError('Gallery upload failed');
        }
        imageUrls.addAll(uploaded);
        newlyUploadedUrls.addAll(uploaded);
      }

      final requestPackages = <ClubPackageModel>[
        ...packages,
        if (widget.draft.isEditing) ..._deactivatedPackages,
      ];
      final request = ClubUpsertRequestModel(
        name: widget.draft.name,
        description: widget.draft.description,
        location: widget.draft.location.trim(),
        thumbnail: thumbnailUrl,
        images: imageUrls,
        dressCode: widget.draft.dressCode,
        isRecurring: widget.draft.isRecurring,
        isVip: widget.draft.isVip,
        latitude: widget.draft.latitude,
        longitude: widget.draft.longitude,
        openingHours: widget.draft.openingHours,
        packages: List.unmodifiable(requestPackages),
        isActive: widget.draft.isActive,
      );

      final response = widget.draft.isEditing
          ? await _repository.updateClub(
              id: widget.draft.clubId!,
              request: request,
            )
          : await _repository.createClub(request);
      if (!response.success) {
        throw StateError(
          response.message.isEmpty ? 'Club request failed' : response.message,
        );
      }

      final activityController = Get.isRegistered<OwnerActivityController>()
          ? Get.find<OwnerActivityController>()
          : Get.put(OwnerActivityController());
      final previous = widget.draft.isEditing
          ? activityController.activityList.firstWhereOrNull(
              (item) => item.id == widget.draft.clubId,
            )
          : null;
      final isActive = response.isActive ?? widget.draft.isActive;
      final activityItem = ActivityItemModel(
        id: widget.draft.isEditing
            ? widget.draft.clubId!
            : response.clubId ??
                  DateTime.now().millisecondsSinceEpoch.toString(),
        title: widget.draft.name,
        type: 'Club',
        image: thumbnailUrl,
        images: imageUrls,
        location: widget.draft.location,
        rating: previous?.rating ?? '0.0',
        price: _priceLabel(packages.first),
        status: isActive ? 'Active' : 'Inactive',
        description: widget.draft.description,
        openingHours: _openingHoursLabel(widget.draft.openingHours),
        dressCode: widget.draft.dressCode,
        isRecurring: widget.draft.isRecurring,
        isVip: widget.draft.isVip,
        isActive: isActive,
        deactivatedAt: isActive
            ? null
            : response.deactivatedAt ??
                  previous?.deactivatedAt ??
                  DateTime.now(),
        latitude: widget.draft.latitude,
        longitude: widget.draft.longitude,
        openingHoursData: widget.draft.openingHours,
        clubPackages: List.unmodifiable(packages),
      );
      if (widget.draft.isEditing) {
        activityController.updateActivityItem(activityItem);
      } else {
        activityController.addActivityItem(activityItem);
      }

      CustomSnackBar.success(
        message: response.message.isNotEmpty
            ? response.message
            : widget.draft.isEditing
            ? 'Club updated successfully!'
            : 'Club created successfully!',
      );
      Get.back(result: true);
      Get.back(result: true);
    } catch (error) {
      if (newlyUploadedUrls.isNotEmpty) {
        await MediaService.deleteMedia(newlyUploadedUrls);
      }
      CustomSnackBar.error(message: error.toString());
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  String _priceLabel(ClubPackageModel package) {
    final value = package.price == package.price.roundToDouble()
        ? package.price.toInt().toString()
        : package.price.toStringAsFixed(2);
    return 'From €$value';
  }

  String _openingHoursLabel(List<ClubOpeningHourModel> openingHours) {
    const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final activeHours = openingHours
        .where((hours) => !hours.isClosed)
        .toList(growable: false);
    if (activeHours.isEmpty) return 'Closed';

    final dayNames = activeHours
        .map((hours) => days[hours.dayOfWeek])
        .join(', ');
    final first = activeHours.first;
    return '$dayNames: ${_timeLabel(first.openTime)} - ${_timeLabel(first.closeTime)}';
  }

  String _timeLabel(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF0D0D0D);
    const cardBgColor = Color(0xFF161616);
    const primaryYellow = Color(0xFFDCA73A);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: CustomAppBar(
        title: widget.draft.isEditing ? 'Edit Packages' : 'Add Packages',
        backgroundColor: bgColor,
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: CustomButton(
                    title: _editingIndex == null
                        ? 'Save Package'
                        : 'Update Package',
                    isGradient: false,
                    buttonColor: Colors.transparent,
                    border: Border.all(color: Colors.white24),
                    titleColor: Colors.white,
                    paddingVertical: 0,
                    borderRadius: 16,
                    fontSize: 13,
                    onTap: _isPublishing ? null : _savePackage,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: CustomButton(
                    title: widget.draft.isEditing ? 'Update' : 'Publish',
                    isLoading: _isPublishing,
                    isGradient: false,
                    buttonColor: primaryYellow,
                    titleColor: Colors.black,
                    paddingVertical: 0,
                    borderRadius: 16,
                    onTap: _publish,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Obx(
              () => packages.isEmpty
                  ? const SizedBox.shrink()
                  : _SavedPackages(
                      packages: packages,
                      onEdit: _editPackage,
                      onDelete: _removePackage,
                    ),
            ),
            Obx(
              () => packages.isEmpty
                  ? const SizedBox.shrink()
                  : const SizedBox(height: 22),
            ),
            CustomText(
              text: _editingIndex == null ? 'Add Package' : 'Edit Package',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: packageNameController,
              label: 'Package Name',
              hint: 'e.g. Birthday Package',
              labelColor: Colors.white,
              filled: true,
              fillColor: cardBgColor,
              isBorder: false,
            ),
            const SizedBox(height: 14),
            CustomTextField(
              controller: packageDescriptionController,
              label: 'Package Description',
              hint: 'What is included in this package?',
              labelColor: Colors.white,
              maxLines: 3,
              filled: true,
              fillColor: cardBgColor,
              isBorder: false,
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: CustomTextField(
                    controller: capacityController,
                    label: 'Capacity',
                    hint: 'e.g. 10',
                    keyboardType: TextInputType.number,
                    labelColor: Colors.white,
                    filled: true,
                    fillColor: cardBgColor,
                    isBorder: false,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomTextField(
                    controller: priceController,
                    label: 'Price (EUR)',
                    hint: 'e.g. 240',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    labelColor: Colors.white,
                    filled: true,
                    fillColor: cardBgColor,
                    isBorder: false,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const CustomText(
              text: 'Package Features',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    controller: featureInputController,
                    hint: 'Write feature here',
                    filled: true,
                    fillColor: cardBgColor,
                    isBorder: false,
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _addFeature,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 52,
                    width: 52,
                    decoration: BoxDecoration(
                      color: cardBgColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.add, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Obx(
              () => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: features
                    .map((feature) {
                      return InputChip(
                        label: Text(feature),
                        labelStyle: const TextStyle(color: Colors.white),
                        backgroundColor: const Color(0xFF242424),
                        deleteIconColor: Colors.redAccent,
                        side: BorderSide.none,
                        onDeleted: () => features.remove(feature),
                      );
                    })
                    .toList(growable: false),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    packageNameController.dispose();
    packageDescriptionController.dispose();
    capacityController.dispose();
    priceController.dispose();
    featureInputController.dispose();
    super.dispose();
  }
}

class _SavedPackages extends StatelessWidget {
  const _SavedPackages({
    required this.packages,
    required this.onEdit,
    required this.onDelete,
  });

  final List<ClubPackageModel> packages;
  final ValueChanged<int> onEdit;
  final ValueChanged<int> onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomText(
          text: 'Saved Packages (${packages.length})',
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        const SizedBox(height: 10),
        ...List.generate(packages.length, (index) {
          final package = packages[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF161616),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomText(
                        text: package.name,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        maxLine: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      CustomText(
                        text:
                            '€${package.price.toStringAsFixed(2)} • ${package.capacity} guests • ${package.features.length} features',
                        color: Colors.grey,
                        maxLine: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => onEdit(index),
                  icon: const Icon(Icons.edit_outlined, color: Colors.white70),
                ),
                IconButton(
                  onPressed: () => onDelete(index),
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
