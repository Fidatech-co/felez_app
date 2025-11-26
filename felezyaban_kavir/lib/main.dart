import 'package:flutter/material.dart';
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
  late final List<_NewFormItem> _newFormItems = List.generate(
    10,
    (index) => _NewFormItem(title: 'فرم ${index + 1}', order: index),
  );

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
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _toPersianDigits('${item.title} به زودی فعال می‌شود.'),
                    ),
                  ),
                );
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
  _NewFormItem({required this.title, required this.order});

  final String title;
  final int order;
  bool isFavorite = false;
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
