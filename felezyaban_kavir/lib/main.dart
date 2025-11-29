import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  runApp(const FelezyabanApp());
}

class FelezyabanApp extends StatefulWidget {
  const FelezyabanApp({super.key});

  @override
  State<FelezyabanApp> createState() => _FelezyabanAppState();
}

class _FelezyabanAppState extends State<FelezyabanApp> {
  bool _isLoggedIn = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'فراز فلزیابان',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
        fontFamily: 'Roboto',
        iconTheme: const IconThemeData(size: 30),
        appBarTheme: const AppBarTheme(
          iconTheme: IconThemeData(size: 30),
        ),
      ),
      locale: const Locale('fa', 'IR'),
      supportedLocales: const [
        Locale('fa', 'IR'),
        Locale('en'),
      ],
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
          ? HomeShell(onLogout: _handleLogout)
          : LoginPage(onLoginSuccess: _handleLoginSuccess),
    );
  }

  void _handleLoginSuccess() {
    setState(() {
      _isLoggedIn = true;
    });
  }

  void _handleLogout() {
    setState(() {
      _isLoggedIn = false;
    });
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.onLogout});

  final VoidCallback onLogout;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;
  final UserProfile _profile = UserProfile(
    fullName: 'یاسین رحمانی',
    role: 'مدیر سامانه',
    email: 'user@example.com',
    phone: '0912 123 4567',
  );
  final GlobalKey<_FormsPageState> _formsPageKey = GlobalKey<_FormsPageState>();

  final List<FormEntry> _forms = [
    FormEntry(
      id: 1024,
      title: 'فرم ثبت دستگاه جدید',
      description: 'ثبت دستگاه مدل X12 برای مشتری الف',
      offlineSubmittedAt: DateTime.now().subtract(const Duration(hours: 3)),
      onlineSubmittedAt: DateTime.now().subtract(const Duration(hours: 2)),
      status: FormStatus.approved,
    ),
    FormEntry(
      id: 1023,
      title: 'فرم اعلام خرابی',
      description: 'اعلام خرابی دستگاه قدیمی',
      offlineSubmittedAt:
          DateTime.now().subtract(const Duration(days: 1, hours: 5)),
      onlineSubmittedAt:
          DateTime.now().subtract(const Duration(days: 1, hours: 3)),
      status: FormStatus.pending,
    ),
    FormEntry(
      id: 1022,
      title: 'فرم گزارش روزانه',
      description: 'گزارش روزانه تیم پشتیبانی',
      offlineSubmittedAt:
          DateTime.now().subtract(const Duration(days: 2, hours: 6)),
      onlineSubmittedAt: DateTime.now().subtract(const Duration(days: 2)),
      status: FormStatus.needsRevision,
    ),
    FormEntry(
      id: 1021,
      title: 'فرم تحویل به مشتری',
      description: 'تحویل دستگاه سری جدید',
      offlineSubmittedAt: DateTime.now().subtract(const Duration(days: 3, hours: 2)),
      onlineSubmittedAt: DateTime.now().subtract(const Duration(days: 3)),
      status: FormStatus.approved,
    ),
    FormEntry(
      id: 1020,
      title: 'فرم تحویل قطعات',
      description: 'تحویل قطعات یدکی سری B',
      offlineSubmittedAt:
          DateTime.now().subtract(const Duration(days: 4, hours: 4)),
      onlineSubmittedAt:
          DateTime.now().subtract(const Duration(days: 4, hours: 1)),
      status: FormStatus.pending,
    ),
  ];

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

  void _openNotifications() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NotificationsScreen(
          entriesBuilder: _sortedNotificationEntries,
          onNotificationTap: _markNotificationRead,
        ),
      ),
    );
  }

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfilePage(
          profile: _profile,
          onLogout: widget.onLogout,
        ),
      ),
    );
  }

  void _markNotificationRead(int index) {
    if (index < 0 || index >= _notifications.length) {
      return;
    }
    setState(() {
      _notifications[index].isRead = true;
    });
  }

  List<_NotificationEntry> _sortedNotificationEntries() {
    final entries = List.generate(
      _notifications.length,
      (index) => _NotificationEntry(
        index: index,
        notification: _notifications[index],
      ),
    );
    entries.sort((a, b) {
      if (a.notification.isRead != b.notification.isRead) {
        return a.notification.isRead ? 1 : -1;
      }
      return b.notification.timestamp.compareTo(a.notification.timestamp);
    });
    return entries;
  }

  FormEntry get _latestForm => _forms.reduce(
        (a, b) => a.onlineSubmittedAt.isAfter(b.onlineSubmittedAt) ? a : b,
      );

  void _onTabSelected(int index) {
    final previous = _selectedIndex;
    setState(() => _selectedIndex = index);
    if (index == 1 && previous != 1) {
      _formsPageKey.currentState?.resetCollapsed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['داشبورد', 'فرم ها', 'وب'];
    final notificationEntries = _sortedNotificationEntries();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(titles[_selectedIndex]),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.notifications_none, size: 32),
            tooltip: 'اعلانات',
            onPressed: _openNotifications,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.person_outline, size: 32),
              tooltip: 'پروفایل',
              onPressed: _openProfile,
            ),
          ],
        ),
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            DashboardPage(
              userFullName: _profile.fullName,
              notificationEntries: notificationEntries,
              onNotificationTap: _markNotificationRead,
              latestForm: _latestForm,
            ),
            FormsPage(
              key: _formsPageKey,
              forms: _forms,
            ),
            const WebAccessTab(),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          onTap: _onTabSelected,
          selectedIconTheme: const IconThemeData(size: 34),
          unselectedIconTheme: const IconThemeData(size: 30),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              label: 'داشبورد',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.description_outlined),
              label: 'فرم ها',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.language_outlined),
              label: 'وب',
            ),
          ],
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
  final List<_NotificationEntry> notificationEntries;
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
    final latestNotifications =
        notificationEntries.take(3).toList(growable: false);

    return ListView(
      padding: const EdgeInsets.all(16),
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
        Text(
          'آخرین اعلان‌ها',
          style: Theme.of(context).textTheme.titleMedium,
        ),
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
    final tagColor =
        notification.isRead ? theme.colorScheme.primary : Colors.orange;
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
              color: tagColor.withOpacity(0.15),
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
            MaterialPageRoute<void>(
              builder: (_) => FormDetailPage(form: form),
            ),
          );
        },
      ),
    );
  }
}

