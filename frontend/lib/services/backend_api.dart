import 'dart:async';
import 'dart:convert';

import 'package:ff/models/ActivityFeed.dart';
import 'package:ff/models/AdminConsole.dart';
import 'package:ff/models/Achievements.dart';
import 'package:ff/models/AuthSecurity.dart';
import 'package:ff/models/DailyObjectives.dart';
import 'package:ff/models/GameAreas.dart';
import 'package:ff/models/MessageModel.dart';
import 'package:ff/models/OnboardingQuestline.dart';
import 'package:ff/models/PlayerState.dart';
import 'package:ff/models/PushNotifications.dart';
import 'package:ff/models/RealtimeUpdates.dart';
import 'package:ff/models/ResourceLogistics.dart';
import 'package:ff/models/TrainingGrounds.dart';
import 'package:ff/models/User.dart';
import 'package:http/http.dart' as http;

class BackendApiException implements Exception {
  final String message;
  final int? statusCode;

  BackendApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class AuthSession {
  final String token;
  final String refreshToken;
  final User user;
  final DateTime? expiresAt;
  final DateTime? refreshExpiresAt;

  AuthSession({
    required this.token,
    required this.refreshToken,
    required this.user,
    this.expiresAt,
    this.refreshExpiresAt,
  });
}

class BackendApiClient {
  BackendApiClient({
    http.Client? client,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        _baseUrl = Uri.parse(
          baseUrl ??
              const String.fromEnvironment(
                'FF_API_BASE_URL',
                defaultValue: 'http://127.0.0.1:5124',
              ),
        );

  final http.Client _client;
  final Uri _baseUrl;
  String? bearerToken;
  String? refreshToken;
  Future<bool> Function()? onUnauthorized;

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final data = await _post('/auth/login', {
      'email': email,
      'password': password,
    });

    return _authSessionFromJson(data);
  }

  Future<AuthSession> refresh({
    required String refreshToken,
  }) async {
    final data = await _post(
      '/auth/refresh',
      {'refreshToken': refreshToken},
      allowAuthRefresh: false,
    );

    return _authSessionFromJson(data);
  }

  Future<SessionRevokeResult> logout({
    String? refreshToken,
    bool allSessions = false,
  }) async {
    final data = await _post(
      '/auth/logout',
      {
        'refreshToken': refreshToken,
        'allSessions': allSessions,
      },
      allowAuthRefresh: false,
    );
    return _sessionRevokeResultFromJson(data);
  }

  Future<AccountSecurityProfile> fetchAccountSecurity() async {
    final data = await _get('/auth/me');
    if (data is! Map<String, dynamic>) {
      throw BackendApiException('Invalid account security response.');
    }

    return _accountSecurityProfileFromJson(data);
  }

  Future<AuthActionResult> requestEmailVerification() async {
    final data = await _post('/auth/email-verification/request', {});
    return _authActionResultFromJson(data);
  }

  Future<AuthActionResult> confirmEmailVerification({
    required String token,
  }) async {
    final data = await _post(
      '/auth/email-verification/confirm',
      {'token': token},
      allowAuthRefresh: false,
    );
    return _authActionResultFromJson(data);
  }

  Future<AuthActionResult> requestPasswordReset({
    required String email,
  }) async {
    final data = await _post(
      '/auth/password-reset/request',
      {'email': email},
      allowAuthRefresh: false,
    );
    return _authActionResultFromJson(data);
  }

  Future<AuthActionResult> confirmPasswordReset({
    required String token,
    required String password,
  }) async {
    final data = await _post(
      '/auth/password-reset/confirm',
      {'token': token, 'password': password},
      allowAuthRefresh: false,
    );
    return _authActionResultFromJson(data);
  }

  Future<SessionRevokeResult> revokeAllSessions() async {
    final data = await _post('/auth/sessions/revoke-all', {});
    return _sessionRevokeResultFromJson(data);
  }

  Future<AuthSession> register({
    required String email,
    required String password,
    required String username,
  }) async {
    final data = await _post('/auth/register', {
      'email': email,
      'password': password,
      'username': username,
    });

    return _authSessionFromJson(data);
  }

  Future<User> fetchUserProfile(String uid) async {
    final data = await _get('/players/$uid');
    if (data is! Map<String, dynamic>) {
      throw BackendApiException('Invalid player response from backend.');
    }

    return _userFromJson(data);
  }

  Future<PlayerState> fetchPlayerState(String playerId) async {
    final data = await _get('/players/$playerId/state');
    if (data is! Map<String, dynamic>) {
      throw BackendApiException('Invalid player state response from backend.');
    }

    return _playerStateFromJson(data);
  }

  Future<ActivityFeedSummary> fetchActivityFeed(String playerId,
      {int limit = 50}) async {
    final data = await _get(
      '/players/$playerId/activity',
      queryParameters: {'limit': limit.toString()},
    );
    if (data is! Map<String, dynamic>) {
      throw BackendApiException('Invalid activity response from backend.');
    }

    return _activityFeedFromJson(data);
  }

  Future<RealtimeUpdatesEnvelope> fetchRealtimeUpdates(
    String playerId, {
    DateTime? since,
    String? chatToId,
    int limit = 50,
  }) async {
    final data = await _get(
      '/players/$playerId/realtime/updates',
      queryParameters: {
        if (since != null) 'since': since.toUtc().toIso8601String(),
        if (chatToId != null && chatToId.trim().isNotEmpty)
          'chatToId': chatToId.trim(),
        'limit': limit.toString(),
      },
    );
    if (data is! Map<String, dynamic>) {
      throw BackendApiException('Invalid realtime updates response.');
    }

    return _realtimeUpdatesFromJson(data);
  }

  Stream<RealtimeUpdatesEnvelope> subscribeRealtimeUpdates(
    String playerId, {
    DateTime? since,
    String? chatToId,
    int limit = 50,
    Duration retryDelay = const Duration(seconds: 12),
  }) async* {
    var cursor = since;
    while (true) {
      try {
        final update = await fetchRealtimeUpdates(
          playerId,
          since: cursor,
          chatToId: chatToId,
          limit: limit,
        );
        cursor = update.nextCursor;
        yield update;

        final seconds = update.pollAfterSeconds.clamp(3, 60).toInt();
        await Future<void>.delayed(Duration(seconds: seconds));
      } on Exception {
        await Future<void>.delayed(retryDelay);
      }
    }
  }

  Future<ActivityReadResult> markActivityRead({
    required String playerId,
    required String eventId,
  }) async {
    final data = await _post('/players/$playerId/activity/$eventId/read', {});
    return _activityReadResultFromJson(data);
  }

  Future<ActivityReadAllResult> markAllActivityRead({
    required String playerId,
  }) async {
    final data = await _post('/players/$playerId/activity/read-all', {});
    return _activityReadAllResultFromJson(data);
  }

  Future<PushNotificationSettings> fetchPushNotificationSettings(
      String playerId) async {
    final data = await _get('/players/$playerId/push-notifications');
    if (data is! Map<String, dynamic>) {
      throw BackendApiException('Invalid push notification settings response.');
    }

    return _pushNotificationSettingsFromJson(data);
  }

  Future<PushSubscriptionMutationResult> savePushSubscription({
    required String playerId,
    required String endpoint,
    required String p256dh,
    required String auth,
    String? userAgent,
  }) async {
    final data =
        await _post('/players/$playerId/push-notifications/subscriptions', {
      'endpoint': endpoint,
      'p256dh': p256dh,
      'auth': auth,
      if (userAgent != null && userAgent.isNotEmpty) 'userAgent': userAgent,
    });
    return _pushSubscriptionMutationFromJson(data);
  }

  Future<PushSubscriptionMutationResult> disablePushSubscription({
    required String playerId,
    required String endpoint,
  }) async {
    final data = await _post(
      '/players/$playerId/push-notifications/subscriptions/disable',
      {'endpoint': endpoint},
    );
    return _pushSubscriptionMutationFromJson(data);
  }

  Future<PushDeliveryList> fetchPushDeliveries(String playerId,
      {int limit = 25}) async {
    final data = await _get(
      '/players/$playerId/push-notifications/deliveries',
      queryParameters: {'limit': limit.toString()},
    );
    if (data is! Map<String, dynamic>) {
      throw BackendApiException('Invalid push delivery response.');
    }

    return _pushDeliveryListFromJson(data);
  }

  Future<DailyObjectivesSummary> fetchDailyObjectives(String playerId) async {
    final data = await _get('/players/$playerId/daily-objectives');
    if (data is! Map<String, dynamic>) {
      throw BackendApiException(
          'Invalid daily objectives response from backend.');
    }

    return _dailyObjectivesFromJson(data);
  }

  Future<DailyObjectiveClaimResult> claimDailyObjective({
    required String playerId,
    required String objectiveId,
    required String idempotencyKey,
  }) async {
    final data = await _post(
      '/players/$playerId/daily-objectives/$objectiveId/claim',
      {},
      extraHeaders: {'Idempotency-Key': idempotencyKey},
    );
    return _dailyObjectiveClaimResultFromJson(data);
  }

  Future<AchievementsSummary> fetchAchievements(String playerId) async {
    final data = await _get('/players/$playerId/achievements');
    if (data is! Map<String, dynamic>) {
      throw BackendApiException('Invalid achievements response from backend.');
    }

    return _achievementsSummaryFromJson(data);
  }

  Future<AchievementClaimResult> claimAchievement({
    required String playerId,
    required String achievementId,
    required String idempotencyKey,
  }) async {
    final data = await _post(
      '/players/$playerId/achievements/$achievementId/claim',
      {},
      extraHeaders: {'Idempotency-Key': idempotencyKey},
    );
    return _achievementClaimResultFromJson(data);
  }

  Future<OnboardingQuestline> fetchOnboardingQuestline(String playerId) async {
    final data = await _get('/players/$playerId/onboarding-questline');
    if (data is! Map<String, dynamic>) {
      throw BackendApiException(
          'Invalid onboarding questline response from backend.');
    }

    return OnboardingQuestline.fromJson(data);
  }

  Future<OnboardingQuestClaimResult> claimOnboardingQuest({
    required String playerId,
    required String questId,
    required String idempotencyKey,
  }) async {
    final data = await _post(
      '/players/$playerId/onboarding-questline/$questId/claim',
      {},
      extraHeaders: {'Idempotency-Key': idempotencyKey},
    );
    return OnboardingQuestClaimResult.fromJson(data);
  }

  Future<OnboardingQuestSkipResult> skipOnboardingQuest({
    required String playerId,
    required String questId,
    required String idempotencyKey,
  }) async {
    final data = await _post(
      '/players/$playerId/onboarding-questline/$questId/skip',
      {},
      extraHeaders: {'Idempotency-Key': idempotencyKey},
    );
    return OnboardingQuestSkipResult.fromJson(data);
  }

  Future<PublicPlayerProfile> fetchPublicProfile(String playerId) async {
    final data = await _get('/players/$playerId/public');
    if (data is! Map<String, dynamic>) {
      throw BackendApiException(
          'Invalid public profile response from backend.');
    }

    return _publicProfileFromJson(data);
  }

  Future<RankingsLeaderboard> fetchRankingsLeaderboard({
    String sortBy = 'level',
    int limit = 50,
  }) async {
    final data = await _get(
      '/rankings/leaderboard',
      queryParameters: {
        'sortBy': sortBy,
        'limit': limit.toString(),
      },
    );
    if (data is! Map<String, dynamic>) {
      throw BackendApiException('Invalid rankings response from backend.');
    }

    return _rankingsLeaderboardFromJson(data);
  }

  Future<RankingEntry> fetchPlayerRanking(
    String playerId, {
    String sortBy = 'level',
  }) async {
    final data = await _get(
      '/rankings/player/$playerId',
      queryParameters: {'sortBy': sortBy},
    );
    if (data is! Map<String, dynamic>) {
      throw BackendApiException(
          'Invalid player ranking response from backend.');
    }

    return _rankingEntryFromJson(data);
  }

  Future<PlayerActionResult> work(String playerId) async {
    final data = await _post('/players/$playerId/work', {});
    return _playerActionFromJson(data);
  }

  Future<PlayerActionResult> train(String playerId) async {
    final data = await _post('/players/$playerId/train', {});
    return _playerActionFromJson(data);
  }

  Future<TrainingGroundsSummary> fetchTrainingGrounds(String playerId) async {
    final data = await _get('/players/$playerId/training-grounds');
    if (data is! Map<String, dynamic>) {
      throw BackendApiException(
          'Invalid training grounds response from backend.');
    }

    return TrainingGroundsSummary.fromJson(data);
  }

  Future<PlayerActionResult> recoverAtHospital({
    required String playerId,
    required String idempotencyKey,
  }) async {
    final data = await _post(
      '/players/$playerId/hospital/recover',
      {},
      extraHeaders: {'Idempotency-Key': idempotencyKey},
    );
    return _playerActionFromJson(data);
  }

  Future<InventorySummary> fetchInventory(String playerId) async {
    final data = await _get('/players/$playerId/inventory');
    if (data is! Map<String, dynamic>) {
      throw BackendApiException('Invalid inventory response from backend.');
    }

    return _inventoryFromJson(data);
  }

  Future<InventoryItemUseResult> useInventoryItem({
    required String playerId,
    required String itemId,
    required String idempotencyKey,
  }) async {
    final data = await _post(
      '/players/$playerId/inventory/items/$itemId/use',
      {},
      extraHeaders: {'Idempotency-Key': idempotencyKey},
    );
    return _inventoryItemUseResultFromJson(data);
  }

  Future<LedgerSummary> fetchLedger(String playerId, {int limit = 50}) async {
    final data = await _get(
      '/players/$playerId/ledger',
      queryParameters: {'limit': limit.toString()},
    );
    if (data is! Map<String, dynamic>) {
      throw BackendApiException('Invalid ledger response from backend.');
    }

    return _ledgerSummaryFromJson(data);
  }

  Future<AdminPlayerSearchResponse> searchAdminPlayers({
    required String adminToken,
    String query = '',
    int limit = 25,
  }) async {
    final data = await _get(
      '/admin/players/search',
      queryParameters: {
        if (query.trim().isNotEmpty) 'query': query.trim(),
        'limit': limit.toString(),
      },
      extraHeaders: _adminHeaders(adminToken),
    );
    if (data is! Map<String, dynamic>) {
      throw BackendApiException('Invalid admin player search response.');
    }

    return _adminPlayerSearchFromJson(data);
  }

  Future<AdminPlayerSummary> fetchAdminPlayerSummary({
    required String adminToken,
    required String playerId,
  }) async {
    final data = await _get(
      '/admin/players/$playerId/summary',
      extraHeaders: _adminHeaders(adminToken),
    );
    if (data is! Map<String, dynamic>) {
      throw BackendApiException('Invalid admin player summary response.');
    }

    return _adminPlayerSummaryFromJson(data);
  }

  Future<AdminModerationRecord> createAdminModerationRecord({
    required String adminToken,
    required String playerId,
    required String type,
    required String reason,
    DateTime? expiresAt,
  }) async {
    final data = await _post(
      '/admin/players/$playerId/moderation-records',
      {
        'type': type,
        'reason': reason,
        if (expiresAt != null) 'expiresAt': expiresAt.toUtc().toIso8601String(),
      },
      extraHeaders: _adminHeaders(adminToken),
    );
    return _adminModerationRecordFromJson(data);
  }

  Future<AdminAuditRecordList> fetchAdminAuditRecords({
    required String adminToken,
    String? playerId,
    int limit = 50,
  }) async {
    final data = await _get(
      '/admin/audit',
      queryParameters: {
        if (playerId != null && playerId.trim().isNotEmpty)
          'playerId': playerId.trim(),
        'limit': limit.toString(),
      },
      extraHeaders: _adminHeaders(adminToken),
    );
    if (data is! Map<String, dynamic>) {
      throw BackendApiException('Invalid admin audit response.');
    }

    return _adminAuditRecordListFromJson(data);
  }

  Future<AdminEconomyLedgerAuditResponse> fetchAdminEconomyLedger({
    required String adminToken,
    String? playerId,
    String? entryType,
    int limit = 25,
  }) async {
    final data = await _get(
      '/admin/economy/ledger',
      queryParameters: {
        if (playerId != null && playerId.trim().isNotEmpty)
          'playerId': playerId.trim(),
        if (entryType != null && entryType.trim().isNotEmpty)
          'entryType': entryType.trim(),
        'limit': limit.toString(),
      },
      extraHeaders: _adminHeaders(adminToken),
    );
    if (data is! Map<String, dynamic>) {
      throw BackendApiException('Invalid admin economy ledger response.');
    }

    return _adminEconomyLedgerFromJson(data);
  }

  Future<AdminEconomyBalanceDashboard> fetchAdminEconomyDashboard({
    required String adminToken,
    int days = 30,
    int limit = 10,
  }) async {
    final data = await _get(
      '/admin/economy/dashboard',
      queryParameters: {
        'days': days.toString(),
        'limit': limit.toString(),
      },
      extraHeaders: _adminHeaders(adminToken),
    );
    if (data is! Map<String, dynamic>) {
      throw BackendApiException('Invalid admin economy dashboard response.');
    }

    return _adminEconomyDashboardFromJson(data);
  }

  Future<AdminContentModerationQueue> fetchAdminContentQueue({
    required String adminToken,
    String status = 'open',
    int limit = 25,
  }) async {
    final data = await _get(
      '/admin/moderation/content-queue',
      queryParameters: {
        'status': status,
        'limit': limit.toString(),
      },
      extraHeaders: _adminHeaders(adminToken),
    );
    if (data is! Map<String, dynamic>) {
      throw BackendApiException('Invalid content moderation queue response.');
    }

    return _adminContentQueueFromJson(data);
  }

  Future<AdminContentModerationItem> reviewAdminContentQueueItem({
    required String adminToken,
    required String itemId,
    required String status,
    required String resolution,
    String action = 'none',
  }) async {
    final data = await _post(
      '/admin/moderation/content-queue/$itemId/review',
      {
        'status': status,
        'resolution': resolution,
        'action': action,
      },
      extraHeaders: _adminHeaders(adminToken),
    );
    return _adminContentModerationItemFromJson(data);
  }

  Future<AdminAntiAbuseReviewQueue> fetchAdminAntiAbuseQueue({
    required String adminToken,
    String status = 'open',
    String? playerId,
    int limit = 25,
  }) async {
    final data = await _get(
      '/admin/anti-abuse/review-queue',
      queryParameters: {
        'status': status,
        if (playerId != null && playerId.trim().isNotEmpty)
          'playerId': playerId.trim(),
        'limit': limit.toString(),
      },
      extraHeaders: _adminHeaders(adminToken),
    );
    if (data is! Map<String, dynamic>) {
      throw BackendApiException('Invalid anti-abuse review queue response.');
    }

    return _adminAntiAbuseQueueFromJson(data);
  }

  Future<AdminAntiAbuseReviewItem> reviewAdminAntiAbuseEvent({
    required String adminToken,
    required String eventId,
    required String status,
    required String resolution,
  }) async {
    final data = await _post(
      '/admin/anti-abuse/review-queue/$eventId/review',
      {
        'status': status,
        'resolution': resolution,
      },
      extraHeaders: _adminHeaders(adminToken),
    );
    if (data is! Map<String, dynamic>) {
      throw BackendApiException('Invalid anti-abuse review response.');
    }

    return _adminAntiAbuseItemFromJson(data);
  }

  Future<EquipmentSummary> fetchEquipment(String playerId) async {
    final data = await _get('/players/$playerId/equipment');
    if (data is! Map<String, dynamic>) {
      throw BackendApiException('Invalid equipment response from backend.');
    }

    return _equipmentSummaryFromJson(data);
  }

  Future<EquipWeaponResult> equipWeapon({
    required String playerId,
    required String itemId,
    required String idempotencyKey,
  }) async {
    final data = await _post(
      '/players/$playerId/equipment/weapon/equip',
      {'itemId': itemId},
      extraHeaders: {'Idempotency-Key': idempotencyKey},
    );
    return _equipWeaponResultFromJson(data);
  }

  Future<RepairWeaponResult> repairWeapon({
    required String playerId,
    required String idempotencyKey,
  }) async {
    final data = await _post(
      '/players/$playerId/equipment/weapon/repair',
      {},
      extraHeaders: {'Idempotency-Key': idempotencyKey},
    );
    return _repairWeaponResultFromJson(data);
  }

  Future<FactoryPortfolio> fetchFactories(String playerId) async {
    final data = await _get('/players/$playerId/factories');
    if (data is! Map<String, dynamic>) {
      throw BackendApiException('Invalid factories response from backend.');
    }

    return _factoryPortfolioFromJson(data);
  }

  Future<ProductionResult> produce(String playerId, String factoryId) async {
    final data =
        await _post('/players/$playerId/factories/$factoryId/produce', {});
    return _productionResultFromJson(data);
  }

  Future<ProductionJobsResponse> fetchProductionJobs(String playerId) async {
    final data = await _get('/players/$playerId/production-jobs');
    if (data is! Map<String, dynamic>) {
      throw BackendApiException(
          'Invalid production jobs response from backend.');
    }

    return _productionJobsResponseFromJson(data);
  }

  Future<ProductionClaimResult> claimProductionJob({
    required String playerId,
    required String jobId,
  }) async {
    final data =
        await _post('/players/$playerId/production-jobs/$jobId/claim', {});
    return _productionClaimResultFromJson(data);
  }

  Future<FactoryUpgradeQuote> fetchFactoryUpgradeQuote({
    required String playerId,
    required String factoryId,
  }) async {
    final data =
        await _get('/players/$playerId/factories/$factoryId/upgrade-quote');
    if (data is! Map<String, dynamic>) {
      throw BackendApiException(
          'Invalid factory upgrade quote response from backend.');
    }

    return _factoryUpgradeQuoteFromJson(data);
  }

  Future<FactoryUpgradeGatewayResult> upgradeFactory({
    required String playerId,
    required String factoryId,
  }) async {
    final data =
        await _post('/players/$playerId/factories/$factoryId/upgrade', {});
    return _factoryUpgradeGatewayResultFromJson(data);
  }

  Future<ResearchTechnologyCatalog> fetchResearchTechnologies({
    String? scopeType,
  }) async {
    final data = await _get(
      '/research/technologies',
      queryParameters: {
        if (scopeType != null && scopeType.isNotEmpty) 'scopeType': scopeType,
      },
    );
    if (data is! Map<String, dynamic>) {
      throw BackendApiException(
          'Invalid research technology response from backend.');
    }

    return _researchTechnologyCatalogFromJson(data);
  }

  Future<ResearchDashboard> fetchResearchDashboard(String playerId) async {
    final data = await _get('/players/$playerId/research');
    if (data is! Map<String, dynamic>) {
      throw BackendApiException('Invalid research response from backend.');
    }

    return _researchDashboardFromJson(data);
  }

  Future<ResearchScopeState> fetchCountryResearch(String countryId) async {
    final data = await _get('/research/countries/$countryId');
    if (data is! Map<String, dynamic>) {
      throw BackendApiException(
          'Invalid country research response from backend.');
    }

    return _researchScopeStateFromJson(data);
  }

  Future<ResearchScopeState> fetchCompanyResearch(String companyId) async {
    final data = await _get('/research/companies/$companyId');
    if (data is! Map<String, dynamic>) {
      throw BackendApiException(
          'Invalid company research response from backend.');
    }

    return _researchScopeStateFromJson(data);
  }

  Future<ResearchBonusList> fetchCountryResearchBonuses(
      String countryId) async {
    final data = await _get('/research/countries/$countryId/bonuses');
    if (data is! Map<String, dynamic>) {
      throw BackendApiException(
          'Invalid country research bonus response from backend.');
    }

    return _researchBonusListFromJson(data);
  }

  Future<ResearchBonusList> fetchCompanyResearchBonuses(
      String companyId) async {
    final data = await _get('/research/companies/$companyId/bonuses');
    if (data is! Map<String, dynamic>) {
      throw BackendApiException(
          'Invalid company research bonus response from backend.');
    }

    return _researchBonusListFromJson(data);
  }

  Future<ResearchMutationResult> startCountryResearch({
    required String countryId,
    required String technologyId,
    required String idempotencyKey,
  }) async {
    final data = await _post(
      '/research/countries/$countryId/technologies/$technologyId/start',
      {},
      extraHeaders: {'Idempotency-Key': idempotencyKey},
    );
    return _researchMutationResultFromJson(data);
  }

  Future<ResearchMutationResult> contributeCountryResearch({
    required String countryId,
    required String projectId,
    required int points,
    required String idempotencyKey,
  }) async {
    final data = await _post(
      '/research/countries/$countryId/projects/$projectId/contribute',
      {'points': points},
      extraHeaders: {'Idempotency-Key': idempotencyKey},
    );
    return _researchMutationResultFromJson(data);
  }

  Future<ResearchMutationResult> completeCountryResearch({
    required String countryId,
    required String projectId,
    required String idempotencyKey,
  }) async {
    final data = await _post(
      '/research/countries/$countryId/projects/$projectId/complete',
      {},
      extraHeaders: {'Idempotency-Key': idempotencyKey},
    );
    return _researchMutationResultFromJson(data);
  }

  Future<ResearchMutationResult> startCompanyResearch({
    required String companyId,
    required String technologyId,
    required String idempotencyKey,
  }) async {
    final data = await _post(
      '/research/companies/$companyId/technologies/$technologyId/start',
      {},
      extraHeaders: {'Idempotency-Key': idempotencyKey},
    );
    return _researchMutationResultFromJson(data);
  }

  Future<ResearchMutationResult> contributeCompanyResearch({
    required String companyId,
    required String projectId,
    required int points,
    required String idempotencyKey,
  }) async {
    final data = await _post(
      '/research/companies/$companyId/projects/$projectId/contribute',
      {'points': points},
      extraHeaders: {'Idempotency-Key': idempotencyKey},
    );
    return _researchMutationResultFromJson(data);
  }

  Future<ResearchMutationResult> completeCompanyResearch({
    required String companyId,
    required String projectId,
    required String idempotencyKey,
  }) async {
    final data = await _post(
      '/research/companies/$companyId/projects/$projectId/complete',
      {},
      extraHeaders: {'Idempotency-Key': idempotencyKey},
    );
    return _researchMutationResultFromJson(data);
  }

  Future<CompanyPortfolio> fetchCompanies(String playerId) async {
    final data = await _get('/players/$playerId/companies');
    if (data is! Map<String, dynamic>) {
      throw BackendApiException('Invalid companies response from backend.');
    }

    return _companyPortfolioFromJson(data);
  }

  Future<CompanyDetail> fetchCompany(String companyId) async {
    final data = await _get('/companies/$companyId');
    if (data is! Map<String, dynamic>) {
      throw BackendApiException('Invalid company response from backend.');
    }

    return _companyDetailFromJson(data);
  }

  Future<CompanyAssets> fetchCompanyAssets(String companyId) async {
    final data = await _get('/companies/$companyId/assets');
    if (data is! Map<String, dynamic>) {
      throw BackendApiException(
          'Invalid company assets response from backend.');
    }

    return _companyAssetsFromJson(data);
  }

  Future<ResourceSiteList> fetchResourceSites({
    String? countryId,
    String? regionId,
  }) async {
    final data = await _get(
      '/resource-sites',
      queryParameters: {
        if (countryId != null && countryId.isNotEmpty) 'countryId': countryId,
        if (regionId != null && regionId.isNotEmpty) 'regionId': regionId,
      },
    );
    if (data is! Map<String, dynamic>) {
      throw BackendApiException('Invalid resource sites response.');
    }

    return _resourceSiteListFromJson(data);
  }

  Future<ResourceLogisticsDashboard> fetchCompanyResourceLogistics(
      String companyId) async {
    final data = await _get('/companies/$companyId/resource-logistics');
    if (data is! Map<String, dynamic>) {
      throw BackendApiException('Invalid resource logistics response.');
    }

    return _resourceLogisticsDashboardFromJson(data);
  }

  Future<ExtractionMutationResult> startCompanyResourceExtraction({
    required String companyId,
    required String siteId,
    required int requestedRuns,
    required String idempotencyKey,
  }) async {
    final data = await _post(
      '/companies/$companyId/resource-extractions',
      {
        'siteId': siteId,
        'requestedRuns': requestedRuns,
        'idempotencyKey': idempotencyKey,
      },
      extraHeaders: {'Idempotency-Key': idempotencyKey},
    );
    return _extractionMutationFromJson(data);
  }

  Future<ExtractionClaimResult> claimCompanyResourceExtraction({
    required String companyId,
    required String jobId,
  }) async {
    final data = await _post(
        '/companies/$companyId/resource-extractions/$jobId/claim', {});
    return _extractionClaimFromJson(data);
  }

  Future<ShipmentMutationResult> dispatchCompanyShipment({
    required String companyId,
    required InventoryItem item,
    required ResourceSite origin,
    required ResourceSite destination,
    required int quantity,
    required int durationSeconds,
    required String idempotencyKey,
  }) async {
    final data = await _post(
      '/companies/$companyId/shipments',
      {
        'itemId': item.itemId,
        'itemName': item.name,
        'itemCategory': item.category,
        'quantity': quantity,
        'originRegionId': origin.regionId,
        'originRegionName': origin.siteName,
        'destinationRegionId': destination.regionId,
        'destinationRegionName': destination.siteName,
        'durationSeconds': durationSeconds,
        'idempotencyKey': idempotencyKey,
      },
      extraHeaders: {'Idempotency-Key': idempotencyKey},
    );
    return _shipmentMutationFromJson(data);
  }

  Future<ShipmentMutationResult> deliverCompanyShipment({
    required String companyId,
    required String shipmentId,
  }) async {
    final data =
        await _post('/companies/$companyId/shipments/$shipmentId/deliver', {});
    return _shipmentMutationFromJson(data);
  }

  Future<CompanyUpgradeState> fetchCompanyUpgrades(String companyId) async {
    final data = await _get('/companies/$companyId/upgrades');
    if (data is! Map<String, dynamic>) {
      throw BackendApiException(
          'Invalid company upgrades response from backend.');
    }

    return _companyUpgradeStateFromJson(data);
  }

  Future<CompanyMutationResult> createCompany({
    required String playerId,
    required String name,
    String? description,
  }) async {
    final data = await _post('/players/$playerId/companies', {
      'name': name,
      'description': description,
    });
    return _companyMutationResultFromJson(data);
  }

  Future<CompanyMutationResult> joinCompany(String companyId) async {
    final data = await _post('/companies/$companyId/join', {});
    return _companyMutationResultFromJson(data);
  }

  Future<CompanyMutationResult> updateCompanyMemberRole({
    required String companyId,
    required String playerId,
    required String role,
  }) async {
    final data = await _post(
      '/companies/$companyId/members/$playerId/role',
      {'role': role},
    );
    return _companyMutationResultFromJson(data);
  }

  Future<CompanyMutationResult> removeCompanyMember({
    required String companyId,
    required String playerId,
  }) async {
    final data =
        await _post('/companies/$companyId/members/$playerId/remove', {});
    return _companyMutationResultFromJson(data);
  }

  Future<ProductionResult> produceCompanyFactory({
    required String companyId,
    required String factoryId,
  }) async {
    final data =
        await _post('/companies/$companyId/factories/$factoryId/produce', {});
    return _productionResultFromJson(data);
  }

  Future<CompanyProductionClaimResult> claimCompanyProductionJob({
    required String companyId,
    required String jobId,
  }) async {
    final data =
        await _post('/companies/$companyId/production-jobs/$jobId/claim', {});
    return _companyProductionClaimResultFromJson(data);
  }

  Future<CompanyUpgradeMutationResult> upgradeCompanyHq({
    required String companyId,
  }) async {
    final data = await _post('/companies/$companyId/upgrades/hq', {});
    return _companyUpgradeMutationResultFromJson(data);
  }

  Future<CompanyUpgradeMutationResult> setCompanySpecialization({
    required String companyId,
    required String specialization,
  }) async {
    final data = await _post('/companies/$companyId/specialization', {
      'specialization': specialization,
    });
    return _companyUpgradeMutationResultFromJson(data);
  }

  Future<CompanyJobList> fetchWorkforceJobs() async {
    final data = await _get('/workforce/jobs');
    if (data is! Map<String, dynamic>) {
      throw BackendApiException(
          'Invalid workforce jobs response from backend.');
    }

    return _companyJobListFromJson(data);
  }

  Future<CompanyJobList> fetchCompanyJobs(String companyId) async {
    final data = await _get('/companies/$companyId/jobs');
    if (data is! Map<String, dynamic>) {
      throw BackendApiException('Invalid company jobs response from backend.');
    }

    return _companyJobListFromJson(data);
  }

  Future<CompanyJobMutationResult> postCompanyJob({
    required String companyId,
    required String title,
    required String description,
    required int wageGold,
    required int requiredEnergy,
    required int dailyLimit,
    required int productivityReward,
    bool isActive = true,
  }) async {
    final data = await _post('/companies/$companyId/jobs', {
      'title': title,
      'description': description,
      'wageGold': wageGold,
      'requiredEnergy': requiredEnergy,
      'dailyLimit': dailyLimit,
      'productivityReward': productivityReward,
      'isActive': isActive,
    });
    return _companyJobMutationResultFromJson(data);
  }

  Future<CompanyJobMutationResult> updateCompanyJob({
    required String companyId,
    required CompanyJobPosting job,
    required bool isActive,
  }) async {
    final data = await _post('/companies/$companyId/jobs/${job.jobId}', {
      'title': job.title,
      'description': job.description,
      'wageGold': job.wageGold,
      'requiredEnergy': job.requiredEnergy,
      'dailyLimit': job.dailyLimit,
      'productivityReward': job.productivityReward,
      'isActive': isActive,
    });
    return _companyJobMutationResultFromJson(data);
  }

  Future<CompanyJobMutationResult> closeCompanyJob({
    required String companyId,
    required String jobId,
  }) async {
    final data = await _post('/companies/$companyId/jobs/$jobId/close', {});
    return _companyJobMutationResultFromJson(data);
  }

  Future<CompanyWorkResult> workCompanyJob({
    required String playerId,
    required String companyId,
    required String jobId,
    required String idempotencyKey,
  }) async {
    final data = await _post(
      '/players/$playerId/companies/$companyId/jobs/$jobId/work',
      {},
      extraHeaders: {'Idempotency-Key': idempotencyKey},
    );
    return _companyWorkResultFromJson(data);
  }

  Future<MarketListings> fetchMarketListings() async {
    final data = await _get('/market/listings');
    if (data is! Map<String, dynamic>) {
      throw BackendApiException('Invalid market response from backend.');
    }

    return _marketListingsFromJson(data);
  }

  Future<PlayerMarketListings> fetchPlayerMarketListings(
      String playerId) async {
    final data = await _get('/players/$playerId/market/listings');
    if (data is! Map<String, dynamic>) {
      throw BackendApiException(
          'Invalid player market listings response from backend.');
    }

    return _playerMarketListingsFromJson(data);
  }

  Future<MarketPriceHistory> fetchMarketPriceHistory({
    String? itemId,
    int limit = 50,
  }) async {
    final data = await _get(
      '/market/price-history',
      queryParameters: {
        if (itemId != null && itemId.trim().isNotEmpty) 'itemId': itemId.trim(),
        'limit': limit.toString(),
      },
    );
    if (data is! Map<String, dynamic>) {
      throw BackendApiException(
          'Invalid market price history response from backend.');
    }

    return _marketPriceHistoryFromJson(data);
  }

  Future<MarketOrderBook> fetchMarketOrderBook({String? itemId}) async {
    final data = await _get(
      '/market/order-book',
      queryParameters: {
        if (itemId != null && itemId.trim().isNotEmpty) 'itemId': itemId.trim(),
      },
    );
    if (data is! Map<String, dynamic>) {
      throw BackendApiException(
          'Invalid market order book response from backend.');
    }

    return _marketOrderBookFromJson(data);
  }

  Future<TradeOfferList> fetchTradeOffers({
    String status = 'open',
    String? actorType,
    String? actorId,
  }) async {
    final data = await _get(
      '/trade/offers',
      queryParameters: {
        if (status.trim().isNotEmpty) 'status': status.trim(),
        if (actorType != null && actorType.trim().isNotEmpty)
          'actorType': actorType.trim(),
        if (actorId != null && actorId.trim().isNotEmpty)
          'actorId': actorId.trim(),
      },
    );
    if (data is! Map<String, dynamic>) {
      throw BackendApiException('Invalid trade offers response from backend.');
    }

    return _tradeOfferListFromJson(data);
  }

  Future<MarketPurchaseResult> buyMarketListing({
    required String playerId,
    required String listingId,
    required String idempotencyKey,
  }) async {
    final data = await _post(
      '/players/$playerId/market/listings/$listingId/buy',
      {},
      extraHeaders: {'Idempotency-Key': idempotencyKey},
    );
    return _marketPurchaseResultFromJson(data);
  }

  Future<MarketSellListingResult> sellMarketListing({
    required String playerId,
    required String itemId,
    required int quantity,
    required int pricePerUnit,
    required String idempotencyKey,
  }) async {
    final data = await _post(
      '/players/$playerId/market/listings',
      {
        'itemId': itemId,
        'quantity': quantity,
        'pricePerUnit': pricePerUnit,
      },
      extraHeaders: {'Idempotency-Key': idempotencyKey},
    );
    return _marketSellListingResultFromJson(data);
  }

  Future<MarketCancelListingResult> cancelMarketListing({
    required String playerId,
    required String listingId,
    required String idempotencyKey,
  }) async {
    final data = await _post(
      '/players/$playerId/market/listings/$listingId/cancel',
      {},
      extraHeaders: {'Idempotency-Key': idempotencyKey},
    );
    return _marketCancelListingResultFromJson(data);
  }

  Future<TradeOfferResult> createTradeOffer({
    required String playerId,
    required String sellerType,
    required String sellerId,
    required String buyerType,
    required String buyerId,
    required String itemId,
    required int quantity,
    required int pricePerUnit,
    required String idempotencyKey,
  }) async {
    final data = await _post('/players/$playerId/trade/offers', {
      'sellerType': sellerType,
      'sellerId': sellerId,
      'buyerType': buyerType,
      'buyerId': buyerId,
      'itemId': itemId,
      'quantity': quantity,
      'pricePerUnit': pricePerUnit,
      'idempotencyKey': idempotencyKey,
    });
    return _tradeOfferResultFromJson(data);
  }

  Future<TradeOfferResult> acceptTradeOffer({
    required String playerId,
    required String offerId,
    required String idempotencyKey,
  }) async {
    final data =
        await _post('/players/$playerId/trade/offers/$offerId/accept', {
      'idempotencyKey': idempotencyKey,
    });
    return _tradeOfferResultFromJson(data);
  }

  Future<TradeOfferResult> cancelTradeOffer({
    required String playerId,
    required String offerId,
    required String idempotencyKey,
  }) async {
    final data =
        await _post('/players/$playerId/trade/offers/$offerId/cancel', {
      'idempotencyKey': idempotencyKey,
    });
    return _tradeOfferResultFromJson(data);
  }

  Future<List<CombatMission>> fetchCombatMissions() async {
    final data = await _get('/combat/missions');
    if (data is! List<dynamic>) {
      throw BackendApiException('Invalid missions response from backend.');
    }

    return data.map((mission) {
      if (mission is! Map<String, dynamic>) {
        throw BackendApiException('Invalid missions response from backend.');
      }

      return _combatMissionFromJson(mission);
    }).toList();
  }

  Future<MissionProgressSummary> fetchMissionProgress(String playerId) async {
    final data = await _get('/players/$playerId/missions/progress');
    if (data is! Map<String, dynamic>) {
      throw BackendApiException(
          'Invalid mission progress response from backend.');
    }

    return _missionProgressSummaryFromJson(data);
  }

  Future<MissionFightResult> fightMission(
    String playerId,
    String missionId,
    String idempotencyKey,
  ) async {
    final data = await _post(
      '/players/$playerId/combat/missions/$missionId/fight',
      {},
      extraHeaders: {'Idempotency-Key': idempotencyKey},
    );
    return _missionFightResultFromJson(data);
  }

  Future<CountryCatalog> fetchCountries() async {
    final data = await _get('/world/countries');
    if (data is! Map<String, dynamic>) {
      throw BackendApiException('Invalid countries response from backend.');
    }

    return _countryCatalogFromJson(data);
  }

  Future<CountryTreasury> fetchCountryTreasury(String countryId) async {
    final data = await _get('/world/countries/$countryId/treasury');
    if (data is! Map<String, dynamic>) {
      throw BackendApiException('Invalid country treasury response.');
    }

    return _countryTreasuryFromJson(data);
  }

  Future<CountryInfrastructure> fetchCountryInfrastructure(
      String countryId) async {
    final data =
        await _get('/world/countries/$countryId/infrastructure-projects');
    if (data is! Map<String, dynamic>) {
      throw BackendApiException('Invalid country infrastructure response.');
    }

    return _countryInfrastructureFromJson(data);
  }

  Future<CountryInfrastructureContributionResult>
      contributeCountryInfrastructure({
    required String playerId,
    required String countryId,
    required String projectId,
    required int goldAmount,
    required int itemQuantity,
    required String idempotencyKey,
    String? itemId,
  }) async {
    final data = await _post(
      '/players/$playerId/world/countries/$countryId/infrastructure-projects/$projectId/contribute',
      {
        'goldAmount': goldAmount,
        'itemQuantity': itemQuantity,
        if (itemId != null && itemId.isNotEmpty) 'itemId': itemId,
      },
      extraHeaders: {'Idempotency-Key': idempotencyKey},
    );
    if (data is! Map<String, dynamic>) {
      throw BackendApiException(
          'Invalid country infrastructure contribution response.');
    }

    return _countryInfrastructureContributionResultFromJson(data);
  }

  Future<CountryTaxPolicyUpdateResult> updateCountryTaxPolicy({
    required String countryId,
    required int incomeTaxRate,
    required int marketTaxRate,
    required int productionTaxRate,
  }) async {
    final data = await _post('/world/countries/$countryId/tax-policy', {
      'incomeTaxRate': incomeTaxRate,
      'marketTaxRate': marketTaxRate,
      'productionTaxRate': productionTaxRate,
    });

    return _countryTaxPolicyUpdateResultFromJson(data);
  }

  Future<RegionList> fetchRegions({String? countryId}) async {
    final query = <String, String>{};
    if (countryId != null && countryId.isNotEmpty) {
      query['countryId'] = countryId;
    }

    final data = await _get('/world/regions', queryParameters: query);
    if (data is! Map<String, dynamic>) {
      throw BackendApiException('Invalid regions response from backend.');
    }

    return _regionListFromJson(data);
  }

  Future<TerritoryMap> fetchTerritoryMap({String? countryId}) async {
    final query = <String, String>{};
    if (countryId != null && countryId.isNotEmpty) {
      query['countryId'] = countryId;
    }

    final data = await _get('/world/territory/map', queryParameters: query);
    if (data is! Map<String, dynamic>) {
      throw BackendApiException('Invalid territory map response.');
    }

    return _territoryMapFromJson(data);
  }

  Future<TerritoryBattleMutationResult> startTerritoryBattle({
    required String playerId,
    required String regionId,
    required String battleType,
  }) async {
    final data = await _post('/players/$playerId/territory/conquests', {
      'regionId': regionId,
      'battleType': battleType,
    });
    return _territoryBattleMutationResultFromJson(data);
  }

  Future<TerritoryBattleMutationResult> resolveTerritoryBattle({
    required String playerId,
    required String battleId,
  }) async {
    final data = await _post(
        '/players/$playerId/territory/battles/$battleId/resolve', {});
    return _territoryBattleMutationResultFromJson(data);
  }

  Future<PlayerCitizenshipStatus> fetchPlayerCitizenship(
      String playerId) async {
    final data = await _get('/players/$playerId/citizenship');
    if (data is! Map<String, dynamic>) {
      throw BackendApiException('Invalid citizenship response from backend.');
    }

    return _playerCitizenshipStatusFromJson(data);
  }

  Future<CitizenshipMutationResult> joinCountry({
    required String playerId,
    required String countryId,
  }) async {
    final data = await _post('/players/$playerId/citizenship/join', {
      'countryId': countryId,
    });
    return _citizenshipMutationResultFromJson(data);
  }

  Future<CitizenshipMutationResult> changeCountry({
    required String playerId,
    required String countryId,
  }) async {
    final data = await _post('/players/$playerId/citizenship/change', {
      'countryId': countryId,
    });
    return _citizenshipMutationResultFromJson(data);
  }

  Future<DiplomacyStatus> fetchDiplomacyStatus(String playerId) async {
    final data = await _get('/players/$playerId/diplomacy');
    if (data is! Map<String, dynamic>) {
      throw BackendApiException('Invalid diplomacy response from backend.');
    }

    try {
      return DiplomacyStatus.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  Future<DiplomaticTreatyList> fetchDiplomacyTreaties({
    String? countryId,
    String? counterpartyCountryId,
    String? status,
    String? treatyType,
    int limit = 50,
  }) async {
    final query = <String, String>{'limit': limit.toString()};
    if (countryId != null && countryId.isNotEmpty) {
      query['countryId'] = countryId;
    }
    if (counterpartyCountryId != null && counterpartyCountryId.isNotEmpty) {
      query['counterpartyCountryId'] = counterpartyCountryId;
    }
    if (status != null && status.isNotEmpty) {
      query['status'] = status;
    }
    if (treatyType != null && treatyType.isNotEmpty) {
      query['treatyType'] = treatyType;
    }

    final data = await _get('/diplomacy/treaties', queryParameters: query);
    if (data is! Map<String, dynamic>) {
      throw BackendApiException('Invalid treaty list response.');
    }

    try {
      return DiplomaticTreatyList.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  Future<DiplomacyMutationResult> proposeTreaty({
    required String playerId,
    required String initiatorCountryId,
    required String targetCountryId,
    required String treatyType,
    required String title,
    required String terms,
    required int durationDays,
    int? treasuryAmount,
    String? sourceLawId,
    required String idempotencyKey,
  }) async {
    final data = await _post('/players/$playerId/diplomacy/proposals', {
      'initiatorCountryId': initiatorCountryId,
      'targetCountryId': targetCountryId,
      'treatyType': treatyType,
      'title': title,
      'terms': terms,
      'durationDays': durationDays,
      'treasuryAmount': treasuryAmount,
      'sourceLawId': sourceLawId,
      'idempotencyKey': idempotencyKey,
    });
    return _diplomacyMutationResultFromJson(data);
  }

  Future<DiplomacyMutationResult> ratifyTreaty({
    required String playerId,
    required String treatyId,
    required String idempotencyKey,
  }) async {
    final data = await _post(
      '/players/$playerId/diplomacy/treaties/$treatyId/ratify',
      {'idempotencyKey': idempotencyKey},
    );
    return _diplomacyMutationResultFromJson(data);
  }

  Future<DiplomacyMutationResult> rejectTreaty({
    required String playerId,
    required String treatyId,
    required String reason,
    required String idempotencyKey,
  }) async {
    final data = await _post(
      '/players/$playerId/diplomacy/treaties/$treatyId/reject',
      {'reason': reason, 'idempotencyKey': idempotencyKey},
    );
    return _diplomacyMutationResultFromJson(data);
  }

  Future<DiplomacyMutationResult> terminateTreaty({
    required String playerId,
    required String treatyId,
    required String reason,
    required String idempotencyKey,
  }) async {
    final data = await _post(
      '/players/$playerId/diplomacy/treaties/$treatyId/terminate',
      {'reason': reason, 'idempotencyKey': idempotencyKey},
    );
    return _diplomacyMutationResultFromJson(data);
  }

  Future<PoliticalPartyList> fetchPoliticalParties({String? countryId}) async {
    final query = <String, String>{};
    if (countryId != null && countryId.isNotEmpty) {
      query['countryId'] = countryId;
    }

    final data = await _get('/politics/parties', queryParameters: query);
    if (data is! Map<String, dynamic>) {
      throw BackendApiException(
          'Invalid political parties response from backend.');
    }

    return _politicalPartyListFromJson(data);
  }

  Future<PlayerPoliticsStatus> fetchPlayerPoliticsStatus(
      String playerId) async {
    final data = await _get('/players/$playerId/politics/status');
    if (data is! Map<String, dynamic>) {
      throw BackendApiException(
          'Invalid politics status response from backend.');
    }

    return _playerPoliticsStatusFromJson(data);
  }

  Future<PoliticalPartyMutationResult> createPoliticalParty({
    required String playerId,
    required String countryId,
    required String name,
    required String shortName,
    required String description,
    required String ideology,
  }) async {
    final data = await _post('/players/$playerId/politics/parties', {
      'countryId': countryId,
      'name': name,
      'shortName': shortName,
      'description': description,
      'ideology': ideology,
    });
    return _politicalPartyMutationResultFromJson(data);
  }

  Future<PoliticalPartyMutationResult> joinPoliticalParty({
    required String playerId,
    required String partyId,
  }) async {
    final data =
        await _post('/players/$playerId/politics/parties/$partyId/join', {});
    return _politicalPartyMutationResultFromJson(data);
  }

  Future<PoliticalPartyMutationResult> leavePoliticalParty({
    required String playerId,
    required String partyId,
  }) async {
    final data =
        await _post('/players/$playerId/politics/parties/$partyId/leave', {});
    return _politicalPartyMutationResultFromJson(data);
  }

  Future<ElectionList> fetchElections({String status = 'current'}) async {
    final data = await _get(
      '/politics/elections',
      queryParameters: {'status': status},
    );
    if (data is! Map<String, dynamic>) {
      throw BackendApiException('Invalid elections response from backend.');
    }

    return _electionListFromJson(data);
  }

  Future<ElectionDetails> fetchElectionDetails(String electionId) async {
    final data = await _get('/politics/elections/$electionId');
    if (data is! Map<String, dynamic>) {
      throw BackendApiException('Invalid election details response.');
    }

    return _electionDetailsFromJson(data);
  }

  Future<ElectionResults> fetchElectionResults(String electionId) async {
    final data = await _get('/politics/elections/$electionId/results');
    if (data is! Map<String, dynamic>) {
      throw BackendApiException('Invalid election results response.');
    }

    return _electionResultsFromJson(data);
  }

  Future<CandidacyMutationResult> declareCandidacy({
    required String playerId,
    required String electionId,
    String? partyId,
    required String manifesto,
  }) async {
    final data = await _post(
      '/players/$playerId/politics/elections/$electionId/candidacies',
      {
        'partyId': partyId,
        'manifesto': manifesto,
      },
    );
    return _candidacyMutationResultFromJson(data);
  }

  Future<VoteMutationResult> voteInElection({
    required String playerId,
    required String electionId,
    required String candidacyId,
  }) async {
    final data = await _post(
      '/players/$playerId/politics/elections/$electionId/vote',
      {'candidacyId': candidacyId},
    );
    return _voteMutationResultFromJson(data);
  }

  Future<OfficeHolderList> fetchOfficeHolders({String? countryId}) async {
    final query = <String, String>{};
    if (countryId != null && countryId.isNotEmpty) {
      query['countryId'] = countryId;
    }

    final data = await _get('/politics/office-holders', queryParameters: query);
    if (data is! Map<String, dynamic>) {
      throw BackendApiException('Invalid office holders response.');
    }

    return _officeHolderListFromJson(data);
  }

  Future<LawProposalList> fetchLawProposals({
    String? countryId,
    String? status = 'current',
    int limit = 50,
  }) async {
    final query = <String, String>{'limit': limit.toString()};
    if (countryId != null && countryId.isNotEmpty) {
      query['countryId'] = countryId;
    }
    if (status != null && status.isNotEmpty) {
      query['status'] = status;
    }

    final data = await _get('/politics/law-proposals', queryParameters: query);
    if (data is! Map<String, dynamic>) {
      throw BackendApiException('Invalid law proposals response.');
    }

    return _lawProposalListFromJson(data);
  }

  Future<LawProposalDetails> fetchLawProposalDetails(String proposalId) async {
    final data = await _get('/politics/law-proposals/$proposalId');
    if (data is! Map<String, dynamic>) {
      throw BackendApiException('Invalid law proposal response.');
    }

    return _lawProposalDetailsFromJson(data);
  }

  Future<LawList> fetchLaws({
    String? countryId,
    String status = 'active',
    int limit = 50,
  }) async {
    final query = <String, String>{
      'status': status,
      'limit': limit.toString(),
    };
    if (countryId != null && countryId.isNotEmpty) {
      query['countryId'] = countryId;
    }

    final data = await _get('/politics/laws', queryParameters: query);
    if (data is! Map<String, dynamic>) {
      throw BackendApiException('Invalid laws response.');
    }

    return _lawListFromJson(data);
  }

  Future<LawProposalMutationResult> createLawProposal({
    required String playerId,
    required String countryId,
    required String proposalType,
    required String title,
    required String description,
    int? incomeTaxRate,
    int? marketTaxRate,
    int? productionTaxRate,
    int? treasuryAmount,
    String? treasuryTargetPlayerId,
    String? treasuryReason,
    String? citizenshipRule,
    int? votingHours,
  }) async {
    final data = await _post('/players/$playerId/politics/law-proposals', {
      'countryId': countryId,
      'proposalType': proposalType,
      'title': title,
      'description': description,
      'incomeTaxRate': incomeTaxRate,
      'marketTaxRate': marketTaxRate,
      'productionTaxRate': productionTaxRate,
      'treasuryAmount': treasuryAmount,
      'treasuryTargetPlayerId': treasuryTargetPlayerId,
      'treasuryReason': treasuryReason,
      'citizenshipRule': citizenshipRule,
      'votingHours': votingHours,
    });
    return _lawProposalMutationResultFromJson(data);
  }

  Future<LawVoteMutationResult> voteOnLawProposal({
    required String playerId,
    required String proposalId,
    required String choice,
  }) async {
    final data = await _post(
      '/players/$playerId/politics/law-proposals/$proposalId/vote',
      {'choice': choice},
    );
    return _lawVoteMutationResultFromJson(data);
  }

  Future<LawProposalMutationResult> resolveLawProposal({
    required String playerId,
    required String proposalId,
  }) async {
    final data = await _post(
      '/players/$playerId/politics/law-proposals/$proposalId/resolve',
      {},
    );
    return _lawProposalMutationResultFromJson(data);
  }

  Future<CountryBattleList> fetchCountryBattles(
      {String status = 'current'}) async {
    final data = await _get(
      '/world/battles',
      queryParameters: {'status': status},
    );
    if (data is! Map<String, dynamic>) {
      throw BackendApiException('Invalid battles response from backend.');
    }

    return _countryBattleListFromJson(data);
  }

  Future<BattleDetails> fetchBattleDetails(String battleId) async {
    final data = await _get('/world/battles/$battleId');
    if (data is! Map<String, dynamic>) {
      throw BackendApiException(
          'Invalid battle details response from backend.');
    }

    return _battleDetailsFromJson(data);
  }

  Future<CombatReportList> fetchBattleReports({
    required String battleId,
    String? playerId,
    int limit = 25,
  }) async {
    final query = <String, String>{
      'limit': limit.toString(),
    };
    if (playerId != null && playerId.isNotEmpty) {
      query['playerId'] = playerId;
    }
    final data =
        await _get('/world/battles/$battleId/reports', queryParameters: query);
    if (data is! Map<String, dynamic>) {
      throw BackendApiException('Invalid battle reports response.');
    }

    return _combatReportListFromJson(data);
  }

  Future<CombatReportList> fetchPlayerCombatReports({
    required String playerId,
    String? battleId,
    int limit = 25,
  }) async {
    final query = <String, String>{
      'limit': limit.toString(),
    };
    if (battleId != null && battleId.isNotEmpty) {
      query['battleId'] = battleId;
    }
    final data =
        await _get('/players/$playerId/combat-reports', queryParameters: query);
    if (data is! Map<String, dynamic>) {
      throw BackendApiException('Invalid combat reports response.');
    }

    return _combatReportListFromJson(data);
  }

  Future<PlayerBattleParticipationStatus> fetchBattleParticipation({
    required String playerId,
    required String battleId,
  }) async {
    final data =
        await _get('/players/$playerId/battles/$battleId/participation');
    if (data is! Map<String, dynamic>) {
      throw BackendApiException(
          'Invalid battle participation response from backend.');
    }

    return _playerBattleParticipationStatusFromJson(data);
  }

  Future<BattleContributionResult> contributeToBattle({
    required String playerId,
    required String battleId,
    required String idempotencyKey,
  }) async {
    final data = await _post(
      '/players/$playerId/battles/$battleId/contribute',
      {},
      extraHeaders: {'Idempotency-Key': idempotencyKey},
    );
    return _battleContributionResultFromJson(data);
  }

  Future<CampaignList> fetchCampaigns({
    String? countryId,
    String status = 'active',
    int limit = 25,
  }) async {
    final query = <String, String>{
      'status': status,
      'limit': limit.toString(),
    };
    if (countryId != null && countryId.isNotEmpty) {
      query['countryId'] = countryId;
    }
    final data = await _get('/world/campaigns', queryParameters: query);
    if (data is! Map<String, dynamic>) {
      throw BackendApiException('Invalid campaigns response from backend.');
    }

    return _campaignListFromJson(data);
  }

  Future<CampaignDetails> fetchCampaignDetails(String campaignId) async {
    final data = await _get('/world/campaigns/$campaignId');
    if (data is! Map<String, dynamic>) {
      throw BackendApiException('Invalid campaign details response.');
    }

    return _campaignDetailsFromJson(data);
  }

  Future<CampaignMutationResult> createCampaign({
    required String playerId,
    required String countryId,
    required String name,
    required String description,
    required String campaignType,
    required int objectiveScore,
    required String idempotencyKey,
  }) async {
    final data = await _post(
      '/players/$playerId/campaigns',
      {
        'countryId': countryId,
        'name': name,
        'description': description,
        'campaignType': campaignType,
        'objectiveScore': objectiveScore,
      },
      extraHeaders: {'Idempotency-Key': idempotencyKey},
    );
    return _campaignMutationResultFromJson(data);
  }

  Future<CampaignMutationResult> completeCampaignPhase({
    required String playerId,
    required String campaignId,
    required String phaseId,
  }) async {
    final data = await _post(
      '/players/$playerId/campaigns/$campaignId/phases/$phaseId/complete',
      {},
    );
    return _campaignMutationResultFromJson(data);
  }

  Future<CampaignRewardClaimResult> claimCampaignReward({
    required String playerId,
    required String campaignId,
    required String idempotencyKey,
  }) async {
    final data = await _post(
      '/players/$playerId/campaigns/$campaignId/rewards/claim',
      {},
      extraHeaders: {'Idempotency-Key': idempotencyKey},
    );
    return _campaignRewardClaimResultFromJson(data);
  }

  Future<CountryBattleLeaderboard> fetchCountryBattleLeaderboard({
    String? campaignId,
    String? battleId,
    int limit = 25,
  }) async {
    final query = <String, String>{'limit': limit.toString()};
    if (campaignId != null && campaignId.isNotEmpty) {
      query['campaignId'] = campaignId;
    }
    if (battleId != null && battleId.isNotEmpty) {
      query['battleId'] = battleId;
    }
    final data =
        await _get('/world/leaderboards/countries', queryParameters: query);
    if (data is! Map<String, dynamic>) {
      throw BackendApiException('Invalid country battle leaderboard response.');
    }

    return _countryBattleLeaderboardFromJson(data);
  }

  Future<CampaignUnitLeaderboard> fetchCampaignUnitLeaderboard({
    required String campaignId,
    int limit = 25,
  }) async {
    final data = await _get(
      '/world/campaigns/$campaignId/leaderboards/units',
      queryParameters: {'limit': limit.toString()},
    );
    if (data is! Map<String, dynamic>) {
      throw BackendApiException('Invalid campaign unit leaderboard response.');
    }

    return _campaignUnitLeaderboardFromJson(data);
  }

  Future<MilitaryUnitList> fetchMilitaryUnits(String playerId) async {
    final data = await _get('/players/$playerId/military-units');
    if (data is! Map<String, dynamic>) {
      throw BackendApiException(
          'Invalid military units response from backend.');
    }

    return _militaryUnitListFromJson(data);
  }

  Future<MilitaryUnitDetails> fetchMilitaryUnitDetails({
    required String unitId,
    required String playerId,
  }) async {
    final data = await _get(
      '/military-units/$unitId',
      queryParameters: {'playerId': playerId},
    );
    if (data is! Map<String, dynamic>) {
      throw BackendApiException(
          'Invalid military unit details response from backend.');
    }

    return _militaryUnitDetailsFromJson(data);
  }

  Future<MilitaryUnitMutationResult> createMilitaryUnit({
    required String playerId,
    required String name,
    required String description,
    required String idempotencyKey,
  }) async {
    final data = await _post(
      '/players/$playerId/military-units',
      {
        'name': name,
        'description': description,
      },
      extraHeaders: {'Idempotency-Key': idempotencyKey},
    );
    return _militaryUnitMutationResultFromJson(data);
  }

  Future<MilitaryUnitMutationResult> joinMilitaryUnit({
    required String playerId,
    required String unitId,
    required String idempotencyKey,
  }) async {
    final data = await _post(
      '/players/$playerId/military-units/$unitId/join',
      {},
      extraHeaders: {'Idempotency-Key': idempotencyKey},
    );
    return _militaryUnitMutationResultFromJson(data);
  }

  Future<MilitaryUnitMutationResult> leaveMilitaryUnit({
    required String playerId,
    required String unitId,
  }) async {
    final data =
        await _post('/players/$playerId/military-units/$unitId/leave', {});
    return _militaryUnitMutationResultFromJson(data);
  }

  Future<MilitaryUnitOrderMutationResult> issueMilitaryUnitOrder({
    required String playerId,
    required String unitId,
    required String title,
    required String description,
    required String orderType,
    String? targetBattleId,
    required String idempotencyKey,
  }) async {
    final data = await _post(
      '/players/$playerId/military-units/$unitId/orders',
      {
        'title': title,
        'description': description,
        'orderType': orderType,
        'targetBattleId': targetBattleId,
      },
      extraHeaders: {'Idempotency-Key': idempotencyKey},
    );
    return _militaryUnitOrderMutationResultFromJson(data);
  }

  Future<MilitaryUnitOrderMutationResult> completeMilitaryUnitOrder({
    required String playerId,
    required String unitId,
    required String orderId,
  }) async {
    final data = await _post(
      '/players/$playerId/military-units/$unitId/orders/$orderId/complete',
      {},
    );
    return _militaryUnitOrderMutationResultFromJson(data);
  }

  Future<MilitaryUnitOrderMutationResult> cancelMilitaryUnitOrder({
    required String playerId,
    required String unitId,
    required String orderId,
  }) async {
    final data = await _post(
      '/players/$playerId/military-units/$unitId/orders/$orderId/cancel',
      {},
    );
    return _militaryUnitOrderMutationResultFromJson(data);
  }

  Future<MilitaryUnitLeaderboard> fetchMilitaryUnitLeaderboard({
    String? battleId,
    int limit = 25,
  }) async {
    final query = <String, String>{'limit': limit.toString()};
    if (battleId != null && battleId.isNotEmpty) {
      query['battleId'] = battleId;
    }
    final data =
        await _get('/military-units/leaderboard', queryParameters: query);
    if (data is! Map<String, dynamic>) {
      throw BackendApiException(
          'Invalid military unit leaderboard response from backend.');
    }

    return _militaryUnitLeaderboardFromJson(data);
  }

  Future<UnitBattleContributions> fetchMilitaryUnitBattleContributions({
    required String unitId,
    String? battleId,
    int limit = 25,
  }) async {
    final query = <String, String>{'limit': limit.toString()};
    if (battleId != null && battleId.isNotEmpty) {
      query['battleId'] = battleId;
    }
    final data = await _get(
      '/military-units/$unitId/battle-contributions',
      queryParameters: query,
    );
    if (data is! Map<String, dynamic>) {
      throw BackendApiException(
          'Invalid military unit contributions response from backend.');
    }

    return _unitBattleContributionsFromJson(data);
  }

  Future<UnitDivisionList> fetchUnitDivisions({
    required String unitId,
    String? campaignId,
  }) async {
    final query = <String, String>{};
    if (campaignId != null && campaignId.isNotEmpty) {
      query['campaignId'] = campaignId;
    }
    final data = await _get(
      '/military-units/$unitId/divisions',
      queryParameters: query,
    );
    if (data is! Map<String, dynamic>) {
      throw BackendApiException('Invalid unit divisions response.');
    }

    return _unitDivisionListFromJson(data);
  }

  Future<DeploymentOrderList> fetchDeploymentOrders({
    required String unitId,
    String? campaignId,
    String? status,
  }) async {
    final query = <String, String>{};
    if (campaignId != null && campaignId.isNotEmpty) {
      query['campaignId'] = campaignId;
    }
    if (status != null && status.isNotEmpty) {
      query['status'] = status;
    }
    final data = await _get(
      '/military-units/$unitId/deployment-orders',
      queryParameters: query,
    );
    if (data is! Map<String, dynamic>) {
      throw BackendApiException('Invalid deployment orders response.');
    }

    return _deploymentOrderListFromJson(data);
  }

  Future<UnitDivisionMutationResult> createUnitDivision({
    required String playerId,
    required String unitId,
    required String campaignId,
    required String name,
    required String divisionRole,
    required int memberCount,
    required int assignedStrength,
    required String idempotencyKey,
  }) async {
    final data = await _post(
      '/players/$playerId/military-units/$unitId/divisions',
      {
        'campaignId': campaignId,
        'name': name,
        'divisionRole': divisionRole,
        'memberCount': memberCount,
        'assignedStrength': assignedStrength,
      },
      extraHeaders: {'Idempotency-Key': idempotencyKey},
    );
    return _unitDivisionMutationResultFromJson(data);
  }

  Future<DeploymentOrderMutationResult> issueDeploymentOrder({
    required String playerId,
    required String unitId,
    String? campaignId,
    String? divisionId,
    String? targetBattleId,
    required String orderType,
    required String title,
    required String description,
    required int troopCommitment,
    required String idempotencyKey,
  }) async {
    final data = await _post(
      '/players/$playerId/military-units/$unitId/deployment-orders',
      {
        'campaignId': campaignId,
        'divisionId': divisionId,
        'targetBattleId': targetBattleId,
        'orderType': orderType,
        'title': title,
        'description': description,
        'troopCommitment': troopCommitment,
      },
      extraHeaders: {'Idempotency-Key': idempotencyKey},
    );
    return _deploymentOrderMutationResultFromJson(data);
  }

  Future<DeploymentOrderMutationResult> executeDeploymentOrder({
    required String playerId,
    required String unitId,
    required String orderId,
  }) async {
    final data = await _post(
      '/players/$playerId/military-units/$unitId/deployment-orders/$orderId/execute',
      {},
    );
    return _deploymentOrderMutationResultFromJson(data);
  }

  Future<DeploymentOrderMutationResult> cancelDeploymentOrder({
    required String playerId,
    required String unitId,
    required String orderId,
  }) async {
    final data = await _post(
      '/players/$playerId/military-units/$unitId/deployment-orders/$orderId/cancel',
      {},
    );
    return _deploymentOrderMutationResultFromJson(data);
  }

  Future<NewspaperCatalog> fetchNewspapers(String playerId,
      {int limit = 25}) async {
    final data = await _get(
      '/players/$playerId/media/newspapers',
      queryParameters: {'limit': limit.toString()},
    );
    if (data is! Map<String, dynamic>) {
      throw BackendApiException('Invalid newspapers response from backend.');
    }

    return _newspaperCatalogFromJson(data);
  }

  Future<NewspaperMutationResult> createNewspaper({
    required String playerId,
    required String name,
    required String description,
  }) async {
    final data = await _post('/players/$playerId/media/newspapers', {
      'name': name,
      'description': description,
    });
    return _newspaperMutationResultFromJson(data);
  }

  Future<NewspaperArticleList> fetchNewspaperArticles({
    required String playerId,
    required String newspaperId,
    int limit = 25,
  }) async {
    final data = await _get(
      '/players/$playerId/media/newspapers/$newspaperId/articles',
      queryParameters: {'limit': limit.toString()},
    );
    if (data is! Map<String, dynamic>) {
      throw BackendApiException(
          'Invalid newspaper articles response from backend.');
    }

    return _newspaperArticleListFromJson(data);
  }

  Future<ArticlePublicationResult> publishArticle({
    required String playerId,
    required String newspaperId,
    required String title,
    required String content,
  }) async {
    final data = await _post(
      '/players/$playerId/media/newspapers/$newspaperId/articles',
      {
        'title': title,
        'content': content,
      },
    );
    return _articlePublicationResultFromJson(data);
  }

  Future<NewspaperArticle> fetchNewspaperArticle({
    required String playerId,
    required String articleId,
  }) async {
    final data = await _get('/players/$playerId/media/articles/$articleId');
    if (data is! Map<String, dynamic>) {
      throw BackendApiException('Invalid newspaper article response.');
    }

    return _newspaperArticleFromJson(data);
  }

  Future<ArticleCommentResult> commentOnArticle({
    required String playerId,
    required String articleId,
    required String content,
  }) async {
    final data = await _post(
      '/players/$playerId/media/articles/$articleId/comments',
      {'content': content},
    );
    return _articleCommentResultFromJson(data);
  }

  Future<ArticleVoteResult> voteOnArticle({
    required String playerId,
    required String articleId,
    required int value,
  }) async {
    final data = await _post(
      '/players/$playerId/media/articles/$articleId/votes',
      {'value': value},
    );
    return _articleVoteResultFromJson(data);
  }

  Future<NewspaperSubscriptionResult> subscribeToNewspaper({
    required String playerId,
    required String newspaperId,
    required bool subscribe,
  }) async {
    final data = await _post(
      '/players/$playerId/media/newspapers/$newspaperId/subscribe',
      {'subscribe': subscribe},
    );
    return _newspaperSubscriptionResultFromJson(data);
  }

  Future<ContentReportResult> reportNewspaper({
    required String playerId,
    required String newspaperId,
    required String reason,
    String? details,
  }) async {
    final data = await _post(
      '/players/$playerId/media/newspapers/$newspaperId/report',
      {
        'reason': reason,
        if (details != null && details.trim().isNotEmpty)
          'details': details.trim(),
      },
    );
    return _contentReportResultFromJson(data);
  }

  Future<ContentReportResult> reportArticle({
    required String playerId,
    required String articleId,
    required String reason,
    String? details,
  }) async {
    final data = await _post(
      '/players/$playerId/media/articles/$articleId/report',
      {
        'reason': reason,
        if (details != null && details.trim().isNotEmpty)
          'details': details.trim(),
      },
    );
    return _contentReportResultFromJson(data);
  }

  Future<ContentReportResult> reportArticleComment({
    required String playerId,
    required String articleId,
    required String commentId,
    required String reason,
    String? details,
  }) async {
    final data = await _post(
      '/players/$playerId/media/articles/$articleId/comments/$commentId/report',
      {
        'reason': reason,
        if (details != null && details.trim().isNotEmpty)
          'details': details.trim(),
      },
    );
    return _contentReportResultFromJson(data);
  }

  Future<List<Message>> fetchMessages({
    String? fromId,
    String? toId,
    DateTime? since,
  }) async {
    final query = <String, String>{};
    if (fromId != null && fromId.isNotEmpty) {
      query['fromId'] = fromId;
    }
    if (toId != null && toId.isNotEmpty) {
      query['toId'] = toId;
    }
    if (since != null) {
      query['since'] = since.toUtc().toIso8601String();
    }

    final data = await _get('/messages', queryParameters: query);
    if (data is! List<dynamic>) {
      throw BackendApiException('Invalid messages response from backend.');
    }

    return data.map((message) {
      if (message is! Map<String, dynamic>) {
        throw BackendApiException('Invalid messages response from backend.');
      }

      return _messageFromJson(message);
    }).toList();
  }

  Future<Message> sendMessage({
    required String content,
    required String fromId,
    required String toId,
  }) async {
    final data = await _post('/messages', {
      'content': content,
      'fromId': fromId,
      'toId': toId,
    });

    return _messageFromJson(data);
  }

  Future<ContentReportResult> reportMessage({
    required String playerId,
    required String messageId,
    required String reason,
    String? details,
  }) async {
    final data = await _post(
      '/players/$playerId/messages/$messageId/report',
      {
        'reason': reason,
        if (details != null && details.trim().isNotEmpty)
          'details': details.trim(),
      },
    );
    return _contentReportResultFromJson(data);
  }

  void close() {
    _client.close();
  }

  AuthSession _authSessionFromJson(Map<String, dynamic> data) {
    final userData = data['user'];
    if (userData is! Map<String, dynamic>) {
      throw BackendApiException('Invalid auth response from backend.');
    }

    return AuthSession(
      token: data['token']?.toString() ?? '',
      refreshToken:
          (data['refreshToken'] ?? data['refresh_token'])?.toString() ?? '',
      user: _userFromJson(userData),
      expiresAt: _date(data['expires_at'] ?? data['expiresAt']),
      refreshExpiresAt:
          _date(data['refresh_expires_at'] ?? data['refreshExpiresAt']),
    );
  }

  AccountSecurityProfile _accountSecurityProfileFromJson(
      Map<String, dynamic> data) {
    try {
      return AccountSecurityProfile.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  AuthActionResult _authActionResultFromJson(Map<String, dynamic> data) {
    try {
      return AuthActionResult.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  SessionRevokeResult _sessionRevokeResultFromJson(Map<String, dynamic> data) {
    try {
      return SessionRevokeResult.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  User _userFromJson(Map<String, dynamic> data) {
    try {
      return User.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  Message _messageFromJson(Map<String, dynamic> data) {
    try {
      return Message.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  PlayerState _playerStateFromJson(Map<String, dynamic> data) {
    try {
      return PlayerState.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  PlayerActionResult _playerActionFromJson(Map<String, dynamic> data) {
    try {
      return PlayerActionResult.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  ActivityFeedSummary _activityFeedFromJson(Map<String, dynamic> data) {
    try {
      return ActivityFeedSummary.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  ActivityReadResult _activityReadResultFromJson(Map<String, dynamic> data) {
    try {
      return ActivityReadResult.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  ActivityReadAllResult _activityReadAllResultFromJson(
      Map<String, dynamic> data) {
    try {
      return ActivityReadAllResult.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  PushNotificationSettings _pushNotificationSettingsFromJson(
      Map<String, dynamic> data) {
    try {
      return PushNotificationSettings.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  PushSubscriptionMutationResult _pushSubscriptionMutationFromJson(
      Map<String, dynamic> data) {
    try {
      return PushSubscriptionMutationResult.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  PushDeliveryList _pushDeliveryListFromJson(Map<String, dynamic> data) {
    try {
      return PushDeliveryList.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  RealtimeUpdatesEnvelope _realtimeUpdatesFromJson(Map<String, dynamic> data) {
    try {
      return RealtimeUpdatesEnvelope.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  DailyObjectivesSummary _dailyObjectivesFromJson(Map<String, dynamic> data) {
    try {
      return DailyObjectivesSummary.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  DailyObjectiveClaimResult _dailyObjectiveClaimResultFromJson(
      Map<String, dynamic> data) {
    try {
      return DailyObjectiveClaimResult.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  AchievementsSummary _achievementsSummaryFromJson(Map<String, dynamic> data) {
    try {
      return AchievementsSummary.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  AchievementClaimResult _achievementClaimResultFromJson(
      Map<String, dynamic> data) {
    try {
      return AchievementClaimResult.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  PublicPlayerProfile _publicProfileFromJson(Map<String, dynamic> data) {
    try {
      return PublicPlayerProfile.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  RankingsLeaderboard _rankingsLeaderboardFromJson(Map<String, dynamic> data) {
    try {
      return RankingsLeaderboard.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  RankingEntry _rankingEntryFromJson(Map<String, dynamic> data) {
    try {
      return RankingEntry.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  InventorySummary _inventoryFromJson(Map<String, dynamic> data) {
    try {
      return InventorySummary.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  InventoryItemUseResult _inventoryItemUseResultFromJson(
      Map<String, dynamic> data) {
    try {
      return InventoryItemUseResult.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  LedgerSummary _ledgerSummaryFromJson(Map<String, dynamic> data) {
    try {
      return LedgerSummary.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  AdminPlayerSearchResponse _adminPlayerSearchFromJson(
      Map<String, dynamic> data) {
    try {
      return AdminPlayerSearchResponse.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  AdminPlayerSummary _adminPlayerSummaryFromJson(Map<String, dynamic> data) {
    try {
      return AdminPlayerSummary.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  AdminModerationRecord _adminModerationRecordFromJson(
      Map<String, dynamic> data) {
    try {
      return AdminModerationRecord.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  AdminAuditRecordList _adminAuditRecordListFromJson(
      Map<String, dynamic> data) {
    try {
      return AdminAuditRecordList.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  AdminEconomyLedgerAuditResponse _adminEconomyLedgerFromJson(
      Map<String, dynamic> data) {
    try {
      return AdminEconomyLedgerAuditResponse.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  AdminEconomyBalanceDashboard _adminEconomyDashboardFromJson(
      Map<String, dynamic> data) {
    try {
      return AdminEconomyBalanceDashboard.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  AdminContentModerationQueue _adminContentQueueFromJson(
      Map<String, dynamic> data) {
    try {
      return AdminContentModerationQueue.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  AdminContentModerationItem _adminContentModerationItemFromJson(
      Map<String, dynamic> data) {
    try {
      return AdminContentModerationItem.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  AdminAntiAbuseReviewQueue _adminAntiAbuseQueueFromJson(
      Map<String, dynamic> data) {
    try {
      return AdminAntiAbuseReviewQueue.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  AdminAntiAbuseReviewItem _adminAntiAbuseItemFromJson(
      Map<String, dynamic> data) {
    try {
      return AdminAntiAbuseReviewItem.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  EquipmentSummary _equipmentSummaryFromJson(Map<String, dynamic> data) {
    try {
      return EquipmentSummary.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  EquipWeaponResult _equipWeaponResultFromJson(Map<String, dynamic> data) {
    try {
      return EquipWeaponResult.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  RepairWeaponResult _repairWeaponResultFromJson(Map<String, dynamic> data) {
    try {
      return RepairWeaponResult.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  FactoryPortfolio _factoryPortfolioFromJson(Map<String, dynamic> data) {
    try {
      return FactoryPortfolio.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  ProductionResult _productionResultFromJson(Map<String, dynamic> data) {
    try {
      return ProductionResult.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  ProductionJobsResponse _productionJobsResponseFromJson(
      Map<String, dynamic> data) {
    try {
      return ProductionJobsResponse.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  ProductionClaimResult _productionClaimResultFromJson(
      Map<String, dynamic> data) {
    try {
      return ProductionClaimResult.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  FactoryUpgradeQuote _factoryUpgradeQuoteFromJson(Map<String, dynamic> data) {
    try {
      return FactoryUpgradeQuote.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  FactoryUpgradeGatewayResult _factoryUpgradeGatewayResultFromJson(
      Map<String, dynamic> data) {
    try {
      return FactoryUpgradeGatewayResult.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  ResearchTechnologyCatalog _researchTechnologyCatalogFromJson(
      Map<String, dynamic> data) {
    try {
      return ResearchTechnologyCatalog.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  ResearchDashboard _researchDashboardFromJson(Map<String, dynamic> data) {
    try {
      return ResearchDashboard.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  ResearchScopeState _researchScopeStateFromJson(Map<String, dynamic> data) {
    try {
      return ResearchScopeState.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  ResearchBonusList _researchBonusListFromJson(Map<String, dynamic> data) {
    try {
      return ResearchBonusList.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  ResearchMutationResult _researchMutationResultFromJson(
      Map<String, dynamic> data) {
    try {
      return ResearchMutationResult.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  CompanyPortfolio _companyPortfolioFromJson(Map<String, dynamic> data) {
    try {
      return CompanyPortfolio.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  CompanyDetail _companyDetailFromJson(Map<String, dynamic> data) {
    try {
      return CompanyDetail.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  CompanyAssets _companyAssetsFromJson(Map<String, dynamic> data) {
    try {
      return CompanyAssets.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  ResourceSiteList _resourceSiteListFromJson(Map<String, dynamic> data) {
    try {
      return ResourceSiteList.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  ResourceLogisticsDashboard _resourceLogisticsDashboardFromJson(
      Map<String, dynamic> data) {
    try {
      return ResourceLogisticsDashboard.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  ExtractionMutationResult _extractionMutationFromJson(
      Map<String, dynamic> data) {
    try {
      return ExtractionMutationResult.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  ExtractionClaimResult _extractionClaimFromJson(Map<String, dynamic> data) {
    try {
      return ExtractionClaimResult.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  ShipmentMutationResult _shipmentMutationFromJson(Map<String, dynamic> data) {
    try {
      return ShipmentMutationResult.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  CompanyUpgradeState _companyUpgradeStateFromJson(Map<String, dynamic> data) {
    try {
      return CompanyUpgradeState.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  CompanyMutationResult _companyMutationResultFromJson(
      Map<String, dynamic> data) {
    try {
      return CompanyMutationResult.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  CompanyProductionClaimResult _companyProductionClaimResultFromJson(
      Map<String, dynamic> data) {
    try {
      return CompanyProductionClaimResult.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  CompanyUpgradeMutationResult _companyUpgradeMutationResultFromJson(
      Map<String, dynamic> data) {
    try {
      return CompanyUpgradeMutationResult.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  CompanyJobList _companyJobListFromJson(Map<String, dynamic> data) {
    try {
      return CompanyJobList.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  CompanyJobMutationResult _companyJobMutationResultFromJson(
      Map<String, dynamic> data) {
    try {
      return CompanyJobMutationResult.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  CompanyWorkResult _companyWorkResultFromJson(Map<String, dynamic> data) {
    try {
      return CompanyWorkResult.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  MarketListings _marketListingsFromJson(Map<String, dynamic> data) {
    try {
      return MarketListings.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  PlayerMarketListings _playerMarketListingsFromJson(
      Map<String, dynamic> data) {
    try {
      return PlayerMarketListings.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  MarketPriceHistory _marketPriceHistoryFromJson(Map<String, dynamic> data) {
    try {
      return MarketPriceHistory.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  MarketOrderBook _marketOrderBookFromJson(Map<String, dynamic> data) {
    try {
      return MarketOrderBook.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  TradeOfferList _tradeOfferListFromJson(Map<String, dynamic> data) {
    try {
      return TradeOfferList.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  MarketPurchaseResult _marketPurchaseResultFromJson(
      Map<String, dynamic> data) {
    try {
      return MarketPurchaseResult.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  MarketSellListingResult _marketSellListingResultFromJson(
      Map<String, dynamic> data) {
    try {
      return MarketSellListingResult.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  MarketCancelListingResult _marketCancelListingResultFromJson(
      Map<String, dynamic> data) {
    try {
      return MarketCancelListingResult.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  TradeOfferResult _tradeOfferResultFromJson(Map<String, dynamic> data) {
    try {
      return TradeOfferResult.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  CombatMission _combatMissionFromJson(Map<String, dynamic> data) {
    try {
      return CombatMission.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  MissionProgressSummary _missionProgressSummaryFromJson(
      Map<String, dynamic> data) {
    try {
      return MissionProgressSummary.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  MissionFightResult _missionFightResultFromJson(Map<String, dynamic> data) {
    try {
      return MissionFightResult.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  CountryCatalog _countryCatalogFromJson(Map<String, dynamic> data) {
    try {
      return CountryCatalog.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  CountryTreasury _countryTreasuryFromJson(Map<String, dynamic> data) {
    try {
      return CountryTreasury.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  CountryInfrastructure _countryInfrastructureFromJson(
      Map<String, dynamic> data) {
    try {
      return CountryInfrastructure.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  CountryInfrastructureContributionResult
      _countryInfrastructureContributionResultFromJson(
          Map<String, dynamic> data) {
    try {
      return CountryInfrastructureContributionResult.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  CountryTaxPolicyUpdateResult _countryTaxPolicyUpdateResultFromJson(
      Map<String, dynamic> data) {
    try {
      return CountryTaxPolicyUpdateResult.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  RegionList _regionListFromJson(Map<String, dynamic> data) {
    try {
      return RegionList.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  TerritoryMap _territoryMapFromJson(Map<String, dynamic> data) {
    try {
      return TerritoryMap.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  TerritoryBattleMutationResult _territoryBattleMutationResultFromJson(
      Map<String, dynamic> data) {
    try {
      return TerritoryBattleMutationResult.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  PlayerCitizenshipStatus _playerCitizenshipStatusFromJson(
      Map<String, dynamic> data) {
    try {
      return PlayerCitizenshipStatus.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  CitizenshipMutationResult _citizenshipMutationResultFromJson(
      Map<String, dynamic> data) {
    try {
      return CitizenshipMutationResult.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  DiplomacyMutationResult _diplomacyMutationResultFromJson(
      Map<String, dynamic> data) {
    try {
      return DiplomacyMutationResult.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  PoliticalPartyList _politicalPartyListFromJson(Map<String, dynamic> data) {
    try {
      return PoliticalPartyList.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  PlayerPoliticsStatus _playerPoliticsStatusFromJson(
      Map<String, dynamic> data) {
    try {
      return PlayerPoliticsStatus.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  PoliticalPartyMutationResult _politicalPartyMutationResultFromJson(
      Map<String, dynamic> data) {
    try {
      return PoliticalPartyMutationResult.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  ElectionList _electionListFromJson(Map<String, dynamic> data) {
    try {
      return ElectionList.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  ElectionDetails _electionDetailsFromJson(Map<String, dynamic> data) {
    try {
      return ElectionDetails.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  ElectionResults _electionResultsFromJson(Map<String, dynamic> data) {
    try {
      return ElectionResults.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  CandidacyMutationResult _candidacyMutationResultFromJson(
      Map<String, dynamic> data) {
    try {
      return CandidacyMutationResult.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  VoteMutationResult _voteMutationResultFromJson(Map<String, dynamic> data) {
    try {
      return VoteMutationResult.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  OfficeHolderList _officeHolderListFromJson(Map<String, dynamic> data) {
    try {
      return OfficeHolderList.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  LawProposalList _lawProposalListFromJson(Map<String, dynamic> data) {
    try {
      return LawProposalList.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  LawProposalDetails _lawProposalDetailsFromJson(Map<String, dynamic> data) {
    try {
      return LawProposalDetails.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  LawList _lawListFromJson(Map<String, dynamic> data) {
    try {
      return LawList.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  LawProposalMutationResult _lawProposalMutationResultFromJson(
      Map<String, dynamic> data) {
    try {
      return LawProposalMutationResult.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  LawVoteMutationResult _lawVoteMutationResultFromJson(
      Map<String, dynamic> data) {
    try {
      return LawVoteMutationResult.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  CountryBattleList _countryBattleListFromJson(Map<String, dynamic> data) {
    try {
      return CountryBattleList.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  BattleDetails _battleDetailsFromJson(Map<String, dynamic> data) {
    try {
      return BattleDetails.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  CombatReportList _combatReportListFromJson(Map<String, dynamic> data) {
    try {
      return CombatReportList.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  PlayerBattleParticipationStatus _playerBattleParticipationStatusFromJson(
      Map<String, dynamic> data) {
    try {
      return PlayerBattleParticipationStatus.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  BattleContributionResult _battleContributionResultFromJson(
      Map<String, dynamic> data) {
    try {
      return BattleContributionResult.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  CampaignList _campaignListFromJson(Map<String, dynamic> data) {
    try {
      return CampaignList.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  CampaignDetails _campaignDetailsFromJson(Map<String, dynamic> data) {
    try {
      return CampaignDetails.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  CampaignMutationResult _campaignMutationResultFromJson(
      Map<String, dynamic> data) {
    try {
      return CampaignMutationResult.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  CampaignRewardClaimResult _campaignRewardClaimResultFromJson(
      Map<String, dynamic> data) {
    try {
      return CampaignRewardClaimResult.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  CountryBattleLeaderboard _countryBattleLeaderboardFromJson(
      Map<String, dynamic> data) {
    try {
      return CountryBattleLeaderboard.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  CampaignUnitLeaderboard _campaignUnitLeaderboardFromJson(
      Map<String, dynamic> data) {
    try {
      return CampaignUnitLeaderboard.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  MilitaryUnitList _militaryUnitListFromJson(Map<String, dynamic> data) {
    try {
      return MilitaryUnitList.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  MilitaryUnitDetails _militaryUnitDetailsFromJson(Map<String, dynamic> data) {
    try {
      return MilitaryUnitDetails.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  MilitaryUnitMutationResult _militaryUnitMutationResultFromJson(
      Map<String, dynamic> data) {
    try {
      return MilitaryUnitMutationResult.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  MilitaryUnitOrderMutationResult _militaryUnitOrderMutationResultFromJson(
      Map<String, dynamic> data) {
    try {
      return MilitaryUnitOrderMutationResult.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  MilitaryUnitLeaderboard _militaryUnitLeaderboardFromJson(
      Map<String, dynamic> data) {
    try {
      return MilitaryUnitLeaderboard.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  UnitBattleContributions _unitBattleContributionsFromJson(
      Map<String, dynamic> data) {
    try {
      return UnitBattleContributions.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  UnitDivisionList _unitDivisionListFromJson(Map<String, dynamic> data) {
    try {
      return UnitDivisionList.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  DeploymentOrderList _deploymentOrderListFromJson(Map<String, dynamic> data) {
    try {
      return DeploymentOrderList.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  UnitDivisionMutationResult _unitDivisionMutationResultFromJson(
      Map<String, dynamic> data) {
    try {
      return UnitDivisionMutationResult.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  DeploymentOrderMutationResult _deploymentOrderMutationResultFromJson(
      Map<String, dynamic> data) {
    try {
      return DeploymentOrderMutationResult.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  NewspaperCatalog _newspaperCatalogFromJson(Map<String, dynamic> data) {
    try {
      return NewspaperCatalog.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  NewspaperArticleList _newspaperArticleListFromJson(
      Map<String, dynamic> data) {
    try {
      return NewspaperArticleList.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  NewspaperArticle _newspaperArticleFromJson(Map<String, dynamic> data) {
    try {
      return NewspaperArticle.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  NewspaperMutationResult _newspaperMutationResultFromJson(
      Map<String, dynamic> data) {
    try {
      return NewspaperMutationResult.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  ArticlePublicationResult _articlePublicationResultFromJson(
      Map<String, dynamic> data) {
    try {
      return ArticlePublicationResult.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  ArticleCommentResult _articleCommentResultFromJson(
      Map<String, dynamic> data) {
    try {
      return ArticleCommentResult.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  ArticleVoteResult _articleVoteResultFromJson(Map<String, dynamic> data) {
    try {
      return ArticleVoteResult.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  NewspaperSubscriptionResult _newspaperSubscriptionResultFromJson(
      Map<String, dynamic> data) {
    try {
      return NewspaperSubscriptionResult.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  ContentReportResult _contentReportResultFromJson(Map<String, dynamic> data) {
    try {
      return ContentReportResult.fromJson(data);
    } on FormatException catch (e) {
      throw BackendApiException(e.message);
    }
  }

  Future<dynamic> _get(
    String path, {
    Map<String, String>? queryParameters,
    Map<String, String>? extraHeaders,
    bool allowAuthRefresh = true,
  }) async {
    var response = await _client.get(
      _uri(path, queryParameters),
      headers: _headers(extraHeaders: extraHeaders),
    );
    if (response.statusCode == 401 &&
        allowAuthRefresh &&
        await _tryRefreshSession()) {
      response = await _client.get(
        _uri(path, queryParameters),
        headers: _headers(extraHeaders: extraHeaders),
      );
    }
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, Object?> body, {
    Map<String, String>? extraHeaders,
    bool allowAuthRefresh = true,
  }) async {
    var response = await _client.post(
      _uri(path),
      headers: _headers(
        contentType: 'application/json',
        extraHeaders: extraHeaders,
      ),
      body: jsonEncode(body),
    );
    if (response.statusCode == 401 &&
        allowAuthRefresh &&
        await _tryRefreshSession()) {
      response = await _client.post(
        _uri(path),
        headers: _headers(
          contentType: 'application/json',
          extraHeaders: extraHeaders,
        ),
        body: jsonEncode(body),
      );
    }
    final data = _decodeResponse(response);
    if (data is! Map<String, dynamic>) {
      throw BackendApiException('Invalid response from backend.');
    }

    return data;
  }

  Future<bool> _tryRefreshSession() async {
    final refresh = onUnauthorized;
    if (refresh == null) {
      return false;
    }

    try {
      return await refresh();
    } on Exception {
      return false;
    }
  }

  Map<String, String> _adminHeaders(String adminToken) {
    return {'X-FF-Admin-Token': adminToken};
  }

  Map<String, String> _headers({
    String? contentType,
    Map<String, String>? extraHeaders,
  }) {
    final headers = <String, String>{
      if (extraHeaders != null) ...extraHeaders,
    };
    if (contentType != null) {
      headers['Content-Type'] = contentType;
    }

    final token = bearerToken;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  Uri _uri(String path, [Map<String, String>? queryParameters]) {
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    return _baseUrl.replace(
      pathSegments: [
        ..._baseUrl.pathSegments.where((segment) => segment.isNotEmpty),
        ...normalizedPath.split('/').where((segment) => segment.isNotEmpty),
      ],
      queryParameters: queryParameters == null || queryParameters.isEmpty
          ? null
          : queryParameters,
    );
  }

  dynamic _decodeResponse(http.Response response) {
    final body = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    var message = 'Backend request failed.';
    if (body is Map<String, dynamic>) {
      message = body['message']?.toString() ??
          body['error']?.toString() ??
          body['title']?.toString() ??
          message;
    }

    throw BackendApiException(message, statusCode: response.statusCode);
  }

  DateTime? _date(Object? value) {
    if (value == null || value.toString().isEmpty) {
      return null;
    }

    return DateTime.tryParse(value.toString())?.toUtc();
  }
}
