import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'form_entry.dart';
import 'local_db.dart';
import 'models.dart';
import 'user_profile.dart';

class SyncStatus {
  const SyncStatus({
    required this.isSyncing,
    required this.isOnline,
    this.lastSyncAt,
    this.lastError,
  });

  final bool isSyncing;
  final bool isOnline;
  final DateTime? lastSyncAt;
  final String? lastError;

  SyncStatus copyWith({
    bool? isSyncing,
    bool? isOnline,
    DateTime? lastSyncAt,
    String? lastError,
  }) {
    return SyncStatus(
      isSyncing: isSyncing ?? this.isSyncing,
      isOnline: isOnline ?? this.isOnline,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      lastError: lastError,
    );
  }

  static const idle = SyncStatus(isSyncing: false, isOnline: true);
}

class FormTypes {
  static const drilling = 'drilling';
  static const downtime = 'downtime';
  static const consumables = 'consumables';
  static const driverSelection = 'driver_selection';
  static const machineChecklistDrilling = 'machine_checklist_drilling';
  static const machineChecklistLightHeavy = 'machine_checklist_light_heavy';
}

class AppRepository {
  AppRepository({required this.baseUrl})
    : formsNotifier = ValueNotifier<List<FormEntry>>([]),
      syncStatusNotifier = ValueNotifier<SyncStatus>(SyncStatus.idle),
      allowedFormsNotifier = ValueNotifier<Set<String>>(<String>{}),
      profileNotifier = ValueNotifier<UserProfile?>(null);

  final String baseUrl;
  late final Future<LocalDatabase> databaseFuture = LocalDatabase.open();

  late final ApiClient api;
  late final LocalDatabase database;

  final ValueNotifier<List<FormEntry>> formsNotifier;
  final ValueNotifier<SyncStatus> syncStatusNotifier;
  final ValueNotifier<Set<String>> allowedFormsNotifier;
  final ValueNotifier<UserProfile?> profileNotifier;

  Timer? _syncTimer;
  DateTime? _lastNetworkFailureAt;
  bool _isInitialized = false;

  bool get hasSession => _isInitialized && api.hasSession;

  static const _cacheProjects = 'projects';
  static const _cacheConjectures = 'conjectures';
  static const _cacheMachines = 'machines';
  static const _cachePersons = 'persons';
  static const _cacheStopCauses = 'stop_causes';
  static const _cacheStoneTypes = 'stone_types';
  static const _cacheMaterials = 'materials';
  static const _cacheStorages = 'storages';
  static const _cacheCities = 'cities';
  static const _cacheDailyReports = 'daily_reports';
  static const _cacheDailyReportNames = 'daily_report_names';
  static const _cacheAccess = 'access_menu';
  static const _cacheProfile = 'profile';

  static const Map<int, List<String>> formAccessMap = {
    1700: [
      FormTypes.drilling,
      FormTypes.downtime,
      FormTypes.consumables,
      FormTypes.driverSelection,
    ],
    1401: [
      FormTypes.machineChecklistDrilling,
      FormTypes.machineChecklistLightHeavy,
    ],
  };

  Future<void> init() async {
    database = await databaseFuture;
    api = ApiClient(baseUrl: baseUrl, database: database);
    await api.init();
    _isInitialized = true;
    await _loadCachedProfile();
    await _loadRecentForms();
    await _loadCachedAccess();
  }

  void dispose() {
    _syncTimer?.cancel();
  }

  Future<void> loginWithPassword(String phone, String password) async {
    final data = await api.post(
      '/account/login/',
      body: {'phone_number': phone, 'password': password},
      auth: false,
    );
    await _handleLoginResponse(data);
  }

  Future<void> loginWithOtp(String phone, String code) async {
    final data = await api.post(
      '/account/login/code/',
      body: {'phone_number': phone, 'code': code},
      auth: false,
    );
    await _handleLoginResponse(data);
  }

  Future<void> sendOtp(String phone) async {
    await api.post(
      '/account/otp/send/',
      body: {'phone_number': phone},
      auth: false,
    );
  }

  Future<void> resetPassword({
    required String phone,
    required String code,
    required String newPassword,
    required String repeatPassword,
  }) async {
    await api.post(
      '/account/password/reset/',
      body: {
        'phone_number': phone,
        'code': code,
        'new_password': newPassword,
        'new_password_repeat': repeatPassword,
      },
      auth: false,
    );
  }

