import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  // PayMongo API Keys
  static String get paymongoSecretKey => dotenv.env['PAYMONGO_SECRET_KEY'] ?? '';
  static String get paymongoPublicKey => dotenv.env['PAYMONGO_PUBLIC_KEY'] ?? '';
  static String get paymongoWebhookSecret => dotenv.env['PAYMONGO_WEBHOOK_SECRET'] ?? '';

  // Xendit API Keys
  static String get xenditSecretKey => dotenv.env['XENDIT_SECRET_KEY'] ?? '';
  static String get xenditPublicKey => dotenv.env['XENDIT_PUBLIC_KEY'] ?? '';
  static String get xenditWebhookToken => dotenv.env['XENDIT_WEBHOOK_TOKEN'] ?? '';

  // Google Maps API
  static String get googleMapsApiKey => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  // Email Configuration
  static String get smtpServer => dotenv.env['SMTP_SERVER'] ?? '';
  static String get smtpPort => dotenv.env['SMTP_PORT'] ?? '';
  static String get emailAddress => dotenv.env['EMAIL_ADDRESS'] ?? '';
  static String get emailPassword => dotenv.env['EMAIL_PASSWORD'] ?? '';
  static String get emailUseTls => dotenv.env['EMAIL_USE_TLS'] ?? '';
}