class FormsPage extends StatefulWidget {
  const FormsPage({
    super.key,
    required this.forms,
  });

  final List<FormEntry> forms;

  @override
  State<FormsPage> createState() => _FormsPageState();
}

class _FormsPageState extends State<FormsPage> {
  bool _showAll = false;
  late final List<_NewFormItem> _newFormItems = [
    _NewFormItem(
      title: 'فرم ایجاد حفاری',
      order: 0,
      builder: (_) => const DrillingFormPage(),
    ),
    _NewFormItem(
      title: 'فرم اقلام مصرفی',
      order: 1,
      builder: (_) => const ConsumablesFormPage(),
    ),
    _NewFormItem(
      title: 'فرم توقف و تاخیرات حفاری',
      order: 2,
      builder: (_) => const DowntimeFormPage(),
    ),
    _NewFormItem(
      title: 'فرم صورت جلسه تحویل خودرو',
      order: 3,
      builder: (_) => const VehicleDeliveryFormPage(),
    ),
    ...List.generate(
      6,
      (index) => _NewFormItem(
        title: 'فرم ${index + 5}',
        order: index + 4,
      ),
    ),
  ];

  List<FormEntry> get _visibleForms =>
      _showAll ? widget.forms : widget.forms.take(3).toList();

  List<_NewFormItem> get _sortedNewForms {
    final list = [..._newFormItems];
    list.sort((a, b) {
      if (a.isFavorite != b.isFavorite) {
        return a.isFavorite ? -1 : 1;
      }
      return a.order.compareTo(b.order);
    });
    return list;
  }