  Future<void> logout() async {
    final tokens = await database.loadTokens();
    if (tokens != null) {
      await api.post(
        '/account/logout/',
        body: {'refresh': tokens.refresh},
        auth: false,
      );
    }
    await database.saveTokens(const AuthTokens(access: '', refresh: ''));
    profileNotifier.value = null;
  }

  Future<void> syncOnLogin() async {
    await _fetchProfile();
    await _fetchAccessMenu();
    _startSyncTimer();
    // Kick off heavier work in the background to avoid blocking startup.
    unawaited(syncLookups());
    unawaited(syncPendingSubmissions());
  }

  Future<void> syncLookups() async {
    try {
      await Future.wait([
        _fetchProjectsList(),
        _fetchPaginatedList('/conjecture/', _cacheConjectures),
        _fetchPaginatedList('/machine/', _cacheMachines),
        _fetchPaginatedList('/hrs/persons/', _cachePersons),
        _fetchPaginatedList('/daily/report/stop/causes/', _cacheStopCauses),
        _fetchPaginatedList('/daily/report/stone/', _cacheStoneTypes),
        _fetchPaginatedList('/vendoring/materials/', _cacheMaterials),
        _fetchPaginatedList('/vendoring/storages/', _cacheStorages),
        _fetchPaginatedList('/core/cities/', _cacheCities),
      ]);
    } on ApiException catch (error) {
      await logAppEvent(
        'lookups_failed_${error.statusCode ?? 0}: ${error.message}',
      );
      rethrow;
    } catch (_) {
      await logAppEvent('lookups_failed');
      rethrow;
    }
  }

  Future<void> syncProjectLookups() async {
    try {
      await Future.wait([
        _fetchProjectsList(),
        _fetchPaginatedList('/conjecture/', _cacheConjectures),
      ]);
    } on ApiException catch (error) {
      await logAppEvent(
        'projects_lookup_failed_${error.statusCode ?? 0}: ${error.message}',
      );
      rethrow;
    } catch (_) {
      await logAppEvent('projects_lookup_failed');
      rethrow;
    }
  }

  Future<void> syncDrillingLookups() async {
    try {
      await Future.wait([
        _fetchPaginatedList('/conjecture/', _cacheConjectures),
        _fetchPaginatedList('/machine/', _cacheMachines),
        _fetchPaginatedList('/hrs/persons/', _cachePersons),
        _fetchPaginatedList('/daily/report/stone/', _cacheStoneTypes),
      ]);
    } on ApiException catch (error) {
      await logAppEvent(
        'drilling_lookup_failed_${error.statusCode ?? 0}: ${error.message}',
      );
      rethrow;
    } catch (_) {
      await logAppEvent('drilling_lookup_failed');
      rethrow;
    }
  }

  Future<void> syncReportLookups() async {
    try {
      await Future.wait([
        _fetchPaginatedList('/vendoring/materials/', _cacheMaterials),
        _fetchPaginatedList('/daily/report/stop/causes/', _cacheStopCauses),
      ]);
    } on ApiException catch (error) {
      await logAppEvent(
        'report_lookup_failed_${error.statusCode ?? 0}: ${error.message}',
      );
      rethrow;
    } catch (_) {
      await logAppEvent('report_lookup_failed');
      rethrow;
    }
  }

  String _dailyReportNamesCacheKey({int? projectId, int? conjectureId}) {
    final buffer = StringBuffer(_cacheDailyReportNames);
    if (projectId != null) {
      buffer.write('_p$projectId');
    }
    if (conjectureId != null) {
      buffer.write('_c$conjectureId');
    }
    return buffer.toString();
  }

  Future<List<DailyReportNameOption>> getDailyReportNames({
    int? projectId,
    int? conjectureId,
  }) async {
    final cacheKey = _dailyReportNamesCacheKey(
      projectId: projectId,
      conjectureId: conjectureId,
    );
    final data = await database.loadCache(cacheKey);
    final list = _ensureList(data);
    return list.map((item) => DailyReportNameOption.fromJson(item)).toList();
  }

