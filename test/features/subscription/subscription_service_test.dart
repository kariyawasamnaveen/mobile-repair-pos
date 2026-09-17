import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fpdart/fpdart.dart';
import 'package:pos_system/features/settings/data/settings_repository.dart';
import 'package:pos_system/features/subscription/domain/subscription_service.dart';

class MockSettingsRepository extends Mock implements SettingsRepository {}

void main() {
  late MockSettingsRepository mockSettingsRepo;
  late DateTime mockNow;

  setUp(() {
    mockSettingsRepo = MockSettingsRepository();
    // Default mocks
    when(() => mockSettingsRepo.getBusinessAccountId())
        .thenAnswer((_) async => const Right('biz_123'));
    
    when(() => mockSettingsRepo.setSubscriptionExpiryDate(any()))
        .thenAnswer((_) async => const Right(unit));
        
    when(() => mockSettingsRepo.setLastSubscriptionCheckDate(any()))
        .thenAnswer((_) async => const Right(unit));
  });

  SubscriptionService createService({Future<DateTime?> Function(String bizId)? fetchRemoteOverride}) {
    return SubscriptionService(
      mockSettingsRepo,
      null, // passing null for SupabaseClient since we mock the network call
      fetchRemoteExpiryOverride: fetchRemoteOverride,
    );
  }

  test('isSubscriptionActive returns false if no business account ID', () async {
    when(() => mockSettingsRepo.getBusinessAccountId())
        .thenAnswer((_) async => const Right(null));
        
    final service = createService();
    final isActive = await service.isSubscriptionActive();
    expect(isActive, false);
  });

  test('isSubscriptionActive performs network check if last check > 24h and active', () async {
    mockNow = DateTime.now();
    when(() => mockSettingsRepo.getLastSubscriptionCheckDate())
        .thenAnswer((_) async => Right(mockNow.subtract(const Duration(hours: 25))));
        
    final futureExpiry = mockNow.add(const Duration(days: 30));
    
    final service = createService(
      fetchRemoteOverride: (bizId) async {
        expect(bizId, 'biz_123');
        return futureExpiry;
      }
    );
    
    final isActive = await service.isSubscriptionActive();
    expect(isActive, true);
    verify(() => mockSettingsRepo.setSubscriptionExpiryDate(futureExpiry)).called(1);
    verify(() => mockSettingsRepo.setLastSubscriptionCheckDate(any())).called(1);
  });

  test('isSubscriptionActive performs network check if last check > 24h and expired', () async {
    mockNow = DateTime.now();
    when(() => mockSettingsRepo.getLastSubscriptionCheckDate())
        .thenAnswer((_) async => Right(mockNow.subtract(const Duration(hours: 25))));
        
    final pastExpiry = mockNow.subtract(const Duration(days: 5));
    
    final service = createService(
      fetchRemoteOverride: (bizId) async {
        return pastExpiry;
      }
    );
    
    final isActive = await service.isSubscriptionActive();
    expect(isActive, false);
    verify(() => mockSettingsRepo.setSubscriptionExpiryDate(pastExpiry)).called(1);
  });

  test('isSubscriptionActive skips network and uses cache if last check < 24h (active cache)', () async {
    mockNow = DateTime.now();
    when(() => mockSettingsRepo.getLastSubscriptionCheckDate())
        .thenAnswer((_) async => Right(mockNow.subtract(const Duration(hours: 12))));
    
    // Cached is active
    final cachedExpiry = mockNow.add(const Duration(days: 10));
    when(() => mockSettingsRepo.getSubscriptionExpiryDate())
        .thenAnswer((_) async => Right(cachedExpiry));
        
    var networkCalled = false;
    final service = createService(
      fetchRemoteOverride: (bizId) async {
        networkCalled = true;
        return null;
      }
    );
    
    final isActive = await service.isSubscriptionActive();
    expect(isActive, true);
    expect(networkCalled, false);
  });

  test('isSubscriptionActive uses offline cache grace period if network fails', () async {
    mockNow = DateTime.now();
    // Checked 3 days ago (needs network check, but within 7 days grace)
    when(() => mockSettingsRepo.getLastSubscriptionCheckDate())
        .thenAnswer((_) async => Right(mockNow.subtract(const Duration(days: 3))));
    
    final cachedExpiry = mockNow.add(const Duration(days: 10));
    when(() => mockSettingsRepo.getSubscriptionExpiryDate())
        .thenAnswer((_) async => Right(cachedExpiry));
        
    final service = createService(
      fetchRemoteOverride: (bizId) async {
        throw Exception('Network failure');
      }
    );
    
    final isActive = await service.isSubscriptionActive();
    expect(isActive, true); // Active because of grace period and cached expiry
  });

  test('isSubscriptionActive rejects if offline grace period (> 7 days) expires', () async {
    mockNow = DateTime.now();
    // Checked 8 days ago (beyond grace period)
    when(() => mockSettingsRepo.getLastSubscriptionCheckDate())
        .thenAnswer((_) async => Right(mockNow.subtract(const Duration(days: 8))));
    
    final cachedExpiry = mockNow.add(const Duration(days: 10)); // technically still active
    when(() => mockSettingsRepo.getSubscriptionExpiryDate())
        .thenAnswer((_) async => Right(cachedExpiry));
        
    final service = createService(
      fetchRemoteOverride: (bizId) async {
        throw Exception('Network failure');
      }
    );
    
    final isActive = await service.isSubscriptionActive();
    expect(isActive, false); // Blocked due to grace period expiration
  });

  test('isSubscriptionActive rejects if subscription not found in DB', () async {
    mockNow = DateTime.now();
    when(() => mockSettingsRepo.getLastSubscriptionCheckDate())
        .thenAnswer((_) async => Right(mockNow.subtract(const Duration(hours: 25))));
        
    final service = createService(
      fetchRemoteOverride: (bizId) async {
        return null; // DB returns no row
      }
    );
    
    final isActive = await service.isSubscriptionActive();
    expect(isActive, false);
    // Should cache a long-past date to mark as inactive
    verify(() => mockSettingsRepo.setSubscriptionExpiryDate(DateTime(2000))).called(1);
  });
}
