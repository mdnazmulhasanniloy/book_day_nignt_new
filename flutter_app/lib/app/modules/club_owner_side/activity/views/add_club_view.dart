import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/resources/common_widget/custom_app_bar.dart';
import '../../../../core/resources/common_widget/custom_button.dart';
import '../../../../core/resources/common_widget/custom_checkbox.dart';
import '../../../../core/resources/common_widget/custom_text.dart';
import '../../../../core/resources/common_widget/custom_text_field.dart';
import '../../../../core/utils/custom_snack_bar.dart';
import '../controllers/owner_activity_controller.dart';
import '../model/club_location_model.dart';
import '../model/club_upsert_model.dart';
import '../repository/club_location_repository.dart';
import 'add_club_packages_view.dart';
import 'club_location_picker_view.dart';

class AddClubView extends StatefulWidget {
  const AddClubView({super.key, this.item});

  final ActivityItemModel? item;

  @override
  State<AddClubView> createState() => _AddClubViewState();
}

class _AddClubViewState extends State<AddClubView> {
  late final TextEditingController nameController;
  late final TextEditingController descController;
  late final TextEditingController locationController;
  late final TextEditingController dressCodeController;

  final willReoccur = false.obs;
  final isVip = false.obs;
  final selectedDays = <int>{}.obs;
  final ImagePicker _picker = ImagePicker();
  final ClubLocationRepository _locationRepository = ClubLocationRepository();
  final List<File> _galleryImages = [];
  final List<String> _existingGalleryImages = [];
  final List<ClubPlaceSuggestionModel> _locationSuggestions = [];

  File? _thumbnailImage;
  String _existingThumbnail = '';
  Timer? _locationDebounce;
  double? _selectedLatitude;
  double? _selectedLongitude;
  String? _selectedAddress;
  TimeOfDay? fromTime;
  TimeOfDay? toTime;
  bool _isPreparing = false;
  bool _isSearchingLocation = false;
  bool _isResolvingLocation = false;
  bool _isActive = true;

  static const weekdays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  bool get _isEditing => widget.item != null;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    nameController = TextEditingController(text: item?.title ?? '');
    descController = TextEditingController(text: item?.description ?? '');
    locationController = TextEditingController(text: item?.location ?? '');
    dressCodeController = TextEditingController(text: item?.dressCode ?? '');
    _existingThumbnail = item?.image ?? '';
    _existingGalleryImages.addAll(item?.images ?? const []);
    willReoccur.value = item?.isRecurring ?? false;
    isVip.value = item?.isVip ?? false;
    _isActive = item?.isActive ?? true;
    if (item != null && (item.latitude != 0 || item.longitude != 0)) {
      _selectedLatitude = item.latitude;
      _selectedLongitude = item.longitude;
      _selectedAddress = item.location;
    }

