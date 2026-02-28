import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:workmanager/workmanager.dart';

import 'data/form_entry.dart';
import 'data/models.dart';
import 'data/api_client.dart';
import 'data/repository.dart';
import 'data/user_profile.dart';
import 'services/gauge_ocr_service.dart';
import 'services/screen_processor.dart';

part 'native_forms_part.dart';
part 'native_forms_machine_part.dart';
part 'native_forms_storage_part.dart';
part 'native_forms_storage_graph_part.dart';
part 'form_select_launchers_part.dart';

late final AppRepository appRepository;

const String _backgroundSyncTask = 'backgroundSyncTask';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    final repository = AppRepository(baseUrl: 'https://api.felezyaban.com');
    await repository.init();
    if (!repository.hasSession) {
      return Future.value(true);
    }
    try {
      await repository.syncLookups();
      await repository.syncPendingSubmissions();
    } catch (error) {
      unawaited(repository.logAppEvent('background_sync_failed: $error'));
    }
    return Future.value(true);
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  appRepository = AppRepository(baseUrl: 'https://api.felezyaban.com');
  await appRepository.init();
  await Workmanager().initialize(callbackDispatcher);
  await Workmanager().registerPeriodicTask(
    'backgroundSync',
    _backgroundSyncTask,
    frequency: const Duration(minutes: 15),
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );
  runApp(FelezyabanApp(repository: appRepository));
}

class FelezyabanApp extends StatefulWidget {
  const FelezyabanApp({super.key, required this.repository});

  final AppRepository repository;

  @override
  State<FelezyabanApp> createState() => _FelezyabanAppState();
}

class _FelezyabanAppState extends State<FelezyabanApp> {
  late bool _isLoggedIn;
  ThemeMode _themeMode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    _isLoggedIn = widget.repository.hasSession;
    if (_isLoggedIn) {
      widget.repository.syncOnLogin();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title:
          '\u0641\u0644\u0632\u06cc\u0627\u0628\u0627\u0646 \u06a9\u0648\u06cc\u0631',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
        fontFamily: 'Estedad',
        fontFamilyFallback: const ['Tahoma', 'sans-serif'],
        iconTheme: const IconThemeData(size: 30),
        appBarTheme: const AppBarTheme(iconTheme: IconThemeData(size: 30)),
        inputDecorationTheme: const InputDecorationTheme(),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'Estedad',
        fontFamilyFallback: const ['Tahoma', 'sans-serif'],
        iconTheme: const IconThemeData(size: 30, color: Colors.white),
        appBarTheme: const AppBarTheme(
          iconTheme: IconThemeData(size: 30, color: Colors.white),
          foregroundColor: Colors.white,
        ),
      ),
      themeMode: _themeMode,
      locale: const Locale('fa', 'IR'),
      supportedLocales: const [Locale('fa', 'IR'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => DefaultTextStyle(
        style: DefaultTextStyle.of(context).style,
        textAlign: TextAlign.justify,
        child: child ?? const SizedBox.shrink(),
      ),
      home: _isLoggedIn
          ? HomeShell(
              onLogout: _handleLogout,
              onToggleTheme: _toggleThemeMode,
              themeMode: _themeMode,
              repository: widget.repository,
            )
          : LoginPage(
              onLoginSuccess: _handleLoginSuccess,
              repository: widget.repository,
            ),
    );
  }

  void _handleLoginSuccess() {
    setState(() {
      _isLoggedIn = true;
    });
    unawaited(widget.repository.syncOnLogin());
  }

  void _handleLogout() {
    setState(() {
      _isLoggedIn = false;
    });
  }

  void _toggleThemeMode() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light
          ? ThemeMode.dark
          : ThemeMode.light;
    });
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.onLogout,
    required this.onToggleTheme,
    required this.themeMode,
    required this.repository,
  });

  final VoidCallback onLogout;
  final VoidCallback onToggleTheme;
  final ThemeMode themeMode;
  final AppRepository repository;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late UserProfile _profile;
  late final VoidCallback _profileListener;
  final GlobalKey<_FormsPageState> _formsPageKey = GlobalKey<_FormsPageState>();

  final List<DashboardNotification> _notifications = [
    DashboardNotification(
      message: 'اعلان امنیتی جدید ثبت شد.',
      isRead: false,
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
    ),
    DashboardNotification(
      message: 'به‌روزرسانی نرم‌افزار آماده نصب است.',
      isRead: false,
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    DashboardNotification(
      message: 'کاربر جدیدی به سامانه افزوده شد.',
      isRead: true,
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfilePage(
          profile: _profile,
          repository: widget.repository,
          onLogout: widget.onLogout,
        ),
      ),
    );
  }

  void markNotificationRead(int index) {
    if (index < 0 || index >= _notifications.length) {
      return;
    }
    setState(() {
      _notifications[index].isRead = true;
    });
  }

  List<NotificationEntry> sortedNotificationEntries() {
    final entries = List.generate(
      _notifications.length,
      (index) =>
          NotificationEntry(index: index, notification: _notifications[index]),
    );
    entries.sort((a, b) {
      if (a.notification.isRead != b.notification.isRead) {
        return a.notification.isRead ? 1 : -1;
      }
      return b.notification.timestamp.compareTo(a.notification.timestamp);
    });
    return entries;
  }

  void _showHomeInfo() {
    final theme = Theme.of(context);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('راهنمای صفحه خانه'),
        content: SingleChildScrollView(
          child: Text(
            'فرم‌ها ابتدا به صورت آفلاین ذخیره می‌شوند و سپس هنگام اتصال ارسال خواهند شد.\n'
            'وضعیت‌ها:\n'
            '• در انتظار اتصال به شبکه: فرم ذخیره شده و منتظر اتصال است.\n'
            '• ارسال شده به مخزن داده: فرم با موفقیت به سرور ارسال شده است.\n'
            '• نیاز به اصلاح: فرم ارسال شده اما نیاز به ویرایش دارد.\n'
            '• \u062e\u0637\u0627 \u062f\u0631 \u0627\u0631\u0633\u0627\u0644 \u0628\u0647 \u0633\u0631\u0648\u0631: \u0627\u0631\u0633\u0627\u0644 \u0627\u0646\u062c\u0627\u0645 \u0634\u062f\u0647 \u0627\u0645\u0627 \u067e\u0627\u0633\u062e \u0645\u0648\u0641\u0642 \u062f\u0631\u06cc\u0627\u0641\u062a \u0646\u0634\u062f\u0647 \u0627\u0633\u062a.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('متوجه شدم'),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _profile =
        widget.repository.profileNotifier.value ??
        const UserProfile(
          id: 0,
          fullName: 'کاربر سامانه',
          role: 'کاربر سامانه',
          email: '',
          phone: '',
        );
    _profileListener = () {
      final profile = widget.repository.profileNotifier.value;
      if (profile != null && mounted) {
        setState(() => _profile = profile);
      }
    };
    widget.repository.profileNotifier.addListener(_profileListener);
  }

  @override
  void dispose() {
    widget.repository.profileNotifier.removeListener(_profileListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('فرم‌ها'),
          centerTitle: true,
          leading: IconButton(
            icon: Icon(
              widget.themeMode == ThemeMode.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
              size: 32,
            ),
            tooltip: 'تغییر تم',
            onPressed: widget.onToggleTheme,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline, size: 28),
              tooltip: 'راهنما',
              onPressed: _showHomeInfo,
            ),
            ValueListenableBuilder<SyncStatus>(
              valueListenable: widget.repository.syncStatusNotifier,
              builder: (context, status, _) {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                final onlineColor = isDark
                    ? Colors.greenAccent.shade200
                    : Colors.green;
                final offlineColor = isDark
                    ? Colors.redAccent.shade100
                    : Colors.red;
                if (status.isSyncing) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }
                final icon = status.isOnline
                    ? Icons.cloud_done_outlined
                    : Icons.cloud_off_outlined;
                final tooltip = status.isOnline
                    ? 'اتصال برقرار است'
                    : 'آفلاین - در انتظار اتصال';
                return IconButton(
                  icon: Icon(
                    icon,
                    size: 28,
                    color: status.isOnline ? onlineColor : offlineColor,
                  ),
                  tooltip: tooltip,
                  onPressed: widget.repository.syncPendingSubmissions,
                );
              },
            ),
            ValueListenableBuilder<SyncStatus>(
              valueListenable: widget.repository.syncStatusNotifier,
              builder: (context, status, _) {
                return IconButton(
                  icon: const Icon(Icons.sync, size: 28),
                  tooltip:
                      '\u0647\u0645\u06af\u0627\u0645\u200c\u0633\u0627\u0632\u06cc \u0645\u062c\u062f\u062f',
                  onPressed: status.isSyncing
                      ? null
                      : widget.repository.resyncNow,
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.person_outline, size: 32),
              tooltip: 'پروفایل',
              onPressed: _openProfile,
            ),
          ],
        ),
        body: ValueListenableBuilder<List<FormEntry>>(
          valueListenable: widget.repository.formsNotifier,
          builder: (context, forms, _) {
            return ValueListenableBuilder<Set<String>>(
              valueListenable: widget.repository.allowedFormsNotifier,
              builder: (context, allowed, _) {
                return FormsPage(
                  key: _formsPageKey,
                  forms: forms,
                  allowedForms: allowed,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({
    super.key,
    required this.userFullName,
    required this.notificationEntries,
    required this.onNotificationTap,
    required this.latestForm,
  });

  final String userFullName;
  final List<NotificationEntry> notificationEntries;
  final ValueChanged<int> onNotificationTap;
  final FormEntry latestForm;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final jalali = Jalali.fromDateTime(now);
    final dayName = _normalizeDayName(jalali.formatter.wN);
    final rawTime =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final rawDate =
        '$dayName ${jalali.formatter.d} ${jalali.formatter.mN} ${jalali.year}';
    final timeText = _toPersianDigits(rawTime);
    final dateText = _toPersianDigits(rawDate);
    final latestNotifications = notificationEntries
        .take(3)
        .toList(growable: false);

    return ListView(
      padding: _pagePadding(context),
      children: [
        Text(
          'خوش آمدید، $userFullName',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        Text(
          _toPersianDigits('$dateText - ساعت $timeText'),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        Text('آخرین اعلان‌ها', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...List.generate(
          latestNotifications.length,
          (index) => _DashboardNotificationTile(
            notification: latestNotifications[index].notification,
            onTap: () => onNotificationTap(latestNotifications[index].index),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'آخرین فرم ثبت شده',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        _LatestFormCard(form: latestForm),
      ],
    );
  }
}

class _DashboardNotificationTile extends StatelessWidget {
  const _DashboardNotificationTile({
    required this.notification,
    required this.onTap,
  });

  final DashboardNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tagText = notification.isRead ? 'خوانده شده' : 'خوانده نشده';
    final tagColor = notification.isRead
        ? theme.colorScheme.primary
        : Colors.orange;
    final timestamp = _formatJalali(notification.timestamp);

    return Opacity(
      opacity: notification.isRead ? 0.5 : 1,
      child: Card(
        child: ListTile(
          leading: Icon(
            notification.isRead
                ? Icons.notifications_outlined
                : Icons.notifications_active,
            color: tagColor,
          ),
          title: Text(_toPersianDigits(notification.message)),
          subtitle: Text(
            timestamp,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: tagColor.withAlpha(38),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              tagText,
              style: theme.textTheme.bodySmall?.copyWith(color: tagColor),
            ),
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}

class _LatestFormCard extends StatelessWidget {
  const _LatestFormCard({required this.form});

  final FormEntry form;

  @override
  Widget build(BuildContext context) {
    final jalali = Jalali.fromDateTime(form.onlineSubmittedAt);
    final dayName = _normalizeDayName(jalali.formatter.wN);
    final time =
        '${form.onlineSubmittedAt.hour.toString().padLeft(2, '0')}:${form.onlineSubmittedAt.minute.toString().padLeft(2, '0')}';
    final dateText =
        '$dayName، ${jalali.formatter.d} ${jalali.formatter.mN} ${jalali.year}';
    final subtitle = _toPersianDigits(
      '${form.description}\n$dateText - ساعت $time',
    );

    return Card(
      child: ListTile(
        leading: const Icon(Icons.article_outlined, size: 32),
        title: Text(form.title),
        subtitle: Text(subtitle),
        isThreeLine: true,
        trailing: _StatusChip(status: form.status),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => FormDetailPage(form: form)),
          );
        },
      ),
    );
  }
}

class FormsPage extends StatefulWidget {
  const FormsPage({super.key, required this.forms, required this.allowedForms});

  final List<FormEntry> forms;
  final Set<String> allowedForms;

  @override
  State<FormsPage> createState() => _FormsPageState();
}

class _FormsPageState extends State<FormsPage> with _FormFieldMixin {
  static const String _misBaseUrl = 'https://mis.felezyaban.com';

  bool _showAll = false;
  bool _isLoadingLookups = false;
  String? _lookupError;
  SelectionOption? _selectedProject;
  SelectionOption? _selectedDrillingProject;
  SelectionOption? _selectedDrillingMachine;
  SelectionOption? _selectedLightHeavyMachine;
  List<ProjectOption> _projects = [];
  List<MachineOption> _machines = [];
  bool _lookupsRequested = false;
  bool _lookupsLoaded = false;
  Set<String> _lastAllowedForms = const <String>{};
  List<_NewFormItem> _cachedSortedForms = const <_NewFormItem>[];
  bool _sortDirty = true;
  late final List<_NewFormItem> _newFormItems = [
    _NewFormItem(
      title: 'ایجاد گمانه',
      order: 0,
      isProjectForm: true,
      section: _FormSection.drilling,
      icon: Icons.construction_outlined,
      builder: (_) => NativeConjectureCreatePage(
        initialProjectId: _selectedDrillingProject?.id,
        initialProjectTitle: _selectedDrillingProject?.title,
      ),
    ),
    _NewFormItem(
      title: 'گزارش روزانه حفاری',
      order: 1,
      isProjectForm: true,
      section: _FormSection.drilling,
      selectionRequirement: _FormSelectionRequirement.project,
      icon: Icons.assignment_outlined,
      builder: (_) =>
          DrillingFormPage(selectedProjectId: _selectedDrillingProject?.id),
    ),
    _NewFormItem(
      title: 'هزینه‌کرد روزانه',
      order: 2,
      isProjectForm: true,
      section: _FormSection.drilling,
      icon: Icons.payments_outlined,
      builder: (_) =>
          ConsumablesFormPage(selectedProjectId: _selectedDrillingProject?.id),
    ),
    _NewFormItem(
      title: 'توقفات روزانه',
      order: 3,
      isProjectForm: true,
      section: _FormSection.drilling,
      selectionRequirement: _FormSelectionRequirement.project,
      icon: Icons.pause_circle_outline,
      builder: (_) =>
          DowntimeFormPage(selectedProjectId: _selectedDrillingProject?.id),
    ),
    _NewFormItem(
      title: 'سرویس دوره‌ای ماشین حفاری',
      order: 10,
      isProjectForm: false,
      section: _FormSection.machinery,
      icon: Icons.miscellaneous_services_outlined,
      builder: (_) => _MachineSelectionLauncherPage(
        formTitle: 'سرویس دوره‌ای ماشین حفاری',
        category: _MachineSelectorCategory.drilling,
        initialProjectId: _selectedProject?.id,
        initialMachineId: _selectedDrillingMachine?.id,
        formBuilder: (machine, _) => MachinePeriodicServiceNativePage(
          machineId: machine.id,
          machineTitle: machine.displayName,
        ),
      ),
    ),
    _NewFormItem(
      title: 'صورتجلسه تحویل ماشین حفاری',
      order: 11,
      isProjectForm: false,
      section: _FormSection.machinery,
      icon: Icons.local_shipping_outlined,
      builder: (_) => _MachineSelectionLauncherPage(
        formTitle: 'صورتجلسه تحویل ماشین حفاری',
        category: _MachineSelectorCategory.drilling,
        initialProjectId: _selectedProject?.id,
        initialMachineId: _selectedDrillingMachine?.id,
        formBuilder: (machine, project) => MachineDeliveryNativePage(
          machineId: machine.id,
          machineTitle: machine.displayName,
          initialProjectId: project?.id,
        ),
      ),
    ),
    _NewFormItem(
      title: 'درخواست تعمیر ماشین حفاری',
      order: 12,
      isProjectForm: false,
      section: _FormSection.machinery,
      icon: Icons.build_outlined,
      builder: (_) => _MachineSelectionLauncherPage(
        formTitle: 'درخواست تعمیر ماشین حفاری',
        category: _MachineSelectorCategory.drilling,
        initialProjectId: _selectedProject?.id,
        initialMachineId: _selectedDrillingMachine?.id,
        formBuilder: (machine, _) => MachineRepairRequestNativePage(
          machineId: machine.id,
          machineTitle: machine.displayName,
        ),
      ),
    ),
    _NewFormItem(
      title: 'چک لیست روزانه ماشین حفاری',
      order: 4,
      isProjectForm: false,
      section: _FormSection.drilling,
      icon: Icons.fact_check_outlined,
      builder: (_) => const DrillingChecklistFormPage(),
    ),
    _NewFormItem(
      title: 'سرویس دوره‌ای ماشین سبک و سنگین',
      order: 14,
      isProjectForm: false,
      section: _FormSection.machinery,
      icon: Icons.car_repair_outlined,
      builder: (_) => _MachineSelectionLauncherPage(
        formTitle: 'سرویس دوره‌ای ماشین سبک و سنگین',
        category: _MachineSelectorCategory.lightHeavy,
        initialProjectId: _selectedProject?.id,
        initialMachineId: _selectedLightHeavyMachine?.id,
        formBuilder: (machine, _) => MachinePeriodicServiceNativePage(
          machineId: machine.id,
          machineTitle: machine.displayName,
        ),
      ),
    ),
    _NewFormItem(
      title: 'صورتجلسه تحویل ماشین سبک و سنگین',
      order: 15,
      isProjectForm: false,
      section: _FormSection.machinery,
      icon: Icons.move_to_inbox_outlined,
      builder: (_) => _MachineSelectionLauncherPage(
        formTitle: 'صورتجلسه تحویل ماشین سبک و سنگین',
        category: _MachineSelectorCategory.lightHeavy,
        initialProjectId: _selectedProject?.id,
        initialMachineId: _selectedLightHeavyMachine?.id,
        formBuilder: (machine, project) => MachineDeliveryNativePage(
          machineId: machine.id,
          machineTitle: machine.displayName,
          initialProjectId: project?.id,
        ),
      ),
    ),
    _NewFormItem(
      title: 'درخواست تعمیر ماشین سبک و سنگین',
      order: 16,
      isProjectForm: false,
      section: _FormSection.machinery,
      icon: Icons.handyman_outlined,
      builder: (_) => _MachineSelectionLauncherPage(
        formTitle: 'درخواست تعمیر ماشین سبک و سنگین',
        category: _MachineSelectorCategory.lightHeavy,
        initialProjectId: _selectedProject?.id,
        initialMachineId: _selectedLightHeavyMachine?.id,
        formBuilder: (machine, _) => MachineRepairRequestNativePage(
          machineId: machine.id,
          machineTitle: machine.displayName,
        ),
      ),
    ),
    _NewFormItem(
      title: 'چک لیست روزانه ماشین سبک و سنگین',
      order: 17,
      isProjectForm: false,
      section: _FormSection.machinery,
      icon: Icons.checklist_rtl_outlined,
      builder: (_) => VehicleInspectionFormPage(
        initialMachineId: _selectedLightHeavyMachine?.id,
      ),
    ),
    _NewFormItem(
      title: 'ثبت راننده',
      order: 18,
      isProjectForm: false,
      section: _FormSection.machinery,
      icon: Icons.directions_car_filled_outlined,
      builder: (_) => VehicleDriverSelectionFormPage(
        initialMachineId: _selectedLightHeavyMachine?.id,
      ),
    ),
    _NewFormItem(
      title: 'گردش انبار',
      order: 30,
      isProjectForm: false,
      section: _FormSection.storage,
      icon: Icons.warehouse_outlined,
      builder: (_) => const WarehouseOverviewNativePage(),
    ),
    _NewFormItem(
      title: 'درخواست انتقال کالا',
      order: 31,
      isProjectForm: false,
      section: _FormSection.storage,
      icon: Icons.swap_horiz_outlined,
      builder: (_) => WarehouseTransferRequestNativePage(
        initialProjectId: _selectedProject?.id,
      ),
    ),
    _NewFormItem(
      title: 'درخواست مصرف کالا',
      order: 32,
      isProjectForm: false,
      section: _FormSection.storage,
      icon: Icons.inventory_2_outlined,
      builder: (_) => WarehouseConsumptionRequestNativePage(
        initialProjectId: _selectedProject?.id,
      ),
    ),
  ];

  List<FormEntry> get _visibleForms =>
      _showAll ? widget.forms : widget.forms.take(3).toList();

  List<_NewFormItem> get _sortedNewForms {
    final allowed = widget.allowedForms;
    if (!_sortDirty && _sameAllowedForms(allowed)) {
      return _cachedSortedForms;
    }
    final list = [..._newFormItems];
    if (allowed.isNotEmpty) {
      list.removeWhere(
        (item) => item.accessKey != null && !allowed.contains(item.accessKey),
      );
    }
    list.sort((a, b) {
      if (a.isFavorite != b.isFavorite) {
        return a.isFavorite ? -1 : 1;
      }
      return a.order.compareTo(b.order);
    });
    _cachedSortedForms = list;
    _lastAllowedForms = Set<String>.from(allowed);
    _sortDirty = false;
    return _cachedSortedForms;
  }

  void _toggleNewFormFavorite(_NewFormItem item) {
    setState(() {
      item.isFavorite = !item.isFavorite;
      _sortDirty = true;
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_ensureProjectLookups());
    });
  }

  @override
  void didUpdateWidget(covariant FormsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameAllowedForms(widget.allowedForms)) {
      _sortDirty = true;
    }
  }

  bool _sameAllowedForms(Set<String> allowed) {
    final previous = _lastAllowedForms;
    return previous.length == allowed.length &&
        previous.containsAll(allowed) &&
        allowed.containsAll(previous);
  }

  Future<void> _loadProjectLookups() async {
    unawaited(appRepository.logAppEvent('projects_lookup: start'));
    setState(() {
      _isLoadingLookups = true;
      _lookupError = null;
      _lookupsRequested = true;
      _lookupsLoaded = false;
    });
    try {
      final results = await Future.wait([
        appRepository.getProjects(),
        appRepository.getMachines(),
      ]);
      if (!mounted) {
        return;
      }
      final projects = results[0] as List<ProjectOption>;
      final machines = results[1] as List<MachineOption>;
      unawaited(
        appRepository.logAppEvent(
          'projects_lookup: cache projects=${projects.length} machines=${machines.length}',
        ),
      );

      setState(() {
        _projects = projects;
        _machines = machines;
        final selectedProjectId = _selectedProject?.id;
        if (selectedProjectId != null &&
            !_projects.any((item) => item.id == selectedProjectId)) {
          _selectedProject = null;
        }
        final selectedDrillingProjectId = _selectedDrillingProject?.id;
        if (selectedDrillingProjectId != null &&
            !_projects.any(
              (item) =>
                  item.id == selectedDrillingProjectId &&
                  !_isExploratoryProject(item.raw),
            )) {
          _selectedDrillingProject = null;
        }
        _pruneMachineSelections();
        _isLoadingLookups = false;
        _lookupsLoaded = projects.isNotEmpty;
        _lookupError = projects.isEmpty ? 'پروژه فعالی یافت نشد.' : null;
      });

      // Do not block the UI if cache is available; refresh in background.
      if (projects.isEmpty || machines.isEmpty) {
        unawaited(_refreshProjectLookupsInBackground());
      }
    } catch (error) {
      if (error is ApiException && error.statusCode != null) {
        unawaited(
          appRepository.logAppEvent(
            'projects_lookup: failed_${error.statusCode}',
          ),
        );
      } else {
        unawaited(appRepository.logAppEvent('projects_lookup: failed'));
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingLookups = false;
        _lookupsLoaded = false;
        if (error is ApiException && error.statusCode == 401) {
          _lookupError = 'دسترسی به پروژه‌ها ممکن نیست. لطفا دوباره وارد شوید.';
        } else if (error is ApiException && error.statusCode != null) {
          _lookupError =
              'خطا در دریافت پروژه‌ها و ماشین‌آلات (کد ${error.statusCode}).';
        } else {
          _lookupError = 'دریافت پروژه‌ها و ماشین‌آلات با خطا مواجه شد.';
        }
      });
    } finally {
      if (mounted && _isLoadingLookups) {
        setState(() {
          _isLoadingLookups = false;
        });
      }
    }
  }

  Future<void> _refreshProjectLookupsInBackground() async {
    try {
      unawaited(appRepository.logAppEvent('projects_lookup: sync_start'));
      await appRepository.syncLookups();
      final results = await Future.wait([
        appRepository.getProjects(),
        appRepository.getMachines(),
      ]);
      if (!mounted) {
        return;
      }
      final projects = results[0] as List<ProjectOption>;
      final machines = results[1] as List<MachineOption>;
      unawaited(
        appRepository.logAppEvent(
          'projects_lookup: sync_done projects=${projects.length} machines=${machines.length}',
        ),
      );
      setState(() {
        _projects = projects;
        _machines = machines;
        final selectedProjectId = _selectedProject?.id;
        if (selectedProjectId != null &&
            !_projects.any((item) => item.id == selectedProjectId)) {
          _selectedProject = null;
        }
        final selectedDrillingProjectId = _selectedDrillingProject?.id;
        if (selectedDrillingProjectId != null &&
            !_projects.any(
              (item) =>
                  item.id == selectedDrillingProjectId &&
                  !_isExploratoryProject(item.raw),
            )) {
          _selectedDrillingProject = null;
        }
        _pruneMachineSelections();
        _lookupsLoaded = projects.isNotEmpty;
        if (projects.isNotEmpty) {
          _lookupError = null;
        }
      });
    } catch (_) {
      // Ignore background refresh failures and keep cached values.
    }
  }

  Future<void> _ensureProjectLookups() async {
    if (_lookupsLoaded || _isLoadingLookups) {
      return;
    }
    if (_lookupsRequested && _lookupError == null) {
      return;
    }
    await _loadProjectLookups();
  }

  List<SelectionOption> get _projectOptions => _projects
      .map(
        (project) => SelectionOption(
          id: project.id,
          title: project.name,
          raw: project.raw,
        ),
      )
      .toList();

  List<SelectionOption> get _drillingProjectOptions =>
      _projects
          .where((project) => !_isExploratoryProject(project.raw))
          .map(
            (project) => SelectionOption(
              id: project.id,
              title: project.name,
              raw: project.raw,
            ),
          )
          .toList()
        ..sort((a, b) => a.title.compareTo(b.title));

  int? _projectTypeId(Map<String, dynamic> raw) {
    final value = raw['project_type'] ?? raw['type'];
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '');
  }

  String _projectTypeLabel(Map<String, dynamic> raw) {
    final display =
        raw['project_type_display'] ?? raw['type_display'] ?? raw['type_name'];
    final text = display?.toString().trim() ?? '';
    if (text.isNotEmpty) {
      return text;
    }
    if (_projectTypeId(raw) == 21) {
      return 'اکتشافی';
    }
    return 'غیر اکتشافی';
  }

  bool _isExploratoryProject(Map<String, dynamic> raw) {
    final typeId = _projectTypeId(raw);
    if (typeId == 21) {
      return true;
    }
    final label = _projectTypeLabel(raw);
    return label.contains('اکتشاف');
  }

  Color _projectTypeColor(BuildContext context, Map<String, dynamic> raw) {
    return _isExploratoryProject(raw)
        ? Colors.orange.shade700
        : Theme.of(context).colorScheme.primary;
  }

  Widget _projectTypeChip(BuildContext context, Map<String, dynamic> raw) {
    final color = _projectTypeColor(context, raw);
    final label = _projectTypeLabel(raw);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Future<SelectionOption?> _showProjectPickerSheet() {
    final options = _projectOptions;
    return showModalBottomSheet<SelectionOption>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (modalContext) {
        var query = '';
        var selectedId = _selectedProject?.id;
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(modalContext).viewInsets.bottom + 16,
              ),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.62,
                child: StatefulBuilder(
                  builder: (context, setModalState) {
                    final normalized = query.trim().toLowerCase();
                    final filtered = normalized.isEmpty
                        ? options
                        : options
                              .where(
                                (option) => option.title.toLowerCase().contains(
                                  normalized,
                                ),
                              )
                              .toList();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'انتخاب پروژه فعال',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _projectTypeChip(context, const <String, dynamic>{
                              'project_type_display': 'اکتشافی',
                            }),
                            _projectTypeChip(context, const <String, dynamic>{
                              'project_type_display': 'سایر پروژه‌ها',
                              'project_type': 0,
                            }),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            labelText: 'جستجو',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) =>
                              setModalState(() => query = value),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: filtered.isEmpty
                              ? const Center(child: Text('پروژه‌ای یافت نشد'))
                              : ListView.separated(
                                  itemCount: filtered.length,
                                  separatorBuilder: (context, index) =>
                                      const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final option = filtered[index];
                                    final selected = selectedId == option.id;
                                    final color = _projectTypeColor(
                                      context,
                                      option.raw,
                                    );
                                    return ListTile(
                                      onTap: () =>
                                          Navigator.of(context).pop(option),
                                      leading: Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: color,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      title: Text(option.title),
                                      subtitle: Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: _projectTypeChip(
                                          context,
                                          option.raw,
                                        ),
                                      ),
                                      trailing: Radio<int>(
                                        value: option.id,
                                        groupValue: selectedId,
                                        onChanged: (value) {
                                          if (value == null) {
                                            return;
                                          }
                                          selectedId = value;
                                          Navigator.of(context).pop(option);
                                        },
                                      ),
                                      selected: selected,
                                      selectedTileColor: color.withAlpha(14),
                                    );
                                  },
                                ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<MachineOption> get _machinesInSelectedProject {
    final selectedProjectId = _selectedProject?.id;
    if (selectedProjectId == null) {
      return const <MachineOption>[];
    }
    return _machines
        .where((item) => item.projectId == selectedProjectId)
        .toList();
  }

  List<SelectionOption> _machineOptionsForTypes(Set<int> types) {
    final projectName = _selectedProject?.title;
    return _machinesInSelectedProject
        .where((item) => types.contains(item.machineType))
        .map(
          (item) => SelectionOption(
            id: item.id,
            title: projectName == null
                ? item.displayName
                : '${item.displayName} - $projectName',
            raw: item.raw,
          ),
        )
        .toList();
  }

  List<SelectionOption> get _drillingMachineOptions =>
      _machineOptionsForTypes(const <int>{100});

  List<SelectionOption> get _lightHeavyMachineOptions =>
      _machineOptionsForTypes(const <int>{101, 102});

  void _pruneMachineSelections() {
    final drillingIds = _drillingMachineOptions.map((item) => item.id).toSet();
    final lightHeavyIds = _lightHeavyMachineOptions
        .map((item) => item.id)
        .toSet();
    if (_selectedDrillingMachine != null &&
        !drillingIds.contains(_selectedDrillingMachine!.id)) {
      _selectedDrillingMachine = null;
    }
    if (_selectedLightHeavyMachine != null &&
        !lightHeavyIds.contains(_selectedLightHeavyMachine!.id)) {
      _selectedLightHeavyMachine = null;
    }
  }

  Future<void> _selectProject() async {
    await _ensureProjectLookups();
    if (!mounted || _isLoadingLookups) {
      return;
    }
    if (_lookupError != null && _projects.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_lookupError!)));
      return;
    }
    final result = await _showProjectPickerSheet();
    if (result == null) {
      return;
    }
    setState(() {
      _selectedProject = result;
      _pruneMachineSelections();
    });
  }

  Future<void> _selectDrillingProject() async {
    await _ensureProjectLookups();
    if (!mounted || _isLoadingLookups) {
      return;
    }
    if (_lookupError != null && _projects.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_lookupError!)));
      return;
    }
    final options = _drillingProjectOptions;
    if (options.isEmpty) {
      _showLookupSnack('پروژه حفاری فعال (غیر اکتشافی) یافت نشد.');
      return;
    }
    final result = await showSearchableSingleOptionSheet(
      context: context,
      title: 'پروژه حفاری',
      options: options,
      initialId: _selectedDrillingProject?.id,
    );
    if (result == null) {
      return;
    }
    setState(() {
      _selectedDrillingProject = result;
    });
  }

  Future<void> _selectDrillingMachine() async {
    await _selectMachine(
      title: 'ماشین حفاری',
      options: _drillingMachineOptions,
      initialId: _selectedDrillingMachine?.id,
      onSelected: (value) => setState(() => _selectedDrillingMachine = value),
    );
  }

  Future<void> _selectLightHeavyMachine() async {
    await _selectMachine(
      title: 'ماشین سبک/سنگین',
      options: _lightHeavyMachineOptions,
      initialId: _selectedLightHeavyMachine?.id,
      onSelected: (value) => setState(() => _selectedLightHeavyMachine = value),
    );
  }

  Future<void> _selectMachine({
    required String title,
    required List<SelectionOption> options,
    required int? initialId,
    required ValueChanged<SelectionOption> onSelected,
  }) async {
    await _ensureProjectLookups();
    if (!mounted || _isLoadingLookups) {
      return;
    }
    if (_selectedProject == null) {
      _showLookupSnack('ابتدا پروژه فعال را انتخاب کنید.');
      return;
    }
    if (options.isEmpty) {
      _showLookupSnack('در پروژه انتخاب‌شده، موردی برای "$title" یافت نشد.');
      return;
    }
    final result = await showSearchableSingleOptionSheet(
      context: context,
      title: title,
      options: options,
      initialId: initialId,
    );
    if (result != null) {
      onSelected(result);
    }
  }

  void _showLookupSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showMissingSelectionError(_FormSelectionRequirement requirement) {
    final message = switch (requirement) {
      _FormSelectionRequirement.project => 'ابتدا پروژه فعال را انتخاب کنید.',
      _FormSelectionRequirement.drillingMachine =>
        'ابتدا ماشین حفاری را انتخاب کنید.',
      _FormSelectionRequirement.lightHeavyMachine =>
        'ابتدا ماشین سبک/سنگین را انتخاب کنید.',
      _FormSelectionRequirement.none => 'انتخاب مورد الزامی است.',
    };
    _showLookupSnack(message);
  }

  Future<void> _openWebRoute({
    required String title,
    required String path,
  }) async {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$_misBaseUrl$normalizedPath');
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WebRoutePage(title: title, url: uri.toString()),
      ),
    );
  }

  Future<void> _handleNewFormItemTap(_NewFormItem item) async {
    if (item.selectionRequirement == _FormSelectionRequirement.project &&
        item.section == _FormSection.drilling &&
        _selectedDrillingProject == null) {
      _showLookupSnack('ابتدا پروژه حفاری را انتخاب کنید.');
      return;
    }
    if (item.builder != null) {
      if (!mounted) {
        return;
      }
      await Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: item.builder!));
      return;
    }
    final webPath = item.webPathBuilder?.call();
    if (webPath != null && webPath.isNotEmpty) {
      await _openWebRoute(title: item.title, path: webPath);
      return;
    }
    _showLookupSnack('این بخش هنوز به‌صورت بومی کامل نشده است.');
  }

  void resetCollapsed() {
    if (!_showAll) {
      return;
    }
    setState(() {
      _showAll = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final newForms = _sortedNewForms;
    final drillingForms = newForms
        .where((item) => item.section == _FormSection.drilling)
        .toList();
    final machineryForms = newForms
        .where((item) => item.section == _FormSection.machinery)
        .toList();
    final storageForms = newForms
        .where((item) => item.section == _FormSection.storage)
        .toList();
    final theme = Theme.of(context);

    return ListView(
      padding: _pagePadding(context),
      children: [
        Text('فرم‌های ثبت‌شده', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        _FormsGrid(
          items: _visibleForms,
          onTap: (form) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => FormDetailPage(form: form),
              ),
            );
          },
        ),
        if (widget.forms.length > 3)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() => _showAll = !_showAll),
              child: Text(_showAll ? 'نمایش کمتر' : 'نمایش بیشتر'),
            ),
          ),
        const SizedBox(height: 24),
        Text('حفاری', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _selectionField(
                  label: 'پروژه حفاری',
                  value: _selectedDrillingProject?.title,
                  placeholder:
                      'انتخاب پروژه حفاری (فقط پروژه‌های فعال غیر اکتشافی)',
                  icon: Icons.business_center_outlined,
                  onTap: _selectDrillingProject,
                ),
                if (_selectedDrillingProject != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _projectTypeChip(context, _selectedDrillingProject!.raw),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () =>
                            setState(() => _selectedDrillingProject = null),
                        icon: const Icon(Icons.clear),
                        label: const Text('پاک کردن'),
                      ),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 10),
                  Text(
                    'در فرم‌های حفاری فقط پروژه‌های فعال مرتبط (غیر اکتشافی) قابل انتخاب هستند.',
                    style: TextStyle(color: theme.hintColor),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _NewFormsGrid(
          items: drillingForms,
          onToggleFavorite: _toggleNewFormFavorite,
          onTapItem: _handleNewFormItemTap,
        ),
        const SizedBox(height: 24),
        Text('ماشین‌آلات', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        _NewFormsGrid(
          items: machineryForms,
          onToggleFavorite: _toggleNewFormFavorite,
          onTapItem: _handleNewFormItemTap,
        ),
        const SizedBox(height: 24),
        Text('انبار', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        _NewFormsGrid(
          items: storageForms,
          onToggleFavorite: _toggleNewFormFavorite,
          onTapItem: _handleNewFormItemTap,
        ),
      ],
    );
  }
}