  Future<void> syncDailyReportNames({int? projectId, int? conjectureId}) async {
    final cacheKey = _dailyReportNamesCacheKey(
      projectId: projectId,
      conjectureId: conjectureId,
    );
    if (projectId == null && conjectureId == null) {
      await database.saveCache(cacheKey, const <Map<String, dynamic>>[]);
      return;
    }

    final query = <String, String>{
      if (projectId != null) 'project': projectId.toString(),
      if (conjectureId != null) 'conjecture': conjectureId.toString(),
    };

    final reports = await _fetchPaginated('/daily/report/', query: query);
    final data = reports
        .map((item) => DailyReportOption.fromJson(item))
        .map(
          (report) => <String, dynamic>{
            'id': report.id,
            'name': report.displayName,
            'shift': report.raw['shift'],
            'shift_display':
                report.raw['shift_display'] ?? report.raw['shift_label'],
          },
        )
        .toList(growable: false);
    await database.saveCache(cacheKey, data);
  }

  Future<void> syncConsumablesLookups({
    int? projectId,
    int? conjectureId,
  }) async {
    try {
      await Future.wait([
        syncDailyReportNames(projectId: projectId, conjectureId: conjectureId),
        _fetchPaginatedList('/vendoring/materials/', _cacheMaterials),
        _fetchPaginatedList('/vendoring/storages/', _cacheStorages),
      ]);
    } on ApiException catch (error) {
      await logAppEvent(
        'consumables_lookup_failed_${error.statusCode ?? 0}: ${error.message}',
      );
      rethrow;
    } catch (_) {
      await logAppEvent('consumables_lookup_failed');
      rethrow;
    }
  }

  Future<void> syncDowntimeLookups({int? projectId, int? conjectureId}) async {
    try {
      await Future.wait([
        syncDailyReportNames(projectId: projectId, conjectureId: conjectureId),
        _fetchPaginatedList('/daily/report/stop/causes/', _cacheStopCauses),
      ]);
    } on ApiException catch (error) {
      await logAppEvent(
        'downtime_lookup_failed_${error.statusCode ?? 0}: ${error.message}',
      );
      rethrow;
    } catch (_) {
      await logAppEvent('downtime_lookup_failed');
      rethrow;
    }
  }

  Future<int> addProfileLog(String message) async {
    return database.insertProfileLog(message);
  }

  Future<void> logAppEvent(String message) async {
    await database.insertProfileLog(message);
  }

  Future<List<ProfileLogEntry>> loadProfileLogs() async {
    return database.loadProfileLogs();
  }

  Future<void> queueFormSubmission(FormSubmission submission) async {
    final id = await database.insertFormSubmission(submission);
    await _loadRecentForms();
    await _attemptSubmission(submission, id: id);
  }

  Future<void> syncPendingSubmissions() async {
    if (syncStatusNotifier.value.isSyncing) {
      return;
    }
    syncStatusNotifier.value = syncStatusNotifier.value.copyWith(
      isSyncing: true,
      lastError: null,
    );
    final hasNetwork = await _probeNetwork();
    if (!hasNetwork) {
      _lastNetworkFailureAt ??= DateTime.now();
      final elapsed = DateTime.now().difference(_lastNetworkFailureAt!);
      if (elapsed >= const Duration(minutes: 1)) {
        syncStatusNotifier.value = syncStatusNotifier.value.copyWith(
          isSyncing: false,
          isOnline: false,
          lastError: 'network_unavailable',
        );
      } else {
        syncStatusNotifier.value = syncStatusNotifier.value.copyWith(
          isSyncing: false,
        );
      }
      return;
    }
    _lastNetworkFailureAt = null;
    final pending = await database.loadFormSubmissions(
      statuses: ['pending', 'failed'],
    );
    final drillConjecturesToRefresh = <int>{};
    var isOnline = true;
    for (final submission in pending) {
      final id = submission.id;
      if (id == null) {
        continue;
      }
      try {
        await _sendSubmission(submission);
        await database.updateFormSubmission(id, status: 'sent');
        final conjectureId = _extractDrillingConjectureId(submission);
        if (conjectureId != null) {
          drillConjecturesToRefresh.add(conjectureId);
        }
      } on ApiException catch (error) {
        if (error.isNetwork) {
          isOnline = false;
          await logAppEvent('sync: network_unavailable');
          break;
        }
        final status = _isConflictStatus(error.statusCode)
            ? 'conflict'
            : 'failed';
        await logAppEvent(
          'sync: submission_${status}_${error.statusCode ?? 0}',
        );
        await database.updateFormSubmission(
          id,
          status: status,
          lastError: _formatSubmissionError(error),
        );
      } catch (error) {
        await logAppEvent('sync: submission_failed');
        await database.updateFormSubmission(
          id,
          status: 'failed',
          lastError: error.toString(),
        );
      }
    }
    for (final conjectureId in drillConjecturesToRefresh) {
      try {
        await _refreshDailyReportNameCachesForConjecture(conjectureId);
      } catch (error) {
        unawaited(logAppEvent('daily_report_names_refresh_failed: $error'));
      }
    }
    await _loadRecentForms();
    syncStatusNotifier.value = syncStatusNotifier.value.copyWith(
      isSyncing: false,
      isOnline: isOnline,
      lastSyncAt: DateTime.now(),
    );
  }

