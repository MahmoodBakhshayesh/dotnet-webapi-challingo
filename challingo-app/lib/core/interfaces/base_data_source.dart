import '../helpers/api_service.dart';
import '../helpers/remote_response_parser.dart';
import 'base_key_value_store.dart';

abstract class BaseDataSource {}

abstract class LocalDataSource extends BaseDataSource {
  final BaseKeyValueStore keyValueStore;
  LocalDataSource(this.keyValueStore);
}

abstract class RemoteDataSource extends BaseDataSource with RemoteResponseParser {
  final ApiService apiService;

  RemoteDataSource(this.apiService);
}
