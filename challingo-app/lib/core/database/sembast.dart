import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'package:sembast/sembast_io.dart';
import 'package:sembast_web/sembast_web.dart';

class SemBastDB {
  SemBastDB._();

  static late Database _db;
  static late StoreRef<String, dynamic> _store;
  static final SemBastDB instance = SemBastDB._();

  Database get db => _db;

  StoreRef<String, dynamic> get store => _store;

  static Future<SemBastDB> init([String? name]) async {
    String dbName = name ?? 'app.db';
    if (kIsWeb) {
      var factory = databaseFactoryWeb;
      var db = await factory.openDatabase(dbName);
      _db = db;
    } else {
      final appDir = await getApplicationDocumentsDirectory();
      await appDir.create(recursive: true);
      final dbPath = join(appDir.path, dbName);
      final database = await databaseFactoryIo.openDatabase(dbPath);
      _db = database;
    }
    _store = StoreRef.main();
    await SemBastDB.seedDatabase();
    return instance;
  }

  static StoreRef<String, Map<String, Object?>> get usersTable => stringMapStoreFactory.store('users');

  static Future<void> setValue(String key, dynamic value) async {
    _store.record('key').put(_db, value);
  }

  static Future<T> getValue<T>(String key) async {
    final value = await _store.record('key').get(_db) as T;
    return value;
  }

  static Future<void> seedDatabase() async {
    if ((await usersTable.count(_db)) < 2) {
      // Seed local users here when needed.
    }
  }
}
