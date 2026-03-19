import 'package:url_launcher/url_launcher.dart';

/// Ссылки на условия и политику конфиденциальности.
class LegalLinks {
  LegalLinks._();

  static const String termsOfUse =
      'https://sites.google.com/view/gold-mine-trolls/terms-of-use';
  static const String privacyPolicy =
      'https://sites.google.com/view/gold-mine-trolls/privacy-policy';

  static Future<void> openTermsOfUse() async {
    try {
      await launchUrl(
        Uri.parse(termsOfUse),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
  }

  static Future<void> openPrivacyPolicy() async {
    try {
      await launchUrl(
        Uri.parse(privacyPolicy),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
  }
}
