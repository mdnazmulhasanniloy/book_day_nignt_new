import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/resources/common_widget/compact_empty_state.dart';
import '../../../../core/resources/common_widget/custom_button.dart';
import '../../../../core/resources/common_widget/custom_drop_down_widget.dart';
import '../../../../core/resources/common_widget/custom_text.dart';
import '../../../../core/resources/common_widget/custom_text_field.dart';
import '../controllers/explore_controller.dart';
import '../model/place_suggestion_model.dart';

class FilterBottomSheet extends StatelessWidget {
  const FilterBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<ExploreController>()
        ? Get.find<ExploreController>()
        : Get.put(ExploreController());
    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(
          color: Color(0xFF0D0D0D),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 50,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Expanded(
                          child: CustomText(
                            text: 'Filter',
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        TextButton(
                          onPressed: controller.resetFilters,
                          child: const Text(
                            'Reset',
                            style: TextStyle(color: Color(0xFFE1B144)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Obx(
                      () => CustomDropDownWidget(
                        key: ValueKey(controller.selectedCategory.value),
                        items: ExploreController.categories,
                        hintText: 'Club or event',
                        selectedValue: controller.selectedCategory.value,
                        onChanged: (value) {
                          if (value != null) {
                            controller.selectedCategory.value = value;
                          }
                        },
                        fillColor: const Color(0xFF161616),
                        dropDownColor: const Color(0xFF161616),
                        filled: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Obx(
                      () => CustomDropDownWidget(
                        key: ValueKey(controller.selectedCategoryType.value),
                        items: ExploreController.categoryTypes,
                        hintText: 'Category',
                        selectedValue: controller.selectedCategoryType.value,
                        onChanged: (value) {
                          if (value != null) {
                            controller.selectedCategoryType.value = value;
                          }
                        },
                        fillColor: const Color(0xFF161616),
                        dropDownColor: const Color(0xFF161616),
                        filled: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    CustomTextField(
                      hint: 'Mood (optional)',
                      controller: controller.moodController,
                      onChanged: (value) =>
                          controller.selectedMood.value = value.trim(),
                      fillColor: const Color(0xFF161616),
                      filled: true,
                    ),
                    const SizedBox(height: 18),
                    _FilterTabs(controller: controller),
                    const SizedBox(height: 24),
                    Obx(() {
                      switch (controller.selectedTab.value) {
                        case 'Location':
                          return _LocationFilter(controller: controller);
                        case 'Price':
                          return _PriceFilter(controller: controller);
                        case 'Rating':
                          return _RatingFilter(controller: controller);
                        default:
                          return _DateFilter(controller: controller);
                      }
                    }),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 18,
                      offset: const Offset(0, -8),
                    ),
                  ],
                ),
                child: CustomButton(
                  title: 'Apply Filters',
                  onTap: () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    controller.applyFilters();
                    Get.back();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterTabs extends StatelessWidget {
  const _FilterTabs({required this.controller});

  final ExploreController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: ['Date', 'Location', 'Price', 'Rating']
              .map((title) {
                final isSelected = controller.selectedTab.value == title;
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: InkWell(
                    onTap: () => controller.selectedTab.value = title,
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.transparent
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFE1B144)
                              : Colors.transparent,
                        ),
                      ),
                      child: CustomText(
                        text: title,
                        color: isSelected ? Colors.white : Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              })
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _DateFilter extends StatelessWidget {
  const _DateFilter({required this.controller});

  final ExploreController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Select date'),
        const SizedBox(height: 8),
        ...ExploreController.dateOptions.map(
          (option) => _RadioChoice(
            title: option,
            selected: controller.selectedDateOption,
          ),
        ),
        const SizedBox(height: 12),
        const CustomText(
          text: 'Custom date',
          color: Colors.white,
          fontSize: 14,
        ),
        const SizedBox(height: 10),
        CustomTextField(
          controller: controller.customDateController,
          hint: 'DD/MM/YYYY',
          readOnly: true,
          onTap: () => controller.selectDate(context),
          suffixIcon: const Icon(Icons.calendar_month, color: Colors.grey),
        ),
      ],
    );
  }
}

class _LocationFilter extends StatelessWidget {
  const _LocationFilter({required this.controller});

  final ExploreController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomTextField(
          controller: controller.locationSearchController,
          hint: 'Search area, city or place',
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          onChanged: controller.onLocationSearchChanged,
        ),
        const SizedBox(height: 16),
        Obx(
          () => InkWell(
            onTap: () => controller.selectLocation('Current location'),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: controller.selectedLocation.value == 'Current location'
                      ? const Color(0xFFE1B144)
                      : Colors.white10,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.my_location_rounded,
                    color: Color(0xFFE1B144),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const CustomText(
                          text: 'Use current location',
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                        const SizedBox(height: 3),
                        CustomText(
                          text: controller.currentLocationLabel,
                          color: Colors.grey,
                          fontSize: 12,
                          maxLine: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: controller.isLocationLoading.value
                        ? null
                        : controller.refreshCurrentLocation,
                    icon: controller.isLocationLoading.value
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFFE1B144),
                            ),
                          )
                        : const Icon(Icons.refresh_rounded, color: Colors.grey),
                  ),
                  Icon(
                    controller.selectedLocation.value == 'Current location'
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color:
                        controller.selectedLocation.value == 'Current location'
                        ? const Color(0xFFE1B144)
                        : Colors.grey,
                    size: 21,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _LocationChoice(title: 'Any location', controller: controller),
        const Divider(color: Colors.white10),
        Obx(
          () => _SectionTitle(
            controller.locationQuery.value.trim().length < 2
                ? 'Popular cities'
                : 'Place suggestions',
          ),
        ),
        const SizedBox(height: 6),
        Obx(() {
          if (controller.isSearchingPlaces.value ||
              controller.isResolvingPlace.value) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 22),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFE1B144),
                ),
              ),
            );
          }

          final suggestions = controller.placeSuggestions;
          if (suggestions.isEmpty) {
            final selected = controller.selectedPlace.value;
            if (selected != null) {
              return _SelectedPlaceTile(suggestion: selected);
            }
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: CompactEmptyState(
                icon: Icons.place_outlined,
                title: 'No matching place',
                message: 'Try another name or location.',
              ),
            );
          }

          return Column(
            children: suggestions
                .map(
                  (suggestion) => _PlaceSuggestionTile(
                    suggestion: suggestion,
                    onTap: () => controller.selectPlace(suggestion),
                  ),
                )
                .toList(growable: false),
          );
        }),
      ],
    );
  }
}

