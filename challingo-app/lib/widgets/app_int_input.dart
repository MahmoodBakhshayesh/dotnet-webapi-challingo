import 'package:flutter/material.dart';
import 'package:input_quantity/input_quantity.dart';

import '../core/theme/app_dimens.dart';

/// Labeled integer stepper (plus/minus buttons) built on `input_quantity`,
/// clamped to [max] and stepping by [steps].
class AppIntInput extends StatefulWidget {
  final String label;
  final num? max;
  final int value;
  final num steps;
  final void Function(int v) onChange;
  const AppIntInput({super.key, required this.label, this.max, required this.value, required this.onChange, this.steps = 1.0});

  @override
  State<AppIntInput> createState() => _AppIntInputState();
}

class _AppIntInputState extends State<AppIntInput> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 4,
      children: [
        Text(widget.label),
        SizedBox(
          height: AppDimens.controlHeight,
          child: InputQty.int(
            steps: widget.steps,
            isIntrinsicWidth: false,
            maxVal: widget.max ?? double.maxFinite,
            initVal: widget.value,
            onQtyChanged: (a) {
              widget.onChange(a);
            },
            decoration: QtyDecorationProps(
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              fillColor: Colors.white,
              isCollapsed: false,
              isBordered: false,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
