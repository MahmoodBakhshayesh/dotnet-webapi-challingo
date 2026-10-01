import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MyInputFormatter {
  MyInputFormatter._();

  static TextInputFormatter justNumber = FilteringTextInputFormatter.allow(RegExp(r'[0-9]'));

  static TextInputFormatter justText = FilteringTextInputFormatter.allow(RegExp(r'[A-z]'));

  static TextInputFormatter numberWithOption = FilteringTextInputFormatter.allow(RegExp(r'^[\d\(\)\-+]+$'));

  static TextInputFormatter uppercase = UpperCaseTextFormatter();

  static TextInputFormatter alphaNumeric = AlphaNumericFormatter();
}

TextEditingController tcFromIntValue(int? num, {bool isZeroValid = true}) {
  if (num == null) return TextEditingController();
  if (isZeroValid) {
    TextEditingController tc = TextEditingController.fromValue(TextEditingValue(text: num == 0 ? '0' : num.toString(), selection: TextSelection.fromPosition(TextPosition(offset: num.toString().length))));
    return tc;
  } else {
    String numS = num == 0 ? '' : '$num';
    TextEditingController tc = TextEditingController.fromValue(TextEditingValue(text: numS, selection: TextSelection.fromPosition(TextPosition(offset: numS.length))));
    return tc;
  }
}

TextEditingController tcFromStrValue(String val) {
  TextEditingController tc = TextEditingController.fromValue(TextEditingValue(text: val, selection: TextSelection.fromPosition(TextPosition(offset: val.length))));
  return tc;
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

class AlphaNumericFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.replaceAll(RegExp(r'[^a-zA-Z0-9]'), ''),
      selection: newValue.selection,
    );
  }
}

class DateTextFormatter extends TextInputFormatter {
  final DateTime minDate;
  final DateTime maxDate;

  DateTextFormatter({required this.minDate, required this.maxDate});
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {

    //this fixes backspace bug
    if (oldValue.text.length >= newValue.text.length) {
      // if(newValue.text.length>8) return oldValue;

      return newValue;
    }

    var dateText = _addSeperators(newValue.text, '/');
    return newValue.copyWith(text: dateText, selection: updateCursorPosition(dateText));
  }

  String _addSeperators(String value, String seperator) {
    value = value.replaceAll('/', '');
    var newString = '';
    for (int i = 0; i < value.length; i++) {
      newString += value[i];
      if (i == 3) {
        int? typedYear = int.tryParse(newString.substring(0,4))??0;
        int year = max(typedYear,minDate.year);
        year = min(year, maxDate.year);
        newString = '$year';
        newString += seperator;
      }
      if (i == 5) {
        int? typedMonth = int.tryParse(newString.substring(5,7))??0;
        // int month = max(typedMonth,minDate.month);
        // month = min(month, maxDate.month);

        int month = max(typedMonth,1);
        month = min(month, 12);
        newString = "${newString.substring(0,5)}${month.toString().padLeft(2,'0')}";
        newString += seperator;
      }
      if (i == 7) {
        int? typedDay = int.tryParse(newString.substring(8,10))??0;
        // int day = max(typedDay,minDate.day);
        // day = min(day, maxDate.day);
        int day = max(typedDay,1);
        day = min(day, 31);
        newString = "${newString.substring(0,7)}$seperator${day.toString().padLeft(2,'0')}";
        // newString += seperator;
      }
    }
    return newString;
  }

  TextSelection updateCursorPosition(String text) {
    return TextSelection.fromPosition(TextPosition(offset: text.length));
  }
}

class PersianToEnglishNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    String persianToEnglish(String input) {
      const persianNumbers = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
      const englishNumbers = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];

      for (int i = 0; i < persianNumbers.length; i++) {
        input = input.replaceAll(persianNumbers[i], englishNumbers[i]);
      }

      return input;
    }

    String newText = persianToEnglish(newValue.text);
    return newValue.copyWith(text: newText);
  }
}