class _PlaceSuggestionTile extends StatelessWidget {
  const _PlaceSuggestionTile({required this.suggestion, required this.onTap});

  final PlaceSuggestionModel suggestion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              height: 38,
              width: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.location_on_outlined,
                color: Color(0xFFE1B144),
                size: 21,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomText(
                    text: suggestion.primaryText,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    maxLine: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (suggestion.secondaryText.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    CustomText(
                      text: suggestion.secondaryText,
                      color: Colors.grey,
                      fontSize: 11,
                      maxLine: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.north_west_rounded, color: Colors.grey, size: 18),
          ],
        ),
      ),
    );
  }
}

class _SelectedPlaceTile extends StatelessWidget {
  const _SelectedPlaceTile({required this.suggestion});

  final PlaceSuggestionModel suggestion;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE1B144).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE1B144)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Color(0xFFE1B144), size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: CustomText(
              text: suggestion.displayText,
              color: Colors.white,
              maxLine: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationChoice extends StatelessWidget {
  const _LocationChoice({required this.title, required this.controller});

  final String title;
  final ExploreController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isSelected = controller.selectedLocation.value == title;
      return InkWell(
        onTap: () => controller.selectLocation(title),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            children: [
              Expanded(
                child: CustomText(
                  text: title,
                  color: isSelected ? const Color(0xFFE1B144) : Colors.grey,
                  maxLine: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: isSelected ? const Color(0xFFE1B144) : Colors.grey,
                size: 21,
              ),
            ],
          ),
        ),
      );
    });
  }
}

class _PriceFilter extends StatelessWidget {
  const _PriceFilter({required this.controller});

  final ExploreController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Select Price'),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: CustomTextField(
                controller: controller.minimumPriceController,
                hint: 'Min price',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: controller.onCustomPriceChanged,
                fillColor: Colors.white.withValues(alpha: 0.035),
                filled: true,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: CustomTextField(
                controller: controller.maximumPriceController,
                hint: 'Max price',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: controller.onCustomPriceChanged,
                fillColor: Colors.white.withValues(alpha: 0.035),
                filled: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Obx(
          () => Column(
            children: ExploreController.priceOptions
                .map((price) {
                  final isSelected =
                      controller.selectedPriceRange.value == price;
                  return InkWell(
                    onTap: () => controller.selectPriceRange(price),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      child: CustomText(
                        text: price,
                        color: isSelected
                            ? const Color(0xFFE1B144)
                            : Colors.white,
                        fontSize: 16,
                        fontWeight: isSelected
                            ? FontWeight.w500
                            : FontWeight.w400,
                      ),
                    ),
                  );
                })
                .toList(growable: false),
          ),
        ),
      ],
    );
  }
}

class _RatingFilter extends StatelessWidget {
  const _RatingFilter({required this.controller});

  final ExploreController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Select Rating'),
        const SizedBox(height: 14),
        Obx(
          () => Row(
            children: ExploreController.ratingOptions
                .asMap()
                .entries
                .expand((entry) {
                  final rating = entry.value;
                  final isSelected = controller.selectedRating.value == rating;
                  return [
                    if (entry.key > 0) const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: () => controller.selectedRating.value = rating,
                        borderRadius: BorderRadius.circular(14),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          height: 58,
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(
                                    0xFFE1B144,
                                  ).withValues(alpha: 0.08)
                                : Colors.white.withValues(alpha: 0.035),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFFE1B144)
                                  : Colors.white.withValues(alpha: 0.04),
                            ),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: CustomText(
                              text: rating,
                              color: isSelected
                                  ? const Color(0xFFE1B144)
                                  : Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              maxLine: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ];
                })
                .toList(growable: false),
          ),
        ),
      ],
    );
  }
}

class _RadioChoice extends StatelessWidget {
  const _RadioChoice({required this.title, required this.selected});

  final String title;
  final RxString selected;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isSelected = selected.value == title;
      return InkWell(
        onTap: () => selected.value = title,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            children: [
              Expanded(
                child: CustomText(
                  text: title,
                  color: isSelected ? const Color(0xFFE1B144) : Colors.white,
                ),
              ),
              Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: isSelected ? const Color(0xFFE1B144) : Colors.grey,
                size: 22,
              ),
            ],
          ),
        ),
      );
    });
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return CustomText(
      text: title,
      color: Colors.white,
      fontSize: 16,
      fontWeight: FontWeight.w600,
    );
  }
}
