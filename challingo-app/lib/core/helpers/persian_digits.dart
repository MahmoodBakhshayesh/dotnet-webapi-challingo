/// Persian (Eastern Arabic) digits ۰–۹ (U+06F0–U+06F9).
extension PersianDigits on String {
  /// Converts ASCII `0`–`9` to Persian digits.
  String toPersianDigits() {
    if (isEmpty) return this;
    final buffer = StringBuffer();
    for (final rune in runes) {
      if (rune >= 0x30 && rune <= 0x39) {
        buffer.writeCharCode(0x06F0 + (rune - 0x30));
      } else {
        buffer.writeCharCode(rune);
      }
    }
    return buffer.toString();
  }

  /// Converts Persian / Arabic-Indic digits to ASCII `0`–`9`.
  String toEnglishDigits() {
    if (isEmpty) return this;
    final buffer = StringBuffer();
    for (final rune in runes) {
      if (rune >= 0x06F0 && rune <= 0x06F9) {
        buffer.writeCharCode(0x30 + (rune - 0x06F0));
      } else if (rune >= 0x0660 && rune <= 0x0669) {
        buffer.writeCharCode(0x30 + (rune - 0x0660));
      } else {
        buffer.writeCharCode(rune);
      }
    }
    return buffer.toString();
  }
}
