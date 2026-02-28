part of 'main.dart';

String _nativeApiErrorMessage(
  Object error, {
  String fallback = 'انجام عملیات با خطا مواجه شد.',
}) {
  if (error is ApiException) {
    final extracted = _extractFirstApiError(error.data);
    if (extracted != null && extracted.trim().isNotEmpty) {
      return extracted;
    }
    if (error.statusCode != null) {
      return 'خطای سرور (${_toPersianDigits(error.statusCode.toString())})';
    }
  }
  return fallback;
}

String? _extractFirstApiError(dynamic data) {
  if (data == null) {
    return null;
  }
  if (data is String) {
    return data;
  }
  if (data is List) {
    for (final item in data) {
      final text = _extractFirstApiError(item);
      if (text != null && text.isNotEmpty) {
        return text;
      }
    }
    return null;
  }
  if (data is Map) {
    final map = Map<dynamic, dynamic>.from(data);
    for (final entry in map.entries) {
      final text = _extractFirstApiError(entry.value);
      if (text != null && text.isNotEmpty) {
        return text;
      }
    }
  }
  return null;
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return <String, dynamic>{};
}

List<Map<String, dynamic>> _asMapList(dynamic value) {
  if (value is! List) {
    return const <Map<String, dynamic>>[];
  }
  return value.map(_asMap).toList();
}

int? _dynamicInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

double? _dynamicDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

String _dynamicString(dynamic value, [String fallback = '']) {
  if (value == null) return fallback;
  return value.toString();
}

String _formatFaNumber(num? value, {int maxFraction = 2}) {
  if (value == null) return '۰';
  final fractionDigits = maxFraction < 0 ? 0 : maxFraction;
  var text = value.toStringAsFixed(fractionDigits);
  if (fractionDigits > 0 && text.contains('.')) {
    text = text.replaceFirst(RegExp(r'\.?0+$'), '');
  }
  return _toPersianDigits(text);
}

Future<List<Map<String, dynamic>>> _fetchAllPaginatedMaps(
  String path, {
  Map<String, String>? query,
  int pageSize = 200,
}) async {
  final results = <Map<String, dynamic>>[];
  var page = 1;
  var expectedPages = 1;
  while (page <= expectedPages) {
    final queryMap = <String, String>{
      ...?query,
      'page': '$page',
      'page_size': '$pageSize',
    };
    final response = await appRepository.api.get(path, query: queryMap);
    if (response is List) {
      return _asMapList(response);
    }
    final map = _asMap(response);
    final pageResults = _asMapList(map['results']);
    results.addAll(pageResults);
    final count = _dynamicInt(map['count']);
    if (count == null) {
      if (pageResults.length < pageSize) {
        break;
      }
      page += 1;
      continue;
    }
    final computedPages = count <= 0 ? 1 : ((count + pageSize - 1) ~/ pageSize);
    expectedPages = computedPages < 1 ? 1 : computedPages;
    page += 1;
  }
  return results;
}

Future<MachineOption?> _loadMachineOptionById(int machineId) async {
  try {
    final cached = await appRepository.getMachines();
    for (final machine in cached) {
      if (machine.id == machineId) {
        return machine;
      }
    }
  } catch (_) {
    // Ignore cache errors and fall back to API.
  }
  final response = await appRepository.api.get('/machine/$machineId/');
  final map = _asMap(response);
  if (map.isEmpty) {
    return null;
  }
  return MachineOption.fromJson(map);
}

String _normalizeStorageRole(String? title) {
  final normalized = (title ?? '')
      .replaceAll('ي', 'ی')
      .replaceAll('ك', 'ک')
      .trim()
      .toLowerCase();
  if (normalized.contains('داغ') || normalized.contains('hot')) return 'hot';
  if (normalized.contains('مرکزی') ||
      normalized.contains('اصلی') ||
      normalized.contains('central')) {
    return 'central';
  }
  return 'project';
}

String _storageRoleLabel(String? role) {
  switch (role) {
    case 'central':
      return 'مرکزی';
    case 'hot':
      return 'داخی';
    default:
      return 'پروژه';
  }
}

