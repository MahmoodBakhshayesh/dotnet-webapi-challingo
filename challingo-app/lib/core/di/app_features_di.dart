import 'package:get_it/get_it.dart';

import '../../features/home/home_di.dart';
import '../../features/login/login_di.dart';
import '../../features/profile/profile_di.dart';
import 'generated_features_di.dart';

void registerAppFeatureDependencies(GetIt locator) {
  registerHomeDependencies(locator);
  registerLoginDependencies(locator);
  registerProfileDependencies(locator);
  registerGeneratedFeatureDependencies(locator);
}
