import 'dart:developer' as developer;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:http/http.dart' as http;
import 'package:pos_system/core/error/failure.dart';
import 'dart:convert';

import 'package:pos_system/features/subscription/domain/subscription_service.dart';

/// Single switch point to swap SMS gateways.
/// Change this to HttpSmsGateway when real API credentials are ready.
final smsGatewayProvider = Provider<SmsGateway>((ref) {
  return HttpSmsGateway(ref.watch(subscriptionServiceProvider));
});

abstract class SmsGateway {
  Future<Either<Failure, void>> sendSms({
    required String toPhone,
    required String message,
  });
}

class LoggingSmsGateway implements SmsGateway {
  final SubscriptionService _subscriptionService;

  LoggingSmsGateway(this._subscriptionService);

  @override
  Future<Either<Failure, void>> sendSms({
    required String toPhone,
    required String message,
  }) async {
    final isActive = await _subscriptionService.isSubscriptionActive();
    if (!isActive) {
      return Left(Failure('Subscription expired - contact support to renew'));
    }

    final buffer = StringBuffer();
    buffer.writeln('================ SMS NOTIFICATION STUB ================');
    buffer.writeln('Would send SMS to: $toPhone');
    buffer.writeln('Message: $message');
    buffer.writeln('=======================================================');
    developer.log(buffer.toString(), name: 'SmsGateway');
    return const Right(null);
  }
}

class HttpSmsGateway implements SmsGateway {
  final SubscriptionService _subscriptionService;

  HttpSmsGateway(this._subscriptionService);

  @override
  Future<Either<Failure, void>> sendSms({
    required String toPhone,
    required String message,
  }) async {
    try {
      final isActive = await _subscriptionService.isSubscriptionActive();
      if (!isActive) {
        return Left(Failure('Subscription expired - contact support to renew'));
      }

      final apiUrl = dotenv.env['SMS_API_URL'];
      final userId = dotenv.env['SMS_USER_ID'];
      final apiKey = dotenv.env['SMS_API_KEY'];
      final senderId = dotenv.env['SMS_SENDER_ID'];

      if (apiUrl == null ||
          apiUrl.isEmpty ||
          userId == null ||
          userId.isEmpty ||
          apiKey == null ||
          apiKey.isEmpty ||
          senderId == null ||
          senderId.isEmpty) {
        return Left(Failure('SMS API configuration is missing in .env'));
      }

      // Normalize Sri Lankan phone number to 947XXXXXXXX
      String normalizedPhone = toPhone.replaceAll(RegExp(r'[\s\-]'), '');
      if (normalizedPhone.startsWith('+')) {
        normalizedPhone = normalizedPhone.substring(1);
      }
      if (normalizedPhone.startsWith('0')) {
        normalizedPhone = '94${normalizedPhone.substring(1)}';
      }

      final uri = Uri.parse(apiUrl).replace(
        queryParameters: {
          'user_id': userId,
          'api_key': apiKey,
          'sender_id': senderId,
          'to': normalizedPhone,
          'message': message,
        },
      );

      final response = await http.get(uri);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        try {
          final jsonResponse = jsonDecode(response.body);
          // Notify.lk typically returns a status object. Assuming status 'success' or checking for error fields.
          // Since their exact JSON isn't fully detailed here, a 200 OK with valid JSON is a good baseline,
          // but we can check if it explicitly reports an API-level error.
          if (jsonResponse is Map && jsonResponse['status'] == 'error') {
            return Left(
              Failure(
                'SMS API returned error: ${jsonResponse['message'] ?? response.body}',
              ),
            );
          }
          return const Right(null);
        } catch (e) {
          // If response is not valid JSON but status is 200, we still might consider it successful
          // depending on provider, but let's be strict.
          return Left(
            Failure('Failed to parse SMS API response: ${response.body}'),
          );
        }
      } else {
        return Left(
          Failure(
            'Failed to send SMS: HTTP ${response.statusCode} - ${response.body}',
          ),
        );
      }
    } catch (e, st) {
      return Left(Failure('Exception sending SMS', error: e, stackTrace: st));
    }
  }
}
