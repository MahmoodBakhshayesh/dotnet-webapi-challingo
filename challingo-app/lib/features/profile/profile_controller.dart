import 'dart:convert';



import 'package:challingo/core/constants/apis.dart';

import 'package:challingo/core/data/app_data.dart';

import 'package:challingo/core/helpers/nullable.dart';

import 'package:challingo/core/helpers/use_case_runner.dart';

import 'package:challingo/core/interfaces/base_failure.dart';

import 'package:challingo/core/interfaces/base_result.dart';

import 'package:challingo/features/login/domain/entities/login_response.dart';

import 'package:challingo/features/login/login_view_state.dart';

import 'package:challingo/features/profile/profile_state.dart';

import 'package:challingo/features/profile/usecases/update_profile_usecase.dart';

import 'package:dio/dio.dart';

import 'package:fast_cached_network_image/fast_cached_network_image.dart';

import 'package:flutter/material.dart';

import 'package:http_parser/http_parser.dart';

import 'package:image_picker/image_picker.dart';

import '../../core/controllers/base_controller.dart';

import 'package:hooks_riverpod/hooks_riverpod.dart';



import '../../di.dart';



final profileControllerProvider = Provider.autoDispose((ref) {

  final controller = ProfileController(ref);

  Future.microtask(controller.init);

  ref.onDispose(() => controller.dispose());

  return controller;

});



class ProfileController extends BaseController {

  ProfileController(super.ref);



  Future<void> logout(BuildContext context) async {

    final authUserNotifier = ref.read(authenticatedUserProvider.notifier);

    final sp = await sharedPreferencesAsync;

    await sp.remove('User');

    AppData.instance.setToken(null);

    AppData.instance.setUserId(null);

    authUserNotifier.update((s) => null);

  }



  Future<bool> updateProfile({
    required String fullName,
    String? username,
    String? email,
  }) async {

    try {

      final updated = await runUseCase(

        locator<UpdateProfileUsecase>(),

        UpdateProfileRequest(fullName: fullName, username: username, email: email),

      );

      ref.read(authenticatedUserProvider.notifier).update((s) => updated);

      updateUserInCache(userEntity: updated);

      return true;

    } on Failure {

      return false;

    }

  }



  Future<void> setAvatar(String? current) async {

    var updatingAvatarPN = ref.read(settingAvatarProvider.notifier);

    try {

      updatingAvatarPN.update((state) => true);

      final ImagePicker picker = ImagePicker();

      picker.supportsImageSource(ImageSource.gallery);

      final XFile? image = await picker.pickImage(source: ImageSource.gallery, requestFullMetadata: false, imageQuality: 20);

      if (image == null) {

        updatingAvatarPN.update((state) => false);

        return;

      }

      int imageSize = await image.length();



      final kb = imageSize / 1024;

      final mb = kb / 1024;

      if (mb > 5) {

        FailureBus.I.emitMsg('Image Size is more than 5mb!\nUse smaller image.');

        updatingAvatarPN.update((state) => false);

        return;

      }

      await uploadImage(image);

      if (current != null) {

        await evictImage(current);

      }

      updatingAvatarPN.update((state) => false);

      return;

    } catch (e) {

      updatingAvatarPN.update((state) => false);

    }

  }



  Future<void> evictImage(String current) async {

    logger.i('evict image $current');

    await FastCachedImageConfig.deleteCachedImage(imageUrl: current);

    final NetworkImage provider = NetworkImage(current);

    await provider.evict();

  }



  Future<void> uploadImage(XFile imageFile) async {

    final fileName = imageFile.path.split('/').last;



    final formData = FormData.fromMap({

      'file': await MultipartFile.fromFile(

        imageFile.path,

        filename: fileName,

        contentType: MediaType('image', 'jpg'),

      ),

    });



    String apiAddress = '${Apis.baseUrl}users/me/files/profile-image';

    logger.w('uploading image $fileName to $apiAddress \n ${AppData.instance.token}');

    try {

      final dio = Dio(BaseOptions(receiveTimeout: Duration(minutes: 10), sendTimeout: Duration(minutes: 10), connectTimeout: Duration(minutes: 10)));

      final response = await dio.post(

        apiAddress,

        data: formData,

        options: Options(headers: {'Content-Type': 'multipart/form-data', 'Authorization': 'Bearer ${AppData.instance.token}'}),

      );



      if (response.statusCode == 200) {

        logger.w('Upload success: ${response.data}');

        final String fileUrl = response.data['Body']['Response']['FileUrl'];

        ref.read(authenticatedUserProvider.notifier).update((s) => s?.copyWith(profileImageUrl: Nullable(fileUrl)));

        updateUserInCache(userEntity: ref.read(authenticatedUserProvider)!);

      }

    } catch (e) {

      logger.w('Upload failed: $e');

      FailureBus.I.emitMsg(e.toString());

    }

  }



  Future<void> updateUserInCache({String? token, UserEntity? userEntity}) async {

    final sp = await sharedPreferencesAsync;

    LoginResponseData loginResponseData = LoginResponseData(accessToken: token ?? AppData.instance.token!, user: userEntity ?? ref.read(authenticatedUserProvider)!);

    logger.w('saveing user ing cache ${loginResponseData.toJson()}');

    await sp.setString('User', jsonEncode(loginResponseData.toJson()));

  }

}

