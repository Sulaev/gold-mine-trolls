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
}