  Future<void> resyncNow() async {
    if (syncStatusNotifier.value.isSyncing) {
      return;
    }
    final hasNetwork = await _probeNetwork();
    if (!hasNetwork) {
      syncStatusNotifier.value = syncStatusNotifier.value.copyWith(
        isOnline: false,
        lastError: 'network_unavailable',
      );
      return;
    }
    await database.deleteCacheByPrefix(_cacheDailyReportNames);
    await syncPendingSubmissions();
    try {
      await syncLookups();
    } catch (error) {
      unawaited(logAppEvent('resync: lookups_failed: $error'));
    }
  }

  String _formatSubmissionError(ApiException error) {
    final code = error.statusCode;
    if (code != null) {
      return 'HTTP $code';
    }
    return error.message;
  }

  bool _isOngoingProject(ProjectOption project) {
    final raw = project.raw;
    final stateValue =
        raw['project_state'] ?? raw['project_status'] ?? raw['state'];
    final state = int.tryParse(stateValue?.toString() ?? '');
    if (state != null && state != 30) {
      return false;
    }
    return true;
  }

  Future<List<ProjectOption>> getProjects() async {
    final data = await database.loadCache(_cacheProjects);
    final list = _ensureList(data);
    final projects = list.map((item) => ProjectOption.fromJson(item)).toList();
    return projects.where(_isOngoingProject).toList();
  }

  Future<List<ConjectureOption>> getConjectures() async {
    final data = await database.loadCache(_cacheConjectures);
    final list = _ensureList(data);
    return list.map((item) => ConjectureOption.fromJson(item)).toList();
  }

  Future<List<MachineOption>> getMachines() async {
    final data = await database.loadCache(_cacheMachines);
    final list = _ensureList(data);
    return list.map((item) => MachineOption.fromJson(item)).toList();
  }

  Future<List<PersonOption>> getPersons() async {
    final data = await database.loadCache(_cachePersons);
    final list = _ensureList(data);
    return list.map((item) => PersonOption.fromJson(item)).toList();
  }

  Future<List<StopCauseOption>> getStopCauses() async {
    final data = await database.loadCache(_cacheStopCauses);
    final list = _ensureList(data);
    return list.map((item) => StopCauseOption.fromJson(item)).toList();
  }

  Future<List<StoneTypeOption>> getStoneTypes() async {
    final data = await database.loadCache(_cacheStoneTypes);
    final list = _ensureList(data);
    return list.map((item) => StoneTypeOption.fromJson(item)).toList();
  }

  Future<List<MaterialOption>> getMaterials() async {
    final data = await database.loadCache(_cacheMaterials);
    final list = _ensureList(data);
    return list.map((item) => MaterialOption.fromJson(item)).toList();
  }

  Future<List<StorageOption>> getStorages() async {
    final data = await database.loadCache(_cacheStorages);
    final list = _ensureList(data);
    return list.map((item) => StorageOption.fromJson(item)).toList();
  }

  Future<List<CityOption>> getCities() async {
    final data = await database.loadCache(_cacheCities);
    final list = _ensureList(data);
    return list.map((item) => CityOption.fromJson(item)).toList();
  }

  Future<List<DailyReportOption>> getDailyReports() async {
    final data = await database.loadCache(_cacheDailyReports);
    final list = _ensureList(data);
    return list.map((item) => DailyReportOption.fromJson(item)).toList();
  }

