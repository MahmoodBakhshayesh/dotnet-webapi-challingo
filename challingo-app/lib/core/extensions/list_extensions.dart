
extension StringListUtils on List<String> {
  int get validFieldsLength {
    int count = 0;

    for (final item in this) {
      if (item.isNotEmpty) count++;
    }

    return count;
  }

  void fillUntilIndex(int index) {
    while (length <= index) {
      add('');
    }
  }
}

extension FirstWhereExt<T> on Iterable<T> {
  /// The first element satisfying [test], or `null` if there are none.
  T? firstWhereOrNull(bool Function(T element) test) {
    for (var element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}