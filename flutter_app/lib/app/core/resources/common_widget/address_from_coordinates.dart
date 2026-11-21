import 'package:flutter/material.dart';

import '../../utils/location_helpfer_function.dart';
import 'custom_text.dart';

/// Shows [fallbackText] when provided, otherwise reverse-geocodes [lat]/[lng].
class AddressFromCoordinates extends StatelessWidget {
  const AddressFromCoordinates({
    super.key,
    this.lat,
    this.lng,
    this.existingAddress = '',
    this.fallback = 'Location not found',
    this.loadingText = 'Finding location...',
    this.color = Colors.grey,
    this.fontSize = 14,
    this.fontWeight,
    this.maxLine = 1,
  });

  final double? lat;
  final double? lng;
  final String existingAddress;
  final String fallback;
  final String loadingText;
  final Color color;
  final double fontSize;
  final FontWeight? fontWeight;
  final int maxLine;

  @override
  Widget build(BuildContext context) {
    final known = existingAddress.trim();
    final weight = fontWeight ?? FontWeight.normal;
    if (known.isNotEmpty) {
      return CustomText(
        text: known,
        color: color,
        fontSize: fontSize,
        fontWeight: weight,
        maxLine: maxLine,
        overflow: TextOverflow.ellipsis,
      );
    }

    if (lat == null || lng == null) {
      return CustomText(
        text: fallback,
        color: color,
        fontSize: fontSize,
        fontWeight: weight,
        maxLine: maxLine,
        overflow: TextOverflow.ellipsis,
      );
    }

    return FutureBuilder<String>(
      future: LocationHelperFunction.getCityCountryFromLatLng(
        lat: lat!,
        lng: lng!,
        fallback: fallback,
      ),
      builder: (context, snapshot) {
        final text = snapshot.connectionState == ConnectionState.waiting
            ? loadingText
            : (snapshot.data?.trim().isNotEmpty == true
                  ? snapshot.data!
                  : fallback);
        return CustomText(
          text: text,
          color: color,
          fontSize: fontSize,
          fontWeight: weight,
          maxLine: maxLine,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}
