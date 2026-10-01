import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The base class for all controllers in the application.
abstract class BaseController {
  @protected
  final Ref ref;

  /// A pre-configured logger that automatically includes the controller's class name.
  /// Use this for all logging within controllers to provide clear, contextual output.
  final Logger logger;

  final Future<SharedPreferences> sharedPreferencesAsync ;

  /// The constructor initializes the logger with the runtimeType of the concrete class.
  BaseController(this.ref) : logger = Logger(printer: SimplePrinter(colors: true), output: ConsoleOutput()),sharedPreferencesAsync = SharedPreferences.getInstance();

  void init() {
    logger.i('Initialized');
  }

  void dispose() {
    logger.i('Disposed');
  }
}