class _FormsGrid extends StatelessWidget {
  const _FormsGrid({required this.items, required this.onTap});

  final List<FormEntry> items;
  final ValueChanged<FormEntry> onTap;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Text('فرمی ثبت نشده است.');
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final form = items[index];
        return _FormGridCard(form: form, onTap: () => onTap(form));
      },
    );
  }
}

class _NewFormsGrid extends StatelessWidget {
  const _NewFormsGrid({
    required this.items,
    required this.onToggleFavorite,
    this.onTapItem,
    this.requireProjectSelection = false,
    this.hasProjectSelection = true,
    this.onMissingSelection,
  });

  final List<_NewFormItem> items;
  final ValueChanged<_NewFormItem> onToggleFavorite;
  final Future<void> Function(_NewFormItem item)? onTapItem;
  final bool requireProjectSelection;
  final bool hasProjectSelection;
  final VoidCallback? onMissingSelection;

  int _crossAxisCount(double width) {
    if (width >= 900) {
      return 3;
    }
    if (width >= 600) {
      return 2;
    }
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Text('فرمی برای نمایش وجود ندارد.');
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _crossAxisCount(constraints.maxWidth),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.3,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  if (onTapItem != null) {
                    unawaited(onTapItem!(item));
                    return;
                  }
                  if (requireProjectSelection && !hasProjectSelection) {
                    onMissingSelection?.call();
                    return;
                  }
                  if (item.builder != null) {
                    Navigator.of(
                      context,
                    ).push(MaterialPageRoute<void>(builder: item.builder!));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          _toPersianDigits(
                            '${item.title} به زودی فعال می‌شود.',
                          ),
                        ),
                      ),
                    );
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            item.isFavorite ? Icons.star : Icons.star_border,
                            color: item.isFavorite ? Colors.amber : null,
                          ),
                          onPressed: () => onToggleFavorite(item),
                        ),
                      ),
                      const Spacer(),
                      Center(
                        child: Icon(
                          item.icon,
                          size: 54,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _toPersianDigits(item.title),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _FormGridCard extends StatelessWidget {
  const _FormGridCard({required this.form, required this.onTap});

  final FormEntry form;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                form.title,
                style: Theme.of(context).textTheme.titleSmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                _toPersianDigits(_formatJalali(form.onlineSubmittedAt)),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: _StatusChip(status: form.status),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final FormStatus status;

  @override
  Widget build(BuildContext context) {
    final color = status.color;
    return Transform.translate(
      offset: const Offset(-8, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withAlpha(31),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          status.label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.onLoginSuccess,
    required this.repository,
  });

  final VoidCallback onLoginSuccess;
  final AppRepository repository;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? _errorMessage;
  bool _isSubmitting = false;
  bool _obscurePassword = true;

  void _setLoginError(Object error) {
    if (error is ApiException && error.isNetwork) {
      _errorMessage = 'دسترسی به اینترنت وجود ندارد';
      unawaited(appRepository.logAppEvent('login: network_unavailable'));
      return;
    }
    if (error is ApiException &&
        error.statusCode != null &&
        error.statusCode! >= 500) {
      _errorMessage = 'خطای سرور لطفا مجددا تلاش کنید';
      unawaited(
        appRepository.logAppEvent('login: server_error_${error.statusCode}'),
      );
      return;
    }
    if (error is ApiException &&
        (error.statusCode == 400 || error.statusCode == 401)) {
      _errorMessage = 'نام کاربری یا رمز عبور اشتباه است';
      unawaited(appRepository.logAppEvent('login: invalid_credentials'));
      return;
    }
    _errorMessage = 'ورود ناموفق بود. دوباره تلاش کنید.';
    unawaited(appRepository.logAppEvent('login: failed'));
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _attemptLogin() async {
    final user = _usernameController.text.trim();
    final pass = _passwordController.text.trim();
    if (user.isEmpty || pass.isEmpty) {
      setState(() {
        _errorMessage = 'شماره همراه و رمز عبور را وارد کنید.';
      });
      return;
    }
    setState(() {
      _errorMessage = null;
      _isSubmitting = true;
    });
    try {
      await widget.repository.loginWithPassword(user, pass);
      await widget.repository.syncOnLogin();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('با موفقیت وارد شدید'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(top: 16, left: 16, right: 16),
          duration: const Duration(seconds: 2),
        ),
      );
      widget.onLoginSuccess();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _setLoginError(error);
      });
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _loginWithOtp() async {
    final phone = _usernameController.text.trim();
    if (phone.isEmpty) {
      setState(() {
        _errorMessage = 'شماره همراه را وارد کنید.';
      });
      return;
    }
    setState(() {
      _errorMessage = null;
      _isSubmitting = true;
    });
    try {
      await widget.repository.sendOtp(phone);
      final code = await _promptInput(
        title: 'ورود با رمز یکبار مصرف',
        label: 'کد پیامک شده',
      );
      if (code == null || code.trim().isEmpty) {
        return;
      }
      await widget.repository.loginWithOtp(phone, code.trim());
      await widget.repository.syncOnLogin();
      if (!mounted) return;
      widget.onLoginSuccess();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        if (error is ApiException && error.isNetwork) {
          _errorMessage = 'دسترسی به اینترنت وجود ندارد';
        } else if (error is ApiException &&
            error.statusCode != null &&
            error.statusCode! >= 500) {
          _errorMessage = 'خطای سرور لطفا مجددا تلاش کنید';
        } else {
          _errorMessage = 'ارسال یا تایید رمز یکبار مصرف ناموفق بود.';
        }
      });
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _resetPasswordFlow() async {
    final phone = _usernameController.text.trim();
    if (phone.isEmpty) {
      setState(() {
        _errorMessage = 'شماره همراه را وارد کنید.';
      });
      return;
    }
    setState(() {
      _errorMessage = null;
      _isSubmitting = true;
    });
    try {
      await widget.repository.sendOtp(phone);
      final code = await _promptInput(
        title: 'بازیابی رمز عبور',
        label: 'کد پیامک شده',
      );
      if (code == null || code.trim().isEmpty) {
        return;
      }
      final newPassword = await _promptInput(
        title: 'رمز عبور جدید',
        label: 'رمز عبور جدید',
        obscureText: true,
      );
      if (newPassword == null || newPassword.isEmpty) {
        return;
      }
      final repeatPassword = await _promptInput(
        title: 'تکرار رمز عبور',
        label: 'تکرار رمز عبور',
        obscureText: true,
      );
      if (repeatPassword == null || repeatPassword.isEmpty) {
        return;
      }
      await widget.repository.resetPassword(
        phone: phone,
        code: code.trim(),
        newPassword: newPassword,
        repeatPassword: repeatPassword,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('رمز عبور با موفقیت تغییر کرد.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        if (error is ApiException && error.isNetwork) {
          _errorMessage = 'دسترسی به اینترنت وجود ندارد';
        } else if (error is ApiException &&
            error.statusCode != null &&
            error.statusCode! >= 500) {
          _errorMessage = 'خطای سرور لطفا مجددا تلاش کنید';
        } else {
          _errorMessage = 'بازیابی رمز عبور ناموفق بود.';
        }
      });
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<String?> _promptInput({
    required String title,
    required String label,
    bool obscureText = false,
  }) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            obscureText: obscureText,
            decoration: InputDecoration(labelText: label),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('انصراف'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('تایید'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Column(
                    children: [
                      Image.asset(
                        'لوگو فلزیابان.png',
                        height: 96,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'سامانه مدیریت اطلاعات سازمانی',
                        style: TextStyle(fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'ورود به سامانه',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    key: const ValueKey('loginUsernameField'),
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'نام کاربری یا شماره همراه',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const ValueKey('loginPasswordField'),
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'رمز عبور',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: _isSubmitting ? null : _resetPasswordFlow,
                      child: const Text('فراموشی رمز عبور'),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: _isSubmitting ? null : _loginWithOtp,
                      child: const Text('ورود با رمز یکبار مصرف'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _attemptLogin,
                    child: const Text('ورود'),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _FormSection { drilling, machinery, storage, other }

enum _FormSelectionRequirement {
  none,
  project,
  drillingMachine,
  lightHeavyMachine,
}

class _NewFormItem {
  _NewFormItem({
    required this.title,
    required this.order,
    required this.isProjectForm,
    required this.icon,
    this.builder,
    this.accessKey,
    this.section = _FormSection.other,
    this.selectionRequirement = _FormSelectionRequirement.none,
    this.webPathBuilder,
  });

  final String title;
  final int order;
  final bool isProjectForm;
  final IconData icon;
  final WidgetBuilder? builder;
  final String? accessKey;
  final _FormSection section;
  final _FormSelectionRequirement selectionRequirement;
  final String? Function()? webPathBuilder;
  bool isFavorite = false;
}

const List<String> _weekdayLabels = ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'];
const Map<String, List<String>> iranCities = {
  'آذربایجان شرقی': ['تبریز', 'مراغه', 'مرند', 'اهر', 'بناب'],
  'آذربایجان غربی': ['ارومیه', 'خوی', 'میاندوآب', 'مهاباد'],
  'اردبیل': ['اردبیل', 'پارس‌آباد', 'خلخال', 'مشگین‌شهر'],
  'اصفهان': ['اصفهان', 'کاشان', 'خمینی‌شهر', 'نجف‌آباد', 'شاهین‌شهر'],
  'البرز': ['کرج', 'فردیس', 'نظرآباد', 'هشتگرد'],
  'ایلام': ['ایلام', 'دهلران', 'مهران', 'ایوان'],
  'بوشهر': ['بوشهر', 'برازجان', 'کنگان', 'دیلم'],
  'تهران': ['تهران', 'اسلام‌شهر', 'ملارد', 'ورامین', 'ری'],
  'چهارمحال و بختیاری': ['شهرکرد', 'بروجن', 'فرخ‌شهر'],
  'خراسان جنوبی': ['بیرجند', 'قائن', 'طبس'],
  'خراسان رضوی': ['مشهد', 'نیشابور', 'سبزوار', 'تربت حیدریه'],
  'خراسان شمالی': ['بجنورد', 'شیروان', 'اسفراین'],
  'خوزستان': ['اهواز', 'آبادان', 'دزفول', 'ماهشهر', 'بهبهان'],
  'زنجان': ['زنجان', 'ابهر', 'خرمدره'],
  'سمنان': ['سمنان', 'شاهرود', 'دامغان', 'گرمسار'],
  'سیستان و بلوچستان': ['زاهدان', 'چابهار', 'ایرانشهر', 'زابل'],
  'فارس': ['شیراز', 'مرودشت', 'کازرون', 'لار', 'جهرم'],
  'قزوین': ['قزوین', 'الوند', 'تاکستان'],
  'قم': ['قم'],
  'كردستان': ['سنندج', 'سقز', 'بانه', 'مریوان'],
  'كرمان': ['کرمان', 'سیرجان', 'رفسنجان', 'جیرفت'],
  'كرمانشاه': ['کرمانشاه', 'اسلام‌آباد غرب', 'سنقر'],
  'كهگیلویه و بویراحمد': ['یاسوج', 'دوگنبدان', 'دهدشت'],
  'گلستان': ['گرگان', 'گنبد کاووس', 'بندر ترکمن'],
  'گیلان': ['رشت', 'انزلی', 'لاهیجان', 'صومعه‌سرا'],
  'لرستان': ['خرم‌آباد', 'بروجرد', 'دورود'],
  'مازندران': ['ساری', 'بابل', 'آمل', 'قائم‌شهر', 'نوشهر'],
  'مرکزی': ['اراک', 'ساوه', 'خمین', 'محلات'],
  'هرمزگان': ['بندرعباس', 'قشم', 'میناب', 'کیش'],
  'همدان': ['همدان', 'ملایر', 'نهاوند'],
  'یزد': ['یزد', 'اردکان', 'میبد', 'بافق'],
};

mixin _FormFieldMixin<T extends StatefulWidget> on State<T> {
  void showFormInfo(String title, String message) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(message)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('متوجه شدم'),
          ),
        ],
      ),
    );
  }

  IconData? _iconForLabel(String label) {
    final normalized = label.trim();
    if (normalized.contains('پروژه')) return Icons.work_outline;
    if (normalized.contains('گمانه')) return Icons.place_outlined;
    if (normalized.contains('انبار')) return Icons.warehouse_outlined;
    if (normalized.contains('کالا') || normalized.contains('اقلام')) {
      return Icons.inventory_2_outlined;
    }
    if (normalized.contains('مقدار') ||
        normalized.contains('متراژ') ||
        normalized.contains('تعداد')) {
      return Icons.numbers_outlined;
    }
    if (normalized.contains('تاریخ') || normalized.contains('روز')) {
      return Icons.calendar_month_outlined;
    }
    if (normalized.contains('زمان') || normalized.contains('ساعت')) {
      return Icons.schedule_outlined;
    }
    if (normalized.contains('شیفت')) return Icons.timelapse_outlined;
    if (normalized.contains('دستگاه') || normalized.contains('ماشین')) {
      return Icons.precision_manufacturing_outlined;
    }
    if (normalized.contains('حفار') || normalized.contains('راننده')) {
      return Icons.badge_outlined;
    }
    if (normalized.contains('نوع')) return Icons.category_outlined;
    if (normalized.contains('علت')) return Icons.help_outline;
    if (normalized.contains('کد')) return Icons.pin_outlined;
    if (normalized.contains('توضیح') || normalized.contains('شرح')) {
      return Icons.notes_outlined;
    }
    if (normalized.contains('نام')) return Icons.text_fields_outlined;
    if (normalized.contains('ایمیل')) return Icons.mail_outline;
    if (normalized.contains('رمز')) return Icons.lock_outline;
    if (normalized.contains('شماره')) return Icons.phone_outlined;
    return null;
  }

  InputDecoration _inputDecoration(
    String label, {
    Widget? suffixIcon,
    IconData? prefixIcon,
    bool alwaysFloatLabel = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final borderColor = colorScheme.outline.withAlpha(153);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: borderColor),
    );
    final focusedBorder = border.copyWith(
      borderSide: BorderSide(color: colorScheme.primary.withAlpha(204)),
    );
    final resolvedPrefix = prefixIcon ?? _iconForLabel(label);
    return InputDecoration(
      labelText: label,
      border: border,
      enabledBorder: border,
      focusedBorder: focusedBorder,
      prefixIcon: resolvedPrefix == null ? null : Icon(resolvedPrefix),
      suffixIcon: suffixIcon,
      floatingLabelBehavior: alwaysFloatLabel
          ? FloatingLabelBehavior.always
          : null,
    );
  }

  Widget _buildNumberField(
    TextEditingController controller,
    String label, {
    TextInputType keyboardType = TextInputType.number,
    String? Function(String?)? validator,
    String? errorText,
    ValueChanged<String>? onChanged,
    IconData? icon,
  }) {
    final decoration = _inputDecoration(
      label,
      prefixIcon: icon,
    ).copyWith(errorText: errorText);
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator:
          validator ??
          (value) {
            if (value == null || value.trim().isEmpty) {
              return 'وارد کردن $label الزامی است';
            }
            return null;
          },
      onChanged: onChanged,
      autovalidateMode: AutovalidateMode.disabled,
      decoration: decoration,
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    IconData? icon,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: _inputDecoration(label, prefixIcon: icon),
      validator:
          validator ??
          (value) {
            if (value == null || value.trim().isEmpty) {
              return 'وارد کردن $label الزامی است';
            }
            return null;
          },
    );
  }

  Widget _selectionField({
    required String label,
    required VoidCallback onTap,
    String? value,
    String? placeholder,
    IconData? icon,
  }) {
    final theme = Theme.of(context);
    final hasValue = value != null && value.trim().isNotEmpty;
    final hintStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.hintColor,
    );
    final displayWidget = hasValue
        ? Text(value, style: theme.textTheme.bodyMedium)
        : placeholder != null && placeholder.isNotEmpty
        ? Text(placeholder, style: hintStyle)
        : const SizedBox(height: 20);
    return Material(
      borderRadius: BorderRadius.circular(12),
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: InputDecorator(
          isEmpty: false,
          decoration: _inputDecoration(
            label,
            suffixIcon: Icon(icon ?? Icons.expand_more),
            alwaysFloatLabel: true,
          ),
          child: displayWidget,
        ),
      ),
    );
  }

  Widget _multiSelectionField({
    required String label,
    required Set<String> values,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final hasValue = values.isNotEmpty;
    final chips = values
        .map(
          (value) =>
              Chip(label: Text(value), visualDensity: VisualDensity.compact),
        )
        .toList();
    return Material(
      borderRadius: BorderRadius.circular(12),
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: InputDecorator(
          isEmpty: false,
          decoration: _inputDecoration(label, alwaysFloatLabel: true),
          child: hasValue
              ? Wrap(spacing: 8, runSpacing: 8, children: chips)
              : Text(
                  'موردی انتخاب نشده',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
        ),
      ),
    );
  }

  Future<DateTime?> pickJalaliDate({DateTime? initialDate}) async {
    final base = initialDate ?? DateTime.now();
    final initialJalali = Jalali.fromDateTime(base);
    final jalali = await _showJalaliDatePicker(
      initialDate: initialJalali,
      firstDate: Jalali(initialJalali.year - 2, 1, 1),
      lastDate: Jalali(initialJalali.year + 2, 12, 29),
    );
    if (jalali == null) {
      return null;
    }
    final gregorian = jalali.toDateTime();
    return DateTime(gregorian.year, gregorian.month, gregorian.day);
  }

  Future<DateTime?> pickJalaliDateTime({DateTime? initialDate}) async {
    final base = initialDate ?? DateTime.now();
    final initialJalali = Jalali.fromDateTime(base);
    final jalali = await _showJalaliDatePicker(
      initialDate: initialJalali,
      firstDate: Jalali(initialJalali.year - 2, 1, 1),
      lastDate: Jalali(initialJalali.year + 2, 12, 29),
    );
    if (jalali == null) {
      return null;
    }
    if (!mounted) {
      return null;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(alwaysUse24HourFormat: true),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
    if (time == null) {
      return null;
    }
    final gregorian = jalali.toDateTime();
    return DateTime(
      gregorian.year,
      gregorian.month,
      gregorian.day,
      time.hour,
      time.minute,
    );
  }

  String? formatJalaliDate(DateTime? value, {bool includeTime = false}) {
    if (value == null) {
      return null;
    }
    final jalali = Jalali.fromDateTime(value);
    final dayName = _normalizeDayName(jalali.formatter.wN);
    final dateText =
        '$dayName، ${jalali.formatter.d} ${jalali.formatter.mN} ${jalali.year}';
    if (!includeTime) {
      return _toPersianDigits(dateText);
    }
    final time =
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    return _toPersianDigits('$dateText - ساعت $time');
  }

  Future<Jalali?> _showJalaliDatePicker({
    required Jalali initialDate,
    required Jalali firstDate,
    required Jalali lastDate,
  }) {
    final firstMonthStart = Jalali(firstDate.year, firstDate.month, 1);
    final lastMonthStart = Jalali(lastDate.year, lastDate.month, 1);
    return showModalBottomSheet<Jalali>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (modalContext) {
        var visibleMonth = Jalali(initialDate.year, initialDate.month, 1);
        Jalali? tempSelection = initialDate;
        final mediaQuery = MediaQuery.of(context);
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: mediaQuery.viewInsets.bottom + 16,
              ),
              child: SizedBox(
                height: mediaQuery.size.height * 0.6,
                child: StatefulBuilder(
                  builder: (context, setModalState) {
                    final theme = Theme.of(context);
                    final canGoPrev =
                        _compareJalali(visibleMonth, firstMonthStart) > 0;
                    final canGoNext =
                        _compareJalali(visibleMonth, lastMonthStart) < 0;
                    final headerText =
                        '${visibleMonth.formatter.mN} ${visibleMonth.year}';
                    final headerDisplay = _toPersianDigits(headerText);
                    final startWeekIndex =
                        (Jalali(
                              visibleMonth.year,
                              visibleMonth.month,
                              1,
                            ).weekDay -
                            1) %
                        7;
                    final leadingEmpty = (startWeekIndex + 7) % 7;
                    final daysInMonth = visibleMonth.monthLength;
                    final cells = <Widget>[];
                    for (var i = 0; i < leadingEmpty; i++) {
                      cells.add(const SizedBox.shrink());
                    }
                    for (var day = 1; day <= daysInMonth; day++) {
                      final currentDate = Jalali(
                        visibleMonth.year,
                        visibleMonth.month,
                        day,
                      );
                      final isDisabled =
                          _compareJalali(currentDate, firstDate) < 0 ||
                          _compareJalali(currentDate, lastDate) > 0;
                      final isSelected =
                          tempSelection != null &&
                          _compareJalali(currentDate, tempSelection!) == 0;
                      cells.add(
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: isDisabled
                                ? null
                                : () {
                                    setModalState(() {
                                      tempSelection = currentDate;
                                    });
                                  },
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : Colors.transparent,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                _toPersianDigits(day.toString()),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: isSelected
                                      ? theme.colorScheme.onPrimary
                                      : isDisabled
                                      ? theme.disabledColor
                                      : theme.colorScheme.onSurface,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                    while (cells.length % 7 != 0) {
                      cells.add(const SizedBox.shrink());
                    }
                    final rows = <TableRow>[];
                    for (var i = 0; i < cells.length; i += 7) {
                      rows.add(TableRow(children: cells.sublist(i, i + 7)));
                    }
                    final selectedLabel = tempSelection == null
                        ? ''
                        : _toPersianDigits(
                            '${tempSelection!.day} ${tempSelection!.formatter.mN} ${tempSelection!.year}',
                          );
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: canGoNext
                                  ? () => setModalState(
                                      () => visibleMonth = _nextMonth(
                                        visibleMonth,
                                      ),
                                    )
                                  : null,
                              icon: const Icon(Icons.chevron_left),
                            ),
                            Expanded(
                              child: Center(
                                child: Text(
                                  headerDisplay,
                                  style: theme.textTheme.titleMedium,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: canGoPrev
                                  ? () => setModalState(
                                      () => visibleMonth = _previousMonth(
                                        visibleMonth,
                                      ),
                                    )
                                  : null,
                              icon: const Icon(Icons.chevron_right),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: _weekdayLabels
                              .map(
                                (label) => Expanded(
                                  child: Center(
                                    child: Text(
                                      label,
                                      style: theme.textTheme.labelLarge
                                          ?.copyWith(
                                            color: theme.colorScheme.primary,
                                          ),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Table(children: rows),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          selectedLabel.isEmpty
                              ? 'تاریخی انتخاب نشده است'
                              : 'تاریخ انتخاب شده: $selectedLabel',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('انصراف'),
                            ),
                            const Spacer(),
                            FilledButton(
                              onPressed: tempSelection == null
                                  ? null
                                  : () => Navigator.of(
                                      context,
                                    ).pop(tempSelection),
                              child: const Text('تایید تاریخ'),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  int _compareJalali(Jalali a, Jalali b) {
    if (a.year != b.year) {
      return a.year.compareTo(b.year);
    }
    if (a.month != b.month) {
      return a.month.compareTo(b.month);
    }
    return a.day.compareTo(b.day);
  }

  Jalali _previousMonth(Jalali date) {
    var year = date.year;
    var month = date.month - 1;
    if (month < 1) {
      month = 12;
      year -= 1;
    }
    return Jalali(year, month, 1);
  }

  Jalali _nextMonth(Jalali date) {
    var year = date.year;
    var month = date.month + 1;
    if (month > 12) {
      month = 1;
      year += 1;
    }
    return Jalali(year, month, 1);
  }
}

class DrillingFormPage extends StatefulWidget {
  const DrillingFormPage({
    super.key,
    this.initialConjectureId,
    this.selectedProjectId,
    this.initialMachineId,
  });

  final int? initialConjectureId;
  final int? selectedProjectId;
  final int? initialMachineId;

  @override
  State<DrillingFormPage> createState() => _DrillingFormPageState();
}

class _DrillingFormPageState extends State<DrillingFormPage>
    with _FormFieldMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _casingLengthController = TextEditingController();
  SelectionOption? _selectedBorehole;
  SelectionOption? _selectedDrillMachine;
  DateTime? _drillingDate;
  DrillShift _selectedShift = DrillShift.day;
  SelectionOption? _selectedFractureType;
  SelectionOption? _selectedRockType;
  SelectionOption? _selectedRockColor;
  SelectionOption? _selectedDriller;
  SelectionOption? _selectedShiftLeader;
  final Set<int> _selectedAssistantIds = <int>{};
  final List<_DrillingRunEntry> _runs = [];
  bool _isLoadingLookups = true;
  bool _isSubmitting = false;
  String? _lookupError;
  bool _didAttemptSync = false;
  List<SelectionOption> _boreholeOptions = [];
  List<SelectionOption> _machineOptions = [];
  List<SelectionOption> _personOptions = [];
  List<SelectionOption> _stoneOptions = [];
  Map<int, String> _personLabelsById = {};

  static const List<SelectionOption> _fractureOptions = [
    SelectionOption(id: 230, title: 'یکنواخت', raw: {}),
    SelectionOption(id: 231, title: 'ضعیف', raw: {}),
    SelectionOption(id: 232, title: 'متوسط', raw: {}),
    SelectionOption(id: 233, title: 'شدید', raw: {}),
    SelectionOption(id: 234, title: 'بسیار شدید', raw: {}),
  ];

  static const List<SelectionOption> _rockColorOptions = [
    SelectionOption(id: 227, title: 'روشن', raw: {}),
    SelectionOption(id: 226, title: 'نیمه روشن', raw: {}),
    SelectionOption(id: 225, title: 'تیره', raw: {}),
  ];

  @override
  void initState() {
    super.initState();
    _runs.add(_DrillingRunEntry());
    _loadLookups();
  }

  @override
  void dispose() {
    _casingLengthController.dispose();
    for (final run in _runs) {
      run.dispose();
    }
    super.dispose();
  }

  Future<void> _loadLookups() async {
    setState(() {
      _isLoadingLookups = true;
      _lookupError = null;
    });
    try {
      Future<List<Object>> loadLookups() {
        return Future.wait([
          appRepository.getConjectures(),
          appRepository.getMachines(),
          appRepository.getPersons(),
          appRepository.getStoneTypes(),
        ]);
      }

      var results = await loadLookups();
      if (!mounted) {
        return;
      }
      var boreholes = results[0] as List<ConjectureOption>;
      var machinesRaw = results[1] as List<MachineOption>;
      var persons = results[2] as List<PersonOption>;
      var stones = results[3] as List<StoneTypeOption>;

      if (!_didAttemptSync &&
          (machinesRaw.isEmpty || persons.isEmpty || stones.isEmpty)) {
        _didAttemptSync = true;
        try {
          await appRepository.syncDrillingLookups();
        } catch (_) {
          // Keep cached values if sync fails.
        }
        results = await loadLookups();
        if (!mounted) {
          return;
        }
        boreholes = results[0] as List<ConjectureOption>;
        machinesRaw = results[1] as List<MachineOption>;
        persons = results[2] as List<PersonOption>;
        stones = results[3] as List<StoneTypeOption>;
      }

      final machines = machinesRaw.where((item) {
        if (item.machineType != 100) {
          return false;
        }
        final selectedProjectId = widget.selectedProjectId;
        if (selectedProjectId == null) {
          return true;
        }
        return item.projectId == selectedProjectId;
      }).toList();
      final filteredBoreholes = boreholes.where((item) {
        final selectedProjectId = widget.selectedProjectId;
        if (selectedProjectId == null) {
          return true;
        }
        return item.projectId == selectedProjectId;
      }).toList();

      setState(() {
        _boreholeOptions = filteredBoreholes
            .map(
              (item) =>
                  SelectionOption(id: item.id, title: item.name, raw: item.raw),
            )
            .toList();
        _machineOptions = machines
            .map(
              (item) => SelectionOption(
                id: item.id,
                title: item.displayName,
                raw: item.raw,
              ),
            )
            .toList();
        _personOptions = persons
            .map(
              (item) => SelectionOption(
                id: item.id,
                title: item.fullName,
                raw: item.raw,
              ),
            )
            .toList();
        _personLabelsById = {
          for (final person in persons) person.id: person.fullName,
        };
        _stoneOptions = stones
            .map(
              (item) => SelectionOption(
                id: item.id,
                title: item.displayName,
                raw: item.raw,
              ),
            )
            .toList();
        if (_selectedBorehole == null && widget.initialConjectureId != null) {
          final match = _boreholeOptions
              .where((item) => item.id == widget.initialConjectureId)
              .toList();
          if (match.isNotEmpty) {
            _selectedBorehole = match.first;
          }
        }
        if (_selectedBorehole == null && _boreholeOptions.length == 1) {
          _selectedBorehole = _boreholeOptions.first;
        }
        if (_selectedDrillMachine == null && widget.initialMachineId != null) {
          final match = _machineOptions
              .where((item) => item.id == widget.initialMachineId)
              .toList();
          if (match.isNotEmpty) {
            _selectedDrillMachine = match.first;
          }
        }
        if (_selectedDrillMachine == null && _machineOptions.length == 1) {
          _selectedDrillMachine = _machineOptions.first;
        }
        _isLoadingLookups = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingLookups = false;
        _lookupError = 'دریافت داده‌های اولیه با خطا مواجه شد.';
      });
    }
  }

  void _showLookupSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<SelectionOption?> _pickSingleOption({
    required String title,
    required List<SelectionOption> options,
    int? initialId,
  }) async {
    if (_isLoadingLookups) {
      _showLookupSnack('در حال دریافت اطلاعات هستیم.');
      return null;
    }
    if (options.isEmpty) {
      _showLookupSnack('لیست $title خالی است.');
      return null;
    }
    return showSearchableSingleOptionSheet(
      context: context,
      title: title,
      options: options,
      initialId: initialId,
    );
  }

  Future<Set<int>?> _pickMultiOption({
    required String title,
    required List<SelectionOption> options,
    required Set<int> currentIds,
  }) async {
    if (_isLoadingLookups) {
      _showLookupSnack('در حال دریافت اطلاعات هستیم.');
      return null;
    }
    if (options.isEmpty) {
      _showLookupSnack('لیست $title خالی است.');
      return null;
    }
    return showSearchableMultiOptionSheet(
      context: context,
      title: title,
      options: options,
      currentIds: currentIds,
    );
  }

  Set<String> _assistantLabels() {
    final labels = <String>{};
    for (final id in _selectedAssistantIds) {
      final label = _personLabelsById[id];
      if (label != null && label.trim().isNotEmpty) {
        labels.add(label);
      }
    }
    return labels;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('فرم ایجاد حفاری'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: 'راهنمای فرم',
              onPressed: () => showFormInfo(
                'راهنمای فرم ایجاد حفاری',
                'فیلدهای اصلی (الزامی): گمانه، دستگاه حفاری، متراژ کیسینگ، تاریخ حفاری، شیفت، نوع شکستگی، نوع سنگ، رنگ سنگ، حفار، سرشیفت.\n'
                    'پرسنل کمک حفار اختیاری است.\n'
                    'برای هر ران، زمان شروع/پایان، متراژ شروع/پایان، سایز سرمته، درصد آب برگشتی و رنگ آب را وارد کنید.',
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: _pagePadding(context),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isLoadingLookups) ...[
                    const LinearProgressIndicator(),
                    const SizedBox(height: 12),
                  ],
                  if (_lookupError != null) ...[
                    Text(
                      _lookupError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: _loadLookups,
                        child: const Text('تلاش مجدد'),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    'قسمت حفاری',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  _selectionField(
                    label: 'انتخاب گمانه',
                    value: _selectedBorehole?.title,
                    onTap: () async {
                      final result = await _pickSingleOption(
                        title: 'گمانه',
                        options: _boreholeOptions,
                        initialId: _selectedBorehole?.id,
                      );
                      if (result != null) {
                        setState(() => _selectedBorehole = result);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _selectionField(
                    label: 'انتخاب دستگاه حفاری',
                    value: _selectedDrillMachine?.title,
                    onTap: () async {
                      final result = await _pickSingleOption(
                        title: 'دستگاه حفاری',
                        options: _machineOptions,
                        initialId: _selectedDrillMachine?.id,
                      );
                      if (result != null) {
                        setState(() => _selectedDrillMachine = result);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildNumberField(
                    _casingLengthController,
                    'متراژ کیسینگ (متر)',
                  ),
                  const SizedBox(height: 16),
                  _selectionField(
                    label: 'تاریخ حفاری',
                    value: formatJalaliDate(_drillingDate),
                    onTap: () async {
                      final result = await pickJalaliDate(
                        initialDate: _drillingDate,
                      );
                      if (result != null) {
                        setState(() => _drillingDate = result);
                      }
                    },
                    placeholder: 'انتخاب تاریخ',
                    icon: Icons.event,
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<DrillShift>(
                    segments: DrillShift.values
                        .map(
                          (shift) => ButtonSegment<DrillShift>(
                            value: shift,
                            label: Text(shift.label),
                          ),
                        )
                        .toList(),
                    selected: {_selectedShift},
                    onSelectionChanged: (selection) {
                      if (selection.isNotEmpty) {
                        setState(() => _selectedShift = selection.first);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _selectionField(
                    label: 'نوع شکستگی',
                    value: _selectedFractureType?.title,
                    onTap: () async {
                      final result = await _pickSingleOption(
                        title: 'نوع شکستگی',
                        options: _fractureOptions,
                        initialId: _selectedFractureType?.id,
                      );
                      if (result != null) {
                        setState(() => _selectedFractureType = result);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _selectionField(
                    label: 'نوع سنگ',
                    value: _selectedRockType?.title,
                    onTap: () async {
                      final result = await _pickSingleOption(
                        title: 'نوع سنگ',
                        options: _stoneOptions,
                        initialId: _selectedRockType?.id,
                      );
                      if (result != null) {
                        setState(() => _selectedRockType = result);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _selectionField(
                    label: 'رنگ سنگ',
                    value: _selectedRockColor?.title,
                    onTap: () async {
                      final result = await _pickSingleOption(
                        title: 'رنگ سنگ',
                        options: _rockColorOptions,
                        initialId: _selectedRockColor?.id,
                      );
                      if (result != null) {
                        setState(() => _selectedRockColor = result);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _selectionField(
                    label: 'حفار',
                    value: _selectedDriller?.title,
                    onTap: () async {
                      final result = await _pickSingleOption(
                        title: 'حفار',
                        options: _personOptions,
                        initialId: _selectedDriller?.id,
                      );
                      if (result != null) {
                        setState(() => _selectedDriller = result);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _selectionField(
                    label: 'سرشیفت',
                    value: _selectedShiftLeader?.title,
                    onTap: () async {
                      final result = await _pickSingleOption(
                        title: 'سرشیفت',
                        options: _personOptions,
                        initialId: _selectedShiftLeader?.id,
                      );
                      if (result != null) {
                        setState(() => _selectedShiftLeader = result);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _multiSelectionField(
                    label: 'پرسنل کمک حفار',
                    values: _assistantLabels(),
                    onTap: () async {
                      final result = await _pickMultiOption(
                        title: 'پرسنل کمک حفار',
                        options: _personOptions,
                        currentIds: _selectedAssistantIds,
                      );
                      if (result != null) {
                        setState(() {
                          _selectedAssistantIds
                            ..clear()
                            ..addAll(result);
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'قسمت ران',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  ..._runs.asMap().entries.map(
                    (entry) => _buildRunCard(entry.key, entry.value),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: _addRun,
                      icon: const Icon(Icons.add),
                      label: const Text('افزودن ران'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('ثبت فرم'),
                      onPressed: _isSubmitting ? null : _handleSubmit,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _addRun() {
    setState(() {
      _runs.add(_DrillingRunEntry());
    });
  }

  void _removeRun(int index) {
    if (_runs.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حداقل یک ران باید ثبت شود.')),
      );
      return;
    }
    setState(() {
      final removed = _runs.removeAt(index);
      removed.dispose();
    });
  }

  String? _formatTime(TimeOfDay? time) {
    if (time == null) {
      return null;
    }
    final text =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    return _toPersianDigits(text);
  }

  Future<void> _pickRunTime(
    _DrillingRunEntry run, {
    required bool isStart,
  }) async {
    final initialTime = isStart ? run.startTime : run.endTime;
    final selected = await showTimePicker(
      context: context,
      initialTime: initialTime ?? TimeOfDay.now(),
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(alwaysUse24HourFormat: true),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
    if (selected == null) {
      return;
    }
    setState(() {
      if (isStart) {
        run.startTime = selected;
      } else {
        run.endTime = selected;
      }
    });
  }

  Widget _buildRunCard(int index, _DrillingRunEntry run) {
    final runTitle = _toPersianDigits('ران ${index + 1}');
    return Card(
      child: ExpansionTile(
        title: Text(runTitle),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: 'حذف ران',
          onPressed: () => _removeRun(index),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              children: [
                _buildTextField(run.waterColorController, 'رنگ آب'),
                const SizedBox(height: 16),
                _buildNumberField(
                  run.waterReturnPercentController,
                  'درصد آب برگشتی',
                ),
                const SizedBox(height: 16),
                _buildNumberField(run.bitSizeController, 'سایز سرمته'),
                const SizedBox(height: 16),
                _selectionField(
                  label: 'زمان شروع',
                  value: _formatTime(run.startTime),
                  onTap: () => _pickRunTime(run, isStart: true),
                  placeholder: 'انتخاب زمان',
                  icon: Icons.access_time,
                ),
                const SizedBox(height: 16),
                _selectionField(
                  label: 'زمان پایان',
                  value: _formatTime(run.endTime),
                  onTap: () => _pickRunTime(run, isStart: false),
                  placeholder: 'انتخاب زمان',
                  icon: Icons.access_time,
                ),
                const SizedBox(height: 16),
                _buildNumberField(run.startFromController, 'شروع از'),
                const SizedBox(height: 16),
                _buildNumberField(run.endToController, 'پایان تا'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (_isSubmitting) {
      return;
    }
    final missingSelections = <String>[];
    if (_selectedBorehole == null) missingSelections.add('گمانه');
    if (_selectedDrillMachine == null) missingSelections.add('دستگاه حفاری');
    if (_drillingDate == null) missingSelections.add('تاریخ حفاری');
    if (_selectedFractureType == null) missingSelections.add('نوع شکستگی');
    if (_selectedRockType == null) missingSelections.add('نوع سنگ');
    if (_selectedRockColor == null) missingSelections.add('رنگ سنگ');
    if (_selectedDriller == null) missingSelections.add('حفار');
    if (_selectedShiftLeader == null) missingSelections.add('سرشیفت');
    if (_runs.isEmpty) missingSelections.add('ران');

    if (missingSelections.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('لطفا ${missingSelections.join('، ')} را تکمیل کنید.'),
          backgroundColor: Colors.orange.shade700,
        ),
      );
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final hasMissingTimes = _runs.any(
      (run) => run.startTime == null || run.endTime == null,
    );
    if (hasMissingTimes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('زمان شروع و پایان هر ران را وارد کنید.')),
      );
      return;
    }

    final casingLength = _parseInt(_casingLengthController.text);
    if (casingLength == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('متراژ کیسینگ معتبر وارد کنید.')),
      );
      return;
    }

    final runsPayload = <Map<String, dynamic>>[];
    for (final run in _runs) {
      final startDepth = _parseInt(run.startFromController.text);
      final endDepth = _parseInt(run.endToController.text);
      final bitSize = _parseInt(run.bitSizeController.text);
      final returnPercent = _parseInt(run.waterReturnPercentController.text);
      if (startDepth == null ||
          endDepth == null ||
          bitSize == null ||
          returnPercent == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('اطلاعات عددی ران‌ها را کامل کنید.')),
        );
        return;
      }
      runsPayload.add({
        'start_depth': startDepth,
        'end_depth': endDepth,
        'start_time': _formatApiTime(run.startTime!),
        'end_time': _formatApiTime(run.endTime!),
        'boring_bit_size': bitSize,
        'return_water_percentage': returnPercent,
        'water_color': run.waterColorController.text.trim(),
      });
    }

    final reportPayload = {
      'conjecture': _selectedBorehole!.id,
      'machine': _selectedDrillMachine!.id,
      'casing_length': casingLength,
      'report_date': _formatApiDate(_drillingDate!),
      'shift': _selectedShift == DrillShift.day ? 220 : 221,
      'crack_type': _selectedFractureType!.id,
      'ore': _selectedRockType!.id,
      'stone_color': _selectedRockColor!.id,
      'driller': _selectedDriller!.id,
      'shift_man': _selectedShiftLeader!.id,
      'driller_helpers': _selectedAssistantIds.toList(),
    };

    final now = DateTime.now();
    final submission = FormSubmission(
      formType: FormTypes.drilling,
      title: 'فرم ایجاد حفاری',
      description:
          'گمانه: ${_selectedBorehole!.title} - دستگاه: ${_selectedDrillMachine!.title}',
      payload: {'report': reportPayload, 'runs': runsPayload},
      createdAt: now,
      updatedAt: now,
      status: 'pending',
    );

    setState(() => _isSubmitting = true);
    try {
      await appRepository.queueFormSubmission(submission);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _toPersianDigits('فرم ثبت شد و در صف ارسال قرار گرفت.'),
          ),
        ),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ثبت فرم با خطا مواجه شد: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}

class _DrillingRunEntry {
  final TextEditingController waterColorController = TextEditingController();
  final TextEditingController waterReturnPercentController =
      TextEditingController();
  final TextEditingController bitSizeController = TextEditingController();
  final TextEditingController startFromController = TextEditingController();
  final TextEditingController endToController = TextEditingController();
  TimeOfDay? startTime;
  TimeOfDay? endTime;

  void dispose() {
    waterColorController.dispose();
    waterReturnPercentController.dispose();
    bitSizeController.dispose();
    startFromController.dispose();
    endToController.dispose();
  }
}

class ConsumablesFormPage extends StatefulWidget {
  const ConsumablesFormPage({
    super.key,
    this.selectedProjectId,
    this.selectedConjectureId,
  });

  final int? selectedProjectId;
  final int? selectedConjectureId;

  @override
  State<ConsumablesFormPage> createState() => _ConsumablesFormPageState();
}

class _ConsumablesFormPageState extends State<ConsumablesFormPage>
    with _FormFieldMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  SelectionOption? _selectedProject;
  SelectionOption? _selectedDrilling;
  SelectionOption? _selectedWarehouse;
  SelectionOption? _selectedItem;
  bool _isLoadingLookups = true;
  bool _isRefreshingDrillings = false;
  bool _isSubmitting = false;
  String? _lookupError;
  bool _didAttemptSync = false;
  List<SelectionOption> _projectOptions = [];
  List<SelectionOption> _drillingOptions = [];
  List<SelectionOption> _allWarehouseOptions = [];
  List<SelectionOption> _warehouseOptions = [];
  List<SelectionOption> _itemOptions = [];

  @override
  void initState() {
    super.initState();
    _loadLookups();
  }

  String? _dailyReportShiftLabel(Map<String, dynamic> raw) {
    final display = raw['shift_display'] ?? raw['shift_label'];
    final displayText = display?.toString().trim() ?? '';
    if (displayText.isNotEmpty) {
      return displayText;
    }
    final shiftValue = raw['shift'];
    final shift = int.tryParse(shiftValue?.toString() ?? '');
    if (shift == 220) return 'روز';
    if (shift == 221) return 'شب';
    return null;
  }

  String _dailyReportOptionTitle(DailyReportNameOption item) {
    final base = item.name.trim().isEmpty
        ? 'حفاری ${item.id}'
        : item.name.trim();
    if (base.contains('شیفت')) {
      return base;
    }
    final shiftLabel = _dailyReportShiftLabel(item.raw);
    if (shiftLabel == null || shiftLabel.isEmpty) {
      return base;
    }
    return '$base - شیفت $shiftLabel';
  }

  bool _dailyReportsIncludeShift(List<DailyReportNameOption> reports) {
    for (final item in reports) {
      if (item.name.contains('شیفت') ||
          _dailyReportShiftLabel(item.raw) != null) {
        return true;
      }
    }
    return false;
  }

  int? _projectTypeId(Map<String, dynamic> raw) {
    final value = raw['project_type'] ?? raw['type'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  bool _isExploratoryProject(Map<String, dynamic> raw) {
    if (_projectTypeId(raw) == 21) {
      return true;
    }
    final label =
        (raw['project_type_display'] ?? raw['type_display'] ?? raw['type_name'])
            ?.toString() ??
        '';
    return label.contains('اکتشاف');
  }

  int? _storageProjectId(Map<String, dynamic> raw) {
    int? parseId(dynamic value) {
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
        return parseId(map['id'] ?? map['pk'] ?? map['value']);
      }
      return null;
    }

    return parseId(raw['project'] ?? raw['project_id'] ?? raw['projectId']);
  }

  bool _isActiveStorage(Map<String, dynamic> raw) {
    final active = raw['is_active'] ?? raw['active'] ?? raw['isActive'];
    if (active is bool) {
      return active;
    }
    if (active is num) {
      return active != 0;
    }
    if (active is String) {
      final normalized = active.toLowerCase().trim();
      if (normalized.isEmpty) return true;
      return normalized == 'true' ||
          normalized == '1' ||
          normalized == 'active';
    }
    final status = (raw['status'] ?? raw['storage_status'] ?? '')
        .toString()
        .toLowerCase();
    if (status.contains('inactive') ||
        status.contains('disabled') ||
        status.contains('ended')) {
      return false;
    }
    return true;
  }

  List<SelectionOption> _filterWarehousesForProject(int? projectId) {
    if (projectId == null) {
      return const <SelectionOption>[];
    }
    final active = _allWarehouseOptions
        .where((item) => _isActiveStorage(item.raw))
        .toList();
    return active
        .where((item) => _storageProjectId(item.raw) == projectId)
        .toList();
  }

  void _applyWarehouseProjectFilter() {
    final projectId = _selectedProject?.id;
    _warehouseOptions = _filterWarehousesForProject(projectId);
    final selectedWarehouseId = _selectedWarehouse?.id;
    if (selectedWarehouseId != null &&
        !_warehouseOptions.any((item) => item.id == selectedWarehouseId)) {
      _selectedWarehouse = null;
    }
    if (_selectedWarehouse == null && _warehouseOptions.length == 1) {
      _selectedWarehouse = _warehouseOptions.first;
    }
  }

  Future<void> _reloadDrillingOptionsForSelectedProject() async {
    final projectId = _selectedProject?.id;
    setState(() {
      _isRefreshingDrillings = true;
      _lookupError = null;
      _selectedDrilling = null;
      _applyWarehouseProjectFilter();
    });
    try {
      Future<List<DailyReportNameOption>> loadReports() {
        return appRepository.getDailyReportNames(
          projectId: projectId,
          conjectureId: widget.selectedConjectureId,
        );
      }

      var reports = await loadReports();
      if (!_didAttemptSync &&
          (reports.isEmpty || !_dailyReportsIncludeShift(reports))) {
        _didAttemptSync = true;
        try {
          await appRepository.syncConsumablesLookups(
            projectId: projectId,
            conjectureId: widget.selectedConjectureId,
          );
        } catch (_) {}
        reports = await loadReports();
      }
      if (!mounted) return;
      setState(() {
        _drillingOptions = reports
            .map(
              (item) => SelectionOption(
                id: item.id,
                title: _dailyReportOptionTitle(item),
                raw: item.raw,
              ),
            )
            .toList();
        _isRefreshingDrillings = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isRefreshingDrillings = false;
        _lookupError = 'دریافت حفاری‌های پروژه با خطا مواجه شد.';
      });
    }
  }

  Future<void> _loadLookups() async {
    setState(() {
      _isLoadingLookups = true;
      _isRefreshingDrillings = true;
      _lookupError = null;
    });
    try {
      final requestedProjectId =
          _selectedProject?.id ?? widget.selectedProjectId;
      final shouldHaveReports =
          requestedProjectId != null || widget.selectedConjectureId != null;

      Future<List<Object>> loadLookups() {
        return Future.wait([
          appRepository.getProjects(),
          appRepository.getDailyReportNames(
            projectId: requestedProjectId,
            conjectureId: widget.selectedConjectureId,
          ),
          appRepository.getStorages(),
          appRepository.getMaterials(),
        ]);
      }

      var results = await loadLookups();
      if (!mounted) {
        return;
      }
      var projects = results[0] as List<ProjectOption>;
      var reports = results[1] as List<DailyReportNameOption>;
      var storages = results[2] as List<StorageOption>;
      var materials = results[3] as List<MaterialOption>;

      if (!_didAttemptSync &&
          (projects.isEmpty ||
              storages.isEmpty ||
              materials.isEmpty ||
              (shouldHaveReports &&
                  (reports.isEmpty || !_dailyReportsIncludeShift(reports))))) {
        _didAttemptSync = true;
        try {
          await appRepository.syncConsumablesLookups(
            projectId: requestedProjectId,
            conjectureId: widget.selectedConjectureId,
          );
          if (projects.isEmpty || storages.isEmpty || materials.isEmpty) {
            await appRepository.syncLookups();
          }
        } catch (_) {
          // Keep cached values if sync fails.
        }
        results = await loadLookups();
        if (!mounted) {
          return;
        }
        projects = results[0] as List<ProjectOption>;
        reports = results[1] as List<DailyReportNameOption>;
        storages = results[2] as List<StorageOption>;
        materials = results[3] as List<MaterialOption>;
      }

      setState(() {
        _projectOptions =
            projects
                .where((item) => !_isExploratoryProject(item.raw))
                .map(
                  (item) => SelectionOption(
                    id: item.id,
                    title: item.name,
                    raw: item.raw,
                  ),
                )
                .toList()
              ..sort((a, b) => a.title.compareTo(b.title));

        final preferredProjectId =
            _selectedProject?.id ?? widget.selectedProjectId;
        if (preferredProjectId != null) {
          final matches = _projectOptions
              .where((item) => item.id == preferredProjectId)
              .toList();
          _selectedProject = matches.isNotEmpty ? matches.first : null;
        }

        _drillingOptions = reports
            .map(
              (item) => SelectionOption(
                id: item.id,
                title: _dailyReportOptionTitle(item),
                raw: item.raw,
              ),
            )
            .toList();
        _allWarehouseOptions = storages
            .map(
              (item) => SelectionOption(
                id: item.id,
                title: item.displayName,
                raw: item.raw,
              ),
            )
            .toList();
        _applyWarehouseProjectFilter();
        _itemOptions = materials
            .map(
              (item) => SelectionOption(
                id: item.id,
                title: item.title,
                raw: item.raw,
              ),
            )
            .toList();
        if (_selectedProject == null) {
          _drillingOptions = const <SelectionOption>[];
        }
        _isLoadingLookups = false;
        _isRefreshingDrillings = false;
      });
    } catch (error) {
      unawaited(appRepository.logAppEvent('consumables_lookup: failed'));
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingLookups = false;
        _isRefreshingDrillings = false;
        _lookupError = 'دریافت داده‌های اولیه با خطا مواجه شد.';
      });
    }
  }

  void _showLookupSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<SelectionOption?> _pickSingleOption({
    required String title,
    required List<SelectionOption> options,
    int? initialId,
  }) async {
    if (_isLoadingLookups || _isRefreshingDrillings) {
      _showLookupSnack('در حال دریافت اطلاعات هستیم.');
      return null;
    }
    if ((title == 'حفاری' || title == 'انبار') && _selectedProject == null) {
      _showLookupSnack('ابتدا پروژه را انتخاب کنید.');
      return null;
    }
    if (options.isEmpty) {
      _showLookupSnack('لیست $title خالی است.');
      return null;
    }
    return showSearchableSingleOptionSheet(
      context: context,
      title: title,
      options: options,
      initialId: initialId,
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('فرم اقلام مصرفی'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: 'راهنمای فرم',
              onPressed: () => showFormInfo(
                'راهنمای فرم اقلام مصرفی',
                'فیلدهای الزامی: پروژه، حفاری، انبار، نام کالا، مقدار.\n'
                    'توضیح اختیاری است.',
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: _pagePadding(context),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isLoadingLookups) ...[
                    const LinearProgressIndicator(),
                    const SizedBox(height: 12),
                  ],
                  if (!_isLoadingLookups && _isRefreshingDrillings) ...[
                    const LinearProgressIndicator(),
                    const SizedBox(height: 12),
                  ],
                  if (_lookupError != null) ...[
                    Text(
                      _lookupError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: _loadLookups,
                        child: const Text('تلاش مجدد'),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  _selectionField(
                    label: 'پروژه',
                    value: _selectedProject?.title,
                    onTap: () async {
                      final result = await _pickSingleOption(
                        title: 'پروژه',
                        options: _projectOptions,
                        initialId: _selectedProject?.id,
                      );
                      if (result == null || _selectedProject?.id == result.id) {
                        return;
                      }
                      setState(() {
                        _selectedProject = result;
                      });
                      await _reloadDrillingOptionsForSelectedProject();
                    },
                  ),
                  const SizedBox(height: 16),
                  _selectionField(
                    label: 'حفاری',
                    value: _selectedDrilling?.title,
                    onTap: () async {
                      final result = await _pickSingleOption(
                        title: 'حفاری',
                        options: _drillingOptions,
                        initialId: _selectedDrilling?.id,
                      );
                      if (result != null) {
                        setState(() => _selectedDrilling = result);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _selectionField(
                    label: 'انبار',
                    value: _selectedWarehouse?.title,
                    onTap: () async {
                      final result = await _pickSingleOption(
                        title: 'انبار',
                        options: _warehouseOptions,
                        initialId: _selectedWarehouse?.id,
                      );
                      if (result != null) {
                        setState(() => _selectedWarehouse = result);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _selectionField(
                    label: 'نام کالا',
                    value: _selectedItem?.title,
                    onTap: () async {
                      final result = await _pickSingleOption(
                        title: 'نام کالا',
                        options: _itemOptions,
                        initialId: _selectedItem?.id,
                      );
                      if (result != null) {
                        setState(() => _selectedItem = result);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildNumberField(_amountController, 'مقدار'),
                  const SizedBox(height: 16),
                  _buildTextField(_descriptionController, 'توضیح', maxLines: 4),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.send),
                      label: const Text('ثبت اقلام مصرفی'),
                      onPressed: _isSubmitting ? null : _handleSubmit,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (_isSubmitting) {
      return;
    }
    if (_selectedDrilling == null ||
        _selectedWarehouse == null ||
        _selectedItem == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لطفا حفاری، انبار و نام کالا را انتخاب کنید.'),
        ),
      );
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final amount = _parseInt(_amountController.text);
    if (amount == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('مقدار معتبر وارد کنید.')));
      return;
    }

    final descriptionText = _descriptionController.text.trim();
    final descriptionParts = <String>[
      'انبار: ${_selectedWarehouse!.title}',
      if (descriptionText.isNotEmpty) 'توضیح: $descriptionText',
    ];
    final description = descriptionParts.join(' - ');

    final payload = <String, dynamic>{
      'report': _selectedDrilling!.id,
      'report_label': _selectedDrilling!.title,
      'material': _selectedItem!.id,
      'material_label': _selectedItem!.title,
      'amount': amount,
      if (description.isNotEmpty) 'description': description,
    };

    final now = DateTime.now();
    final submission = FormSubmission(
      formType: FormTypes.consumables,
      title: 'فرم اقلام مصرفی',
      description:
          'کالا: ${_selectedItem!.title} - انبار: ${_selectedWarehouse!.title}',
      payload: payload,
      createdAt: now,
      updatedAt: now,
      status: 'pending',
    );

    setState(() => _isSubmitting = true);
    try {
      await appRepository.queueFormSubmission(submission);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _toPersianDigits('مصرف ${_selectedItem!.title} ثبت شد.'),
          ),
        ),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ثبت فرم با خطا مواجه شد: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}

class DowntimeFormPage extends StatefulWidget {
  const DowntimeFormPage({
    super.key,
    this.selectedProjectId,
    this.selectedConjectureId,
  });

  final int? selectedProjectId;
  final int? selectedConjectureId;

  @override
  State<DowntimeFormPage> createState() => _DowntimeFormPageState();
}

class _DowntimeFormPageState extends State<DowntimeFormPage>
    with _FormFieldMixin {
  final _formKey = GlobalKey<FormState>();
  DateTime? _startDateTime;
  DateTime? _endDateTime;
  SelectionOption? _selectedDrilling;
  SelectionOption? _selectedReason;
  bool _isLoadingLookups = true;
  bool _isSubmitting = false;
  String? _lookupError;
  bool _didAttemptSync = false;
  List<SelectionOption> _drillingOptions = [];
  List<SelectionOption> _reasonOptions = [];

  @override
  void initState() {
    super.initState();
    _loadLookups();
  }

  String? _dailyReportShiftLabel(Map<String, dynamic> raw) {
    final display = raw['shift_display'] ?? raw['shift_label'];
    final displayText = display?.toString().trim() ?? '';
    if (displayText.isNotEmpty) {
      return displayText;
    }
    final shiftValue = raw['shift'];
    final shift = int.tryParse(shiftValue?.toString() ?? '');
    if (shift == 220) return 'روز';
    if (shift == 221) return 'شب';
    return null;
  }

  String _dailyReportOptionTitle(DailyReportNameOption item) {
    final base = item.name.trim().isEmpty
        ? 'حفاری ${item.id}'
        : item.name.trim();
    if (base.contains('شیفت')) {
      return base;
    }
    final shiftLabel = _dailyReportShiftLabel(item.raw);
    if (shiftLabel == null || shiftLabel.isEmpty) {
      return base;
    }
    return '$base - شیفت $shiftLabel';
  }

  bool _dailyReportsIncludeShift(List<DailyReportNameOption> reports) {
    for (final item in reports) {
      if (item.name.contains('شیفت') ||
          _dailyReportShiftLabel(item.raw) != null) {
        return true;
      }
    }
    return false;
  }

  Future<void> _loadLookups() async {
    setState(() {
      _isLoadingLookups = true;
      _lookupError = null;
    });
    try {
      Future<List<Object>> loadLookups() {
        return Future.wait([
          appRepository.getDailyReportNames(
            projectId: widget.selectedProjectId,
            conjectureId: widget.selectedConjectureId,
          ),
          appRepository.getStopCauses(),
        ]);
      }

      var results = await loadLookups();
      if (!mounted) {
        return;
      }
      var reports = results[0] as List<DailyReportNameOption>;
      var causes = results[1] as List<StopCauseOption>;

      if (!_didAttemptSync &&
          (reports.isEmpty ||
              causes.isEmpty ||
              !_dailyReportsIncludeShift(reports))) {
        _didAttemptSync = true;
        try {
          await appRepository.syncDowntimeLookups(
            projectId: widget.selectedProjectId,
            conjectureId: widget.selectedConjectureId,
          );
        } catch (_) {
          // Keep cached values if sync fails.
        }
        results = await loadLookups();
        if (!mounted) {
          return;
        }
        reports = results[0] as List<DailyReportNameOption>;
        causes = results[1] as List<StopCauseOption>;
      }
      setState(() {
        _drillingOptions = reports
            .map(
              (item) => SelectionOption(
                id: item.id,
                title: _dailyReportOptionTitle(item),
                raw: item.raw,
              ),
            )
            .toList();
        _reasonOptions = causes
            .map(
              (item) => SelectionOption(
                id: item.id,
                title: item.title,
                raw: item.raw,
              ),
            )
            .toList();
        _isLoadingLookups = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingLookups = false;
        _lookupError = 'دریافت داده‌های اولیه با خطا مواجه شد.';
      });
    }
  }

  void _showLookupSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<SelectionOption?> _pickSingleOption({
    required String title,
    required List<SelectionOption> options,
    int? initialId,
  }) async {
    if (_isLoadingLookups) {
      _showLookupSnack('در حال دریافت اطلاعات هستیم.');
      return null;
    }
    if (options.isEmpty) {
      _showLookupSnack('لیست $title خالی است.');
      return null;
    }
    return showSearchableSingleOptionSheet(
      context: context,
      title: title,
      options: options,
      initialId: initialId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('فرم توقف و تاخیرات'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: 'راهنمای فرم',
              onPressed: () => showFormInfo(
                'راهنمای فرم توقف و تاخیرات',
                'فیلدهای الزامی: حفاری، علت توقف، زمان شروع و پایان توقف.\n'
                    'پایان توقف باید بعد از شروع باشد.',
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: _pagePadding(context),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isLoadingLookups) ...[
                    const LinearProgressIndicator(),
                    const SizedBox(height: 12),
                  ],
                  if (_lookupError != null) ...[
                    Text(
                      _lookupError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: _loadLookups,
                        child: const Text('تلاش مجدد'),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  _selectionField(
                    label: 'حفاری',
                    value: _selectedDrilling?.title,
                    onTap: () async {
                      final result = await _pickSingleOption(
                        title: 'حفاری',
                        options: _drillingOptions,
                        initialId: _selectedDrilling?.id,
                      );
                      if (result != null) {
                        setState(() => _selectedDrilling = result);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _selectionField(
                    label: 'علت توقف',
                    value: _selectedReason?.title,
                    onTap: () async {
                      final result = await _pickSingleOption(
                        title: 'علت توقف',
                        options: _reasonOptions,
                        initialId: _selectedReason?.id,
                      );
                      if (result != null) {
                        setState(() => _selectedReason = result);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _selectionField(
                    label: 'شروع توقف',
                    value: _formatJalaliDateTime(_startDateTime),
                    onTap: () => _pickDateTime(isStart: true),
                    placeholder: 'تاریخ و ساعت را انتخاب کنید',
                    icon: Icons.event,
                  ),
                  const SizedBox(height: 16),
                  _selectionField(
                    label: 'پایان توقف',
                    value: _formatJalaliDateTime(_endDateTime),
                    onTap: () => _pickDateTime(isStart: false),
                    placeholder: 'تاریخ و ساعت را انتخاب کنید',
                    icon: Icons.event,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.pause_circle_outline),
                      label: const Text('ثبت توقف'),
                      onPressed: _isSubmitting ? null : _handleSubmit,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final now = DateTime.now();
    final baseValue = isStart ? _startDateTime : _endDateTime;
    final initialDateTime = baseValue ?? now;
    final initialJalali = Jalali.fromDateTime(initialDateTime);
    final jalali = await _showJalaliDatePicker(
      initialDate: initialJalali,
      firstDate: Jalali(initialJalali.year - 2, 1, 1),
      lastDate: Jalali(initialJalali.year + 2, 12, 29),
    );
    if (jalali == null) {
      return;
    }
    if (!mounted) {
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDateTime),
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(alwaysUse24HourFormat: true),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
    if (time == null) {
      return;
    }
    final gregorian = jalali.toDateTime();
    final selected = DateTime(
      gregorian.year,
      gregorian.month,
      gregorian.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (isStart) {
        _startDateTime = selected;
      } else {
        _endDateTime = selected;
      }
    });
  }

  Future<void> _handleSubmit() async {
    if (_isSubmitting) {
      return;
    }
    if (_selectedDrilling == null ||
        _selectedReason == null ||
        _startDateTime == null ||
        _endDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('حفاری، علت توقف و بازه زمانی باید مشخص شود.'),
        ),
      );
      return;
    }
    if (_endDateTime!.isBefore(_startDateTime!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('پایان توقف باید بعد از شروع باشد.')),
      );
      return;
    }
    if (!(_formKey.currentState?.validate() ?? true)) {
      return;
    }

    final payload = {
      'report': _selectedDrilling!.id,
      'report_label': _selectedDrilling!.title,
      'start_time': _formatApiTime(TimeOfDay.fromDateTime(_startDateTime!)),
      'end_time': _formatApiTime(TimeOfDay.fromDateTime(_endDateTime!)),
      'cause_id': _selectedReason!.id,
      'cause_label': _selectedReason!.title,
    };

    final now = DateTime.now();
    final submission = FormSubmission(
      formType: FormTypes.downtime,
      title: 'فرم توقف و تاخیرات',
      description: 'علت: ${_selectedReason!.title}',
      payload: payload,
      createdAt: now,
      updatedAt: now,
      status: 'pending',
    );

    setState(() => _isSubmitting = true);
    try {
      await appRepository.queueFormSubmission(submission);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _toPersianDigits('توقف "${_selectedReason!.title}" ثبت شد.'),
          ),
        ),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ثبت فرم با خطا مواجه شد: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String? _formatJalaliDateTime(DateTime? value) {
    if (value == null) {
      return null;
    }
    final jalali = Jalali.fromDateTime(value);
    final dayName = _normalizeDayName(jalali.formatter.wN);
    final dateText =
        '$dayName، ${jalali.formatter.d} ${jalali.formatter.mN} ${jalali.year}';
    final time =
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    return _toPersianDigits('$dateText - ساعت $time');
  }
}

class VehicleDriverSelectionFormPage extends StatefulWidget {
  const VehicleDriverSelectionFormPage({super.key, this.initialMachineId});

  final int? initialMachineId;

  @override
  State<VehicleDriverSelectionFormPage> createState() =>
      _VehicleDriverSelectionFormPageState();
}

class _VehicleDriverSelectionFormPageState
    extends State<VehicleDriverSelectionFormPage>
    with _FormFieldMixin {
  final _formKey = GlobalKey<FormState>();
  SelectionOption? _selectedVehicle;
  SelectionOption? _selectedDriver;
  DateTime? _deliveryDate;
  DateTime? _returnDate;
  bool _isLoadingLookups = true;
  bool _isSubmitting = false;
  String? _lookupError;
  bool _didAttemptSync = false;
  List<SelectionOption> _vehicleOptions = [];
  List<SelectionOption> _driverOptions = [];
  Map<int, MachineOption> _machinesById = {};

  @override
  void initState() {
    super.initState();
    _loadLookups();
  }

  Future<void> _loadLookups() async {
    setState(() {
      _isLoadingLookups = true;
      _lookupError = null;
    });
    try {
      Future<List<Object>> loadLookups() {
        return Future.wait([
          appRepository.getMachines(),
          appRepository.getPersons(),
          appRepository.getProjects(),
        ]);
      }

      var results = await loadLookups();
      if (!mounted) {
        return;
      }
      var machines = results[0] as List<MachineOption>;
      var persons = results[1] as List<PersonOption>;
      var projects = results[2] as List<ProjectOption>;

      if (!_didAttemptSync && (machines.isEmpty || persons.isEmpty)) {
        _didAttemptSync = true;
        try {
          await appRepository.syncLookups();
        } catch (_) {
          // Keep cached values if sync fails.
        }
        results = await loadLookups();
        if (!mounted) {
          return;
        }
        machines = results[0] as List<MachineOption>;
        persons = results[1] as List<PersonOption>;
        projects = results[2] as List<ProjectOption>;
      }
      final projectNames = {
        for (final project in projects) project.id: project.name,
      };
      final projectMachines = machines
          .where((item) => item.machineType == 101 || item.machineType == 102)
          .toList();
      setState(() {
        _machinesById = {
          for (final machine in projectMachines) machine.id: machine,
        };
        _vehicleOptions = projectMachines
            .map(
              (item) => SelectionOption(
                id: item.id,
                title: projectNames[item.projectId] == null
                    ? item.displayName
                    : '${item.displayName} - ${projectNames[item.projectId]}',
                raw: item.raw,
              ),
            )
            .toList();
        _driverOptions = persons
            .map(
              (item) => SelectionOption(
                id: item.id,
                title: item.fullName,
                raw: item.raw,
              ),
            )
            .toList();
        if (widget.initialMachineId != null) {
          final match = _vehicleOptions
              .where((item) => item.id == widget.initialMachineId)
              .toList();
          if (match.isNotEmpty) {
            _selectedVehicle = match.first;
          }
        }
        _isLoadingLookups = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingLookups = false;
        _lookupError = 'دریافت داده‌های اولیه با خطا مواجه شد.';
      });
    }
  }

  void _showLookupSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<SelectionOption?> _pickSingleOption({
    required String title,
    required List<SelectionOption> options,
    int? initialId,
  }) async {
    if (_isLoadingLookups) {
      _showLookupSnack('در حال دریافت اطلاعات هستیم.');
      return null;
    }
    if (options.isEmpty) {
      _showLookupSnack('لیست $title خالی است.');
      return null;
    }
    return showSearchableSingleOptionSheet(
      context: context,
      title: title,
      options: options,
      initialId: initialId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('فرم انتخاب راننده ماشین'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: 'راهنمای فرم',
              onPressed: () => showFormInfo(
                'راهنمای فرم انتخاب راننده ماشین',
                'فیلدهای الزامی: خودرو، راننده، تاریخ تحویل و تاریخ برگشت.\n'
                    'تاریخ برگشت باید بعد از تاریخ تحویل باشد.',
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: _pagePadding(context),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isLoadingLookups) ...[
                    const LinearProgressIndicator(),
                    const SizedBox(height: 12),
                  ],
                  if (_lookupError != null) ...[
                    Text(
                      _lookupError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: _loadLookups,
                        child: const Text('تلاش مجدد'),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  _selectionField(
                    label: 'خودروهای درون پروژه',
                    value: _selectedVehicle?.title,
                    onTap: () async {
                      final result = await _pickSingleOption(
                        title: 'خودروهای درون پروژه',
                        options: _vehicleOptions,
                        initialId: _selectedVehicle?.id,
                      );
                      if (result != null) {
                        setState(() => _selectedVehicle = result);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _selectionField(
                    label: 'راننده',
                    value: _selectedDriver?.title,
                    onTap: () async {
                      final result = await _pickSingleOption(
                        title: 'راننده',
                        options: _driverOptions,
                        initialId: _selectedDriver?.id,
                      );
                      if (result != null) {
                        setState(() => _selectedDriver = result);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _selectionField(
                    label: 'تاریخ تحویل',
                    value: formatJalaliDate(_deliveryDate),
                    onTap: () async {
                      final result = await pickJalaliDate(
                        initialDate: _deliveryDate,
                      );
                      if (result != null) {
                        setState(() => _deliveryDate = result);
                      }
                    },
                    placeholder: 'انتخاب تاریخ',
                    icon: Icons.event,
                  ),
                  const SizedBox(height: 16),
                  _selectionField(
                    label: 'تاریخ برگشت',
                    value: formatJalaliDate(_returnDate),
                    onTap: () async {
                      final result = await pickJalaliDate(
                        initialDate: _returnDate,
                      );
                      if (result != null) {
                        setState(() => _returnDate = result);
                      }
                    },
                    placeholder: 'انتخاب تاریخ',
                    icon: Icons.event,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.assignment_turned_in),
                      label: const Text('ثبت فرم'),
                      onPressed: _isSubmitting ? null : _handleSubmit,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (_isSubmitting) {
      return;
    }
    if (_selectedVehicle == null ||
        _selectedDriver == null ||
        _deliveryDate == null ||
        _returnDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('همه فیلدها را تکمیل کنید.')),
      );
      return;
    }
    if (_returnDate!.isBefore(_deliveryDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تاریخ برگشت باید بعد از تحویل باشد.')),
      );
      return;
    }
    if (!(_formKey.currentState?.validate() ?? true)) {
      return;
    }

    final machine = _machinesById[_selectedVehicle!.id];
    final payload = <String, dynamic>{
      if (machine?.projectId != null) 'project': machine!.projectId,
      'machine': _selectedVehicle!.id,
      'driver': _selectedDriver!.id,
      'receive_date': _formatApiDate(_deliveryDate!),
      'return_date': _formatApiDate(_returnDate!),
    };

    final now = DateTime.now();
    final submission = FormSubmission(
      formType: FormTypes.driverSelection,
      title: 'فرم انتخاب راننده ماشین',
      description: 'خودرو: ${_selectedVehicle!.title}',
      payload: payload,
      createdAt: now,
      updatedAt: now,
      status: 'pending',
    );

    setState(() => _isSubmitting = true);
    try {
      await appRepository.queueFormSubmission(submission);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _toPersianDigits(
              'فرم انتخاب راننده برای ${_selectedVehicle!.title} ثبت شد.',
            ),
          ),
        ),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ثبت فرم با خطا مواجه شد: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}

class VehicleDeliveryFormPage extends StatefulWidget {
  const VehicleDeliveryFormPage({super.key});

  @override
  State<VehicleDeliveryFormPage> createState() =>
      _VehicleDeliveryFormPageState();
}

class BoreholeCompletionFormPage extends StatefulWidget {
  const BoreholeCompletionFormPage({super.key});

  @override
  State<BoreholeCompletionFormPage> createState() =>
      _BoreholeCompletionFormPageState();
}

class _BoreholeCompletionFormPageState extends State<BoreholeCompletionFormPage>
    with _FormFieldMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _designedDepthController =
      TextEditingController();
  final TextEditingController _finalDepthController = TextEditingController();
  final TextEditingController _sizePController = TextEditingController();
  final TextEditingController _sizeHController = TextEditingController();
  final TextEditingController _sizeNController = TextEditingController();
  final TextEditingController _blackPipeController = TextEditingController();
  final TextEditingController _casingPController = TextEditingController();
  final TextEditingController _casingHController = TextEditingController();
  final TextEditingController _cementMeterController = TextEditingController();
  final TextEditingController _cementCountController = TextEditingController();
  final TextEditingController _cementScrapeMeterController =
      TextEditingController();
  final TextEditingController _cementScrapeCountController =
      TextEditingController();
  final TextEditingController _waterAsphaltController = TextEditingController();
  final TextEditingController _waterDirtController = TextEditingController();
  final TextEditingController _sampleBoxesController = TextEditingController();
  final TextEditingController _doubleWallController = TextEditingController();
  final TextEditingController _tripleWallController = TextEditingController();
  final TextEditingController _rqdController = TextEditingController();
  final TextEditingController _crController = TextEditingController();
  final TextEditingController _crOreController = TextEditingController();
  final TextEditingController _crWasteController = TextEditingController();
  final TextEditingController _cementBlocksController = TextEditingController();
  final TextEditingController _galvanizedPipeController =
      TextEditingController();
  final TextEditingController _hardnessSoftController = TextEditingController();
  final TextEditingController _hardnessMidController = TextEditingController();
  final TextEditingController _oreLengthController = TextEditingController();
  final TextEditingController _alluviumLengthController =
      TextEditingController();
  final TextEditingController _wasteLengthController = TextEditingController();
  final TextEditingController _bentoniteLengthController =
      TextEditingController();
  final TextEditingController _supermixLengthController =
      TextEditingController();
  final TextEditingController _otherAdditivesController =
      TextEditingController();
  final TextEditingController _pondVolumeController = TextEditingController();
  final TextEditingController _cementStopController = TextEditingController();
  final TextEditingController _surveyLengthController = TextEditingController();
  final TextEditingController _deviceStopController = TextEditingController();
  final TextEditingController _deviceMoveController = TextEditingController();
  final TextEditingController _wellFillDescriptionController =
      TextEditingController();
  final TextEditingController _piezometerPressureController =
      TextEditingController();
  final TextEditingController _piezometerLengthController =
      TextEditingController();
  final TextEditingController _pressureTenBarController =
      TextEditingController();
  final TextEditingController _inchLengthController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  String? _selectedDevice;
  DateTime? _handoverDate;
  DateTime? _startDate;
  DateTime? _endDate;
  String? _photoName;
  String? _photoPath;

  bool _hasPlatform = false;
  bool _movedToNext = false;
  bool _concreted = false;
  bool _wellFilled = false;
  bool _hasPiezometer = false;

  final Set<String> _piezometerPipes = {};

  static const List<String> _devices = [
    'دستگاه 101',
    'دستگاه 205',
    'دستگاه 310',
    'دستگاه 412',
  ];

  static const List<String> _piezometerPipeOptions = [
    'لوله پلی اتیلن',
    'PVC',
    'گالوانیزه',
  ];

  @override
  void dispose() {
    _designedDepthController.dispose();
    _finalDepthController.dispose();
    _sizePController.dispose();
    _sizeHController.dispose();
    _sizeNController.dispose();
    _blackPipeController.dispose();
    _casingPController.dispose();
    _casingHController.dispose();
    _cementMeterController.dispose();
    _cementCountController.dispose();
    _cementScrapeMeterController.dispose();
    _cementScrapeCountController.dispose();
    _waterAsphaltController.dispose();
    _waterDirtController.dispose();
    _sampleBoxesController.dispose();
    _doubleWallController.dispose();
    _tripleWallController.dispose();
    _rqdController.dispose();
    _crController.dispose();
    _crOreController.dispose();
    _crWasteController.dispose();
    _cementBlocksController.dispose();
    _galvanizedPipeController.dispose();
    _hardnessSoftController.dispose();
    _hardnessMidController.dispose();
    _oreLengthController.dispose();
    _alluviumLengthController.dispose();
    _wasteLengthController.dispose();
    _bentoniteLengthController.dispose();
    _supermixLengthController.dispose();
    _otherAdditivesController.dispose();
    _pondVolumeController.dispose();
    _cementStopController.dispose();
    _surveyLengthController.dispose();
    _deviceStopController.dispose();
    _deviceMoveController.dispose();
    _wellFillDescriptionController.dispose();
    _piezometerPressureController.dispose();
    _piezometerLengthController.dispose();
    _pressureTenBarController.dispose();
    _inchLengthController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('فرم اتمام گمانه'), centerTitle: true),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: _pagePadding(context),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _selectionField(
                    label: 'شماره دستگاه',
                    value: _selectedDevice,
                    onTap: () async {
                      final result = await showSearchableSingleSelectionSheet(
                        context: context,
                        title: 'شماره دستگاه',
                        options: _devices,
                        initialValue: _selectedDevice,
                      );
                      if (result != null) {
                        setState(() => _selectedDevice = result);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _datePickerField(
                    label: 'تاریخ تحویل گمانه به پیمانکار',
                    value: _handoverDate,
                    onPick: (value) => setState(() => _handoverDate = value),
                  ),
                  const SizedBox(height: 16),
                  _buildNumberField(
                    _designedDepthController,
                    'متراژ عمق طراحی شده',
                  ),
                  const SizedBox(height: 16),
                  _buildNumberField(
                    _finalDepthController,
                    'متراژ عمق نهایی حفاری شده',
                  ),
                  const SizedBox(height: 16),
                  _datePickerField(
                    label: 'تاریخ شروع حفاری',
                    value: _startDate,
                    onPick: (value) => setState(() => _startDate = value),
                  ),
                  const SizedBox(height: 16),
                  _datePickerField(
                    label: 'تاریخ اتمام حفاری',
                    value: _endDate,
                    onPick: (value) => setState(() => _endDate = value),
                  ),
                  const SizedBox(height: 24),
                  _buildDepthGrid(),
                  const SizedBox(height: 24),
                  _buildResourceSection(),
                  const SizedBox(height: 24),
                  _buildLogisticsSection(),
                  const SizedBox(height: 24),
                  _buildAdditivesSection(),
                  const SizedBox(height: 24),
                  _buildOperationsSection(),
                  const SizedBox(height: 24),
                  _buildPiezometerSection(),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('ثبت اطلاعات'),
                      onPressed: _handleSubmit,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _datePickerField({
    required String label,
    required DateTime? value,
    required ValueChanged<DateTime?> onPick,
  }) {
    return _selectionField(
      label: label,
      value: formatJalaliDate(value),
      onTap: () async {
        final result = await pickJalaliDate(initialDate: value);
        if (result != null) {
          onPick(result);
        }
      },
      placeholder: 'انتخاب تاریخ',
      icon: Icons.event,
    );
  }

  Widget _buildDepthGrid() {
    final fields = <MapEntry<TextEditingController, String>>[
      MapEntry(_sizePController, 'متراژ حفاری با سایز P'),
      MapEntry(_sizeHController, 'متراژ حفاری با سایز H'),
      MapEntry(_sizeNController, 'متراژ حفاری با سایز N'),
      MapEntry(_blackPipeController, 'متراژ حفاری با لوله سیاه'),
      MapEntry(_casingPController, 'متراژ کیسینگ P'),
      MapEntry(_casingHController, 'متراژ کیسینگ H'),
      MapEntry(_cementMeterController, 'متراژ سیمان گمانه'),
      MapEntry(_cementCountController, 'تعداد دفعات سیمان گمانه'),
      MapEntry(_cementScrapeMeterController, 'متراژ تراشیدن سیمان گمانه'),
      MapEntry(_cementScrapeCountController, 'دفعات تراشیدن سیمان گمانه'),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('متراژ حفاری', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...fields.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildNumberField(item.key, item.value),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResourceSection() {
    final fields = <MapEntry<TextEditingController, String>>[
      MapEntry(_waterAsphaltController, 'فاصله حمل آب (آسفالت) کیلومتر'),
      MapEntry(_waterDirtController, 'فاصله حمل آب (خاکی) کیلومتر'),
      MapEntry(_sampleBoxesController, 'تعداد جعبه نمونه'),
      MapEntry(_doubleWallController, 'متراژ حفاری دوجداره'),
      MapEntry(_tripleWallController, 'متراژ حفاری سه جداره'),
      MapEntry(_rqdController, 'میانگین درصد RQD'),
      MapEntry(_crController, 'میانگین درصد CR'),
      MapEntry(_crOreController, 'میانگین درصد CR ماده معدنی'),
      MapEntry(_crWasteController, 'میانگین درصد CR باطله'),
      MapEntry(_cementBlocksController, 'بلوک سیمانی (۵۰×۵۰×۵۰)'),
      MapEntry(_galvanizedPipeController, 'مقدار لوله گالوانیزه جهت سرچاهی'),
      MapEntry(_hardnessSoftController, 'متراژ حفاری سختی ۰-۵.۵ موس'),
      MapEntry(_hardnessMidController, 'متراژ حفاری سختی ۵.۵-۷ موس'),
      MapEntry(_oreLengthController, 'متراژ ماده معدنی'),
      MapEntry(_alluviumLengthController, 'متراژ آبرفت'),
      MapEntry(_wasteLengthController, 'متراژ باطله'),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'مقادیر ثبت شده',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ...fields.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildNumberField(item.key, item.value),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogisticsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'لجستیک و توقف‌ها',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _buildNumberField(
              _bentoniteLengthController,
              'متراژ حفاری با بنتونیت',
            ),
            const SizedBox(height: 12),
            _buildNumberField(
              _supermixLengthController,
              'متراژ حفاری با سوپرمیکس',
            ),
            const SizedBox(height: 12),
            _buildNumberField(
              _otherAdditivesController,
              'متراژ حفاری با سایر افزودنی‌ها',
            ),
            const SizedBox(height: 12),
            _buildNumberField(
              _pondVolumeController,
              'احداث و تجهیز حوضچه (متر مکعب)',
            ),
            const SizedBox(height: 12),
            _buildNumberField(
              _cementStopController,
              'میزان توقف حفاری به علت سیمان کاری (ساعت)',
            ),
            const SizedBox(height: 12),
            _buildNumberField(
              _surveyLengthController,
              'انحراف سنجی گمانه (متر)',
            ),
            const SizedBox(height: 12),
            _buildNumberField(
              _deviceStopController,
              'میزان توقف عملیات حفاری به ازای هر دستگاه و افراد (دستگاه روز)',
            ),
            const SizedBox(height: 12),
            _buildNumberField(
              _deviceMoveController,
              'جابجایی هر دستگاه و تجهیزات بین گمانه (دستگاه روز)',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdditivesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            SwitchListTile(
              title: const Text('ایجاد محوطه/سکوی حفاری'),
              value: _hasPlatform,
              onChanged: (value) => setState(() => _hasPlatform = value),
            ),
            SwitchListTile(
              title: const Text('جابجایی دستگاه برای گمانه بعدی'),
              value: _movedToNext,
              onChanged: (value) => setState(() => _movedToNext = value),
            ),
            SwitchListTile(
              title: const Text('مهار کردن دستگاه با بتن'),
              value: _concreted,
              onChanged: (value) => setState(() => _concreted = value),
            ),
            SwitchListTile(
              title: const Text('پر کردن چاه'),
              value: _wellFilled,
              onChanged: (value) => setState(() => _wellFilled = value),
            ),
            if (_wellFilled)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _buildTextField(
                  _wellFillDescriptionController,
                  'شرح مواد پرکننده چاه',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOperationsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final picked = await _imagePicker.pickImage(
                        source: ImageSource.gallery,
                      );
                      if (picked != null) {
                        setState(() {
                          _photoName = picked.name;
                          _photoPath = picked.path;
                        });
                      }
                    },
                    icon: const Icon(Icons.upload_file),
                    label: const Text('انتخاب عکس رنگی'),
                  ),
                ),
              ],
            ),
            if (_photoName != null) ...[
              const SizedBox(height: 12),
              Text(
                'فایل انتخاب شده: ${_photoName!}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (_photoPath != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(_photoPath!),
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ],
            const SizedBox(height: 16),
            _buildNumberField(_pressureTenBarController, 'فشار ۱۰ بار قطر'),
            const SizedBox(height: 12),
            _buildNumberField(_inchLengthController, 'اینچ با متراژ'),
            const SizedBox(height: 12),
            _buildTextField(_descriptionController, 'توضیحات', maxLines: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildPiezometerSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              title: const Text('پیزومتری'),
              value: _hasPiezometer,
              onChanged: (value) => setState(() => _hasPiezometer = value),
            ),
            if (_hasPiezometer) ...[
              const SizedBox(height: 8),
              _multiSelectionField(
                label: 'نوع لوله پیزومتری',
                values: _piezometerPipes,
                onTap: () async {
                  final result = await showSearchableMultiSelectionSheet(
                    context: context,
                    title: 'انتخاب لوله',
                    options: _piezometerPipeOptions,
                    currentValues: _piezometerPipes,
                  );
                  if (result != null) {
                    setState(() {
                      _piezometerPipes
                        ..clear()
                        ..addAll(result);
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              _buildNumberField(
                _piezometerPressureController,
                'فشار ۱۰ بار قطر (پیزومتر)',
              ),
              const SizedBox(height: 12),
              _buildNumberField(_piezometerLengthController, 'متراژ پیزومتری'),
            ],
          ],
        ),
      ),
    );
  }

  void _handleSubmit() {
    if (_selectedDevice == null ||
        _handoverDate == null ||
        _startDate == null ||
        _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لطفا دستگاه و تاریخ‌های اصلی را تکمیل کنید.'),
        ),
      );
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _toPersianDigits('اتمام گمانه برای ${_selectedDevice!} ثبت شد.'),
        ),
      ),
    );
  }
}

class BoreholeCreationFormPage extends StatefulWidget {
  const BoreholeCreationFormPage({super.key});

  @override
  State<BoreholeCreationFormPage> createState() =>
      _BoreholeCreationFormPageState();
}

class RepairRequestFormPage extends StatefulWidget {
  const RepairRequestFormPage({super.key});

  @override
  State<RepairRequestFormPage> createState() => _RepairRequestFormPageState();
}

class PeriodicServiceFormPage extends StatefulWidget {
  const PeriodicServiceFormPage({super.key});

  @override
  State<PeriodicServiceFormPage> createState() =>
      _PeriodicServiceFormPageState();
}

class _PeriodicServiceFormPageState extends State<PeriodicServiceFormPage>
    with _FormFieldMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _kilometerController = TextEditingController();
  final TextEditingController _mechanicController = TextEditingController();

  DateTime? _serviceDate;
  String? _selectedDriver;
  String? _selectedCycle;

  bool _oilFilter = false;
  bool _fuelFilter = false;
  bool _greaseFilter = false;
  bool _engineOil = false;
  bool _gearOil = false;
  bool _diffOil = false;

  static const List<String> _drivers = [
    'علی حیدری',
    'مسعود نیازی',
    'مریم سراج',
    'هادی نجفی',
  ];

  static const List<String> _cycles = [
    '۵۰۰۰ کیلومتر',
    '۱۰۰۰۰ کیلومتر',
    '۱۵۰۰۰ کیلومتر',
  ];

  @override
  void dispose() {
    _kilometerController.dispose();
    _mechanicController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('فرم سرویس دوره‌ای'),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: _pagePadding(context),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _selectionField(
                    label: 'تاریخ انجام سرویس',
                    value: formatJalaliDate(_serviceDate),
                    onTap: () async {
                      final result = await pickJalaliDate(
                        initialDate: _serviceDate,
                      );
                      if (result != null) {
                        setState(() => _serviceDate = result);
                      }
                    },
                    placeholder: 'انتخاب تاریخ',
                    icon: Icons.event,
                  ),
                  const SizedBox(height: 16),
                  _buildNumberField(
                    _kilometerController,
                    'کیلومتر انجام سرویس',
                  ),
                  const SizedBox(height: 16),
                  _selectionField(
                    label: 'نام راننده',
                    value: _selectedDriver,
                    onTap: () async {
                      final result = await showSearchableSingleSelectionSheet(
                        context: context,
                        title: 'راننده',
                        options: _drivers,
                        initialValue: _selectedDriver,
                      );
                      if (result != null) {
                        setState(() => _selectedDriver = result);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(_mechanicController, 'سرویس کار'),
                  const SizedBox(height: 16),
                  _selectionField(
                    label: 'دوره',
                    value: _selectedCycle,
                    onTap: () async {
                      final result = await showSearchableSingleSelectionSheet(
                        context: context,
                        title: 'دوره سرویس',
                        options: _cycles,
                        initialValue: _selectedCycle,
                      );
                      if (result != null) {
                        setState(() => _selectedCycle = result);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildServiceChecklist(),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.car_repair),
                      label: const Text('ثبت سرویس'),
                      onPressed: _handleSubmit,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildServiceChecklist() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('موارد سرویس', style: Theme.of(context).textTheme.titleMedium),
            CheckboxListTile(
              value: _oilFilter,
              onChanged: (value) => setState(() => _oilFilter = value ?? false),
              title: const Text('تعویض فیلتر روغن'),
            ),
            CheckboxListTile(
              value: _fuelFilter,
              onChanged: (value) =>
                  setState(() => _fuelFilter = value ?? false),
              title: const Text('تعویض فیلتر صافی بنزین'),
            ),
            CheckboxListTile(
              value: _greaseFilter,
              onChanged: (value) =>
                  setState(() => _greaseFilter = value ?? false),
              title: const Text('تعویض فیلتر گریسکاری'),
            ),
            CheckboxListTile(
              value: _engineOil,
              onChanged: (value) => setState(() => _engineOil = value ?? false),
              title: const Text('تعویض روغن موتور'),
            ),
            CheckboxListTile(
              value: _gearOil,
              onChanged: (value) => setState(() => _gearOil = value ?? false),
              title: const Text('تعویض روغن گیربکس'),
            ),
            CheckboxListTile(
              value: _diffOil,
              onChanged: (value) => setState(() => _diffOil = value ?? false),
              title: const Text('تعویض روغن دیفرانسیل'),
            ),
          ],
        ),
      ),
    );
  }

  void _handleSubmit() {
    if (_serviceDate == null ||
        _selectedDriver == null ||
        _selectedCycle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تاریخ، راننده و دوره را تکمیل کنید.')),
      );
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _toPersianDigits('سرویس دوره‌ای برای $_selectedDriver ثبت شد.'),
        ),
      ),
    );
  }
}

class VehicleInspectionFormPage extends StatefulWidget {
  const VehicleInspectionFormPage({super.key, this.initialMachineId});

  final int? initialMachineId;

  @override
  State<VehicleInspectionFormPage> createState() =>
      _VehicleInspectionFormPageState();
}

class _VehicleInspectionFormPageState extends State<VehicleInspectionFormPage>
    with _FormFieldMixin {
  final _formKey = GlobalKey<FormState>();
  DateTime? _submitDate;
  SelectionOption? _selectedSender;
  SelectionOption? _selectedCity;
  SelectionOption? _selectedMachine;
  List<ChecklistOption> _checklists = [];
  final Map<int, ConditionQuality> _checkValues = {};
  bool _isLoadingLookups = true;
  bool _isLoadingChecklists = false;
  bool _isSubmitting = false;
  String? _lookupError;
  String? _checklistError;
  bool _didAttemptSync = false;
  List<SelectionOption> _senderOptions = [];
  List<SelectionOption> _cityOptions = [];
  List<SelectionOption> _machineOptions = [];
  Map<int, MachineOption> _machinesById = {};

  @override
  void initState() {
    super.initState();
    _loadLookups();
  }

  Future<void> _loadLookups() async {
    setState(() {
      _isLoadingLookups = true;
      _lookupError = null;
    });
    try {
      Future<List<Object>> loadLookups() {
        return Future.wait([
          appRepository.getMachines(),
          appRepository.getPersons(),
          appRepository.getCities(),
        ]);
      }

      var results = await loadLookups();
      if (!mounted) {
        return;
      }
      var machines = results[0] as List<MachineOption>;
      var persons = results[1] as List<PersonOption>;
      var cities = results[2] as List<CityOption>;

      if (!_didAttemptSync &&
          (machines.isEmpty || persons.isEmpty || cities.isEmpty)) {
        _didAttemptSync = true;
        try {
          await appRepository.syncLookups();
        } catch (_) {
          // Keep cached values if sync fails.
        }
        results = await loadLookups();
        if (!mounted) {
          return;
        }
        machines = results[0] as List<MachineOption>;
        persons = results[1] as List<PersonOption>;
        cities = results[2] as List<CityOption>;
      }
      final filteredMachines = machines
          .where((item) => item.machineType == 101 || item.machineType == 102)
          .toList();
      MachineOption? preselectedMachine;
      setState(() {
        _machinesById = {
          for (final machine in filteredMachines) machine.id: machine,
        };
        _machineOptions = filteredMachines
            .map(
              (item) => SelectionOption(
                id: item.id,
                title: item.displayName,
                raw: item.raw,
              ),
            )
            .toList();
        _senderOptions = persons
            .map(
              (item) => SelectionOption(
                id: item.id,
                title: item.fullName,
                raw: item.raw,
              ),
            )
            .toList();
        _cityOptions = cities
            .map(
              (item) =>
                  SelectionOption(id: item.id, title: item.name, raw: item.raw),
            )
            .toList();
        if (widget.initialMachineId != null) {
          final match = _machineOptions
              .where((item) => item.id == widget.initialMachineId)
              .toList();
          if (match.isNotEmpty) {
            _selectedMachine = match.first;
            preselectedMachine = _machinesById[match.first.id];
          }
        }
        _isLoadingLookups = false;
      });
      if (preselectedMachine != null) {
        unawaited(_loadChecklistsForMachine(preselectedMachine!));
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingLookups = false;
        _lookupError = 'دریافت داده‌های اولیه با خطا مواجه شد.';
      });
    }
  }

  Future<void> _loadChecklistsForMachine(MachineOption machine) async {
    setState(() {
      _isLoadingChecklists = true;
      _checklistError = null;
    });
    try {
      final checklists = await appRepository.getChecklistsForMachineType(
        machine.machineType,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _checklists = checklists;
        _checkValues
          ..clear()
          ..addEntries(
            checklists.map((item) => MapEntry(item.id, ConditionQuality.good)),
          );
        _isLoadingChecklists = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingChecklists = false;
        _checklistError = 'دریافت چک لیست با خطا مواجه شد.';
      });
    }
  }

  void _showLookupSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<SelectionOption?> _pickSingleOption({
    required String title,
    required List<SelectionOption> options,
    int? initialId,
  }) async {
    if (_isLoadingLookups) {
      _showLookupSnack('در حال دریافت اطلاعات هستیم.');
      return null;
    }
    if (options.isEmpty) {
      _showLookupSnack('لیست $title خالی است.');
      return null;
    }
    return showSearchableSingleOptionSheet(
      context: context,
      title: title,
      options: options,
      initialId: initialId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('چک لیست روزانه ماشین های سبک و سنگین'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: 'راهنمای فرم',
              onPressed: () => showFormInfo(
                'راهنمای چک لیست ماشین‌های سبک و سنگین',
                'فیلدهای الزامی: تاریخ ارسال، ارسال کننده، ماشین.\n'
                    'شهر اختیاری است.\n'
                    'پس از انتخاب ماشین، موارد چک لیست را برای هر مورد مشخص کنید.',
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: _pagePadding(context),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isLoadingLookups) ...[
                    const LinearProgressIndicator(),
                    const SizedBox(height: 12),
                  ],
                  if (_lookupError != null) ...[
                    Text(
                      _lookupError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: _loadLookups,
                        child: const Text('تلاش مجدد'),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  _selectionField(
                    label: 'تاریخ ارسال',
                    value: formatJalaliDate(_submitDate),
                    onTap: () async {
                      final result = await pickJalaliDate(
                        initialDate: _submitDate,
                      );
                      if (result != null) {
                        setState(() => _submitDate = result);
                      }
                    },
                    placeholder: 'انتخاب تاریخ',
                    icon: Icons.event,
                  ),
                  const SizedBox(height: 16),
                  _selectionField(
                    label: 'ارسال کننده',
                    value: _selectedSender?.title,
                    onTap: () async {
                      final result = await _pickSingleOption(
                        title: 'ارسال کننده',
                        options: _senderOptions,
                        initialId: _selectedSender?.id,
                      );
                      if (result != null) {
                        setState(() => _selectedSender = result);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _selectionField(
                    label: 'ماشین',
                    value: _selectedMachine?.title,
                    onTap: () async {
                      final result = await _pickSingleOption(
                        title: 'ماشین',
                        options: _machineOptions,
                        initialId: _selectedMachine?.id,
                      );
                      if (result != null) {
                        final machine = _machinesById[result.id];
                        setState(() {
                          _selectedMachine = result;
                          _checklists = [];
                          _checkValues.clear();
                        });
                        if (machine != null) {
                          _loadChecklistsForMachine(machine);
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _selectionField(
                    label: 'شهر',
                    value: _selectedCity?.title,
                    onTap: () async {
                      final result = await _pickSingleOption(
                        title: 'شهر',
                        options: _cityOptions,
                        initialId: _selectedCity?.id,
                      );
                      if (result != null) {
                        setState(() => _selectedCity = result);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildChecksCard(),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.check),
                      label: const Text('ثبت چک لیست'),
                      onPressed: _isSubmitting ? null : _handleSubmit,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChecksCard() {
    if (_isLoadingChecklists) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (_checklistError != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _checklistError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () {
                    final machine = _selectedMachine == null
                        ? null
                        : _machinesById[_selectedMachine!.id];
                    if (machine != null) {
                      _loadChecklistsForMachine(machine);
                    }
                  },
                  child: const Text('تلاش مجدد'),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (_checklists.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Text('ابتدا ماشین را انتخاب کنید.'),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: _checklists.map(_buildConditionRow).toList()),
      ),
    );
  }

  Widget _buildConditionRow(ChecklistOption item) {
    final current = _checkValues[item.id] ?? ConditionQuality.good;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(item.title)),
          SegmentedButton<ConditionQuality>(
            segments: ConditionQuality.values
                .map(
                  (value) => ButtonSegment<ConditionQuality>(
                    value: value,
                    label: Text(value.label),
                  ),
                )
                .toList(),
            selected: {current},
            onSelectionChanged: (selection) {
              if (selection.isNotEmpty) {
                setState(() => _checkValues[item.id] = selection.first);
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (_isSubmitting) {
      return;
    }
    if (_submitDate == null ||
        _selectedSender == null ||
        _selectedMachine == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تاریخ ارسال، ارسال کننده و ماشین را انتخاب کنید.'),
        ),
      );
      return;
    }
    if (_checkValues.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('چک لیست بارگذاری نشده است.')),
      );
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final reportDate = DateTime(
      _submitDate!.year,
      _submitDate!.month,
      _submitDate!.day,
    );
    final reportPayload = <String, dynamic>{
      'actor': _selectedSender!.id,
      'report_date': _formatApiDateTime(reportDate),
      'machine': _selectedMachine!.id,
      if (_selectedCity != null) 'location': _selectedCity!.id,
    };
    final items = _checkValues.entries
        .map(
          (entry) => {
            'checklist': entry.key,
            'choice': entry.value == ConditionQuality.good ? 200 : 201,
          },
        )
        .toList();

    final now = DateTime.now();
    final submission = FormSubmission(
      formType: FormTypes.machineChecklistLightHeavy,
      title: 'چک لیست روزانه ماشین های سبک و سنگین',
      description: 'ماشین: ${_selectedMachine!.title}',
      payload: {'report': reportPayload, 'items': items},
      createdAt: now,
      updatedAt: now,
      status: 'pending',
    );

    setState(() => _isSubmitting = true);
    try {
      await appRepository.queueFormSubmission(submission);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('چک لیست روزانه ثبت شد.')));
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ثبت فرم با خطا مواجه شد: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}

class DrillingChecklistFormPage extends StatefulWidget {
  const DrillingChecklistFormPage({super.key, this.initialMachineId});

  final int? initialMachineId;

  @override
  State<DrillingChecklistFormPage> createState() =>
      _DrillingChecklistFormPageState();
}

class _DrillingChecklistFormPageState extends State<DrillingChecklistFormPage>
    with _FormFieldMixin {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  final ScreenProcessorService _screenProcessor = ScreenProcessorService();
  final GaugeOcrService _gaugeOcrService = GaugeOcrService();

  DateTime? _submitDate;
  SelectionOption? _selectedSender;
  SelectionOption? _selectedCity;
  SelectionOption? _selectedMachine;
  String? _photoName;
  String? _photoPath;
  String? _processedImagePath;
  bool _isProcessingPhoto = false;
  String? _processingErrorMessage;
  bool _isRecognizingGauges = false;
  String? _gaugeOcrMessage;
  bool _gaugeCaptured = false;
  bool _isLoadingLookups = true;
  bool _isLoadingChecklists = false;
  bool _isSubmitting = false;
  String? _lookupError;
  String? _checklistError;
  bool _didAttemptSync = false;
  List<SelectionOption> _senderOptions = [];
  List<SelectionOption> _cityOptions = [];
  List<SelectionOption> _machineOptions = [];
  Map<int, MachineOption> _machinesById = {};
  List<ChecklistOption> _checklists = [];
  final Map<int, ConditionQuality> _checkValues = {};
  final Map<String, TextEditingController> _gaugeControllers = {
    for (final key in gaugeBoxOrder) key: TextEditingController(),
  };
  final Map<String, String?> _gaugeFieldErrors = {
    for (final key in gaugeBoxOrder) key: null,
  };

  @override
  void initState() {
    super.initState();
    _loadLookups();
  }

  @override
  void dispose() {
    _discardProcessedFile();
    for (final controller in _gaugeControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadLookups() async {
    setState(() {
      _isLoadingLookups = true;
      _lookupError = null;
    });
    try {
      Future<List<Object>> loadLookups() {
        return Future.wait([
          appRepository.getMachines(),
          appRepository.getPersons(),
          appRepository.getCities(),
        ]);
      }

      var results = await loadLookups();
      if (!mounted) {
        return;
      }
      var machines = results[0] as List<MachineOption>;
      var persons = results[1] as List<PersonOption>;
      var cities = results[2] as List<CityOption>;

      if (!_didAttemptSync &&
          (machines.isEmpty || persons.isEmpty || cities.isEmpty)) {
        _didAttemptSync = true;
        try {
          await appRepository.syncLookups();
        } catch (_) {
          // Keep cached values if sync fails.
        }
        results = await loadLookups();
        if (!mounted) {
          return;
        }
        machines = results[0] as List<MachineOption>;
        persons = results[1] as List<PersonOption>;
        cities = results[2] as List<CityOption>;
      }
      final drillingMachines = machines
          .where((item) => item.machineType == 100)
          .toList();
      MachineOption? preselectedMachine;
      setState(() {
        _machinesById = {
          for (final machine in drillingMachines) machine.id: machine,
        };
        _machineOptions = drillingMachines
            .map(
              (item) => SelectionOption(
                id: item.id,
                title: item.displayName,
                raw: item.raw,
              ),
            )
            .toList();
        _senderOptions = persons
            .map(
              (item) => SelectionOption(
                id: item.id,
                title: item.fullName,
                raw: item.raw,
              ),
            )
            .toList();
        _cityOptions = cities
            .map(
              (item) =>
                  SelectionOption(id: item.id, title: item.name, raw: item.raw),
            )
            .toList();
        if (widget.initialMachineId != null) {
          final match = _machineOptions
              .where((item) => item.id == widget.initialMachineId)
              .toList();
          if (match.isNotEmpty) {
            _selectedMachine = match.first;
            preselectedMachine = _machinesById[match.first.id];
          }
        }
        _isLoadingLookups = false;
      });
      if (preselectedMachine != null) {
        unawaited(_loadChecklistsForMachine(preselectedMachine!));
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingLookups = false;
        _lookupError = 'دریافت داده‌های اولیه با خطا مواجه شد.';
      });
    }
  }

  Future<void> _loadChecklistsForMachine(MachineOption machine) async {
    setState(() {
      _isLoadingChecklists = true;
      _checklistError = null;
    });
    try {
      final checklists = await appRepository.getChecklistsForMachineType(
        machine.machineType,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _checklists = checklists;
        _checkValues
          ..clear()
          ..addEntries(
            checklists.map((item) => MapEntry(item.id, ConditionQuality.good)),
          );
        _isLoadingChecklists = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingChecklists = false;
        _checklistError = 'دریافت چک لیست با خطا مواجه شد.';
      });
    }
  }

  void _showLookupSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<SelectionOption?> _pickSingleOption({
    required String title,
    required List<SelectionOption> options,
    int? initialId,
  }) async {
    if (_isLoadingLookups) {
      _showLookupSnack('در حال دریافت اطلاعات هستیم.');
      return null;
    }
    if (options.isEmpty) {
      _showLookupSnack('لیست $title خالی است.');
      return null;
    }
    return showSearchableSingleOptionSheet(
      context: context,
      title: title,
      options: options,
      initialId: initialId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('چک لیست روزانه ماشین حفاری'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: 'راهنمای فرم',
              onPressed: () => showFormInfo(
                'راهنمای چک لیست ماشین حفاری',
                'فیلدهای الزامی: تاریخ ارسال، ارسال کننده، ماشین.\n'
                    'شهر اختیاری است.\n'
                    'پس از انتخاب ماشین، موارد چک لیست را کامل کنید.\n'
                    'بخش عکس و اعداد گیج‌ها اختیاری است.',
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: _pagePadding(context),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isLoadingLookups) ...[
                    const LinearProgressIndicator(),
                    const SizedBox(height: 12),
                  ],
                  if (_lookupError != null) ...[
                    Text(
                      _lookupError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: _loadLookups,
                        child: const Text('تلاش مجدد'),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  _selectionField(
                    label: 'تاریخ ارسال',
                    value: formatJalaliDate(_submitDate),
                    onTap: () async {
                      final result = await pickJalaliDate(
                        initialDate: _submitDate,
                      );
                      if (result != null) {
                        setState(() => _submitDate = result);
                      }
                    },
                    placeholder: 'انتخاب تاریخ',
                    icon: Icons.event,
                  ),
                  const SizedBox(height: 16),
                  _selectionField(
                    label: 'ارسال کننده',
                    value: _selectedSender?.title,
                    onTap: () async {
                      final result = await _pickSingleOption(
                        title: 'ارسال کننده',
                        options: _senderOptions,
                        initialId: _selectedSender?.id,
                      );
                      if (result != null) {
                        setState(() => _selectedSender = result);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _selectionField(
                    label: 'ماشین',
                    value: _selectedMachine?.title,
                    onTap: () async {
                      final result = await _pickSingleOption(
                        title: 'ماشین',
                        options: _machineOptions,
                        initialId: _selectedMachine?.id,
                      );
                      if (result != null) {
                        final machine = _machinesById[result.id];
                        setState(() {
                          _selectedMachine = result;
                          _checklists = [];
                          _checkValues.clear();
                        });
                        if (machine != null) {
                          _loadChecklistsForMachine(machine);
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _selectionField(
                    label: 'شهر',
                    value: _selectedCity?.title,
                    onTap: () async {
                      final result = await _pickSingleOption(
                        title: 'شهر',
                        options: _cityOptions,
                        initialId: _selectedCity?.id,
                      );
                      if (result != null) {
                        setState(() => _selectedCity = result);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildDrillingChecks(),
                  const SizedBox(height: 16),
                  _buildPhotoSection(),
                  const SizedBox(height: 16),
                  _buildGaugeReadingsCard(),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.assignment_turned_in),
                      label: const Text('ثبت چک لیست'),
                      onPressed: _isSubmitting ? null : _handleSubmit,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrillingChecks() {
    if (_isLoadingChecklists) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (_checklistError != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _checklistError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () {
                    final machine = _selectedMachine == null
                        ? null
                        : _machinesById[_selectedMachine!.id];
                    if (machine != null) {
                      _loadChecklistsForMachine(machine);
                    }
                  },
                  child: const Text('تلاش مجدد'),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (_checklists.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Text('ابتدا ماشین را انتخاب کنید.'),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            ..._checklists.map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(child: Text(item.title)),
                    SegmentedButton<ConditionQuality>(
                      segments: ConditionQuality.values
                          .map(
                            (value) => ButtonSegment<ConditionQuality>(
                              value: value,
                              label: Text(value.label),
                            ),
                          )
                          .toList(),
                      selected: {
                        _checkValues[item.id] ?? ConditionQuality.good,
                      },
                      onSelectionChanged: (selection) {
                        if (selection.isNotEmpty) {
                          setState(
                            () => _checkValues[item.id] = selection.first,
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoSection() {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'عکس نمایشگر دستگاه حفاری',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => showFormInfo(
                  'راهنمای عکس برای هوش مصنوعی',
                  'نمایشگر را کاملا داخل کادر قرار دهید.\n'
                      'نور محیط کافی باشد و از بازتاب نور جلوگیری کنید.\n'
                      'عکس را بدون لرزش و از روبرو بگیرید.\n'
                      'اعداد باید واضح و خوانا باشند.',
                ),
                icon: const Icon(Icons.info_outline, size: 18),
                label: const Text('راهنمای عکس'),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: _isProcessingPhoto
                      ? null
                      : () => _pickDisplayPhoto(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('گرفتن عکس'),
                ),
                OutlinedButton.icon(
                  onPressed: _isProcessingPhoto
                      ? null
                      : () => _pickDisplayPhoto(ImageSource.gallery),
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('انتخاب از گالری'),
                ),
              ],
            ),
            if (_photoName != null) ...[
              const SizedBox(height: 8),
              Text('فایل انتخاب شده: $_photoName'),
            ],
            if (_isProcessingPhoto) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ] else if (_photoPath != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(_photoPath!),
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: _isProcessingPhoto || _photoPath == null
                      ? null
                      : () => _runProcessing(_photoPath!),
                  icon: const Icon(Icons.refresh),
                  label: const Text('پردازش مجدد تصویر'),
                ),
              ),
            ],
            if (_processingErrorMessage != null && !_isProcessingPhoto) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.error_outline, color: theme.colorScheme.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _processingErrorMessage!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGaugeReadingsCard() {
    if (_processedImagePath == null) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('اعداد گیج‌ها', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'پس از OCR می‌توانید هر مقدار را به صورت دستی ویرایش کنید.',
              style: theme.textTheme.bodySmall,
            ),
            if (_isRecognizingGauges) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(color: theme.colorScheme.primary),
              const SizedBox(height: 12),
            ],
            if (_gaugeOcrMessage != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    _gaugeCaptured ? Icons.check_circle : Icons.error_outline,
                    color: _gaugeCaptured
                        ? Colors.green
                        : theme.colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _gaugeOcrMessage!,
                      style: TextStyle(
                        color: _gaugeCaptured
                            ? Colors.green
                            : theme.colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            ...gaugeBoxOrder.map(
              (key) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: _buildNumberField(
                  _gaugeControllers[key]!,
                  gaugeBoxLabels[key] ?? key,
                  errorText: _gaugeFieldErrors[key],
                  onChanged: (_) {
                    if (_gaugeFieldErrors[key] != null) {
                      setState(() {
                        _gaugeFieldErrors[key] = null;
                      });
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDisplayPhoto(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 92,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (picked == null) {
        return;
      }
      setState(() {
        _photoName = picked.name;
        _photoPath = picked.path;
        _discardProcessedFile();
        _processingErrorMessage = null;
      });
      await _runProcessing(picked.path);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _processingErrorMessage = 'امکان دریافت عکس وجود ندارد.';
      });
    }
  }

  Future<void> _runProcessing(String imagePath) async {
    setState(() {
      _isProcessingPhoto = true;
      _processingErrorMessage = null;
      _discardProcessedFile();
    });
    try {
      final result = await _screenProcessor.process(imagePath);
      if (!mounted) {
        return;
      }
      setState(() {
        _processedImagePath = result;
      });
      await _runGaugeOcr(result);
    } on ScreenProcessorException catch (error) {
      setState(() {
        _processingErrorMessage = error.message;
      });
    } catch (_) {
      setState(() {
        _processingErrorMessage = 'پردازش تصویر با خطا مواجه شد.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingPhoto = false;
        });
      }
    }
  }

  Future<void> _runGaugeOcr(String imagePath) async {
    if (!mounted) return;
    setState(() {
      _isRecognizingGauges = true;
      _gaugeOcrMessage = null;
      _gaugeCaptured = false;
    });
    try {
      final readings = await _gaugeOcrService.read(imagePath);
      final errors = <String, String?>{};
      for (final key in gaugeBoxOrder) {
        errors[key] = readings.containsKey(key)
            ? null
            : 'اعداد قابل شناسایی نیست.';
      }
      if (!mounted) return;
      final allCaptured = errors.values.every((value) => value == null);
      setState(() {
        for (final entry in errors.entries) {
          _gaugeFieldErrors[entry.key] = entry.value;
        }
        if (readings.isNotEmpty) {
          _applyGaugeReadings(readings);
          _gaugeCaptured = allCaptured;
          _gaugeOcrMessage = allCaptured
              ? 'اعداد با موفقیت استخراج شدند.'
              : 'برخی فیلدها طی OCR عددی نداشتند.';
        } else {
          _gaugeCaptured = false;
          _gaugeOcrMessage = 'هیچ عددی شناسایی نشد.';
        }
      });
    } on GaugeOcrException catch (error) {
      if (!mounted) return;
      setState(() {
        _gaugeCaptured = false;
        _gaugeOcrMessage = error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _gaugeCaptured = false;
        _gaugeOcrMessage = 'خواندن اعداد با خطا مواجه شد.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isRecognizingGauges = false;
        });
      }
    }
  }

  void _applyGaugeReadings(Map<String, String> readings) {
    for (final entry in readings.entries) {
      final controller = _gaugeControllers[entry.key];
      if (controller != null) {
        controller.text = entry.value;
      }
    }
  }

  void _discardProcessedFile() {
    final previous = _processedImagePath;
    _processedImagePath = null;
    _clearGaugeFields();
    if (previous != null) {
      File(previous).delete().catchError((_) => File(previous));
    }
  }

  void _clearGaugeFields() {
    for (final controller in _gaugeControllers.values) {
      controller.clear();
    }
    _isRecognizingGauges = false;
    _gaugeOcrMessage = null;
    _gaugeCaptured = false;
    for (final key in _gaugeFieldErrors.keys) {
      _gaugeFieldErrors[key] = null;
    }
  }

  Future<void> _handleSubmit() async {
    if (_isSubmitting) {
      return;
    }
    if (_submitDate == null ||
        _selectedSender == null ||
        _selectedMachine == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تاریخ ارسال، ارسال کننده و ماشین را انتخاب کنید.'),
        ),
      );
      return;
    }
    if (_checkValues.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('چک لیست بارگذاری نشده است.')),
      );
      return;
    }

    final reportDate = DateTime(
      _submitDate!.year,
      _submitDate!.month,
      _submitDate!.day,
    );
    final reportPayload = <String, dynamic>{
      'actor': _selectedSender!.id,
      'report_date': _formatApiDateTime(reportDate),
      'machine': _selectedMachine!.id,
      if (_selectedCity != null) 'location': _selectedCity!.id,
    };
    final items = _checkValues.entries
        .map(
          (entry) => {
            'checklist': entry.key,
            'choice': entry.value == ConditionQuality.good ? 200 : 201,
          },
        )
        .toList();

    final now = DateTime.now();
    final submission = FormSubmission(
      formType: FormTypes.machineChecklistDrilling,
      title: 'چک لیست روزانه ماشین حفاری',
      description: 'ماشین: ${_selectedMachine!.title}',
      payload: {'report': reportPayload, 'items': items},
      createdAt: now,
      updatedAt: now,
      status: 'pending',
    );

    setState(() => _isSubmitting = true);
    try {
      await appRepository.queueFormSubmission(submission);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('چک لیست روزانه ثبت شد.')));
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ثبت فرم با خطا مواجه شد: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}

enum RepairPriority { normal, urgent }

extension RepairPriorityInfo on RepairPriority {
  String get label => this == RepairPriority.normal ? 'عادی' : 'ضروری';
}

class _RepairRequestFormPageState extends State<RepairRequestFormPage>
    with _FormFieldMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _equipmentController = TextEditingController();
  final TextEditingController _supplierController = TextEditingController();
  final TextEditingController _costController = TextEditingController();
  final TextEditingController _stopReasonController = TextEditingController();

  DateTime? _startDateTime;
  DateTime? _endDateTime;
  RepairPriority _priority = RepairPriority.normal;
  bool _doInsideCompany = true;
  bool _hasStop = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    _durationController.dispose();
    _equipmentController.dispose();
    _supplierController.dispose();
    _costController.dispose();
    _stopReasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('فرم درخواست تعمیر'),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: _pagePadding(context),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTextField(
                    _descriptionController,
                    'شرح فعالیت درخواستی',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(_durationController, 'مدت زمان فعالیت'),
                  const SizedBox(height: 16),
                  _selectionField(
                    label: 'شروع کار',
                    value: formatJalaliDate(_startDateTime, includeTime: true),
                    onTap: () async {
                      final result = await pickJalaliDateTime(
                        initialDate: _startDateTime,
                      );
                      if (result != null) {
                        setState(() => _startDateTime = result);
                      }
                    },
                    placeholder: 'انتخاب تاریخ و ساعت',
                    icon: Icons.event_available,
                  ),
                  const SizedBox(height: 16),
                  _selectionField(
                    label: 'پایان کار',
                    value: formatJalaliDate(_endDateTime, includeTime: true),
                    onTap: () async {
                      final result = await pickJalaliDateTime(
                        initialDate: _endDateTime,
                      );
                      if (result != null) {
                        setState(() => _endDateTime = result);
                      }
                    },
                    placeholder: 'انتخاب تاریخ و ساعت',
                    icon: Icons.event_busy,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'میزان ضرورت انجام کار',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<RepairPriority>(
                    segments: RepairPriority.values
                        .map(
                          (priority) => ButtonSegment<RepairPriority>(
                            value: priority,
                            label: Text(priority.label),
                          ),
                        )
                        .toList(),
                    selected: {_priority},
                    onSelectionChanged: (selection) {
                      if (selection.isNotEmpty) {
                        setState(() => _priority = selection.first);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('آیا فعالیت داخل شرکت امکان پذیر است؟'),
                    value: _doInsideCompany,
                    onChanged: (value) =>
                        setState(() => _doInsideCompany = value),
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(_equipmentController, 'قطعه تجهیزات'),
                  const SizedBox(height: 16),
                  _buildTextField(_supplierController, 'شرکت تجهیز کننده'),
                  const SizedBox(height: 16),
                  _buildNumberField(_costController, 'هزینه تعمیرات (ریال)'),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('آیا تعمیرات توقف داشته؟'),
                    value: _hasStop,
                    onChanged: (value) => setState(() => _hasStop = value),
                  ),
                  if (_hasStop) ...[
                    const SizedBox(height: 8),
                    _buildTextField(
                      _stopReasonController,
                      'علت توقف',
                      maxLines: 2,
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.build),
                      label: const Text('ثبت درخواست تعمیر'),
                      onPressed: _handleSubmit,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleSubmit() {
    if (_startDateTime == null || _endDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تاریخ‌های شروع و پایان را انتخاب کنید.')),
      );
      return;
    }
    if (_hasStop && _stopReasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('علت توقف را وارد کنید.')));
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('درخواست تعمیر ثبت شد.')));
  }
}

class _BoreholeCreationFormPageState extends State<BoreholeCreationFormPage>
    with _FormFieldMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _coordXController = TextEditingController();
  final TextEditingController _coordYController = TextEditingController();
  final TextEditingController _coordZController = TextEditingController();
  final TextEditingController _angleController = TextEditingController();
  final TextEditingController _azimuthController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void dispose() {
    _nameController.dispose();
    _coordXController.dispose();
    _coordYController.dispose();
    _coordZController.dispose();
    _angleController.dispose();
    _azimuthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('فرم ایجاد گمانه'), centerTitle: true),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: _pagePadding(context),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTextField(_nameController, 'نام گمانه'),
                  const SizedBox(height: 16),
                  _buildNumberField(_coordXController, 'مختصات X'),
                  const SizedBox(height: 16),
                  _buildNumberField(_coordYController, 'مختصات Y'),
                  const SizedBox(height: 16),
                  _buildNumberField(_coordZController, 'مختصات Z'),
                  const SizedBox(height: 16),
                  _buildNumberField(
                    _angleController,
                    'زاویه نسبت به افق (درجه)',
                  ),
                  const SizedBox(height: 16),
                  _buildNumberField(_azimuthController, 'آزیموت (درجه)'),
                  const SizedBox(height: 16),
                  _selectionField(
                    label: 'تاریخ شروع',
                    value: formatJalaliDate(_startDate),
                    onTap: () async {
                      final result = await pickJalaliDate(
                        initialDate: _startDate,
                      );
                      if (result != null) {
                        setState(() => _startDate = result);
                      }
                    },
                    placeholder: 'انتخاب تاریخ',
                    icon: Icons.event,
                  ),
                  const SizedBox(height: 16),
                  _selectionField(
                    label: 'تاریخ پایان',
                    value: formatJalaliDate(_endDate),
                    onTap: () async {
                      final result = await pickJalaliDate(
                        initialDate: _endDate,
                      );
                      if (result != null) {
                        setState(() => _endDate = result);
                      }
                    },
                    placeholder: 'انتخاب تاریخ',
                    icon: Icons.event,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.done),
                      label: const Text('ثبت ایجاد گمانه'),
                      onPressed: _handleSubmit,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleSubmit() {
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تاریخ‌های شروع و پایان را انتخاب کنید.')),
      );
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _toPersianDigits('ایجاد گمانه ${_nameController.text} ثبت شد.'),
        ),
      ),
    );
  }
}

class _VehicleDeliveryFormPageState extends State<VehicleDeliveryFormPage>
    with _FormFieldMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _letterNumberController = TextEditingController();
  final TextEditingController _kilometerController = TextEditingController();
  final TextEditingController _plateController = TextEditingController();
  final TextEditingController _fineUntilController = TextEditingController();
  final TextEditingController _fineRemainingController =
      TextEditingController();
  final TextEditingController _tiresHealthController = TextEditingController();

  ConditionStatus _tiresStatus = ConditionStatus.healthy;

  String? _receiver;
  String? _giver;
  String? _usageLocation;
  String? _commander;

  final Map<String, bool> _accessoryStates = {
    for (final item in _accessoryItems) item: false,
  };

  final Map<String, ConditionStatus> _conditionStates = {
    for (final item in _conditionItems) item: ConditionStatus.healthy,
  };

  static const List<String> _personnelOptions = [
    'مهدی مقدم',
    'سعید رستگار',
    'بهاره نظامی',
    'مجید سعیدی',
    'بهروز مرادی',
  ];

  static const List<String> _usageLocations = [
    'سایت حفاری A',
    'سایت حفاری B',
    'کارگاه مرکزی',
    'ماموریت جاده‌ای',
  ];

  static const List<String> _accessoryItems = [
    'رادیو ضبط',
    'ساعت',
    'فندک',
    'پشتی',
    'لاستیک کفی',
    'قفل فرمان',
    'قفل پدال',
    'آنتن',
    'زاپاس',
    'جک با دسته',
    'کپسول آتش نشانی',
    'علامت خطر',
    'جعبه آچار',
    'پیچ گوشتی چهارسو',
    'پیچ گوشتی دوسو',
    'آچار چرخ',
    'انبردست',
    'آچار فرانسه',
    'قالپاق',
    'گریس پمپ',
    'زنچیر چرخ',
    'چراغ قوه',
    'آچار رینگی',
    'آچار تخت',
    'آچار آلن',
    'انبردست قفلی',
    'کارت سوخت خودرو',
    'کارت بیمه بدنه و شخص ثالث',
    'کارت خودرو',
    'کارت معاینه فنی',
  ];

  static const List<String> _conditionItems = [
    'موتور',
    'اتاق',
    'استارت',
    'گیربکس',
    'صندلی ها',
    'چراغ ها',
    'دیفرانسیل',
    'تودوزی',
    'آمپرها',
    'شاسی',
    'درب‌ها',
    'کیلومتر',
    'رادیاتور',
    'قفل ها',
    'کلید ها',
    'ترمزها',
    'شیشه ها',
    'کولر',
    'رینگ',
    'دستگیره',
    'دزدگیر',
    'چرخ‌ها',
    'آینه‌های خارج',
    'بخاری',
    'باک',
    'آینه داخل',
    'مه‌شکن',
    'فنرها',
    'قالپاق ها',
    'تیغه‌برف‌پاک کن',
    'باطری',
    'آفتاب گیر',
    'دینام',
  ];

  @override
  void dispose() {
    _letterNumberController.dispose();
    _kilometerController.dispose();
    _plateController.dispose();
    _fineUntilController.dispose();
    _fineRemainingController.dispose();
    _tiresHealthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('صورت جلسه تحویل خودرو'),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: _pagePadding(context),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'مشخصات کلی',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  _selectionField(
                    label: 'تحویل گیرنده',
                    value: _receiver,
                    onTap: () => _pickPerson(
                      currentValue: _receiver,
                      onSelected: (value) => setState(() => _receiver = value),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _selectionField(
                    label: 'تحویل دهنده',
                    value: _giver,
                    onTap: () => _pickPerson(
                      currentValue: _giver,
                      onSelected: (value) => setState(() => _giver = value),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _selectionField(
                    label: 'محل استفاده',
                    value: _usageLocation,
                    onTap: () async {
                      final result = await showSearchableSingleSelectionSheet(
                        context: context,
                        title: 'محل استفاده',
                        options: _usageLocations,
                        initialValue: _usageLocation,
                      );
                      if (result != null) {
                        setState(() => _usageLocation = result);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _selectionField(
                    label: 'دستور دهنده',
                    value: _commander,
                    onTap: () => _pickPerson(
                      currentValue: _commander,
                      onSelected: (value) => setState(() => _commander = value),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(_letterNumberController, 'شماره نامه'),
                  const SizedBox(height: 16),
                  _buildNumberField(_kilometerController, 'شماره کیلومتر'),
                  const SizedBox(height: 16),
                  _buildTextField(_plateController, 'شماره انتظامی'),
                  const SizedBox(height: 24),
                  Text(
                    'چک لیست اقلام',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  _buildAccessoryCard(),
                  const SizedBox(height: 24),
                  Text(
                    'وضعیت اجزا',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  _buildConditionCard(),
                  const SizedBox(height: 24),
                  _buildTiresSection(),
                  const SizedBox(height: 24),
                  _buildNumberField(
                    _fineUntilController,
                    'خلافی خودرو تا این تاریخ (ریال)',
                  ),
                  const SizedBox(height: 16),
                  _buildNumberField(
                    _fineRemainingController,
                    'خلافی مانده خودرو (ریال)',
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.assignment_turned_in_outlined),
                      label: const Text('ثبت صورت جلسه'),
                      onPressed: _handleSubmit,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickPerson({
    required String? currentValue,
    required ValueChanged<String> onSelected,
  }) async {
    final result = await showSearchableSingleSelectionSheet(
      context: context,
      title: 'پرسنل',
      options: _personnelOptions,
      initialValue: currentValue,
    );
    if (result != null) {
      onSelected(result);
    }
  }

  Widget _buildAccessoryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: _accessoryItems
              .map(
                (item) => CheckboxListTile(
                  value: _accessoryStates[item],
                  onChanged: (checked) =>
                      setState(() => _accessoryStates[item] = checked ?? false),
                  title: Text(item),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildConditionCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: _conditionItems
              .map(
                (item) => ListTile(
                  title: Text(item),
                  trailing: SegmentedButton<ConditionStatus>(
                    segments: ConditionStatus.values
                        .map(
                          (status) => ButtonSegment<ConditionStatus>(
                            value: status,
                            label: Text(status.label),
                          ),
                        )
                        .toList(),
                    selected: {
                      _conditionStates[item] ?? ConditionStatus.healthy,
                    },
                    onSelectionChanged: (selection) {
                      if (selection.isNotEmpty) {
                        setState(() {
                          _conditionStates[item] = selection.first;
                        });
                      }
                    },
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildTiresSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'وضعیت کلی لاستیک‌ها',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            SegmentedButton<ConditionStatus>(
              segments: ConditionStatus.values
                  .map(
                    (status) => ButtonSegment<ConditionStatus>(
                      value: status,
                      label: Text(status.label),
                    ),
                  )
                  .toList(),
              selected: {_tiresStatus},
              onSelectionChanged: (selection) {
                if (selection.isNotEmpty) {
                  setState(() {
                    _tiresStatus = selection.first;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _tiresHealthController,
              keyboardType: TextInputType.number,
              decoration: _inputDecoration('درصد سلامت لاستیک‌ها'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'درصد سلامت الزامی است';
                }
                final parsed = int.tryParse(value);
                if (parsed == null || parsed < 0 || parsed > 100) {
                  return 'عدد معتبر بین ۰ تا ۱۰۰ وارد کنید';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  void _handleSubmit() {
    final missing = <String>[];
    if (_receiver == null) missing.add('تحویل گیرنده');
    if (_giver == null) missing.add('تحویل دهنده');
    if (_usageLocation == null) missing.add('محل استفاده');
    if (_commander == null) missing.add('دستور دهنده');

    if (missing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('موارد زیر تکمیل نشده‌اند: ${missing.join('، ')}'),
          backgroundColor: Colors.orange.shade700,
        ),
      );
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_toPersianDigits('تحویل خودرو به ${_receiver!} ثبت شد.')),
      ),
    );
  }
}

enum DrillShift { day, night }

extension DrillShiftInfo on DrillShift {
  String get label {
    switch (this) {
      case DrillShift.day:
        return 'روز';
      case DrillShift.night:
        return 'شب';
    }
  }
}

enum ConditionStatus { healthy, unhealthy }

extension ConditionStatusInfo on ConditionStatus {
  String get label {
    switch (this) {
      case ConditionStatus.healthy:
        return 'سالم';
      case ConditionStatus.unhealthy:
        return 'ناسالم';
    }
  }
}

enum ConditionQuality { good, bad }

extension ConditionQualityInfo on ConditionQuality {
  String get label => this == ConditionQuality.good ? 'مناسب' : 'نامناسب';
}

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({
    super.key,
    required this.notificationEntries,
    required this.onNotificationTap,
  });

  final List<NotificationEntry> notificationEntries;
  final ValueChanged<int> onNotificationTap;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: _pagePadding(context),
      children: List.generate(
        notificationEntries.length,
        (index) => _DashboardNotificationTile(
          notification: notificationEntries[index].notification,
          onTap: () => onNotificationTap(notificationEntries[index].index),
        ),
      ),
    );
  }
}

class _FormLookupBundle {
  const _FormLookupBundle({
    this.projects = const {},
    this.conjectures = const {},
    this.machines = const {},
    this.persons = const {},
    this.stoneTypes = const {},
    this.materials = const {},
    this.stopCauses = const {},
    this.dailyReports = const {},
    this.cities = const {},
    this.checklists = const {},
  });

  const _FormLookupBundle.empty()
    : projects = const {},
      conjectures = const {},
      machines = const {},
      persons = const {},
      stoneTypes = const {},
      materials = const {},
      stopCauses = const {},
      dailyReports = const {},
      cities = const {},
      checklists = const {};

  final Map<int, String> projects;
  final Map<int, String> conjectures;
  final Map<int, String> machines;
  final Map<int, String> persons;
  final Map<int, String> stoneTypes;
  final Map<int, String> materials;
  final Map<int, String> stopCauses;
  final Map<int, String> dailyReports;
  final Map<int, String> cities;
  final Map<int, String> checklists;
}

class FormDetailPage extends StatelessWidget {
  const FormDetailPage({super.key, required this.form});

  final FormEntry form;

  String _formatValue(dynamic value) {
    if (value == null) {
      return '-';
    }
    if (value is List) {
      if (value.isEmpty) {
        return '-';
      }
      return value.map((item) => item.toString()).join('، ');
    }
    return value.toString();
  }

  DateTime? _parseDateValue(dynamic value) {
    if (value is DateTime) {
      return value;
    }
    final raw = value?.toString();
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw);
  }

  String _formatDateValue(dynamic value) {
    final parsed = _parseDateValue(value);
    if (parsed == null) {
      return _formatValue(value);
    }
    return _formatJalali(parsed);
  }

  int? _parseLookupId(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  String? _lookupValue(Map<int, String> lookup, dynamic value) {
    final id = _parseLookupId(value);
    if (id == null) {
      return null;
    }
    return lookup[id];
  }

  List<String>? _lookupList(Map<int, String> lookup, dynamic value) {
    if (value is! List) {
      return null;
    }
    final resolved = <String>[];
    for (final item in value) {
      final label = _lookupValue(lookup, item);
      resolved.add(label ?? item.toString());
    }
    return resolved;
  }

  dynamic _resolveLabel(Map data, String key) {
    final label =
        data['${key}_label'] ?? data['${key}_title'] ?? data['${key}_name'];
    if (label != null && label.toString().trim().isNotEmpty) {
      return label;
    }
    return data[key];
  }

  dynamic _resolveListLabel(Map data, String key) {
    final labels = data['${key}_labels'];
    if (labels is List && labels.isNotEmpty) {
      return labels;
    }
    return data[key];
  }

  dynamic _resolveLabelWithLookup(
    Map data,
    String key,
    Map<int, String> lookup,
  ) {
    final resolved = _resolveLabel(data, key);
    if (resolved != data[key]) {
      return resolved;
    }
    final lookupValue = _lookupValue(lookup, data[key]);
    return lookupValue ?? resolved;
  }

  dynamic _resolveListLabelWithLookup(
    Map data,
    String key,
    Map<int, String> lookup,
  ) {
    final resolved = _resolveListLabel(data, key);
    if (resolved != data[key]) {
      return resolved;
    }
    final lookupValues = _lookupList(lookup, data[key]);
    return lookupValues ?? resolved;
  }

  Future<_FormLookupBundle> _loadFormLookups() async {
    switch (form.formType) {
      case FormTypes.drilling:
        Future<List<Object>> loadDrillingLookups() {
          return Future.wait([
            appRepository.getConjectures(),
            appRepository.getMachines(),
            appRepository.getPersons(),
            appRepository.getStoneTypes(),
          ]);
        }
        var results = await loadDrillingLookups();
        var conjectures = results[0] as List<ConjectureOption>;
        var machines = results[1] as List<MachineOption>;
        var persons = results[2] as List<PersonOption>;
        var stoneTypes = results[3] as List<StoneTypeOption>;
        if (conjectures.isEmpty &&
            machines.isEmpty &&
            persons.isEmpty &&
            stoneTypes.isEmpty) {
          try {
            await appRepository.syncDrillingLookups();
          } catch (_) {
            // Keep cached values if sync fails.
          }
          results = await loadDrillingLookups();
          conjectures = results[0] as List<ConjectureOption>;
          machines = results[1] as List<MachineOption>;
          persons = results[2] as List<PersonOption>;
          stoneTypes = results[3] as List<StoneTypeOption>;
        }
        return _FormLookupBundle(
          conjectures: {for (final item in conjectures) item.id: item.name},
          machines: {for (final item in machines) item.id: item.displayName},
          persons: {for (final item in persons) item.id: item.fullName},
          stoneTypes: {
            for (final item in stoneTypes) item.id: item.displayName,
          },
        );
      case FormTypes.consumables:
      case FormTypes.downtime:
        Future<List<Object>> loadReportLookups() {
          return Future.wait([
            appRepository.getDailyReports(),
            appRepository.getMaterials(),
            appRepository.getStopCauses(),
          ]);
        }
        var results = await loadReportLookups();
        var reports = results[0] as List<DailyReportOption>;
        var materials = results[1] as List<MaterialOption>;
        var causes = results[2] as List<StopCauseOption>;
        if (reports.isEmpty && materials.isEmpty && causes.isEmpty) {
          try {
            await appRepository.syncReportLookups();
          } catch (_) {
            // Keep cached values if sync fails.
          }
          results = await loadReportLookups();
          reports = results[0] as List<DailyReportOption>;
          materials = results[1] as List<MaterialOption>;
          causes = results[2] as List<StopCauseOption>;
        }
        return _FormLookupBundle(
          dailyReports: {for (final item in reports) item.id: item.displayName},
          materials: {for (final item in materials) item.id: item.title},
          stopCauses: {for (final item in causes) item.id: item.title},
        );
      case FormTypes.driverSelection:
        Future<List<Object>> loadDriverLookups() {
          return Future.wait([
            appRepository.getProjects(),
            appRepository.getMachines(),
            appRepository.getPersons(),
          ]);
        }
        var results = await loadDriverLookups();
        var projects = results[0] as List<ProjectOption>;
        var machines = results[1] as List<MachineOption>;
        var persons = results[2] as List<PersonOption>;
        if (projects.isEmpty && machines.isEmpty && persons.isEmpty) {
          try {
            await appRepository.syncLookups();
          } catch (_) {
            // Keep cached values if sync fails.
          }
          results = await loadDriverLookups();
          projects = results[0] as List<ProjectOption>;
          machines = results[1] as List<MachineOption>;
          persons = results[2] as List<PersonOption>;
        }
        return _FormLookupBundle(
          projects: {for (final item in projects) item.id: item.name},
          machines: {for (final item in machines) item.id: item.displayName},
          persons: {for (final item in persons) item.id: item.fullName},
        );
      case FormTypes.machineChecklistDrilling:
      case FormTypes.machineChecklistLightHeavy:
        Future<List<Object>> loadChecklistLookups() {
          return Future.wait([
            appRepository.getMachines(),
            appRepository.getPersons(),
            appRepository.getCities(),
          ]);
        }
        var results = await loadChecklistLookups();
        var machines = results[0] as List<MachineOption>;
        var persons = results[1] as List<PersonOption>;
        var cities = results[2] as List<CityOption>;
        if (machines.isEmpty && persons.isEmpty && cities.isEmpty) {
          try {
            await appRepository.syncLookups();
          } catch (_) {
            // Keep cached values if sync fails.
          }
          results = await loadChecklistLookups();
          machines = results[0] as List<MachineOption>;
          persons = results[1] as List<PersonOption>;
          cities = results[2] as List<CityOption>;
        }

        final report = form.payload['report'];
        final reportMap = report is Map ? report : const <String, dynamic>{};
        final machineId = _parseLookupId(reportMap['machine']);
        MachineOption? machine;
        if (machineId != null) {
          for (final item in machines) {
            if (item.id == machineId) {
              machine = item;
              break;
            }
          }
        }

        Map<int, String> checklistMap = const {};
        final machineType = machine?.machineType;
        if (machineType != null) {
          try {
            final items = await appRepository.getChecklistsForMachineType(
              machineType,
            );
            checklistMap = {for (final item in items) item.id: item.title};
          } catch (_) {
            checklistMap = const {};
          }
        }

        return _FormLookupBundle(
          machines: {for (final item in machines) item.id: item.displayName},
          persons: {for (final item in persons) item.id: item.fullName},
          cities: {for (final item in cities) item.id: item.name},
          checklists: checklistMap,
        );
      default:
        return const _FormLookupBundle.empty();
    }
  }

  String? _extractErrorCode(String? error) {
    if (error == null || error.trim().isEmpty) {
      return null;
    }
    final match = RegExp(r'(\d{3})').firstMatch(error);
    return match?.group(1);
  }

  Widget _buildDetailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(flex: 3, child: Text(_toPersianDigits(_formatValue(value)))),
        ],
      ),
    );
  }

  Widget _buildDrillingDetails(
    BuildContext context,
    _FormLookupBundle lookups,
  ) {
    final reportRaw = form.payload['report'];
    final report = reportRaw is Map ? reportRaw : <String, dynamic>{};
    final runsRaw = form.payload['runs'];
    final runs = runsRaw is List ? runsRaw : const [];
    final shiftValue = report['shift'];
    final shiftLabel = shiftValue == 220
        ? 'روز'
        : shiftValue == 221
        ? 'شب'
        : _formatValue(shiftValue);

    final conjectureValue = _resolveLabelWithLookup(
      report,
      'conjecture',
      lookups.conjectures,
    );
    final machineValue = _resolveLabelWithLookup(
      report,
      'machine',
      lookups.machines,
    );
    final crackTypeValue = _resolveLabelWithLookup(
      report,
      'crack_type',
      lookups.stoneTypes,
    );
    final oreValue = _resolveLabelWithLookup(report, 'ore', lookups.stoneTypes);
    final stoneColorValue = _resolveLabelWithLookup(
      report,
      'stone_color',
      lookups.stoneTypes,
    );
    final drillerValue = _resolveLabelWithLookup(
      report,
      'driller',
      lookups.persons,
    );
    final shiftManValue = _resolveLabelWithLookup(
      report,
      'shift_man',
      lookups.persons,
    );
    final drillerHelpersValue = _resolveListLabelWithLookup(
      report,
      'driller_helpers',
      lookups.persons,
    );
    final reportDateValue = _formatDateValue(report['report_date']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('قسمت حفاری', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        _buildDetailRow('گمانه', conjectureValue),
        _buildDetailRow('دستگاه حفاری', machineValue),
        _buildDetailRow('متراژ کیسینگ', report['casing_length']),
        _buildDetailRow('تاریخ حفاری', reportDateValue),
        _buildDetailRow('شیفت', shiftLabel),
        _buildDetailRow('نوع شکستگی', crackTypeValue),
        _buildDetailRow('نوع سنگ', oreValue),
        _buildDetailRow('رنگ سنگ', stoneColorValue),
        _buildDetailRow('حفار', drillerValue),
        _buildDetailRow('سرشیفت', shiftManValue),
        _buildDetailRow('پرسنل کمک حفار', drillerHelpersValue),
        const SizedBox(height: 12),
        Text('قسمت ران', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        if (runs.isEmpty)
          const Text('رانی ثبت نشده است.')
        else
          Column(
            children: runs
                .asMap()
                .entries
                .map(
                  (entry) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _toPersianDigits('ران ${entry.key + 1}'),
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          _buildDetailRow(
                            'متراژ شروع',
                            (entry.value as Map)['start_depth'],
                          ),
                          _buildDetailRow(
                            'متراژ پایان',
                            (entry.value as Map)['end_depth'],
                          ),
                          _buildDetailRow(
                            'زمان شروع',
                            (entry.value as Map)['start_time'],
                          ),
                          _buildDetailRow(
                            'زمان پایان',
                            (entry.value as Map)['end_time'],
                          ),
                          _buildDetailRow(
                            'سایز سرمته',
                            (entry.value as Map)['boring_bit_size'],
                          ),
                          _buildDetailRow(
                            'درصد آب برگشتی',
                            (entry.value as Map)['return_water_percentage'],
                          ),
                          _buildDetailRow(
                            'رنگ آب',
                            (entry.value as Map)['water_color'],
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }

  Widget _buildConsumablesDetails(
    BuildContext context,
    _FormLookupBundle lookups,
  ) {
    final reportValue =
        form.payload['report_label'] ??
        _lookupValue(lookups.dailyReports, form.payload['report']) ??
        form.payload['report'];
    final materialValue =
        form.payload['material_label'] ??
        _lookupValue(lookups.materials, form.payload['material']) ??
        form.payload['material'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailRow('حفاری', reportValue),
        _buildDetailRow('کالا', materialValue),
        _buildDetailRow('مقدار', form.payload['amount']),
        _buildDetailRow('توضیح', form.payload['description']),
      ],
    );
  }

  Widget _buildDowntimeDetails(
    BuildContext context,
    _FormLookupBundle lookups,
  ) {
    final reportValue =
        form.payload['report_label'] ??
        _lookupValue(lookups.dailyReports, form.payload['report']) ??
        form.payload['report'];
    final causeValue =
        form.payload['cause_label'] ??
        _lookupValue(lookups.stopCauses, form.payload['cause_id']) ??
        form.payload['cause_id'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailRow('حفاری', reportValue),
        _buildDetailRow('علت توقف', causeValue),
        _buildDetailRow('زمان شروع', form.payload['start_time']),
        _buildDetailRow('زمان پایان', form.payload['end_time']),
      ],
    );
  }

  Widget _buildDriverSelectionDetails(
    BuildContext context,
    _FormLookupBundle lookups,
  ) {
    final projectValue =
        form.payload['project_label'] ??
        _lookupValue(lookups.projects, form.payload['project']) ??
        form.payload['project'];
    final machineValue =
        form.payload['machine_label'] ??
        _lookupValue(lookups.machines, form.payload['machine']) ??
        form.payload['machine'];
    final driverValue =
        form.payload['driver_label'] ??
        _lookupValue(lookups.persons, form.payload['driver']) ??
        form.payload['driver'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailRow('پروژه', projectValue),
        _buildDetailRow('ماشین', machineValue),
        _buildDetailRow('راننده', driverValue),
        _buildDetailRow(
          'تاریخ تحویل',
          _formatDateValue(form.payload['receive_date']),
        ),
        _buildDetailRow(
          'تاریخ برگشت',
          _formatDateValue(form.payload['return_date']),
        ),
      ],
    );
  }

  String _machineChecklistChoiceLabel(dynamic value) {
    final code = _parseLookupId(value);
    return switch (code) {
      200 => ConditionQuality.good.label,
      201 => ConditionQuality.bad.label,
      _ => _formatValue(value),
    };
  }

  Widget _buildMachineChecklistDetails(
    BuildContext context,
    _FormLookupBundle lookups,
  ) {
    final report = form.payload['report'];
    final reportMap = report is Map ? report : const <String, dynamic>{};
    final itemsRaw = form.payload['items'];
    final items = itemsRaw is List ? itemsRaw : const [];

    final actorValue = _resolveLabelWithLookup(
      reportMap,
      'actor',
      lookups.persons,
    );
    final machineValue = _resolveLabelWithLookup(
      reportMap,
      'machine',
      lookups.machines,
    );
    final cityValue = _resolveLabelWithLookup(
      reportMap,
      'location',
      lookups.cities,
    );
    final reportDateValue = _formatDateValue(reportMap['report_date']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailRow('ارسال کننده', actorValue),
        _buildDetailRow('ماشین', machineValue),
        _buildDetailRow('محل', cityValue),
        _buildDetailRow('تاریخ', reportDateValue),
        const SizedBox(height: 12),
        Text('آیتم‌ها', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        if (items.isEmpty)
          const Text('چک لیست ثبت نشده است.')
        else
          Column(
            children: items
                .whereType<Map>()
                .map(
                  (item) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow(
                            'عنوان',
                            _lookupValue(
                                  lookups.checklists,
                                  item['checklist'],
                                ) ??
                                item['checklist'],
                          ),
                          _buildDetailRow(
                            'وضعیت',
                            _machineChecklistChoiceLabel(item['choice']),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }

  Widget _buildFallbackDetails(BuildContext context) {
    final entries = form.payload.entries.toList();
    if (entries.isEmpty) {
      return const Text('اطلاعاتی برای نمایش وجود ندارد.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: entries
          .map((entry) => _buildDetailRow(entry.key, entry.value))
          .toList(),
    );
  }

  String _resolveFormType() {
    if (form.formType == FormTypes.drilling ||
        form.formType == FormTypes.consumables ||
        form.formType == FormTypes.downtime ||
        form.formType == FormTypes.driverSelection ||
        form.formType == FormTypes.machineChecklistDrilling ||
        form.formType == FormTypes.machineChecklistLightHeavy) {
      return form.formType;
    }
    final payload = form.payload;
    if (payload.containsKey('runs') && payload.containsKey('report')) {
      return FormTypes.drilling;
    }
    if (payload.containsKey('material') || payload.containsKey('amount')) {
      return FormTypes.consumables;
    }
    if (payload.containsKey('cause_id') || payload.containsKey('start_time')) {
      return FormTypes.downtime;
    }
    if (payload.containsKey('driver') &&
        payload.containsKey('machine') &&
        payload.containsKey('receive_date')) {
      return FormTypes.driverSelection;
    }
    if (payload.containsKey('items') && payload.containsKey('report')) {
      return FormTypes.machineChecklistDrilling;
    }
    return form.formType;
  }

  @override
  Widget build(BuildContext context) {
    final errorCode = _extractErrorCode(form.lastError);
    final onlineLabel = switch (form.status) {
      FormStatus.pending =>
        '\u062b\u0628\u062a \u0622\u0646\u0644\u0627\u06cc\u0646: \u062f\u0631 \u0627\u0646\u062a\u0638\u0627\u0631 \u0634\u0628\u06a9\u0647',
      FormStatus.error =>
        errorCode == null
            ? '\u062b\u0628\u062a \u0622\u0646\u0644\u0627\u06cc\u0646: \u062e\u0637\u0627'
            : '\u062b\u0628\u062a \u0622\u0646\u0644\u0627\u06cc\u0646: \u062e\u0637\u0627 (\u06a9\u062f $errorCode)',
      _ =>
        '\u062b\u0628\u062a \u0622\u0646\u0644\u0627\u06cc\u0646: ${_formatJalali(form.onlineSubmittedAt)}',
    };
    final localId = form.localId;
    return FutureBuilder<_FormLookupBundle>(
      future: _loadFormLookups(),
      builder: (context, snapshot) {
        final lookups = snapshot.data ?? const _FormLookupBundle.empty();
        final effectiveType = _resolveFormType();
        final detailContent = switch (effectiveType) {
          FormTypes.drilling => _buildDrillingDetails(context, lookups),
          FormTypes.consumables => _buildConsumablesDetails(context, lookups),
          FormTypes.downtime => _buildDowntimeDetails(context, lookups),
          FormTypes.driverSelection => _buildDriverSelectionDetails(
            context,
            lookups,
          ),
          FormTypes.machineChecklistDrilling => _buildMachineChecklistDetails(
            context,
            lookups,
          ),
          FormTypes.machineChecklistLightHeavy => _buildMachineChecklistDetails(
            context,
            lookups,
          ),
          _ => _buildFallbackDetails(context),
        };
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            appBar: AppBar(title: Text(form.title), centerTitle: true),
            body: ListView(
              padding: _pagePadding(context),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _toPersianDigits('شناسه فرم: ${form.id.toString()}'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Text('وضعیت: '),
                            _StatusChip(status: form.status),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'ثبت آفلاین: ${_formatJalali(form.offlineSubmittedAt)}',
                        ),
                        Text(onlineLabel),
                        if (form.status == FormStatus.error)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '\u062e\u0637\u0627\u06cc \u0627\u0631\u0633\u0627\u0644: ${form.lastError ?? '\u0646\u0627\u0645\u0634\u062e\u0635'}',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        if (form.status == FormStatus.error)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: localId == null
                                        ? null
                                        : () async {
                                            await appRepository.retrySubmission(
                                              localId,
                                            );
                                            if (!context.mounted) {
                                              return;
                                            }
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  '\u0627\u0631\u0633\u0627\u0644 \u0645\u062c\u062f\u062f \u0627\u0646\u062c\u0627\u0645 \u0634\u062f',
                                                ),
                                              ),
                                            );
                                          },
                                    icon: const Icon(Icons.refresh),
                                    label: const Text(
                                      '\u0627\u0631\u0633\u0627\u0644 \u0645\u062c\u062f\u062f',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: localId == null
                                        ? null
                                        : () async {
                                            final confirm = await showDialog<bool>(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: const Text(
                                                  '\u062d\u0630\u0641 \u0641\u0631\u0645',
                                                ),
                                                content: const Text(
                                                  '\u0622\u06cc\u0627 \u0627\u0632 \u062d\u0630\u0641 \u0641\u0631\u0645 \u0645\u0637\u0645\u0626\u0646 \u0647\u0633\u062a\u06cc\u062f؟',
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.of(
                                                          context,
                                                        ).pop(false),
                                                    child: const Text(
                                                      '\u0627\u0646\u0635\u0631\u0627\u0641',
                                                    ),
                                                  ),
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.of(
                                                          context,
                                                        ).pop(true),
                                                    child: Text(
                                                      '\u062d\u0630\u0641',
                                                      style: TextStyle(
                                                        color: Theme.of(
                                                          context,
                                                        ).colorScheme.error,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                            if (confirm != true) {
                                              return;
                                            }
                                            await appRepository
                                                .deleteSubmission(localId);
                                            if (!context.mounted) {
                                              return;
                                            }
                                            Navigator.of(context).pop();
                                          },
                                    icon: const Icon(Icons.delete_outline),
                                    label: const Text('\u062d\u0630\u0641'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'اطلاعات فرم',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _toPersianDigits(
                            form.description.isEmpty
                                ? 'برای این فرم توضیحی ثبت نشده است.'
                                : form.description,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'جزئیات ثبت شده',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        detailContent,
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.profile,
    required this.repository,
    required this.onLogout,
  });

  final UserProfile profile;
  final AppRepository repository;
  final VoidCallback onLogout;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  List<ProfileLogEntry> _logs = [];
  String _versionLabel = '-';
  bool _isLoadingLogs = false;
  bool _logsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadLogs() async {
    if (_isLoadingLogs) {
      return;
    }
    setState(() => _isLoadingLogs = true);
    final logs = await widget.repository.loadProfileLogs();
    if (!mounted) {
      return;
    }
    setState(() {
      _logs = logs;
      _isLoadingLogs = false;
      _logsLoaded = true;
    });
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) {
        return;
      }
      setState(() {
        _versionLabel = '${info.version}+${info.buildNumber}';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _versionLabel = '-');
    }
  }

  Future<void> _openLogsDialog() async {
    if (!_logsLoaded || _isLoadingLogs) {
      await _loadLogs();
    }
    if (!mounted) {
      return;
    }
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final lines = _logs
            .map((log) => '${_formatJalali(log.createdAt)}  ${log.message}.')
            .toList();
        final content = lines.isEmpty ? 'لاگی ثبت نشده است.' : lines.join('\n');
        return AlertDialog(
          title: const Text('لاگ برنامه'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 420, minWidth: 320),
            child: Container(
              width: double.maxFinite,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withAlpha(102),
                borderRadius: BorderRadius.circular(12),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  content,
                  textDirection: TextDirection.rtl,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('بستن'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('امکان باز کردن لینک وجود ندارد.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('پروفایل'), centerTitle: true),
        body: ListView(
          padding: _pagePadding(context),
          children: [
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  radius: 30,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(
                    Icons.person,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                title: Text(widget.profile.fullName),
                subtitle: Text(widget.profile.role),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('درباره سامانه', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    const Text(
                      'این سامانه برای ثبت، پیگیری و مدیریت عملیات میدانی، گزارش‌های حفاری و گردش فرم‌ها در پروژه‌ها طراحی شده است.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.mail_outline, size: 30),
                    title: const Text('ایمیل'),
                    subtitle: Text(
                      widget.profile.email.isEmpty ? '-' : widget.profile.email,
                    ),
                  ),
                  const Divider(height: 0),
                  ListTile(
                    leading: const Icon(Icons.phone_outlined, size: 30),
                    title: const Text('شماره تماس'),
                    subtitle: Text(_toPersianDigits(widget.profile.phone)),
                  ),
                  const Divider(height: 0),
                  ListTile(
                    leading: const Icon(Icons.vpn_key_outlined, size: 30),
                    title: const Text(
                      '\u0648\u0636\u0639\u06cc\u062a \u062a\u0648\u06a9\u0646',
                    ),
                    subtitle: Text(
                      widget.repository.hasSession
                          ? '\u0641\u0639\u0627\u0644'
                          : '\u063a\u06cc\u0631\u0641\u0639\u0627\u0644',
                    ),
                  ),
                  const Divider(height: 0),
                  ListTile(
                    leading: const Icon(Icons.language_outlined, size: 30),
                    title: const Text('وب‌سایت'),
                    subtitle: const Text('mis.felezyaban.com'),
                    trailing: const Icon(Icons.open_in_new, size: 18),
                    onTap: () => _openUrl('https://mis.felezyaban.com'),
                  ),
                  const Divider(height: 0),
                  ListTile(
                    leading: const Icon(Icons.handshake_outlined, size: 30),
                    title: const Text('توسعه‌دهنده'),
                    subtitle: const Text('FidaTech'),
                    trailing: const Icon(Icons.open_in_new, size: 18),
                    onTap: () => _openUrl('https://www.fidatech.ir'),
                  ),
                  const Divider(height: 0),
                  ListTile(
                    leading: const Icon(Icons.info_outline, size: 30),
                    title: const Text('نسخه برنامه'),
                    subtitle: Text(_versionLabel),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'لاگ برنامه',
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        SizedBox(
                          height: 32,
                          child: OutlinedButton.icon(
                            onPressed: _openLogsDialog,
                            icon: const Icon(Icons.terminal, size: 16),
                            label: const Text('لاگ'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isLoadingLogs
                          ? 'در حال بارگذاری لاگ‌ها...'
                          : _logs.isEmpty
                          ? 'لاگی ثبت نشده است.'
                          : _toPersianDigits(
                              '${_logs.length} لاگ ثبت شده است.',
                            ),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onLogout();
              },
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
              ),
              icon: const Icon(Icons.logout),
              label: const Text('خروج از حساب'),
            ),
          ],
        ),
      ),
    );
  }
}

class WebRoutePage extends StatelessWidget {
  const WebRoutePage({super.key, required this.title, required this.url});

  final String title;
  final String url;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: Text(title), centerTitle: true),
        body: WebRouteContent(url: url),
      ),
    );
  }
}

class WebRouteContent extends StatefulWidget {
  const WebRouteContent({super.key, required this.url});

  final String url;

  @override
  State<WebRouteContent> createState() => _WebRouteContentState();
}

class _WebRouteContentState extends State<WebRouteContent> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(child: WebViewWidget(controller: _controller));
  }
}

class WebAccessTab extends StatelessWidget {
  const WebAccessTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const WebAccessContent();
  }
}

class WebAccessPage extends StatelessWidget {
  const WebAccessPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('دسترسی وب'), centerTitle: true),
        body: const WebAccessContent(),
      ),
    );
  }
}

class WebAccessContent extends StatefulWidget {
  const WebAccessContent({super.key});

  @override
  State<WebAccessContent> createState() => _WebAccessContentState();
}

class _WebAccessContentState extends State<WebAccessContent> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse('https://mis.felezyaban.com'));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(child: WebViewWidget(controller: _controller));
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    required this.entriesBuilder,
    required this.onNotificationTap,
  });

  final List<NotificationEntry> Function() entriesBuilder;
  final ValueChanged<int> onNotificationTap;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  void _handleTap(int index) {
    widget.onNotificationTap(index);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.entriesBuilder();
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('اعلانات'), centerTitle: true),
        body: NotificationsPage(
          notificationEntries: entries,
          onNotificationTap: _handleTap,
        ),
      ),
    );
  }
}

String _formatJalali(DateTime dateTime) {
  final jalali = Jalali.fromDateTime(dateTime);
  final dayName = _normalizeDayName(jalali.formatter.wN);
  final time =
      '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  final formatted =
      '$dayName، ${jalali.formatter.d} ${jalali.formatter.mN} ${jalali.year} - ساعت $time';
  return _toPersianDigits(formatted);
}

class DashboardNotification {
  DashboardNotification({
    required this.message,
    required this.timestamp,
    this.isRead = false,
  });

  final String message;
  final DateTime timestamp;
  bool isRead;
}

class NotificationEntry {
  const NotificationEntry({required this.index, required this.notification});

  final int index;
  final DashboardNotification notification;
}

String _toPersianDigits(String input) {
  const englishToPersian = {
    '0': '۰',
    '1': '۱',
    '2': '۲',
    '3': '۳',
    '4': '۴',
    '5': '۵',
    '6': '۶',
    '7': '۷',
    '8': '۸',
    '9': '۹',
  };
  return input.split('').map((char) => englishToPersian[char] ?? char).join();
}

String _fromPersianDigits(String input) {
  const persianToEnglish = {
    '۰': '0',
    '۱': '1',
    '۲': '2',
    '۳': '3',
    '۴': '4',
    '۵': '5',
    '۶': '6',
    '۷': '7',
    '۸': '8',
    '۹': '9',
  };
  return input.split('').map((char) => persianToEnglish[char] ?? char).join();
}

String _normalizeDayName(String input) {
  return input.replaceAll(' ', '\u200A');
}

String _formatApiDate(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

String _formatApiDateTime(DateTime dateTime) {
  return dateTime.toIso8601String();
}

String _formatApiTime(TimeOfDay time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

int? _parseInt(String value) {
  final normalized = _fromPersianDigits(value).trim();
  if (normalized.isEmpty) {
    return null;
  }
  return int.tryParse(normalized);
}

double? _parseDouble(String value) {
  var normalized = _fromPersianDigits(value).trim();
  if (normalized.isEmpty) {
    return null;
  }
  normalized = normalized.replaceAll('٫', '.').replaceAll(',', '.');
  return double.tryParse(normalized);
}

EdgeInsets _pagePadding(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width >= 900) {
    final horizontal = (width - 720) / 2;
    return EdgeInsets.symmetric(horizontal: horizontal, vertical: 16);
  }
  if (width >= 600) {
    return const EdgeInsets.symmetric(horizontal: 32, vertical: 16);
  }
  return const EdgeInsets.all(16);
}

Future<String?> showSearchableSingleSelectionSheet({
  required BuildContext context,
  required String title,
  required List<String> options,
  String? initialValue,
}) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (modalContext) {
      var query = '';
      var selectedValue = initialValue;
      return Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(modalContext).viewInsets.bottom + 16,
            ),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: StatefulBuilder(
                builder: (context, setModalState) {
                  final normalized = query.trim().toLowerCase();
                  final filtered = normalized.isEmpty
                      ? options
                      : options
                            .where(
                              (option) =>
                                  option.toLowerCase().contains(normalized),
                            )
                            .toList();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'انتخاب $title',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          labelText: 'جستجو',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) =>
                            setModalState(() => query = value),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: filtered.isEmpty
                            ? const Center(child: Text('موردی یافت نشد'))
                            : ListView.builder(
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final option = filtered[index];
                                  return RadioListTile<String>(
                                    value: option,
                                    // ignore: deprecated_member_use
                                    groupValue: selectedValue,
                                    title: Text(option),
                                    // ignore: deprecated_member_use
                                    onChanged: (value) {
                                      if (value == null) {
                                        return;
                                      }
                                      selectedValue = value;
                                      Navigator.of(context).pop(value);
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
    },
  );
}

Future<Set<String>?> showSearchableMultiSelectionSheet({
  required BuildContext context,
  required String title,
  required List<String> options,
  required Set<String> currentValues,
}) {
  return showModalBottomSheet<Set<String>>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (modalContext) {
      var query = '';
      final tempSelection = currentValues.toSet();
      return Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(modalContext).viewInsets.bottom + 16,
            ),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.65,
              child: StatefulBuilder(
                builder: (context, setModalState) {
                  final normalized = query.trim().toLowerCase();
                  final filtered = normalized.isEmpty
                      ? options
                      : options
                            .where(
                              (option) =>
                                  option.toLowerCase().contains(normalized),
                            )
                            .toList();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'انتخاب $title',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          labelText: 'جستجو',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) =>
                            setModalState(() => query = value),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: filtered.isEmpty
                            ? const Center(child: Text('موردی یافت نشد'))
                            : ListView.builder(
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final option = filtered[index];
                                  final isChecked = tempSelection.contains(
                                    option,
                                  );
                                  return CheckboxListTile(
                                    value: isChecked,
                                    title: Text(option),
                                    onChanged: (checked) {
                                      setModalState(() {
                                        if (checked ?? false) {
                                          tempSelection.add(option);
                                        } else {
                                          tempSelection.remove(option);
                                        }
                                      });
                                    },
                                  );
                                },
                              ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('انصراف'),
                          ),
                          FilledButton(
                            onPressed: () =>
                                Navigator.of(context).pop(tempSelection),
                            child: const Text('تایید انتخاب'),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
    },
  );
}

Future<SelectionOption?> showSearchableSingleOptionSheet({
  required BuildContext context,
  required String title,
  required List<SelectionOption> options,
  int? initialId,
}) {
  return showModalBottomSheet<SelectionOption>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (modalContext) {
      var query = '';
      var selectedId = initialId;
      return Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(modalContext).viewInsets.bottom + 16,
            ),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: StatefulBuilder(
                builder: (context, setModalState) {
                  final normalized = query.trim().toLowerCase();
                  final filtered = normalized.isEmpty
                      ? options
                      : options
                            .where(
                              (option) => option.title.toLowerCase().contains(
                                normalized,
                              ),
                            )
                            .toList();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'انتخاب $title',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          labelText: 'جستجو',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) =>
                            setModalState(() => query = value),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: filtered.isEmpty
                            ? const Center(child: Text('موردی یافت نشد'))
                            : ListView.builder(
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final option = filtered[index];
                                  return RadioListTile<int>(
                                    value: option.id,
                                    // ignore: deprecated_member_use
                                    groupValue: selectedId,
                                    title: Text(option.title),
                                    // ignore: deprecated_member_use
                                    onChanged: (value) {
                                      if (value == null) {
                                        return;
                                      }
                                      selectedId = value;
                                      Navigator.of(context).pop(option);
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
    },
  );
}

Future<Set<int>?> showSearchableMultiOptionSheet({
  required BuildContext context,
  required String title,
  required List<SelectionOption> options,
  required Set<int> currentIds,
}) {
  return showModalBottomSheet<Set<int>>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (modalContext) {
      var query = '';
      final tempSelection = currentIds.toSet();
      return Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(modalContext).viewInsets.bottom + 16,
            ),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.65,
              child: StatefulBuilder(
                builder: (context, setModalState) {
                  final normalized = query.trim().toLowerCase();
                  final filtered = normalized.isEmpty
                      ? options
                      : options
                            .where(
                              (option) => option.title.toLowerCase().contains(
                                normalized,
                              ),
                            )
                            .toList();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'انتخاب $title',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          labelText: 'جستجو',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) =>
                            setModalState(() => query = value),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: filtered.isEmpty
                            ? const Center(child: Text('موردی یافت نشد'))
                            : ListView.builder(
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final option = filtered[index];
                                  final isChecked = tempSelection.contains(
                                    option.id,
                                  );
                                  return CheckboxListTile(
                                    value: isChecked,
                                    title: Text(option.title),
                                    onChanged: (checked) {
                                      setModalState(() {
                                        if (checked ?? false) {
                                          tempSelection.add(option.id);
                                        } else {
                                          tempSelection.remove(option.id);
                                        }
                                      });
                                    },
                                  );
                                },
                              ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('انصراف'),
                          ),
                          FilledButton(
                            onPressed: () =>
                                Navigator.of(context).pop(tempSelection),
                            child: const Text('تایید انتخاب'),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
    },
  );
}
