import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:http/http.dart' as http;
import 'package:pos_system/core/error/failure.dart';
import 'dart:convert';

/// Single switch point to swap SMS gateways.
/// Change this to HttpSmsGateway when real API credentials are ready.
final smsGatewayProvider = Provider<SmsGateway>((ref) {
  return LoggingSmsGateway();
  // return HttpSmsGateway();
});

abstract class SmsGateway {
  Future<Either<Failure, void>> sendSms({required String toPhone, required String message});
}

class LoggingSmsGateway implements SmsGateway {
  @override
  Future<Either<Failure, void>> sendSms({required String toPhone, required String message}) async {
    debugPrint('================ SMS NOTIFICATION STUB ================');
    debugPrint('Would send SMS to: $toPhone');
    debugPrint('Message: $message');
    debugPrint('=======================================================');
    return const Right(null);
  }
}

class HttpSmsGateway implements SmsGateway {
  @override
  Future<Either<Failure, void>> sendSms({required String toPhone, required String message}) async {
    try {
      final apiUrl = dotenv.env['SMS_API_URL'];
      final apiKey = dotenv.env['SMS_API_KEY'];
      final senderId = dotenv.env['SMS_SENDER_ID'];

      if (apiUrl == null || apiUrl.isEmpty) {
        return Left(Failure('SMS_API_URL is not configured'));
      }

      // TODO: Adjust payload and headers to match the chosen SMS provider (e.g. notify.lk, Text.lk, etc.)
      final uri = Uri.parse(apiUrl);
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey', // Or whatever auth scheme they use
        },
        body: jsonEncode({
          'to': toPhone, // May need to strip leading '0' or add '+94' based on API docs
          'sender_id': senderId,
          'message': message,
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return const Right(null);
      } else {
        return Left(Failure('Failed to send SMS: ${response.statusCode} - ${response.body}'));
      }
    } catch (e, st) {
      return Left(Failure('Exception sending SMS', error: e, stackTrace: st));
    }
  }
}