mixin _NativePageHelpers<T extends StatefulWidget>
    on State<T>, _FormFieldMixin<T> {
  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<SelectionOption?> _pickOption({
    required String title,
    required List<SelectionOption> options,
    int? initialId,
    bool isLoading = false,
  }) async {
    if (isLoading) {
      _showSnack('در حال دریافت اطلاعات هستیم.');
      return null;
    }
    if (options.isEmpty) {
      _showSnack('لیست $title خالی است.');
      return null;
    }
    return showSearchableSingleOptionSheet(
      context: context,
      title: title,
      options: options,
      initialId: initialId,
    );
  }

  Widget _readonlyField({
    required String label,
    required String value,
    IconData? icon,
  }) {
    return InputDecorator(
      isEmpty: false,
      decoration: _inputDecoration(
        label,
        prefixIcon: icon,
        alwaysFloatLabel: true,
      ),
      child: Text(value),
    );
  }

  Future<String?> _promptSimpleText({
    required String title,
    required String label,
  }) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text(title),
            content: TextField(
              controller: controller,
              autofocus: true,
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
                child: const Text('ثبت'),
              ),
            ],
          ),
        );
      },
    );
    controller.dispose();
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }
}

class NativeConjectureCreatePage extends StatefulWidget {
  const NativeConjectureCreatePage({
    super.key,
    this.initialProjectId,
    this.initialProjectTitle,
  });

  final int? initialProjectId;
  final String? initialProjectTitle;

  @override
  State<NativeConjectureCreatePage> createState() =>
      _NativeConjectureCreatePageState();
}

