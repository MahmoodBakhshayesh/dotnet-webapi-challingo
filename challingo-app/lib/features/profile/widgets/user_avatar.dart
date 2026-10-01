
import '/core/constants/apis.dart';
import '/features/profile/profile_state.dart';
import 'package:fast_cached_network_image/fast_cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class UserAvatar extends ConsumerWidget {
  final String? url;
  final double size;
  final Function? onChange;

  const UserAvatar({super.key, required this.url, this.size = 40, this.onChange});

  @override
  Widget build(BuildContext context,WidgetRef ref) {
    final loading = ref.watch(settingAvatarProvider);
    final canChange =  onChange!=null;

    final  String? photoUrl = url==null?null:Apis.photoBaseUrl+ url!;
    return Container(
      padding: EdgeInsets.all(8),
      width: size,
      height: size,

      constraints: BoxConstraints(),
      child: ClipRRect(
        borderRadius: BorderRadiusGeometry.circular(size),

        child: Container(
          decoration: BoxDecoration(
              color: Colors.blueGrey
          ),
          child: GestureDetector(
            onTap: !canChange?null:(){
              onChange!(photoUrl);
            },
            child: Builder(
              builder: (BuildContext context) {
                if (photoUrl == null) {
                  return CircleAvatar(
                    child: Icon(
                      canChange ? Icons.person_add : Icons.person,
                      size: size * 0.4,
                    ),
                  );
                }
                if(loading){
                  return SpinKitCircle(size: size*.6,color: Colors.black,);
                }

                return FastCachedImage(url:photoUrl,fit: BoxFit.contain);
              },
            ),
          ),
        ),
      ),
    );
  }
}
