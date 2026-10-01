
import 'package:flutter/material.dart';
import 'package:flutter_rating_stars/flutter_rating_stars.dart';

/// Read-only 5-star rating display for a 0–5 [value].
class StartRateWidget extends StatelessWidget {
  final double value;
  const  StartRateWidget({super.key, required this.value});

  @override
  Widget build(BuildContext context) {
    return RatingStars(
      axis: Axis.horizontal,
      value:value,
      starCount: 5,
      starSize: 10,
      maxValue: 5,
      starSpacing: 2,
      maxValueVisibility: false,
      valueLabelVisibility: false,
      starOffColor: const Color(0xffe7e8ea),
      starColor: Colors.green,
      angle: 4,
    );
  }
}
