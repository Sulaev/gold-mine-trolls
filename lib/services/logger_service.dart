import 'package:logger/logger.dart' show Logger, PrettyPrinter, DateTimeFormat;

class LoggerService {
  static late Logger _logger;

  static void init() {
    _logger = Logger(
      printer: PrettyPrinter(
        methodCount: 0,
        errorMethodCount: 5,
        lineLength: 50,
        colors: true,
        printEmojis: true,
        dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
      ),
    );
  }

  static void info(String message) {
    _logger.i(message);
  }

  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  static void warning(String message) {
    _logger.w(message);
  }

  static void debug(String message) {
    _logger.d(message);
  }
}
