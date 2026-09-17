import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/features/settings/data/settings_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer' as developer;

final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  return SubscriptionService(
    ref.watch(settingsRepositoryProvider),
    Supabase.instance.client,
  );
});

class SubscriptionService {
  final SettingsRepository _settingsRepository;
  final SupabaseClient? _supabase;
  
  // For testing
  final Future<DateTime?> Function(String bizId)? _fetchRemoteExpiryOverride;

  SubscriptionService(this._settingsRepository, this._supabase, {Future<DateTime?> Function(String bizId)? fetchRemoteExpiryOverride}) : _fetchRemoteExpiryOverride = fetchRemoteExpiryOverride;

  Future<bool> isSubscriptionActive() async {
    try {
      final bizIdRes = await _settingsRepository.getBusinessAccountId();
      final bizId = bizIdRes.isRight() ? bizIdRes.getRight().toNullable() : null;

      if (bizId == null || bizId.isEmpty) {
        // Without a business ID, we cannot verify premium subscription
        return false;
      }

      final now = DateTime.now();
      
      final lastCheckRes = await _settingsRepository.getLastSubscriptionCheckDate();
      final lastCheck = lastCheckRes.isRight() ? lastCheckRes.getRight().toNullable() : null;
      
      bool needsNetworkCheck = true;
      if (lastCheck != null && now.difference(lastCheck).inHours < 24) {
        needsNetworkCheck = false;
      }

      if (needsNetworkCheck) {
        try {
          DateTime? expiryDt;
          if (_fetchRemoteExpiryOverride != null) {
            expiryDt = await _fetchRemoteExpiryOverride(bizId);
          } else if (_supabase != null) {
            final response = await _supabase
                .from('subscriptions')
                .select('subscription_expiry_date')
                .eq('business_account_id', bizId)
                .maybeSingle();

            if (response != null && response['subscription_expiry_date'] != null) {
              final expiryStr = response['subscription_expiry_date'] as String;
              expiryDt = DateTime.parse(expiryStr);
            }
          }

          if (expiryDt != null) {
            await _settingsRepository.setSubscriptionExpiryDate(expiryDt);
            await _settingsRepository.setLastSubscriptionCheckDate(now);
            
            return now.isBefore(expiryDt);
          } else {
             // No subscription row found, so it is inactive
             await _settingsRepository.setSubscriptionExpiryDate(DateTime(2000));
             await _settingsRepository.setLastSubscriptionCheckDate(now);
             return false;
          }
        } catch (e) {
          developer.log('Network failure checking subscription', name: 'SubscriptionService', error: e);
          // Fall through to offline check
        }
      }

      // Offline check / Cached check
      final cachedExpiryRes = await _settingsRepository.getSubscriptionExpiryDate();
      final cachedExpiry = cachedExpiryRes.isRight() ? cachedExpiryRes.getRight().toNullable() : null;

      if (cachedExpiry == null) {
        return false; // No cached data, assume inactive
      }

      // 7-day grace period for offline
      if (lastCheck != null && now.difference(lastCheck).inDays >= 7) {
        return false; 
      }

      return now.isBefore(cachedExpiry);
    } catch (e) {
       developer.log('Error evaluating subscription status', name: 'SubscriptionService', error: e);
       return false;
    }
  }
}
