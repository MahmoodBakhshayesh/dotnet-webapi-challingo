import 'package:hooks_riverpod/legacy.dart';

import 'domain/entities/login_response.dart';

final loginIsLoadingProvider = StateProvider<bool>((ref) => false);
final loginErrorMessageProvider = StateProvider<String?>((ref) => null);
final authenticatedUserProvider = StateProvider<UserEntity?>((ref) => null);
final signupStepProvider = StateProvider<int>((ref) => 0);
final checkingUserProvider = StateProvider<bool>((ref) => true);
final receivedCodeProvider = StateProvider<String>((ref) => '');
