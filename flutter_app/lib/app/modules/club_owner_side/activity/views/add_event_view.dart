import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/resources/common_widget/custom_app_bar.dart';
import '../../../../core/resources/common_widget/custom_button.dart';
import '../../../../core/resources/common_widget/custom_text.dart';
import '../../../../core/resources/common_widget/custom_text_field.dart';
import '../../../../core/utils/custom_snack_bar.dart';
import '../../../../services/media_service.dart';
import '../../../../core/explore/model/event_offer_model.dart';
import '../controllers/owner_activity_controller.dart';
import '../model/club_api_model.dart';
import '../model/club_location_model.dart';
import '../model/event_api_model.dart';
import '../repository/club_location_repository.dart';
import '../repository/club_repository.dart';
import '../repository/event_repository.dart';
import 'club_location_picker_view.dart';

class AddEventView extends StatefulWidget {
  const AddEventView({super.key, this.item});

  final ActivityItemModel? item;

  @override
  State<AddEventView> createState() => _AddEventViewState();
}

class _AddEventViewState extends State<AddEventView> {
  static const _background = Color(0xFF0D0D0D);
  static const _fieldColor = Color(0xFF161616);
  static const _panelColor = Color(0xFF242424);
  static const _panelFieldColor = Color(0xFF333333);
  static const _primary = Color(0xFFDCA73A);

  late final TextEditingController nameController;
  late final TextEditingController descriptionController;
  late final TextEditingController locationController;
  late final TextEditingController priceController;
  late final TextEditingController dressCodeController;
  late final TextEditingController genresController;

  final ImagePicker _picker = ImagePicker();
  final EventRepository _repository = EventRepository();
  final ClubRepository _clubRepository = ClubRepository();
  final ClubLocationRepository _locationRepository = ClubLocationRepository();
  final List<ClubDataModel> _clubs = [];
  final List<EventTicketTierModel> _tiers = [];
  final List<EventLineupArtistModel> _lineup = [];
  String? _clubId;
  final List<File> _galleryFiles = [];
  final List<String> _existingImages = [];
  final List<ClubPlaceSuggestionModel> _locationSuggestions = [];

  File? _thumbnailFile;
  String _existingThumbnail = '';
  DateTime? _startAt;
  DateTime? _endAt;
  double? _latitude;
  double? _longitude;
  String? _selectedAddress;
  bool _isActive = true;
  bool _wantsCancel = false;
  Timer? _locationDebounce;
  bool _isSearchingLocation = false;
  bool _isResolvingLocation = false;
  bool _isSubmitting = false;
  String _categoryType = 'CLUB';