class _NativeConjectureCreatePageState extends State<NativeConjectureCreatePage>
    with _FormFieldMixin, _NativePageHelpers<NativeConjectureCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _xController = TextEditingController();
  final _yController = TextEditingController();
  final _zController = TextEditingController();
  final _angleController = TextEditingController(text: '0');
  final _azimuthController = TextEditingController(text: '0');

  DateTime? _startDate;
  DateTime? _endDate;
  bool _isSubmitting = false;
  bool _isLoadingProjects = true;
  bool _didAttemptProjectSync = false;
  String? _projectLookupError;
  SelectionOption? _project;
  List<SelectionOption> _projectOptions = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialProjectId != null &&
        (widget.initialProjectTitle?.trim().isNotEmpty ?? false)) {
      _project = SelectionOption(
        id: widget.initialProjectId!,
        title: widget.initialProjectTitle!.trim(),
        raw: const <String, dynamic>{},
      );
    }
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    setState(() {
      _isLoadingProjects = true;
      _projectLookupError = null;
    });
    try {
      Future<List<ProjectOption>> loadProjects() => appRepository.getProjects();
      var projects = await loadProjects();
      if (!_didAttemptProjectSync && projects.isEmpty) {
        _didAttemptProjectSync = true;
        try {
          await appRepository.syncLookups();
        } catch (_) {}
        projects = await loadProjects();
      }
      if (!mounted) return;
      final options =
          projects
              .where((item) => !_isExploratoryProject(item.raw))
              .map(
                (item) => SelectionOption(
                  id: item.id,
                  title: item.name,
                  raw: item.raw,
                ),
              )
              .where((item) => item.id > 0 && item.title.trim().isNotEmpty)
              .toList()
            ..sort((a, b) => a.title.compareTo(b.title));
      SelectionOption? selected = _project;
      if (widget.initialProjectId != null) {
        for (final option in options) {
          if (option.id == widget.initialProjectId) {
            selected = option;
            break;
          }
        }
      }
      if (selected != null &&
          !options.any((option) => option.id == selected!.id)) {
        selected = null;
      }
      setState(() {
        _projectOptions = options;
        _project = selected;
        _isLoadingProjects = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingProjects = false;
        _projectLookupError = _nativeApiErrorMessage(
          error,
          fallback: 'دریافت فهرست پروژه‌ها با خطا مواجه شد.',
        );
      });
    }
  }

  int? _projectTypeId(Map<String, dynamic> raw) {
    final value = raw['project_type'] ?? raw['type'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  bool _isExploratoryProject(Map<String, dynamic> raw) {
    final typeId = _projectTypeId(raw);
    if (typeId == 21) {
      return true;
    }
    final display =
        (raw['project_type_display'] ?? raw['type_display'] ?? raw['type_name'])
            ?.toString() ??
        '';
    return display.contains('اکتشاف');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _xController.dispose();
    _yController.dispose();
    _zController.dispose();
    _angleController.dispose();
    _azimuthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('ایجاد گمانه'), centerTitle: true),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: _pagePadding(context),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isLoadingProjects) ...[
                    const LinearProgressIndicator(),
                    const SizedBox(height: 12),
                  ],
                  if (_projectLookupError != null) ...[
                    Text(
                      _projectLookupError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _loadProjects,
                        icon: const Icon(Icons.refresh),
                        label: const Text('تلاش مجدد'),
                      ),
                    ),
                  ],
                  _selectionField(
                    label: 'پروژه',
                    value: _project?.title,
                    placeholder:
                        'انتخاب پروژه (فقط پروژه‌های فعال غیر اکتشافی)',
                    icon: Icons.business_center_outlined,
                    onTap: () async {
                      final item = await _pickOption(
                        title: 'پروژه',
                        options: _projectOptions,
                        initialId: _project?.id,
                        isLoading: _isLoadingProjects,
                      );
                      if (item != null) {
                        setState(() => _project = item);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(_nameController, 'نام گمانه'),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildNumberField(
                          _xController,
                          'مختصات X',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildNumberField(
                          _yController,
                          'مختصات Y',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildNumberField(
                    _zController,
                    'مختصات Z',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildNumberField(_azimuthController, 'آزیموت'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildNumberField(
                          _angleController,
                          'زاویه حفاری',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _selectionField(
                    label: 'تاریخ شروع',
                    value: formatJalaliDate(_startDate),
                    placeholder: 'انتخاب تاریخ',
                    icon: Icons.event,
                    onTap: () async {
                      final date = await pickJalaliDate(
                        initialDate: _startDate,
                      );
                      if (date != null) {
                        setState(() => _startDate = date);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _selectionField(
                    label: 'تاریخ پایان (اختیاری)',
                    value: formatJalaliDate(_endDate),
                    placeholder: 'انتخاب تاریخ',
                    icon: Icons.event_available,
                    onTap: () async {
                      final date = await pickJalaliDate(initialDate: _endDate);
                      if (date != null) {
                        setState(() => _endDate = date);
                      }
                    },
                  ),
                  if (_endDate != null) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => setState(() => _endDate = null),
                        icon: const Icon(Icons.clear),
                        label: const Text('پاک کردن تاریخ پایان'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isSubmitting ? null : _submit,
                      icon: const Icon(Icons.save_outlined),
                      label: Text(
                        _isSubmitting ? 'در حال ثبت...' : 'ثبت گمانه',
                      ),
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

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_project == null) {
      _showSnack('پروژه الزامی است.');
      return;
    }
    if (_startDate == null) {
      _showSnack('تاریخ شروع الزامی است.');
      return;
    }
    final x = _parseDouble(_xController.text);
    final y = _parseDouble(_yController.text);
    final z = _parseDouble(_zController.text);
    final angle = _parseInt(_angleController.text);
    final azimuth = _parseInt(_azimuthController.text);
    if (x == null ||
        y == null ||
        z == null ||
        angle == null ||
        azimuth == null) {
      _showSnack('مقادیر عددی را به‌درستی وارد کنید.');
      return;
    }

    final payload = <String, dynamic>{
      'project': _project!.id,
      'name': _nameController.text.trim(),
      'angle': angle,
      'azimuth': azimuth,
      'location_X': x,
      'location_Y': y,
      'location_Z': z,
      'strat_date': _formatApiDate(_startDate!),
      if (_endDate != null) 'end_date': _formatApiDate(_endDate!),
    };

    setState(() => _isSubmitting = true);
    try {
      await appRepository.api.post('/conjecture/', body: payload);
      if (!mounted) return;
      _showSnack('گمانه با موفقیت ثبت شد.');
      Navigator.of(context).pop();
    } catch (error) {
      _showSnack(
        _nativeApiErrorMessage(error, fallback: 'ثبت گمانه با خطا مواجه شد.'),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}

class MachinePeriodicServiceNativePage extends StatefulWidget {
  const MachinePeriodicServiceNativePage({
    super.key,
    required this.machineId,
    required this.machineTitle,
  });

  final int machineId;
  final String machineTitle;

  @override
  State<MachinePeriodicServiceNativePage> createState() =>
      _MachinePeriodicServiceNativePageState();
}

class _MachinePeriodicServiceNativePageState
    extends State<MachinePeriodicServiceNativePage>
    with _FormFieldMixin, _NativePageHelpers<MachinePeriodicServiceNativePage> {
  final _formKey = GlobalKey<FormState>();
  final _usageController = TextEditingController();

  MachineOption? _machine;
  DateTime? _serviceDateTime;
  SelectionOption? _driver;
  SelectionOption? _serviceMan;
  List<SelectionOption> _driverOptions = [];
  List<SelectionOption> _serviceManOptions = [];
  List<SelectionOption> _serviceItemOptions = [];
  final Set<int> _selectedServiceItemIds = <int>{};
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _loadError;

  bool get _isDrillingMachine => (_machine?.machineType ?? 0) == 100;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _usageController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      var machine = await _loadMachineOptionById(widget.machineId);
      var persons = await appRepository.getPersons();
      if (machine == null || persons.isEmpty) {
        try {
          await appRepository.syncLookups();
        } catch (_) {}
        machine ??= await _loadMachineOptionById(widget.machineId);
        persons = await appRepository.getPersons();
      }
      if (machine == null) {
        throw ApiException('machine_not_found');
      }
      final serviceMenResponse = await appRepository.api.get(
        '/machine/service/men/',
        query: const {'page': '1', 'page_size': '200'},
      );
      final serviceMen = _asMapList(_asMap(serviceMenResponse)['results']);
      final serviceItems = await _fetchAllPaginatedMaps(
        '/machine/service/item/',
        query: {'category__machine_type': machine.machineType.toString()},
      );
      if (!mounted) return;
      setState(() {
        _machine = machine;
        _driverOptions = persons
            .map(
              (item) => SelectionOption(
                id: item.id,
                title: item.fullName,
                raw: item.raw,
              ),
            )
            .toList();
        _serviceManOptions = serviceMen
            .map(
              (item) => SelectionOption(
                id: _dynamicInt(item['id']) ?? 0,
                title: _dynamicString(item['name']),
                raw: item,
              ),
            )
            .where((item) => item.id > 0 && item.title.trim().isNotEmpty)
            .toList();
        _serviceItemOptions = serviceItems
            .map(
              (item) => SelectionOption(
                id: _dynamicInt(item['id']) ?? 0,
                title: _dynamicString(item['title']),
                raw: item,
              ),
            )
            .where((item) => item.id > 0 && item.title.trim().isNotEmpty)
            .toList();
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = _nativeApiErrorMessage(
          error,
          fallback: 'دریافت اطلاعات فرم سرویس دوره‌ای با خطا مواجه شد.',
        );
      });
    }
  }

  Future<void> _addServiceMan() async {
    final name = await _promptSimpleText(
      title: 'افزودن سرویس‌کار',
      label: 'نام سرویس‌کار',
    );
    if (name == null) return;
    try {
      final response = await appRepository.api.post(
        '/machine/service/men/',
        body: {'name': name},
      );
      final map = _asMap(response);
      final option = SelectionOption(
        id: _dynamicInt(map['id']) ?? 0,
        title: _dynamicString(map['name']),
        raw: map,
      );
      if (option.id <= 0 || option.title.isEmpty) return;
      if (!mounted) return;
      setState(() {
        _serviceManOptions = [..._serviceManOptions, option];
        _serviceMan = option;
      });
    } catch (error) {
      _showSnack(
        _nativeApiErrorMessage(
          error,
          fallback: 'افزودن سرویس‌کار با خطا مواجه شد.',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ثبت سرویس دوره‌ای'),
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
                  if (_isLoading) ...[
                    const LinearProgressIndicator(),
                    const SizedBox(height: 12),
                  ],
                  if (_loadError != null) ...[
                    Text(
                      _loadError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _loadData,
                        icon: const Icon(Icons.refresh),
                        label: const Text('تلاش مجدد'),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  _readonlyField(
                    label: 'ماشین',
                    value: _machine?.displayName ?? widget.machineTitle,
                    icon: Icons.precision_manufacturing_outlined,
                  ),
                  const SizedBox(height: 16),
                  _selectionField(
                    label: 'تاریخ و ساعت سرویس',
                    value: formatJalaliDate(
                      _serviceDateTime,
                      includeTime: true,
                    ),
                    placeholder: 'انتخاب تاریخ و ساعت',
                    icon: Icons.event,
                    onTap: () async {
                      final date = await pickJalaliDateTime(
                        initialDate: _serviceDateTime,
                      );
                      if (date != null) {
                        setState(() => _serviceDateTime = date);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildNumberField(
                    _usageController,
                    _isDrillingMachine
                        ? 'ساعت کار هنگام سرویس'
                        : 'کیلومتر هنگام سرویس',
                  ),
                  const SizedBox(height: 16),
                  _selectionField(
                    label: 'راننده',
                    value: _driver?.title,
                    placeholder: 'انتخاب راننده',
                    onTap: () async {
                      final item = await _pickOption(
                        title: 'راننده',
                        options: _driverOptions,
                        initialId: _driver?.id,
                        isLoading: _isLoading,
                      );
                      if (item != null) {
                        setState(() => _driver = item);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _selectionField(
                          label: 'سرویس‌کار',
                          value: _serviceMan?.title,
                          placeholder: 'انتخاب سرویس‌کار',
                          onTap: () async {
                            final item = await _pickOption(
                              title: 'سرویس‌کار',
                              options: _serviceManOptions,
                              initialId: _serviceMan?.id,
                              isLoading: _isLoading,
                            );
                            if (item != null) {
                              setState(() => _serviceMan = item);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        onPressed: _isLoading ? null : _addServiceMan,
                        icon: const Icon(Icons.add),
                        tooltip: 'افزودن سرویس‌کار',
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'چک‌لیست سرویس',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (_serviceItemOptions.isEmpty)
                    Text(
                      _isLoading
                          ? 'در حال دریافت...'
                          : 'آیتمی برای این نوع ماشین یافت نشد.',
                      style: TextStyle(color: Theme.of(context).hintColor),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _serviceItemOptions.map((item) {
                        return FilterChip(
                          label: Text(item.title),
                          selected: _selectedServiceItemIds.contains(item.id),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedServiceItemIds.add(item.id);
                              } else {
                                _selectedServiceItemIds.remove(item.id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isSubmitting ? null : _submit,
                      icon: const Icon(Icons.build_circle_outlined),
                      label: Text(
                        _isSubmitting ? 'در حال ثبت...' : 'ثبت سرویس دوره‌ای',
                      ),
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

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_serviceDateTime == null || _driver == null || _serviceMan == null) {
      _showSnack('تاریخ، راننده و سرویس‌کار را انتخاب کنید.');
      return;
    }
    if (_selectedServiceItemIds.isEmpty) {
      _showSnack('حداقل یک آیتم چک‌لیست سرویس را انتخاب کنید.');
      return;
    }
    final usage = _parseInt(_usageController.text);
    if (usage == null) {
      _showSnack('مقدار کارکرد معتبر نیست.');
      return;
    }
    final payload = <String, dynamic>{
      'cause': '',
      'start_date': _formatApiDateTime(_serviceDateTime!),
      'machine': widget.machineId,
      'driver': _driver!.id,
      'service_man': _serviceMan!.id,
      if (_isDrillingMachine) 'usage_hour': usage else 'usage_km': usage,
      if (_isDrillingMachine) 'usage_km': 0 else 'usage_hour': 0,
    };
    setState(() => _isSubmitting = true);
    try {
      final response = await appRepository.api.post(
        '/machine/periodic/services/',
        body: payload,
      );
      final serviceId = _dynamicInt(_asMap(response)['id']);
      if (serviceId == null) {
        throw ApiException('missing_service_id');
      }
      for (final itemId in _selectedServiceItemIds) {
        await appRepository.api.post(
          '/machine/service/checklist/',
          body: {'service': serviceId, 'service_item': itemId},
        );
      }
      if (!mounted) return;
      _showSnack('سرویس دوره‌ای با موفقیت ثبت شد.');
      Navigator.of(context).pop();
    } catch (error) {
      _showSnack(
        _nativeApiErrorMessage(
          error,
          fallback: 'ثبت سرویس دوره‌ای با خطا مواجه شد.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