  Future<List<ChecklistOption>> getChecklistsForMachineType(
    int machineType,
  ) async {
    final cacheKey = 'checklists_$machineType';
    final cached = await database.loadCache(cacheKey);
    if (cached != null) {
      final list = _ensureList(cached);
      return list.map((item) => ChecklistOption.fromJson(item)).toList();
    }
    final data = await _fetchPaginated(
      '/machine/checklist/',
      query: {'machine_type': machineType.toString()},
    );
    await database.saveCache(cacheKey, data);
    return data.map((item) => ChecklistOption.fromJson(item)).toList();
  }

  Future<List<FormEntry>> _loadRecentForms() async {
    final cutoff = DateTime.now().subtract(const Duration(days: 15));
    await database.deleteOldSubmissions(cutoff);
    final submissions = await database.loadFormSubmissions(since: cutoff);
    final forms = submissions.map(_mapSubmissionToFormEntry).toList();
    formsNotifier.value = forms;
    return forms;
  }

  FormEntry _mapSubmissionToFormEntry(FormSubmission submission) {
    final status = switch (submission.status) {
      'sent' => FormStatus.approved,
      'conflict' => FormStatus.needsRevision,
      'failed' => FormStatus.error,
      _ => FormStatus.pending,
    };
    final onlineAt = submission.status == 'sent'
        ? submission.updatedAt
        : submission.createdAt;
    final id = submission.remoteId ?? submission.id ?? 0;
    return FormEntry(
      id: id,
      localId: submission.id,
      title: submission.title,
      description: submission.description,
      formType: submission.formType,
      payload: submission.payload,
      offlineSubmittedAt: submission.createdAt,
      onlineSubmittedAt: onlineAt,
      status: status,
      lastError: submission.lastError,
    );
  }

  Future<void> _handleLoginResponse(dynamic data) async {
    if (data is! Map) {
      throw ApiException('Invalid login response');
    }
    final access = data['access']?.toString();
    final refresh = data['refresh']?.toString();
    if (access == null || refresh == null) {
      throw ApiException('Missing tokens');
    }
    await api.saveTokens(AuthTokens(access: access, refresh: refresh));
  }

  Future<void> _fetchProfile() async {
    final data = await api.get('/account/profile/');
    if (data is! Map) {
      return;
    }
    final id = data['id'] as int? ?? 0;
    final firstName = data['first_name']?.toString() ?? '';
    final lastName = data['last_name']?.toString() ?? '';
    final fullName = ('$firstName $lastName').trim().isEmpty
        ? 'کاربر'
        : ('$firstName $lastName').trim();
    final role = data['user_type_display']?.toString() ?? 'کاربر سامانه';
    final email = data['email']?.toString() ?? '';
    final phone = data['phone_number']?.toString() ?? '';
    profileNotifier.value = UserProfile(
      id: id,
      fullName: fullName,
      role: role,
      email: email,
      phone: phone,
    );
    await database.saveCache(
      _cacheProfile,
      profileNotifier.value?.toJson() ?? {},
    );
  }

  Future<void> _loadCachedProfile() async {
    final data = await database.loadCache(_cacheProfile);
    if (data is Map) {
      profileNotifier.value = UserProfile.fromJson(
        Map<String, dynamic>.from(data),
      );
    }
  }

  Future<void> _fetchAccessMenu() async {
    final data = await api.get('/account/menu/');
    await database.saveCache(_cacheAccess, data ?? []);
    final allowed = _resolveAllowedForms(data);
    allowedFormsNotifier.value = allowed;
  }

  Future<void> _loadCachedAccess() async {
    final data = await database.loadCache(_cacheAccess);
    if (data == null) {
      return;
    }
    allowedFormsNotifier.value = _resolveAllowedForms(data);
  }

  Set<String> _resolveAllowedForms(dynamic data) {
    if (formAccessMap.isEmpty) {
      return <String>{};
    }
    final list = _ensureList(data);
    final allowed = <String>{};
    for (final item in list) {
      final formId = item['form'] as int?;
      if (formId == null) {
        continue;
      }
      final keys = formAccessMap[formId];
      if (keys != null) {
        allowed.addAll(keys);
      }
    }
    return allowed;
  }

