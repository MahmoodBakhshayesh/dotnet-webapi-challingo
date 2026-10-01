import '/features/home/domain/data_sources/home_data_source_local.dart';
import '/features/home/domain/data_sources/home_data_source_remote.dart';

import '../interfaces/home_repository_interface.dart';
import 'package:get_it/get_it.dart';

class HomeRepository implements HomeRepositoryInterface {
  final HomeDataSourceRemote homeDataSourceRemote;
  final HomeDataSourceLocal homeDataSourceLocal ;

HomeRepository({
    required this.homeDataSourceRemote,
    required this.homeDataSourceLocal,
  });

  static HomeRepository builder() {
    return HomeRepository(
      homeDataSourceRemote: GetIt.instance.get(instanceName: 'HomeDataSourceRemote'),
      homeDataSourceLocal: GetIt.instance.get(instanceName: 'HomeDataSourceLocal'),
    );
   }
}