  bool get _isEditing => widget.item != null;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    nameController = TextEditingController(text: item?.title ?? '');
    descriptionController = TextEditingController(
      text: item?.description ?? '',
    );
    locationController = TextEditingController(text: item?.location ?? '');
    priceController = TextEditingController(
      text: item?.eventPrice == null ? '' : _numberLabel(item!.eventPrice!),
    );
    dressCodeController = TextEditingController(text: item?.dressCode ?? '');
    genresController = TextEditingController(
      text: item == null || item.musicGenres.isEmpty
          ? ''
          : item.musicGenres.join(', '),
    );
    _clubId = item?.clubId;
    _tiers.addAll(item?.ticketTiers ?? const []);
    _lineup.addAll(item?.lineup ?? const []);
    _loadClubs();
    if (_isEditing && item != null) _loadEventExtras(item.id);
    _existingThumbnail = item?.image ?? '';
    _existingImages.addAll(item?.images ?? const []);
    _startAt = item?.startAt;
    _endAt = item?.endAt;
    _isActive = item?.isActive ?? true;
    _wantsCancel =
        _apiStatus(item?.eventStatus ?? item?.status) == 'CANCELED';
    _categoryType = (item?.categoryType ?? 'CLUB').trim().toUpperCase();
    if (_categoryType.isEmpty) _categoryType = 'CLUB';
    if (item != null && (item.latitude != 0 || item.longitude != 0)) {
      _latitude = item.latitude;
      _longitude = item.longitude;
      _selectedAddress = item.location;
    }
  }

  String _apiStatus(String? value) {
    final status = value?.trim().toUpperCase();
    if (status == 'CANCELED' || status == 'CANCELLED') return 'CANCELED';
    if (status == 'UPCOMING' || status == 'ONGOING' || status == 'COMPLETED') {
      return status!;
    }
    return 'UPCOMING';
  }

  String get _currentStatus =>
      _apiStatus(widget.item?.eventStatus ?? widget.item?.status);

  bool get _isCanceled => _wantsCancel || _currentStatus == 'CANCELED';

  String get _submitStatus {
    if (_isActive && _isCanceled) return 'UPCOMING';
    if (_wantsCancel) return 'CANCELED';
    return _currentStatus;
  }

  Future<void> _onActiveChanged(bool value) async {
    if (!value) {
      final confirmed = await _confirm(
        title: 'Hide this event?',
        body:
            'Guests will not see it. Status stays Upcoming — this is not a cancellation.',
        confirmLabel: 'Hide event',
      );
      if (confirmed != true) return;
      if (!mounted) return;
      setState(() {
        _isActive = false;
        if (_currentStatus != 'CANCELED') _wantsCancel = false;
      });
      return;
    }
    if (_isCanceled) {
      final confirmed = await _confirm(
        title: 'Restore this event?',
        body: 'Sets status back to Upcoming and makes it visible again.',
        confirmLabel: 'Restore',
        destructive: false,
      );
      if (confirmed != true) return;
      if (!mounted) return;
      setState(() {
        _isActive = true;
        _wantsCancel = false;
      });
      return;
    }
    setState(() => _isActive = true);
  }

  Future<void> _onCancelEvent() async {
    final confirmed = await _confirm(
      title: 'Cancel this event?',
      body:
          'Formal cancellation. This can trigger refunds. To only hide it from guests, use the Active switch instead.',
      confirmLabel: 'Cancel event',
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _wantsCancel = true;
      _isActive = false;
    });
  }

  Future<bool?> _confirm({
    required String title,
    required String body,
    required String confirmLabel,
    bool destructive = true,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _fieldColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: CustomText(
          text: title,
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        content: CustomText(text: body, color: Colors.white70, fontSize: 14),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Keep as is',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              confirmLabel,
              style: TextStyle(
                color: destructive ? const Color(0xFFFF6B6B) : _primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickThumbnail() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );
    if (image == null || !mounted) return;
    setState(() {
      _thumbnailFile = File(image.path);
      _existingThumbnail = '';
    });
  }

  Future<void> _pickGallery() async {
    final images = await _picker.pickMultiImage(imageQuality: 88);
    if (images.isEmpty || !mounted) return;
    setState(() {
      _galleryFiles.addAll(images.map((image) => File(image.path)));
    });
  }

  void _onLocationChanged(String value) {
    final query = value.trim();
    if (query != _selectedAddress) {
      _selectedAddress = null;
      _latitude = null;
      _longitude = null;
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
      final results = await _locationRepository.searchSuggestions(
        query: query,
        latitude: _latitude,
        longitude: _longitude,
      );
      if (!mounted || locationController.text.trim() != query) return;
      setState(() {
        _locationSuggestions
          ..clear()
          ..addAll(results);
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

  Future<void> _selectSuggestion(ClubPlaceSuggestionModel suggestion) async {
    setState(() => _isResolvingLocation = true);
    try {
      final location = await _locationRepository.resolveSuggestion(suggestion);
      if (!location.hasCoordinates) throw StateError('Coordinates not found');
      if (!mounted) return;
      final address = location.displayText.trim().isEmpty
          ? suggestion.displayText
          : location.displayText;
      setState(() {
        locationController.text = address;
        locationController.selection = TextSelection.collapsed(
          offset: address.length,
        );
        _selectedAddress = address;
        _latitude = location.latitude;
        _longitude = location.longitude;
        _locationSuggestions.clear();
      });
      FocusScope.of(context).unfocus();
    } catch (_) {
      CustomSnackBar.error(message: 'Could not load this location');
    } finally {
      if (mounted) setState(() => _isResolvingLocation = false);
    }
  }

  Future<void> _openMapPicker() async {
    _locationDebounce?.cancel();
    FocusScope.of(context).unfocus();
    setState(() => _locationSuggestions.clear());
    final result = await Get.to<ClubLocationSelectionModel>(
      () => ClubLocationPickerView(
        initialLatitude: _latitude,
        initialLongitude: _longitude,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      locationController.text = result.address;
      locationController.selection = TextSelection.collapsed(
        offset: result.address.length,
      );
      _selectedAddress = result.address;
      _latitude = result.latitude;
      _longitude = result.longitude;
    });
  }

  DateTime _futureStartInitial(DateTime tomorrow) {
    final current = _startAt;
    if (current != null && !current.isBefore(tomorrow)) return current;
    final suggested = DateTime.now().add(const Duration(hours: 1));
    return DateTime(
      tomorrow.year,
      tomorrow.month,
      tomorrow.day,
      suggested.hour,
      suggested.minute,
    );
  }

  Future<void> _selectDateTime({required bool isStart}) async {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day).add(
      const Duration(days: 1),
    );
    final initial = isStart
        ? _futureStartInitial(tomorrow)
        : _endAt ??
              (_startAt ?? tomorrow).add(const Duration(hours: 2));
    final firstDate = isStart ? tomorrow : DateTime(2000);
    final date = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(firstDate) ? firstDate : initial,
      firstDate: firstDate,
      lastDate: now.add(const Duration(days: 3650)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: _primary,
            onPrimary: Colors.black,
            surface: _fieldColor,
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: _primary,
            onPrimary: Colors.black,
            surface: _fieldColor,
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (time == null || !mounted) return;
    final selected = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (isStart) {
        _startAt = selected;
        _endAt = selected.add(const Duration(hours: 2));
      } else {
        _endAt = selected;
      }
    });
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final name = nameController.text.trim();
    final description = descriptionController.text.trim();
    final address = locationController.text.trim();
    final parsedPrice = double.tryParse(priceController.text.trim());
    final price = _tiers.isNotEmpty ? _cheapestTierPrice : parsedPrice;

    if (name.isEmpty) {
      CustomSnackBar.error(message: 'Please enter event name');
      return;
    }
    if (description.isEmpty) {
      CustomSnackBar.error(message: 'Please enter event description');
      return;
    }
    if (_thumbnailFile == null && _existingThumbnail.isEmpty) {
      CustomSnackBar.error(message: 'Please select a thumbnail image');
      return;
    }
    if (address.isEmpty) {
      CustomSnackBar.error(message: 'Please select event location');
      return;
    }
    if (_startAt == null || _endAt == null) {
      CustomSnackBar.error(message: 'Please select event start and end time');
      return;
    }
    if (!_endAt!.isAfter(_startAt!)) {
      CustomSnackBar.error(message: 'End time must be after start time');
      return;
    }
    if (price == null || price < 0) {
      CustomSnackBar.error(
        message: _tiers.isEmpty
            ? 'Please enter a valid event price'
            : 'Please add a valid ticket tier price',
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final uploadedThisTime = <String>[];
    try {
      var latitude = _latitude;
      var longitude = _longitude;
      if (latitude == null || longitude == null) {
        final location = await _locationRepository.resolveAddress(address);
        latitude = location.latitude;
        longitude = location.longitude;
      }

      var thumbnail = _existingThumbnail;
      if (_thumbnailFile != null) {
        final uploaded = await MediaService.uploadMedia([_thumbnailFile!]);
        if (uploaded == null || uploaded.isEmpty) {
          throw StateError('Thumbnail upload failed');
        }
        thumbnail = uploaded.first;
        uploadedThisTime.addAll(uploaded);
      }

      final images = <String>[..._existingImages];
      if (_galleryFiles.isNotEmpty) {
        final uploaded = await MediaService.uploadMedia(_galleryFiles);
        if (uploaded == null || uploaded.length != _galleryFiles.length) {
          throw StateError('Gallery upload failed');
        }
        images.addAll(uploaded);
        uploadedThisTime.addAll(uploaded);
      }

      final request = EventUpsertRequestModel(
        eventName: name,
        eventDescription: description,
        thumbnail: thumbnail,
        images: images,
        // Hide = isActive false (status unchanged). Cancel = eventStatus CANCELED.
        eventStatus: _submitStatus,
        location: address,
        latitude: latitude,
        longitude: longitude,
        startAt: _startAt!,
        endAt: _endAt!,
        dressCode: dressCodeController.text.trim(),
        eventPrice: price,
        currency: 'EUR',
        isActive: _isActive,
        clubId: _clubId,
        ticketTiers: List.of(_tiers),
        lineup: List.of(_lineup),
        categoryType: _categoryType,
        musicGenres: genresController.text
            .split(',')
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList(),
      );
      final response = _isEditing
          ? await _repository.updateEvent(id: widget.item!.id, request: request)
          : await _repository.createEvent(request);
      if (!response.success || response.data == null) {
        throw StateError(
          response.message.isEmpty ? 'Event request failed' : response.message,
        );
      }

      final controller = Get.isRegistered<OwnerActivityController>()
          ? Get.find<OwnerActivityController>()
          : Get.put(OwnerActivityController());
      if (_isEditing) {
        await controller.upsertEventFromApi(response.data!);
      } else {
        await controller.reloadCreatedEvent();
      }
      CustomSnackBar.success(
        message: response.message.isEmpty
            ? _isEditing
                  ? 'Event updated successfully'
                  : 'Event created successfully'
            : response.message,
      );
      if (!mounted) return;
      Get.back(result: response.data);
    } catch (error) {
      if (uploadedThisTime.isNotEmpty) {
        await MediaService.deleteMedia(uploadedThisTime);
      }
      CustomSnackBar.error(
        message: error
            .toString()
            .replaceFirst('Bad state: ', '')
            .replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: CustomAppBar(
        title: _isEditing ? 'Edit Event' : 'Add Event',
        backgroundColor: _background,
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: SizedBox(
            height: 52,
            child: CustomButton(
              title: _isEditing ? 'Update Event' : 'Publish Event',
              isLoading: _isSubmitting,
              buttonColor: _primary,
              isGradient: false,
              borderRadius: 16,
              paddingVertical: 0,
              titleColor: Colors.black,
              onTap: _submit,
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CustomText(
              text: 'Event Details',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            const SizedBox(height: 16),
            _buildThumbnailPicker(),
            const SizedBox(height: 16),
            _buildGalleryPicker(),
            const SizedBox(height: 10),
            _buildGalleryPreviews(),
            const SizedBox(height: 18),
            _field(nameController, 'Event Name', 'Enter event name'),
            const SizedBox(height: 14),
            _field(
              descriptionController,
              'Event Description',
              'Enter event description',
              maxLines: 4,
            ),
            const SizedBox(height: 14),
            CustomTextField(
              controller: locationController,
              label: 'Event Location',
              hint: 'Search area, city or place',
              labelColor: Colors.white,
              filled: true,
              fillColor: _fieldColor,
              isBorder: false,
              readOnly: false,
              onChanged: _onLocationChanged,
              prefixIcon: const Icon(Icons.search, color: Colors.white54),
              suffixIcon: IconButton(
                tooltip: 'Select from map',
                onPressed: _openMapPicker,
                icon: const Icon(Icons.map_outlined, color: _primary),
              ),
            ),
            _buildLocationSuggestions(),
            const SizedBox(height: 14),
            if (_tiers.isEmpty) ...[
              _field(
                priceController,
                'Event Price (EUR)',
                'e.g. 50',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 6),
              const CustomText(
                text:
                    'Buyers pay this when you do not add ticket tiers. If you add tiers, checkout uses those prices instead.',
                fontSize: 12,
                color: Colors.white54,
              ),
            ] else
              CustomText(
                text:
                    'Event Price is unused here. Checkout uses ticket tiers; listings show from €${_numberLabel(_cheapestTierPrice)}.',
                fontSize: 12,
                color: Colors.white54,
              ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _DateTimeField(
                    label: 'Starts at',
                    value: _dateTimeLabel(_startAt),
                    onTap: () => _selectDateTime(isStart: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DateTimeField(
                    label: 'Ends at',
                    value: _dateTimeLabel(_endAt),
                    onTap: () => _selectDateTime(isStart: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _field(dressCodeController, 'Dress Code', 'e.g. Smart Casual'),
            const SizedBox(height: 14),
            const CustomText(
              text: 'Category',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final value in const [
                  'CLUB',
                  'CONCERT',
                  'FESTIVAL',
                  'OPEN_AIR',
                  'WAREHOUSE',
                ])
                  ChoiceChip(
                    label: Text(
                      value.replaceAll('_', ' ').toLowerCase(),
                      style: TextStyle(
                        color: _categoryType == value
                            ? Colors.black
                            : Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    selected: _categoryType == value,
                    selectedColor: _primary,
                    backgroundColor: _fieldColor,
                    onSelected: (_) => setState(() => _categoryType = value),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            _field(
              genresController,
              'Music genres',
              'Techno, House (comma separated)',
            ),
            const SizedBox(height: 18),
            _buildClubPicker(),
            const SizedBox(height: 18),
            _buildTierEditor(),
            const SizedBox(height: 18),
            _buildLineupEditor(),
            if (_isEditing) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _fieldColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CustomText(
                            text: _isCanceled && !_isActive
                                ? 'Canceled'
                                : _isActive
                                ? 'Active'
                                : 'Hidden',
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          const SizedBox(height: 3),
                          CustomText(
                            text: _isCanceled && !_isActive
                                ? 'Formally canceled. Turn on to restore as Upcoming.'
                                : _isActive
                                ? 'Event is visible to guests'
                                : 'Hidden from guests. Status stays Upcoming.',
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: _isActive,
                      activeTrackColor: _primary,
                      activeThumbColor: Colors.black,
                      onChanged: _onActiveChanged,
                    ),
                  ],
                ),
              ),
              if (!_wantsCancel) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: _onCancelEvent,
                    child: const Text(
                      'Cancel event',
                      style: TextStyle(
                        color: Color(0xFFFF6B6B),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _loadClubs() async {
    try {
      final response = await _clubRepository.getOwnClubs(limit: 50);
      if (!mounted) return;
      setState(() {
        _clubs
          ..clear()
          ..addAll(response.data);
      });
    } catch (_) {}
  }

  double get _cheapestTierPrice {
    if (_tiers.isEmpty) return 0;
    return _tiers
        .map((tier) => tier.price)
        .reduce((lowest, price) => price < lowest ? price : lowest);
  }

  Future<void> _loadEventExtras(String id) async {
    try {
      final response = await _repository.getEventDetail(id);
      final data = response.data;
      if (!mounted || data == null) return;
      setState(() {
        if (data.clubId != null && data.clubId!.trim().isNotEmpty) {
          _clubId = data.clubId;
        }
        if (data.ticketTiers.isNotEmpty) {
          _tiers
            ..clear()
            ..addAll(data.ticketTiers);
        }
        if (data.lineup.isNotEmpty) {
          _lineup
            ..clear()
            ..addAll(data.lineup);
        }
        if (data.musicGenres.isNotEmpty &&
            genresController.text.trim().isEmpty) {
          genresController.text = data.musicGenres.join(', ');
        }
        if (data.categoryType.trim().isNotEmpty) {
          _categoryType = data.categoryType.trim().toUpperCase();
        }
        _isActive = data.isActive;
        _wantsCancel = _apiStatus(data.eventStatus) == 'CANCELED';
      });
    } catch (_) {}
  }

  Widget _buildClubPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CustomText(
          text: 'Associated club',
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        const SizedBox(height: 10),
        if (_clubs.isEmpty)
          const CustomText(
            text: 'Create a club first to link this event.',
            fontSize: 12,
            color: Colors.white54,
          )
        else
          ..._clubs.map(
            (club) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () => setState(
                  () => _clubId = _clubId == club.id ? null : club.id,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: _fieldColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _clubId == club.id ? _primary : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: CustomText(
                          text: club.name,
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                      Icon(
                        _clubId == club.id
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: _clubId == club.id ? _primary : Colors.white38,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTierEditor() {
    return _ListEditor(
      title: 'Ticket tiers',
      emptyIcon: Icons.confirmation_number_outlined,
      emptyTitle: 'No ticket tiers',
      emptyText:
          'Optional. Leave empty to sell a single Event Price. If you add tiers, those prices are used at checkout.',
      onAdd: _addTier,
      children: [
        for (var index = 0; index < _tiers.length; index++)
          _editorRow(
            '${_tiers[index].tierName} · €${_tiers[index].price} · ${_tiers[index].capacity} seats',
            () => setState(() => _tiers.removeAt(index)),
          ),
      ],
    );
  }

  Widget _buildLineupEditor() {
    return _ListEditor(
      title: 'Lineup',
      emptyIcon: Icons.headphones_outlined,
      emptyTitle: 'No lineup yet',
      emptyText: 'Optional DJ / artist names for this event.',
      onAdd: _addArtist,
      children: [
        for (var index = 0; index < _lineup.length; index++)
          _editorRow(
            _lineup[index].artistName,
            () => setState(() => _lineup.removeAt(index)),
          ),
      ],
    );
  }

  Widget _editorRow(String title, VoidCallback onRemove) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _panelFieldColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: CustomText(text: title, color: Colors.white, fontSize: 13),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close, color: Colors.white70, size: 18),
          ),
        ],
      ),
    );
  }

  Future<void> _addTier() async {
    final name = TextEditingController();
    final group = TextEditingController();
    final price = TextEditingController();
    final capacity = TextEditingController();
    final added = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: _panelColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: _primary.withValues(alpha: 0.28)),
        ),
        title: const CustomText(
          text: 'Add ticket tier',
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dialogField(name, 'Tier name'),
            const SizedBox(height: 10),
            _dialogField(group, 'Group name (optional)'),
            const SizedBox(height: 10),
            _dialogField(price, 'Price (EUR)', numeric: true),
            const SizedBox(height: 10),
            _dialogField(capacity, 'Capacity', numeric: true),
          ],
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const CustomText(text: 'Cancel', color: Colors.white54),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: const CustomText(text: 'Add', color: _primary),
          ),
        ],
      ),
    );
    if (added != true) return;
    final parsedPrice = double.tryParse(price.text.trim()) ?? 0;
    final parsedCapacity = int.tryParse(capacity.text.trim()) ?? 0;
    if (name.text.trim().isEmpty || parsedPrice <= 0 || parsedCapacity <= 0) {
      CustomSnackBar.error(message: 'Enter a valid tier name, price and capacity');
      return;
    }
    setState(() {
      _tiers.add(
        EventTicketTierModel(
          tierName: name.text.trim(),
          groupName: group.text.trim(),
          price: parsedPrice,
          capacity: parsedCapacity,
          sortOrder: _tiers.length + 1,
        ),
      );
    });
  }

  Future<void> _addArtist() async {
    final name = TextEditingController();
    final spotify = TextEditingController();
    final added = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: _panelColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: _primary.withValues(alpha: 0.28)),
        ),
        title: const CustomText(
          text: 'Add artist',
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dialogField(name, 'Artist name'),
            const SizedBox(height: 10),
            _dialogField(spotify, 'Spotify URL (optional)'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const CustomText(text: 'Cancel', color: Colors.white54),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: const CustomText(text: 'Add', color: _primary),
          ),
        ],
      ),
    );
    if (added != true || name.text.trim().isEmpty) return;
    setState(() {
      _lineup.add(
        EventLineupArtistModel(
          artistName: name.text.trim(),
          spotifyUrl: spotify.text.trim(),
          sortOrder: _lineup.length + 1,
        ),
      );
    });
  }

  Widget _dialogField(
    TextEditingController controller,
    String hint, {
    bool numeric = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white60),
        filled: true,
        fillColor: _panelFieldColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    String hint, {
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return CustomTextField(
      controller: controller,
      label: label,
      hint: hint,
      maxLines: maxLines,
      keyboardType: keyboardType,
      labelColor: Colors.white,
      filled: true,
      fillColor: _fieldColor,
      isBorder: false,
    );
  }

  Widget _buildThumbnailPicker() {
    final ImageProvider? image = _thumbnailFile != null
        ? FileImage(_thumbnailFile!)
        : _existingThumbnail.isNotEmpty
        ? NetworkImage(_existingThumbnail)
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CustomText(
          text: 'Thumbnail Image',
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _pickThumbnail,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 130,
            width: double.infinity,
            decoration: BoxDecoration(
              color: _fieldColor,
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
                      Icon(Icons.camera_alt_outlined, color: Colors.white70),
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

  Widget _buildGalleryPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CustomText(
          text: 'Event Images',
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _pickGallery,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 82,
            width: double.infinity,
            decoration: BoxDecoration(
              color: _fieldColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_photo_alternate_outlined, color: Colors.white70),
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

  Widget _buildGalleryPreviews() {
    final total = _existingImages.length + _galleryFiles.length;
    if (total == 0) return const SizedBox.shrink();
    return SizedBox(
      height: 70,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: total,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final existing = index < _existingImages.length;
          final provider = existing
              ? NetworkImage(_existingImages[index]) as ImageProvider
              : FileImage(_galleryFiles[index - _existingImages.length]);
          return Stack(
            children: [
              Container(
                height: 70,
                width: 70,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  image: DecorationImage(image: provider, fit: BoxFit.cover),
                ),
              ),
              Positioned(
                right: 3,
                top: 3,
                child: InkWell(
                  onTap: () => setState(() {
                    if (existing) {
                      _existingImages.removeAt(index);
                    } else {
                      _galleryFiles.removeAt(index - _existingImages.length);
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

  Widget _buildLocationSuggestions() {
    if (_isSearchingLocation || _isResolvingLocation) {
      return const Padding(
        padding: EdgeInsets.only(top: 8),
        child: LinearProgressIndicator(
          minHeight: 2,
          color: _primary,
          backgroundColor: Color(0xFF242424),
        ),
      );
    }
    if (_locationSuggestions.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: _fieldColor,
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
                leading: const Icon(
                  Icons.location_on_outlined,
                  color: _primary,
                ),
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
                onTap: () => _selectSuggestion(suggestion),
              ),
              if (index != _locationSuggestions.length - 1)
                const Divider(height: 1, color: Colors.white10),
            ],
          );
        }),
      ),
    );
  }

  String _dateTimeLabel(DateTime? value) {
    if (value == null) return 'Select date & time';
    final local = value.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour < 12 ? 'AM' : 'PM';
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}\n$hour:$minute $period';
  }

  String _numberLabel(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(2);

  @override
  void dispose() {
    _locationDebounce?.cancel();
    nameController.dispose();
    descriptionController.dispose();
    locationController.dispose();
    priceController.dispose();
    dressCodeController.dispose();
    genresController.dispose();
    super.dispose();
  }
}

class _DateTimeField extends StatelessWidget {
  const _DateTimeField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: const Color(0xFF161616),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CustomText(text: label, color: Colors.white54, fontSize: 11),
            const SizedBox(height: 7),
            Row(
              children: [
                Expanded(
                  child: CustomText(
                    text: value,
                    color: Colors.white,
                    fontSize: 12,
                    maxLine: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 5),
                const Icon(
                  Icons.calendar_month_outlined,
                  color: Color(0xFFDCA73A),
                  size: 18,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ListEditor extends StatelessWidget {
  const _ListEditor({
    required this.title,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptyText,
    required this.onAdd,
    required this.children,
  });

  final String title;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyText;
  final VoidCallback onAdd;
  final List<Widget> children;

  static const _panel = Color(0xFF242424);
  static const _gold = Color(0xFFDCA73A);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: CustomText(
                text: title,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            TextButton(
              onPressed: onAdd,
              child: const CustomText(
                text: 'Add',
                color: _gold,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          decoration: BoxDecoration(
            color: _panel,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _gold.withValues(alpha: 0.28)),
          ),
          child: children.isEmpty
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(emptyIcon, color: _gold.withValues(alpha: 0.85), size: 20),
                    const SizedBox(height: 10),
                    CustomText(
                      text: emptyTitle,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 4),
                    CustomText(
                      text: emptyText,
                      fontSize: 12,
                      color: const Color(0xFFC8C8C8),
                      height: 1.4,
                    ),
                  ],
                )
              : Column(children: children),
        ),
      ],
    );
  }
}