  void _startSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      syncPendingSubmissions();
    });
  }

  Future<void> _attemptSubmission(
    FormSubmission submission, {
    required int id,
  }) async {
    try {
      await _sendSubmission(submission);
      await database.updateFormSubmission(id, status: 'sent');
      final conjectureId = _extractDrillingConjectureId(submission);
      if (conjectureId != null) {
        try {
          await _refreshDailyReportNameCachesForConjecture(conjectureId);
        } catch (error) {
          unawaited(logAppEvent('daily_report_names_refresh_failed: $error'));
        }
      }
    } on ApiException catch (error) {
      if (error.isNetwork) {
        _lastNetworkFailureAt ??= DateTime.now();
        await logAppEvent('submit: network_unavailable');
        await database.updateFormSubmission(id, status: 'pending');
        syncStatusNotifier.value = syncStatusNotifier.value.copyWith(
          isOnline: false,
          lastError: error.message,
        );
      } else {
        final status = _isConflictStatus(error.statusCode)
            ? 'conflict'
            : 'failed';
        await logAppEvent(
          'submit: ${submission.formType}_${status}_${error.statusCode ?? 0}',
        );
        await database.updateFormSubmission(
          id,
          status: status,
          lastError: _formatSubmissionError(error),
        );
      }
    } catch (error) {
      await logAppEvent('submit: ${submission.formType}_failed');
    }
    await _loadRecentForms();
  }

  bool _isConflictStatus(int? statusCode) {
    return statusCode == 400 || statusCode == 404;
  }

  Future<void> retrySubmission(int id) async {
    final submission = await database.loadFormSubmission(id);
    if (submission == null) {
      return;
    }
    await _attemptSubmission(submission, id: id);
  }

  Future<void> deleteSubmission(int id) async {
    await database.deleteFormSubmission(id);
    await _loadRecentForms();
  }

  Future<bool> _probeNetwork() async {
    try {
      final host = Uri.parse(baseUrl).host;
      if (host.isEmpty) {
        return false;
      }
      final result = await InternetAddress.lookup(
        host,
      ).timeout(const Duration(seconds: 5));
      return result.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _sendSubmission(FormSubmission submission) async {
    final createdAt = submission.createdAt.toIso8601String();
    final updatedAt = submission.updatedAt.toIso8601String();
    final payload = Map<String, dynamic>.from(submission.payload);
    switch (submission.formType) {
      case FormTypes.drilling:
        final reportPayload = Map<String, dynamic>.from(
          payload['report'] as Map,
        );
        reportPayload['created_at'] ??= createdAt;
        reportPayload['modified_at'] ??= updatedAt;
        final reportResponse = await api.post(
          '/daily/report/',
          body: reportPayload,
        );
        final reportId = _extractId(reportResponse);
        final runs = (payload['runs'] as List?) ?? [];
        for (final item in runs) {
          final runPayload = Map<String, dynamic>.from(item as Map);
          runPayload['report'] = reportId;
          runPayload['created_at'] ??= createdAt;
          runPayload['modified_at'] ??= updatedAt;
          await api.post('/daily/report/runs/', body: runPayload);
        }
        break;
      case FormTypes.downtime:
        payload['created_at'] ??= createdAt;
        payload['modified_at'] ??= updatedAt;
        await api.post('/daily/report/stops/', body: payload);
        break;
      case FormTypes.consumables:
        payload['created_at'] ??= createdAt;
        payload['modified_at'] ??= updatedAt;
        await api.post('/daily/report/materials/', body: payload);
        break;
      case FormTypes.driverSelection:
        payload['created_at'] ??= createdAt;
        payload['modified_at'] ??= updatedAt;
        await api.post('/daily/report/drivers/', body: payload);
        break;
      case FormTypes.machineChecklistDrilling:
      case FormTypes.machineChecklistLightHeavy:
        final reportPayload = Map<String, dynamic>.from(
          payload['report'] as Map,
        );
        reportPayload['created_at'] ??= createdAt;
        reportPayload['modified_at'] ??= updatedAt;
        final reportResponse = await api.post(
          '/machine/daily/reports/',
          body: reportPayload,
        );
        final reportId = _extractId(reportResponse);
        final items = (payload['items'] as List?) ?? [];
        final bulkPayload = {'report': reportId, 'items': items};
        await api.post(
          '/machine/daily/report/checklists/bulk/',
          body: bulkPayload,
        );
        break;
      default:
        throw ApiException('Unknown form type: ${submission.formType}');
    }
  }

  int? _extractDrillingConjectureId(FormSubmission submission) {
    if (submission.formType != FormTypes.drilling) {
      return null;
    }
    final report = submission.payload['report'];
    if (report is Map) {
      final raw = Map<String, dynamic>.from(report);
      return _coerceId(
        raw['conjecture'] ?? raw['conjecture_id'] ?? raw['conjectureId'],
      );
    }
    return null;
  }

  int? _coerceId(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      return _coerceId(map['id'] ?? map['pk'] ?? map['value']);
    }
    return null;
  }

  Future<int?> _projectIdForConjecture(int conjectureId) async {
    final data = await database.loadCache(_cacheConjectures);
    final list = _ensureList(data);
    for (final item in list) {
      final id = _coerceId(item['id']);
      if (id == conjectureId) {
        return _coerceId(
          item['project'] ?? item['project_id'] ?? item['projectId'],
        );
      }
    }
    return null;
  }

  Future<void> _refreshDailyReportNameCachesForConjecture(
    int conjectureId,
  ) async {
    final projectId = await _projectIdForConjecture(conjectureId);
    final futures = <Future<void>>[
      syncDailyReportNames(conjectureId: conjectureId),
    ];
    if (projectId != null) {
      futures.add(
        syncDailyReportNames(projectId: projectId, conjectureId: conjectureId),
      );
    }
    await Future.wait(futures);
  }

  int _extractId(dynamic data) {
    if (data is Map && data['id'] is int) {
      return data['id'] as int;
    }
    if (data is Map && data['id'] != null) {
      return int.tryParse(data['id'].toString()) ?? 0;
    }
    return 0;
  }

  Future<void> _fetchPaginatedList(String path, String cacheKey) async {
    try {
      final data = await _fetchPaginated(path);
      await database.saveCache(cacheKey, data);
    } on ApiException catch (error) {
      unawaited(
        logAppEvent(
          'lookup: $path failed_${error.statusCode ?? 0}: ${error.message}',
        ),
      );
      rethrow;
    }
  }

  Future<void> _fetchProjectsList() async {
    unawaited(logAppEvent('projects: fetch_start'));
    List<Map<String, dynamic>> data = [];
    ApiException? firstError;
    try {
      data = await _fetchPaginated('/project/list/');
    } on ApiException catch (error) {
      firstError = error;
      unawaited(
        logAppEvent(
          'projects: /project/list failed_${error.statusCode ?? 0}: ${error.message}',
        ),
      );
    }
    if (data.isEmpty) {
      try {
        data = await _fetchPaginated('/project/');
      } on ApiException catch (error) {
        unawaited(
          logAppEvent(
            'projects: /project failed_${error.statusCode ?? 0}: ${error.message}',
          ),
        );
        if (firstError != null) {
          throw firstError;
        }
        rethrow;
      }
    }
    if (data.isEmpty && firstError != null) {
      throw firstError;
    }
    unawaited(logAppEvent('projects: fetched_${data.length}'));
    await database.saveCache(_cacheProjects, data);
  }

  Future<List<Map<String, dynamic>>> _fetchPaginated(
    String path, {
    Map<String, String>? query,
  }) async {
    final aggregated = <Map<String, dynamic>>[];
    var page = 1;
    String? next;
    do {
      final response = await api.get(
        path,
        query: {
          'page': page.toString(),
          'page_size': '200',
          if (query != null) ...query,
        },
      );
      if (response is Map && response['results'] is List) {
        final results = List<Map<String, dynamic>>.from(
          response['results'] as List,
        );
        aggregated.addAll(results);
        next = response['next']?.toString();
        page += 1;
      } else if (response is List) {
        aggregated.addAll(List<Map<String, dynamic>>.from(response));
        next = null;
      } else {
        next = null;
      }
    } while (next != null && next.isNotEmpty);
    return aggregated;
  }

  List<Map<String, dynamic>> _ensureList(dynamic data) {
    if (data is Map && data['results'] is List) {
      return List<Map<String, dynamic>>.from(data['results'] as List);
    }
    if (data is List) {
      return List<Map<String, dynamic>>.from(data);
    }
    return <Map<String, dynamic>>[];
  }
}