  void _toggleNewFormFavorite(_NewFormItem item) {
    setState(() {
      item.isFavorite = !item.isFavorite;
    });
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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'فرم‌های ارسال شده',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        ..._visibleForms.map(
          (form) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _FormListTile(form: form),
          ),
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
        Text(
          'فرم جدید',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        ...newForms.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onPressed: () {
                if (item.builder != null) {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: item.builder!,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        _toPersianDigits('${item.title} به زودی فعال می‌شود.'),
                      ),
                    ),
                  );
                }
              },
              child: Row(
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      item.isFavorite ? Icons.star : Icons.star_border,
                      color: item.isFavorite ? Colors.amber : null,
                    ),
                    onPressed: () => _toggleNewFormFavorite(item),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_toPersianDigits(item.title))),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FormListTile extends StatelessWidget {
  const _FormListTile({required this.form});

  final FormEntry form;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.article_outlined, size: 32),
        title: Text(form.title),
        subtitle: Text(
          _toPersianDigits(
            '${form.description}\n${_formatJalali(form.onlineSubmittedAt)}',
          ),
        ),
        trailing: _StatusChip(status: form.status),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => FormDetailPage(form: form),
            ),
          );
        },
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
          color: color.withOpacity(0.12),
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
  const LoginPage({super.key, required this.onLoginSuccess});

  final VoidCallback onLoginSuccess;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _attemptLogin() {
    final user = _usernameController.text.trim();
    final pass = _passwordController.text.trim();
    if (user == 'test' && pass == '1') {
      setState(() {
        _errorMessage = null;
      });
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
    } else {
      setState(() {
        _errorMessage = 'اطلاعات وارد شده صحیح نیست.';
      });
    }
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
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'رمز عبور',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () {},
                      child: const Text('فراموشی رمز عبور'),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () {},
                      child: const Text('ورود با رمز یکبار مصرف'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _attemptLogin,
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

class _NewFormItem {
  _NewFormItem({required this.title, required this.order, this.builder});

  final String title;
  final int order;
  final WidgetBuilder? builder;
  bool isFavorite = false;
}

const List<String> _weekdayLabels = ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'];

mixin _FormFieldMixin<T extends StatefulWidget> on State<T> {
  InputDecoration _inputDecoration(
    String label, {
    Widget? suffixIcon,
    bool alwaysFloatLabel = false,
  }) {
    final borderColor = Colors.black.withOpacity(0.2);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: borderColor),
    );
    final focusedBorder = border.copyWith(
      borderSide: BorderSide(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
      ),
    );
    return InputDecoration(
      labelText: label,
      border: border,
      enabledBorder: border,
      focusedBorder: focusedBorder,
      suffixIcon: suffixIcon,
      floatingLabelBehavior:
          alwaysFloatLabel ? FloatingLabelBehavior.always : null,
    );
  }

  Widget _buildNumberField(
    TextEditingController controller,
    String label, {
    TextInputType keyboardType = TextInputType.number,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: _inputDecoration(label),
      validator: validator ??
          (value) {
            if (value == null || value.trim().isEmpty) {
              return 'وارد کردن $label الزامی است';
            }
            return null;
          },
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: _inputDecoration(label),
      validator: validator ??
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
    final hintStyle =
        theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor);
    final displayWidget = hasValue
        ? Text(
            value,
            style: theme.textTheme.bodyMedium,
          )
        : placeholder != null && placeholder.isNotEmpty
            ? Text(
                placeholder,
                style: hintStyle,
              )
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
          (value) => Chip(
            label: Text(value),
            visualDensity: VisualDensity.compact,
          ),
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
          decoration: _inputDecoration(
            label,
            alwaysFloatLabel: true,
          ),
          child: hasValue
              ? Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: chips,
                )
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
                        (Jalali(visibleMonth.year, visibleMonth.month, 1)
                                    .weekDay -
                                1) %
                            7;
                    final leadingEmpty = (startWeekIndex + 7) % 7;
                    final daysInMonth = visibleMonth.monthLength;
                    final cells = <Widget>[];
                    for (var i = 0; i < leadingEmpty; i++) {
                      cells.add(const SizedBox.shrink());
                    }
                    for (var day = 1; day <= daysInMonth; day++) {
                      final currentDate =
                          Jalali(visibleMonth.year, visibleMonth.month, day);
                      final isDisabled = _compareJalali(
                                currentDate,
                                firstDate,
                              ) <
                              0 ||
                          _compareJalali(currentDate, lastDate) > 0;
                      final isSelected = tempSelection != null &&
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
                      rows.add(
                        TableRow(
                          children: cells.sublist(i, i + 7),
                        ),
                      );
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
                                        () => visibleMonth =
                                            _nextMonth(visibleMonth),
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
                                        () => visibleMonth =
                                            _previousMonth(visibleMonth),
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
                                              color:
                                                  theme.colorScheme.primary),
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
                                  : () =>
                                      Navigator.of(context).pop(tempSelection),
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
  const DrillingFormPage({super.key});

  @override
  State<DrillingFormPage> createState() => _DrillingFormPageState();
}