    final openingHours = item?.openingHoursData ?? const [];
    selectedDays.addAll(
      openingHours
          .where((hours) => !hours.isClosed)
          .map((hours) => hours.dayOfWeek),
    );
    final activeHours = openingHours.firstWhereOrNull(
      (hours) => !hours.isClosed,
    );
    if (activeHours != null) {
      fromTime = TimeOfDay.fromDateTime(activeHours.openTime.toLocal());
      toTime = TimeOfDay.fromDateTime(activeHours.closeTime.toLocal());
    }
  }

  void _onLocationChanged(String value) {
    final query = value.trim();
    if (query != _selectedAddress) {
      _selectedAddress = null;
      _selectedLatitude = null;
      _selectedLongitude = null;
    }
    _locationDebounce?.cancel();
    if (query.length < 2) {
      setState(() {
        _locationSuggestions.clear();
        _isSearchingLocation = false;
      });
      return;
    }
    _locationDebounce = Timer(
      const Duration(milliseconds: 450),
      () => _searchLocations(query),
    );
  }

  Future<void> _searchLocations(String query) async {
    if (!mounted) return;
    setState(() => _isSearchingLocation = true);
    try {
      final suggestions = await _locationRepository.searchSuggestions(
        query: query,
        latitude: _selectedLatitude,
        longitude: _selectedLongitude,
      );
      if (!mounted || locationController.text.trim() != query) return;
      setState(() {
        _locationSuggestions
          ..clear()
          ..addAll(suggestions);
      });
    } catch (_) {
      if (mounted && locationController.text.trim() == query) {
        setState(() => _locationSuggestions.clear());
      }
    } finally {
      if (mounted && locationController.text.trim() == query) {
        setState(() => _isSearchingLocation = false);
      }
    }
  }

  Future<void> _selectLocationSuggestion(
    ClubPlaceSuggestionModel suggestion,
  ) async {
    setState(() => _isResolvingLocation = true);
    try {
      final resolved = await _locationRepository.resolveSuggestion(suggestion);
      if (!resolved.hasCoordinates) {
        throw StateError('Location coordinates not found');
      }
      if (!mounted) return;
      final address = resolved.displayText.trim().isEmpty
          ? suggestion.displayText
          : resolved.displayText;
      setState(() {
        locationController.text = address;
        locationController.selection = TextSelection.collapsed(
          offset: address.length,
        );
        _selectedAddress = address;
        _selectedLatitude = resolved.latitude;
        _selectedLongitude = resolved.longitude;
        _locationSuggestions.clear();
      });
      FocusScope.of(context).unfocus();
    } catch (_) {
      CustomSnackBar.error(message: 'Could not load this location.');
    } finally {
      if (mounted) setState(() => _isResolvingLocation = false);
    }
  }

  Future<void> _openMapPicker() async {
    _locationDebounce?.cancel();
    FocusScope.of(context).unfocus();
    setState(() => _locationSuggestions.clear());
    final selection = await Get.to<ClubLocationSelectionModel>(
      () => ClubLocationPickerView(
        initialLatitude: _selectedLatitude ?? widget.item?.latitude,
        initialLongitude: _selectedLongitude ?? widget.item?.longitude,
      ),
    );
    if (selection == null || !mounted) return;
    setState(() {
      locationController.text = selection.address;
      locationController.selection = TextSelection.collapsed(
        offset: selection.address.length,
      );
      _selectedAddress = selection.address;
      _selectedLatitude = selection.latitude;
      _selectedLongitude = selection.longitude;
    });
  }

  Future<void> _selectTime({required bool isOpeningTime}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isOpeningTime
          ? fromTime ?? const TimeOfDay(hour: 18, minute: 0)
          : toTime ?? const TimeOfDay(hour: 2, minute: 0),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFDCA73A),
              onPrimary: Colors.black,
              surface: Color(0xFF161616),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isOpeningTime) {
        fromTime = picked;
      } else {
        toTime = picked;
      }
    });
  }

  Future<void> _pickThumbnail() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );
    if (image == null || !mounted) return;
    setState(() {
      _thumbnailImage = File(image.path);
      _existingThumbnail = '';
    });
  }

  Future<void> _pickGalleryImages() async {
    final images = await _picker.pickMultiImage(imageQuality: 88);
    if (images.isEmpty || !mounted) return;
    setState(() {
      _galleryImages.addAll(images.map((image) => File(image.path)));
    });
  }

  Future<void> _continueToPackages() async {
    final name = nameController.text.trim();
    final description = descController.text.trim();
    final location = locationController.text.trim();
    if (name.isEmpty) {
      CustomSnackBar.error(message: 'Please enter club name');
      return;
    }
    if (description.isEmpty) {
      CustomSnackBar.error(message: 'Please enter club description');
      return;
    }
    if (location.isEmpty) {
      CustomSnackBar.error(message: 'Please enter club location');
      return;
    }
    if (_thumbnailImage == null && _existingThumbnail.isEmpty) {
      CustomSnackBar.error(message: 'Please select a thumbnail image');
      return;
    }
    if (selectedDays.isEmpty) {
      CustomSnackBar.error(message: 'Please select at least one opening day');
      return;
    }
    if (fromTime == null || toTime == null) {
      CustomSnackBar.error(message: 'Please select opening and closing time');
      return;
    }

    setState(() => _isPreparing = true);
    try {
      double? latitude = _selectedLatitude;
      double? longitude = _selectedLongitude;
      if (latitude == null || longitude == null) {
        final resolved = await _locationRepository.resolveAddress(location);
        latitude = resolved.latitude;
        longitude = resolved.longitude;
      }

      final draft = ClubDraftModel(
        clubId: widget.item?.id,
        name: name,
        description: description,
        location: location,
        dressCode: dressCodeController.text.trim(),
        isRecurring: willReoccur.value,
        isVip: isVip.value,
        latitude: latitude,
        longitude: longitude,
        openingHours: _buildOpeningHours(),
        isActive: _isActive,
        thumbnailFile: _thumbnailImage,
        galleryFiles: List.unmodifiable(_galleryImages),
        existingThumbnail: _existingThumbnail,
        existingImages: List.unmodifiable(_existingGalleryImages),
        existingPackages: widget.item?.clubPackages ?? const [],
      );
      if (!mounted) return;
      await Get.to(() => AddClubPackagesView(draft: draft));
    } catch (_) {
      CustomSnackBar.error(
        message: 'Could not find this location. Enter a complete address.',
      );
    } finally {
      if (mounted) setState(() => _isPreparing = false);
    }
  }

  Future<void> _onActiveChanged(bool value) async {
    if (!value) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF161616),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const CustomText(
            text: 'Hide this club?',
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
          content: const CustomText(
            text:
                'Guests will not see this club until you turn it active again. This does not close table bookings on an event.',
            color: Colors.white70,
            fontSize: 14,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'Keep visible',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                'Hide club',
                style: TextStyle(
                  color: Color(0xFFFF6B6B),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    if (!mounted) return;
    setState(() => _isActive = value);
  }

  List<ClubOpeningHourModel> _buildOpeningHours() {
    final now = DateTime.now();
    final open = DateTime(
      now.year,
      now.month,
      now.day,
      fromTime!.hour,
      fromTime!.minute,
    );
    var close = DateTime(
      now.year,
      now.month,
      now.day,
      toTime!.hour,
      toTime!.minute,
    );
    final closesNextDay = !close.isAfter(open);
    if (closesNextDay) close = close.add(const Duration(days: 1));

    return List.generate(7, (day) {
      final existing = widget.item?.openingHoursData.firstWhereOrNull(
        (hours) => hours.dayOfWeek == day,
      );
      return ClubOpeningHourModel(
        id: existing?.id,
        dayOfWeek: day,
        isClosed: !selectedDays.contains(day),
        openTime: open,
        closeTime: close,
        closesNextDay: closesNextDay,
      );
    }, growable: false);
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF0D0D0D);
    const cardBgColor = Color(0xFF161616);
    const primaryYellow = Color(0xFFDCA73A);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: CustomAppBar(
        title: _isEditing ? 'Edit Club' : 'Add Club',
        backgroundColor: bgColor,
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: SizedBox(
            height: 52,
            child: CustomButton(
              title: 'Next',
              isLoading: _isPreparing,
              buttonColor: primaryYellow,
              isGradient: false,
              borderRadius: 16,
              paddingVertical: 0,
              titleColor: Colors.black,
              onTap: _continueToPackages,
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CustomText(
              text: 'Club Details',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            const SizedBox(height: 16),
            _buildThumbnailUploader(cardBgColor),
            const SizedBox(height: 16),
            _buildGalleryUploader(cardBgColor),
            const SizedBox(height: 12),
            _buildImagePreviews(),
            const SizedBox(height: 20),
            CustomTextField(
              controller: nameController,
              label: 'Club Name',
              hint: 'Enter club name',
              labelColor: Colors.white,
              filled: true,
              fillColor: cardBgColor,
              isBorder: false,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: descController,
              label: 'Club Description',
              hint: 'Enter description',
              labelColor: Colors.white,
              maxLines: 4,
              filled: true,
              fillColor: cardBgColor,
              isBorder: false,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: locationController,
              label: 'Club Location',
              hint: 'Search area, city or place',
              labelColor: Colors.white,
              filled: true,
              fillColor: cardBgColor,
              isBorder: false,
              readOnly: false,
              onChanged: _onLocationChanged,
              prefixIcon: const Icon(Icons.search, color: Colors.white54),
              suffixIcon: IconButton(
                tooltip: 'Select from map',
                onPressed: _openMapPicker,
                icon: const Icon(Icons.map_outlined, color: primaryYellow),
              ),
            ),
            _buildLocationSuggestions(cardBgColor, primaryYellow),
            const SizedBox(height: 16),
            const CustomText(
              text: 'Club Opening hours',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            const SizedBox(height: 12),
            Obx(
              () => Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(weekdays.length, (index) {
                  final selected = selectedDays.contains(index);
                  return InkWell(
                    onTap: () => selected
                        ? selectedDays.remove(index)
                        : selectedDays.add(index),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      height: 36,
                      width: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected
                            ? primaryYellow
                            : const Color(0xFF1E1E1E),
                      ),
                      alignment: Alignment.center,
                      child: CustomText(
                        text: weekdays[index],
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: selected ? Colors.black : Colors.white,
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _TimeField(
                    label: fromTime == null
                        ? 'Opening time'
                        : fromTime!.format(context),
                    onTap: () => _selectTime(isOpeningTime: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TimeField(
                    label: toTime == null
                        ? 'Closing time'
                        : toTime!.format(context),
                    onTap: () => _selectTime(isOpeningTime: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Obx(
              () => CustomCheckBox(
                title: 'Will Reoccur',
                isChecked: willReoccur.value,
                activeColor: primaryYellow,
                textColor: Colors.white,
                onChanged: (value) => willReoccur.value = value,
              ),
            ),
            Obx(
              () => CustomCheckBox(
                title: 'VIP Club',
                isChecked: isVip.value,
                activeColor: primaryYellow,
                textColor: Colors.white,
                onChanged: (value) => isVip.value = value,
              ),
            ),
            if (_isEditing) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: cardBgColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CustomText(
                            text: _isActive ? 'Active' : 'Inactive',
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          const SizedBox(height: 3),
                          CustomText(
                            text: _isActive
                                ? 'Club is visible to guests'
                                : 'Club is hidden. This is not Close bookings.',
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: _isActive,
                      activeTrackColor: primaryYellow,
                      activeThumbColor: Colors.black,
                      onChanged: _onActiveChanged,
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            CustomTextField(
              controller: dressCodeController,
              label: 'Dress Code',
              hint: 'e.g. Smart Casual',
              labelColor: Colors.white,
              filled: true,
              fillColor: cardBgColor,
              isBorder: false,
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSuggestions(Color backgroundColor, Color primary) {
    if (_isSearchingLocation || _isResolvingLocation) {
      return const Padding(
        padding: EdgeInsets.only(top: 10),
        child: LinearProgressIndicator(
          minHeight: 2,
          color: Color(0xFFDCA73A),
          backgroundColor: Color(0xFF242424),
        ),
      );
    }
    if (_locationSuggestions.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: List.generate(_locationSuggestions.length, (index) {
          final suggestion = _locationSuggestions[index];
          return Column(
            children: [
              ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                leading: Icon(Icons.location_on_outlined, color: primary),
                title: CustomText(
                  text: suggestion.primaryText,
                  color: Colors.white,
                  fontSize: 13,
                  maxLine: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: suggestion.secondaryText.isEmpty
                    ? null
                    : CustomText(
                        text: suggestion.secondaryText,
                        color: Colors.white54,
                        fontSize: 11,
                        maxLine: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                onTap: () => _selectLocationSuggestion(suggestion),
              ),
              if (index != _locationSuggestions.length - 1)
                const Divider(height: 1, color: Colors.white10),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildThumbnailUploader(Color backgroundColor) {
    final ImageProvider? image = _thumbnailImage != null
        ? FileImage(_thumbnailImage!)
        : _existingThumbnail.isNotEmpty
        ? NetworkImage(_existingThumbnail)
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CustomText(
          text: 'Thumbnail Image',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _pickThumbnail,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(12),
              image: image == null
                  ? null
                  : DecorationImage(image: image, fit: BoxFit.cover),
            ),
            alignment: Alignment.center,
            child: image == null
                ? const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.camera_alt_outlined,
                        color: Colors.white70,
                        size: 28,
                      ),
                      SizedBox(height: 8),
                      CustomText(
                        text: 'Tap to upload thumbnail',
                        color: Colors.grey,
                      ),
                    ],
                  )
                : const Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: CircleAvatar(
                        backgroundColor: Colors.black54,
                        child: Icon(Icons.edit, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildGalleryUploader(Color backgroundColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CustomText(
          text: 'Club Images',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _pickGalleryImages,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 88,
            width: double.infinity,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_photo_alternate_outlined,
                  color: Colors.white70,
                  size: 26,
                ),
                SizedBox(height: 6),
                CustomText(
                  text: 'Select multiple gallery images',
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePreviews() {
    final total = _existingGalleryImages.length + _galleryImages.length;
    if (total == 0) return const SizedBox.shrink();
    return SizedBox(
      height: 70,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: total,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isExisting = index < _existingGalleryImages.length;
          final imageProvider = isExisting
              ? NetworkImage(_existingGalleryImages[index]) as ImageProvider
              : FileImage(
                  _galleryImages[index - _existingGalleryImages.length],
                );
          return Stack(
            children: [
              Container(
                height: 70,
                width: 70,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  image: DecorationImage(
                    image: imageProvider,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                right: 3,
                top: 3,
                child: InkWell(
                  onTap: () => setState(() {
                    if (isExisting) {
                      _existingGalleryImages.removeAt(index);
                    } else {
                      _galleryImages.removeAt(
                        index - _existingGalleryImages.length,
                      );
                    }
                  }),
                  child: const CircleAvatar(
                    radius: 10,
                    backgroundColor: Colors.red,
                    child: Icon(Icons.close, color: Colors.white, size: 12),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _locationDebounce?.cancel();
    nameController.dispose();
    descController.dispose();
    locationController.dispose();
    dressCodeController.dispose();
    super.dispose();
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF161616),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: CustomText(
                text: label,
                fontSize: 13,
                color: Colors.white70,
                maxLine: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.access_time, color: Color(0xFFDCA73A), size: 18),
          ],
        ),
      ),
    );
  }
}
