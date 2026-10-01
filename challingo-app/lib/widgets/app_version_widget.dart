import 'package:flutter/material.dart';

import '../core/data/app_data.dart';


/// Displays the installed app version as `v<version> (<build>)`, loaded
/// from [AppData].
class VersionText extends StatefulWidget {
  const VersionText({super.key});

  @override
  State<VersionText> createState() => _VersionTextState();
}

class _VersionTextState extends State<VersionText> {
  String versionNumber = '';
  String versionCode = '';

  @override
  void initState() {
    super.initState();
    final appInfo = AppData.instance.getAppInfo;
    appInfo.then((value) {
      versionNumber = value.versionNumber ?? '';
      versionCode = value.versionKey ?? '';
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Text('v$versionNumber ($versionCode)');
  }
}