class _DrillingFormPageState extends State<DrillingFormPage>
    with _FormFieldMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _drillCodeController = TextEditingController();
  final TextEditingController _drillAngleController = TextEditingController();
  final TextEditingController _azimuthController = TextEditingController();
  final TextEditingController _casingLengthController = TextEditingController();
  final TextEditingController _shiftTotalController = TextEditingController();
  final TextEditingController _waterColorController = TextEditingController();
  final TextEditingController _waterReturnController = TextEditingController();
  final TextEditingController _bitSizeController = TextEditingController();
  final TextEditingController _runLengthController = TextEditingController();
  final TextEditingController _endToController = TextEditingController();
  final TextEditingController _startFromController = TextEditingController();
  final TextEditingController _runController = TextEditingController();

  String? _selectedExpert;
  String? _selectedBorehole;
  String? _selectedDriller;
  String? _selectedShiftLeader;
  final Set<String> _selectedAssistants = <String>{};
  DrillShift _selectedShift = DrillShift.day;
  DateTime? _startDateTime;
  DateTime? _endDateTime;

  static const List<String> _experts = [
    'محمد احمدی',
    'علی رضایی',
    'سارا کریمی',
    'پیمان بهرامی',
    'مهدی سلیمانی',
  ];

  static const List<String> _boreholeNumbers = [
    'BH-101',
    'BH-118',
    'BH-203',
    'BH-315',
    'BH-420',
  ];

  static const List<String> _drillers = [
    'حسین قنبری',
    'رضا محمودی',
    'هادی سهرابی',
    'محسن زارعی',
  ];

  static const List<String> _shiftLeaders = [
    'مجید نادری',
    'مسعود تیموری',
    'هاشم قاسمی',
    'شفیع مومنی',
  ];

  static const List<String> _assistantCandidates = [
    'سهیل اکبری',
    'روح الله قائمی',
    'علیرضا رفیعی',
    'مهرداد موسوی',
    'یونس شکوهی',
    'رضوان انصاری',
  ];

  @override
  void dispose() {
    _drillCodeController.dispose();
    _drillAngleController.dispose();
    _azimuthController.dispose();
    _casingLengthController.dispose();
    _shiftTotalController.dispose();
    _waterColorController.dispose();
    _waterReturnController.dispose();
    _bitSizeController.dispose();
    _runLengthController.dispose();
    _endToController.dispose();
    _startFromController.dispose();
    _runController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('فرم ایجاد حفاری'),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'مشخصات اصلی',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  _selectionField(
                    label: 'کارشناس',
                    value: _selectedExpert,
                    onTap: () async {
                      final result = await showSearchableSingleSelectionSheet(
                        context: context,
                        title: 'کارشناس',
                        options: _experts,
                        initialValue: _selectedExpert,
                      );
                      if (result != null) {
                        setState(() => _selectedExpert = result);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _selectionField(
                    label: 'شماره گمانه‌',
                    value: _selectedBorehole == null
                        ? null
                        : _toPersianDigits(_selectedBorehole!),
                    onTap: () async {
                      final result = await showSearchableSingleSelectionSheet(
                        context: context,
                        title: 'شماره گمانه',
                        options: _boreholeNumbers,
                        initialValue: _selectedBorehole,
                      );
                      if (result != null) {
                        setState(() => _selectedBorehole = result);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildNumberField(_drillCodeController,
                    'کد دستگاه حفاری',
                  ),
                  const SizedBox(height: 16),
                  _buildNumberField(_drillAngleController,
                    'زاویه حفاری',
                  ),
                  const SizedBox(height: 16),
                  _buildTextField( _azimuthController, 'آزیموت'),
                  const SizedBox(height: 16),
                  _buildNumberField(_casingLengthController,
                    'متراژ کیسینگ',
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'شیفت و تیم حفاری',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
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
                    label: 'حفار',
                    value: _selectedDriller,
                    onTap: () async {
                      final result = await showSearchableSingleSelectionSheet(
                        context: context,
                        title: 'حفار',
                        options: _drillers,
                        initialValue: _selectedDriller,
                      );
                      if (result != null) {
                        setState(() => _selectedDriller = result);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _selectionField(
                    label: 'سرشیفت',
                    value: _selectedShiftLeader,
                    onTap: () async {
                      final result = await showSearchableSingleSelectionSheet(
                        context: context,
                        title: 'سرشیفت',
                        options: _shiftLeaders,
                        initialValue: _selectedShiftLeader,
                      );
                      if (result != null) {
                        setState(() => _selectedShiftLeader = result);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _multiSelectionField(
                    label: 'پرسنل کمک حفار',
                    values: _selectedAssistants,
                    onTap: () async {
                      final result = await showSearchableMultiSelectionSheet(
                        context: context,
                        title: 'پرسنل کمک حفار',
                        options: _assistantCandidates,
                        currentValues: _selectedAssistants,
                      );
                      if (result != null) {
                        setState(() {
                          _selectedAssistants
                            ..clear()
                            ..addAll(result);
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildNumberField(_shiftTotalController,
                    'مجموع حفاری شیفت',
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'اطلاعات حفاری',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField( _waterColorController, 'رنگ آب'),
                  const SizedBox(height: 16),
                  _buildNumberField(_waterReturnController,
                    'درصد آب برگشتی',
                  ),
                  const SizedBox(height: 16),
                  _buildTextField( _bitSizeController, 'سایز سرمته'),
                  const SizedBox(height: 16),
                  _selectionField(
                    label: 'زمان شروع',
                    value: _formatDateTime(_startDateTime),
                    onTap: () => _pickDateTime(isStart: true),
                    placeholder: 'انتخاب زمان شروع',
                    icon: Icons.calendar_month_outlined,
                  ),
                  const SizedBox(height: 16),
                  _selectionField(
                    label: 'زمان پایان',
                    value: _formatDateTime(_endDateTime),
                    onTap: () => _pickDateTime(isStart: false),
                    placeholder: 'انتخاب زمان پایان',
                    icon: Icons.calendar_month_outlined,
                  ),
                  const SizedBox(height: 16),
                  _buildNumberField( _runLengthController, 'طول ران'),
                  const SizedBox(height: 16),
                  _buildNumberField( _endToController, 'پایان تا'),
                  const SizedBox(height: 16),
                  _buildNumberField( _startFromController, 'شروع از'),
                  const SizedBox(height: 16),
                  _buildNumberField( _runController, 'ران'),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('ثبت فرم'),
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

  Future<String?> _openSingleSelection({
    required String contextTitle,
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
                              (option) => option.toLowerCase().contains(normalized),
                            )
                            .toList();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'انتخاب $contextTitle',
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
                                      groupValue: selectedValue,
                                      title: Text(option),
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

  Future<Set<String>?> _openMultiSelection({
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
                              (option) => option.toLowerCase().contains(normalized),
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
                          onChanged: (value) => setModalState(() => query = value),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: filtered.isEmpty
                              ? const Center(child: Text('موردی یافت نشد'))
                              : ListView.builder(
                                  itemCount: filtered.length,
                                  itemBuilder: (context, index) {
                                    final option = filtered[index];
                                    final isChecked = tempSelection.contains(option);
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

  Future<void> _pickDateTime({required bool isStart}) async {
    try {
      final now = DateTime.now();
      final currentValue = isStart ? _startDateTime : _endDateTime;
      final baseDateTime = currentValue ?? now;
      final initialJalali = Jalali.fromDateTime(baseDateTime);
      final jalali = await _showJalaliDatePicker(
        initialDate: initialJalali,
        firstDate: Jalali(initialJalali.year - 2, 1, 1),
        lastDate: Jalali(initialJalali.year + 2, 12, 29),
      );
      if (jalali == null) {
        return;
      }
      final selectedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(baseDateTime),
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
      if (selectedTime == null) {
        return;
      }
      final gregorian = jalali.toDateTime();
      final selectedDateTime = DateTime(
        gregorian.year,
        gregorian.month,
        gregorian.day,
        selectedTime.hour,
        selectedTime.minute,
      );
      setState(() {
        if (isStart) {
          _startDateTime = selectedDateTime;
        } else {
          _endDateTime = selectedDateTime;
        }
      });
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('باز کردن انتخابگر تاریخ با خطا روبه‌رو شد.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  String? _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) {
      return null;
    }
    final jalali = Jalali.fromDateTime(dateTime);
    final dayName = _normalizeDayName(jalali.formatter.wN);
    final dateText =
        '$dayName، ${jalali.formatter.d} ${jalali.formatter.mN} ${jalali.year}';
    final time =
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    return _toPersianDigits('$dateText - ساعت $time');
  }

  void _handleSubmit() {
    final missingSelections = <String>[];
    if (_selectedExpert == null) missingSelections.add('کارشناس');
    if (_selectedBorehole == null) missingSelections.add('شماره گمانه');
    if (_selectedDriller == null) missingSelections.add('حفار');
    if (_selectedShiftLeader == null) missingSelections.add('سرشیفت');
    if (_selectedAssistants.isEmpty) missingSelections.add('پرسنل کمک حفار');
    if (_startDateTime == null) missingSelections.add('زمان شروع');
    if (_endDateTime == null) missingSelections.add('زمان پایان');

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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _toPersianDigits('فرم ثبت شد. شیفت ${_selectedShift.label} آماده ارسال است.'),
        ),
      ),
    );
  }
}

class ConsumablesFormPage extends StatefulWidget {
  const ConsumablesFormPage({super.key});

  @override
  State<ConsumablesFormPage> createState() => _ConsumablesFormPageState();
}

class _ConsumablesFormPageState extends State<ConsumablesFormPage>
    with _FormFieldMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String? _selectedWarehouse;
  String? _selectedItem;

  static const List<String> _warehouses = [
    'انبار مرکزی',
    'انبار غربی',
    'انبار سایت ۳',
    'انبار حفاری A',
  ];

  static const List<String> _items = [
    'بنتونیت',
    'روغن هیدرولیک',
    'سوخت گازوئیل',
    'کابل حفاری',
    'لوله کیسینگ',
    'گریس صنعتی',
  ];

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
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _selectionField(
                    label: 'انبار',
                    value: _selectedWarehouse,
                    onTap: () async {
                      final result = await showSearchableSingleSelectionSheet(
                        context: context,
                        title: 'انبار',
                        options: _warehouses,
                        initialValue: _selectedWarehouse,
                      );
                      if (result != null) {
                        setState(() => _selectedWarehouse = result);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _selectionField(
                    label: 'نام کالا',
                    value: _selectedItem,
                    onTap: () async {
                      final result = await showSearchableSingleSelectionSheet(
                        context: context,
                        title: 'نام کالا',
                        options: _items,
                        initialValue: _selectedItem,
                      );
                      if (result != null) {
                        setState(() => _selectedItem = result);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildNumberField(
                    _amountController,
                    'مقدار',
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    _descriptionController,
                    'توضیح',
                    maxLines: 4,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.send),
                      label: const Text('ثبت اقلام مصرفی'),
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
    if (_selectedWarehouse == null || _selectedItem == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لطفا انبار و نام کالا را انتخاب کنید.'),
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
          _toPersianDigits(
            'مصرف ${_selectedItem!} از ${_selectedWarehouse!} ثبت شد.',
          ),
        ),
      ),
    );
  }
}

class DowntimeFormPage extends StatefulWidget {
  const DowntimeFormPage({super.key});

  @override
  State<DowntimeFormPage> createState() => _DowntimeFormPageState();
}

class _DowntimeFormPageState extends State<DowntimeFormPage>
    with _FormFieldMixin {
  final _formKey = GlobalKey<FormState>();
  DateTime? _startDateTime;
  DateTime? _endDateTime;
  String? _selectedReason;

  static const List<String> _reasons = [
    'خرابی دستگاه',
    'مشکل تدارکات',
    'شرایط جوی نامناسب',
    'دستور مدیریتی',
    'کمبود نیروی انسانی',
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('فرم توقف و تاخیرات حفاری'),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _selectionField(
                    label: 'علت توقف',
                    value: _selectedReason,
                    onTap: () async {
                      final result = await showSearchableSingleSelectionSheet(
                        context: context,
                        title: 'علت توقف',
                        options: _reasons,
                        initialValue: _selectedReason,
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

  void _handleSubmit() {
    if (_selectedReason == null || _startDateTime == null || _endDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('علت توقف و بازه زمانی باید مشخص شود.'),
        ),
      );
      return;
    }
    if (!(_formKey.currentState?.validate() ?? true)) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _toPersianDigits('توقف "${_selectedReason!}" ثبت شد.'),
        ),
      ),
    );
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

class VehicleDeliveryFormPage extends StatefulWidget {
  const VehicleDeliveryFormPage({super.key});

  @override
  State<VehicleDeliveryFormPage> createState() => _VehicleDeliveryFormPageState();
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

  final Map<String, ConditionStatus> _tireStatus = {
    for (final item in _tireItems) item: ConditionStatus.healthy,
  };

  late final Map<String, TextEditingController> _tireHealthControllers = {
    for (final item in _tireItems) item: TextEditingController(),
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

  static const List<String> _tireItems = [
    'لاستیک جلو راست',
    'لاستیک جلو چپ',
    'لاستیک عقب راست',
    'لاستیک عقب چپ',
  ];

  @override
  void dispose() {
    _letterNumberController.dispose();
    _kilometerController.dispose();
    _plateController.dispose();
    _fineUntilController.dispose();
    _fineRemainingController.dispose();
    for (final controller in _tireHealthControllers.values) {
      controller.dispose();
    }
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
            padding: const EdgeInsets.all(16),
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
                  _buildTextField(
                    _letterNumberController,
                    'شماره نامه',
                  ),
                  const SizedBox(height: 16),
                  _buildNumberField(_kilometerController, 'شماره کیلومتر'),
                  const SizedBox(height: 16),
                  _buildTextField(
                    _plateController,
                    'شماره انتظامی',
                  ),
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
                  Text(
                    'وضعیت لاستیک‌ها',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  _buildTireCard(),
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
                  onChanged: (checked) => setState(
                    () => _accessoryStates[item] = checked ?? false,
                  ),
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
                    selected: {_conditionStates[item] ?? ConditionStatus.healthy},
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

  Widget _buildTireCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: _tireItems.map(_buildTireRow).toList(),
        ),
      ),
    );
  }

  Widget _buildTireRow(String item) {
    final controller = _tireHealthControllers[item]!;
    final selectedStatus = _tireStatus[item] ?? ConditionStatus.healthy;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: SegmentedButton<ConditionStatus>(
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    textStyle: WidgetStateProperty.all<TextStyle>(
                      const TextStyle(fontSize: 11),
                    ),
                  ),
                  segments: ConditionStatus.values
                      .map(
                        (status) => ButtonSegment<ConditionStatus>(
                          value: status,
                          label: Text(
                            status.label,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      )
                      .toList(),
                  selected: {selectedStatus},
                  onSelectionChanged: (selection) {
                    if (selection.isNotEmpty) {
                      setState(() {
                        _tireStatus[item] = selection.first;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 110,
                child: TextFormField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 12),
                  decoration: _inputDecoration('درصد سلامت').copyWith(
                    labelStyle: const TextStyle(fontSize: 11),
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'درصد سلامت الزامی است';
                    }
                    final parsed = int.tryParse(value);
                    if (parsed == null || parsed < 0 || parsed > 100) {
                      return 'عدد معتبر وارد کنید';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
        ],
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
        content: Text(
          _toPersianDigits('تحویل خودرو به ${_receiver!} ثبت شد.'),
        ),
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

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({
    super.key,
    required this.notificationEntries,
    required this.onNotificationTap,
  });

  final List<_NotificationEntry> notificationEntries;
  final ValueChanged<int> onNotificationTap;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
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

class FormDetailPage extends StatelessWidget {
  const FormDetailPage({super.key, required this.form});

  final FormEntry form;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(form.title),
          centerTitle: true,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
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
                    Text(
                      'ثبت آنلاین: ${_formatJalali(form.onlineSubmittedAt)}',
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
                child: Text(
                  _toPersianDigits(
                    'محتوای تکمیل شده فرم "${form.title}" در اینجا نمایش داده می‌شود.',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.profile, required this.onLogout});

  final UserProfile profile;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('پروفایل'),
          centerTitle: true,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ListTile(
              leading: const CircleAvatar(
                radius: 32,
                child: Icon(Icons.person, size: 34),
              ),
              title: Text(profile.fullName),
              subtitle: Text(profile.role),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.mail_outline, size: 32),
              title: const Text('ایمیل'),
              subtitle: Text(profile.email),
            ),
            ListTile(
              leading: const Icon(Icons.phone_outlined, size: 32),
              title: const Text('شماره تماس'),
              subtitle: Text(_toPersianDigits(profile.phone)),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                onLogout();
              },
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
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
        appBar: AppBar(
          title: const Text('دسترسی وب'),
          centerTitle: true,
        ),
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
      ..loadRequest(Uri.parse('https://google.com'));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: WebViewWidget(controller: _controller),
    );
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    required this.entriesBuilder,
    required this.onNotificationTap,
  });

  final List<_NotificationEntry> Function() entriesBuilder;
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
        appBar: AppBar(
          title: const Text('اعلانات'),
          centerTitle: true,
        ),
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

enum FormStatus { approved, pending, needsRevision }

extension FormStatusInfo on FormStatus {
  String get label {
    switch (this) {
      case FormStatus.approved:
        return 'تایید شده';
      case FormStatus.pending:
        return 'در انتظار تایید';
      case FormStatus.needsRevision:
        return 'نیاز به اصلاح';
    }
  }

  Color get color {
    switch (this) {
      case FormStatus.approved:
        return Colors.green;
      case FormStatus.pending:
        return Colors.orange;
      case FormStatus.needsRevision:
        return Colors.red;
    }
  }
}

class FormEntry {
  FormEntry({
    required this.id,
    required this.title,
    required this.description,
    required this.offlineSubmittedAt,
    required this.onlineSubmittedAt,
    required this.status,
  });

  final int id;
  final String title;
  final String description;
  final DateTime offlineSubmittedAt;
  final DateTime onlineSubmittedAt;
  final FormStatus status;
}

class UserProfile {
  const UserProfile({
    required this.fullName,
    required this.role,
    required this.email,
    required this.phone,
  });

  final String fullName;
  final String role;
  final String email;
  final String phone;
}

class _NotificationEntry {
  const _NotificationEntry({
    required this.index,
    required this.notification,
  });

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

String _normalizeDayName(String input) {
  return input.replaceAll(' ', '\u200A');
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
                            (option) => option.toLowerCase().contains(normalized),
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
                        onChanged: (value) => setModalState(() => query = value),
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
                                    groupValue: selectedValue,
                                    title: Text(option),
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
                            (option) => option.toLowerCase().contains(normalized),
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
                        onChanged: (value) => setModalState(() => query = value),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: filtered.isEmpty
                            ? const Center(child: Text('موردی یافت نشد'))
                            : ListView.builder(
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final option = filtered[index];
                                  final isChecked = tempSelection.contains(option);
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
