/// One dropdown entry of a `HoverableTabBar`: display [title] and the
/// [value] passed to the tab's `onPressed`.
class HoverableTabBarItem {
  const HoverableTabBarItem({required this.title, required this.value});

  final String title;
  final String value;
}
