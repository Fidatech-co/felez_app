part of 'main.dart';

enum _DeliveryChecklistMode { availability, condition }

class _DeliveryChecklistItem {
  const _DeliveryChecklistItem({
    required this.id,
    required this.title,
    required this.mode,
  });

  final int id;
  final String title;
  final _DeliveryChecklistMode mode;
}

class MachineDeliveryNativePage extends StatefulWidget {
  const MachineDeliveryNativePage({
    super.key,
    required this.machineId,
    required this.machineTitle,
    this.initialProjectId,
  });

  final int machineId;
  final String machineTitle;
  final int? initialProjectId;

  @override
  State<MachineDeliveryNativePage> createState() =>
      _MachineDeliveryNativePageState();
}

class _MachineDeliveryNativePageState extends State<MachineDeliveryNativePage>
    with _FormFieldMixin, _NativePageHelpers<MachineDeliveryNativePage> {
  final _formKey = GlobalKey<FormState>();
  final _paperNumberController = TextEditingController();
  final _usageKmController = TextEditingController();
  final _plaqueController = TextEditingController();
  final _trafficTicketController = TextEditingController(text: '0');
  final _remainTrafficTicketController = TextEditingController(text: '0');
  final _tireHealthController = TextEditingController();

  MachineOption? _machine;
  DateTime? _deliveryDate;
  SelectionOption? _project;
  SelectionOption? _receiver;
  SelectionOption? _giver;
  SelectionOption? _requester;
  ConditionStatus _tireState = ConditionStatus.healthy;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _loadError;
  List<SelectionOption> _projectOptions = [];
  List<SelectionOption> _personOptions = [];
  List<_DeliveryChecklistItem> _availabilityItems = [];
  List<_DeliveryChecklistItem> _conditionItems = [];
  final Map<int, int> _checklistChoices = <int, int>{};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _paperNumberController.dispose();
    _usageKmController.dispose();
    _plaqueController.dispose();
    _trafficTicketController.dispose();
    _remainTrafficTicketController.dispose();
    _tireHealthController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      var machine = await _loadMachineOptionById(widget.machineId);
      var projects = await appRepository.getProjects();
      var persons = await appRepository.getPersons();
      if (machine == null || projects.isEmpty || persons.isEmpty) {
        try {
          await appRepository.syncLookups();
        } catch (_) {}
        machine ??= await _loadMachineOptionById(widget.machineId);
        projects = await appRepository.getProjects();
        persons = await appRepository.getPersons();
      }
      if (machine == null) {
        throw ApiException('machine_not_found');
      }
      final checklistResponse = await appRepository.api.get(
        '/machine/delivery/checklist/',
        query: const {'page': '1', 'page_size': '200'},
      );
      final checklistMaps = _asMapList(_asMap(checklistResponse)['results']);
      final rawChecklists = checklistMaps
          .map(
            (item) => SelectionOption(
              id: _dynamicInt(item['id']) ?? 0,
              title: _dynamicString(item['title']),
              raw: item,
            ),
          )
          .where((item) => item.id > 0 && item.title.trim().isNotEmpty)
          .toList();
      final splitIndex = rawChecklists.indexWhere(
        (item) => item.title.trim() == 'موتور',
      );
      final availability = <_DeliveryChecklistItem>[];
      final condition = <_DeliveryChecklistItem>[];
      for (var i = 0; i < rawChecklists.length; i++) {
        final option = rawChecklists[i];
        final mode = splitIndex != -1 && i >= splitIndex
            ? _DeliveryChecklistMode.condition
            : _DeliveryChecklistMode.availability;
        final item = _DeliveryChecklistItem(
          id: option.id,
          title: option.title,
          mode: mode,
        );
        if (mode == _DeliveryChecklistMode.availability) {
          availability.add(item);
        } else {
          condition.add(item);
        }
      }

      if (!mounted) return;
      setState(() {
        _machine = machine;
        _projectOptions = projects
            .map(
              (item) =>
                  SelectionOption(id: item.id, title: item.name, raw: item.raw),
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
        if (widget.initialProjectId != null) {
          for (final item in _projectOptions) {
            if (item.id == widget.initialProjectId) {
              _project = item;
              break;
            }
          }
        }
        _plaqueController.text = machine!.plaque ?? _plaqueController.text;
        _availabilityItems = availability;
        _conditionItems = condition;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = _nativeApiErrorMessage(
          error,
          fallback: 'دریافت اطلاعات فرم تحویل ماشین با خطا مواجه شد.',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ثبت صورتجلسه تحویل ماشین'),
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
                    icon: Icons.local_shipping_outlined,
                  ),
                  const SizedBox(height: 16),
                  _selectionField(
                    label: 'پروژه',
                    value: _project?.title,
                    placeholder: 'انتخاب پروژه',
                    onTap: () async {
                      final item = await _pickOption(
                        title: 'پروژه',
                        options: _projectOptions,
                        initialId: _project?.id,
                        isLoading: _isLoading,
                      );
                      if (item != null) {
                        setState(() => _project = item);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _selectionField(
                    label: 'تحویل‌گیرنده',
                    value: _receiver?.title,
                    placeholder: 'انتخاب تحویل‌گیرنده',
                    onTap: () async {
                      final item = await _pickOption(
                        title: 'تحویل‌گیرنده',
                        options: _personOptions,
                        initialId: _receiver?.id,
                        isLoading: _isLoading,
                      );
                      if (item != null) {
                        setState(() => _receiver = item);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _selectionField(
                    label: 'تحویل‌دهنده',
                    value: _giver?.title,
                    placeholder: 'انتخاب تحویل‌دهنده',
                    onTap: () async {
                      final item = await _pickOption(
                        title: 'تحویل‌دهنده',
                        options: _personOptions,
                        initialId: _giver?.id,
                        isLoading: _isLoading,
                      );
                      if (item != null) {
                        setState(() => _giver = item);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _selectionField(
                    label: 'دستوردهنده',
                    value: _requester?.title,
                    placeholder: 'انتخاب دستوردهنده',
                    onTap: () async {
                      final item = await _pickOption(
                        title: 'دستوردهنده',
                        options: _personOptions,
                        initialId: _requester?.id,
                        isLoading: _isLoading,
                      );
                      if (item != null) {
                        setState(() => _requester = item);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _selectionField(
                    label: 'تاریخ تحویل',
                    value: formatJalaliDate(_deliveryDate),
                    placeholder: 'انتخاب تاریخ',
                    icon: Icons.event,
                    onTap: () async {
                      final date = await pickJalaliDate(
                        initialDate: _deliveryDate,
                      );
                      if (date != null) {
                        setState(() => _deliveryDate = date);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(_paperNumberController, 'شماره نامه'),
                  const SizedBox(height: 16),
                  _buildNumberField(
                    _usageKmController,
                    'کیلومتر (اختیاری)',
                    validator: (_) => null,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(_plaqueController, 'شماره پلاک'),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildNumberField(
                          _trafficTicketController,
                          'خلافی تا تاریخ تحویل',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildNumberField(
                          _remainTrafficTicketController,
                          'خلافی مانده',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'وضعیت لاستیک',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 8),
                          SegmentedButton<ConditionStatus>(
                            segments: ConditionStatus.values
                                .map(
                                  (item) => ButtonSegment<ConditionStatus>(
                                    value: item,
                                    label: Text(item.label),
                                  ),
                                )
                                .toList(),
                            selected: {_tireState},
                            onSelectionChanged: (selection) {
                              if (selection.isNotEmpty) {
                                setState(() => _tireState = selection.first);
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildNumberField(
                            _tireHealthController,
                            'درصد سلامت لاستیک (اختیاری)',
                            validator: (_) => null,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_availabilityItems.isNotEmpty) ...[
                    Text(
                      'چک‌لیست اقلام و تجهیزات',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: Column(
                        children: _availabilityItems.map((item) {
                          final checked =
                              (_checklistChoices[item.id] ?? 202) == 203;
                          return CheckboxListTile(
                            value: checked,
                            title: Text(item.title),
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: (value) {
                              setState(() {
                                _checklistChoices[item.id] = (value ?? false)
                                    ? 203
                                    : 202;
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_conditionItems.isNotEmpty) ...[
                    Text(
                      'چک‌لیست سلامت قطعات',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: _conditionItems.map((item) {
                            final current = _checklistChoices[item.id];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                children: [
                                  Expanded(child: Text(item.title)),
                                  const SizedBox(width: 8),
                                  SegmentedButton<int>(
                                    emptySelectionAllowed: true,
                                    segments: const [
                                      ButtonSegment<int>(
                                        value: 200,
                                        label: Text('سالم'),
                                      ),
                                      ButtonSegment<int>(
                                        value: 201,
                                        label: Text('ناسالم'),
                                      ),
                                    ],
                                    selected: current == null
                                        ? const <int>{}
                                        : {current},
                                    onSelectionChanged: (selection) {
                                      if (selection.isEmpty) return;
                                      setState(() {
                                        _checklistChoices[item.id] =
                                            selection.first;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isSubmitting ? null : _submit,
                      icon: const Icon(Icons.assignment_turned_in_outlined),
                      label: Text(
                        _isSubmitting ? 'در حال ثبت...' : 'ثبت صورتجلسه تحویل',
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
    if (_project == null ||
        _receiver == null ||
        _giver == null ||
        _requester == null ||
        _deliveryDate == null) {
      _showSnack('پروژه، افراد و تاریخ تحویل را کامل کنید.');
      return;
    }
    final traffic = _parseInt(_trafficTicketController.text);
    final remain = _parseInt(_remainTrafficTicketController.text);
    if (traffic == null || remain == null) {
      _showSnack('مقادیر خلافی معتبر نیست.');
      return;
    }
    final usageKm = _parseInt(_usageKmController.text);
    final tireHealth = _parseInt(_tireHealthController.text);
    final payload = <String, dynamic>{
      'project': _project!.id,
      'machine': widget.machineId,
      'receiver_personnel': _receiver!.id,
      'giver_personnel': _giver!.id,
      'requester': _requester!.id,
      'delivery_date': _formatApiDate(_deliveryDate!),
      'paper_number': _paperNumberController.text.trim(),
      'plaque': _plaqueController.text.trim(),
      'traffic_ticket': traffic,
      'remain_traffic_ticket': remain,
      'tire_state': _tireState == ConditionStatus.healthy ? 200 : 201,
      if (usageKm != null) 'usage_km': usageKm,
      if (tireHealth != null) 'tire_health_percentage': tireHealth,
    };
    setState(() => _isSubmitting = true);
    try {
      final response = await appRepository.api.post(
        '/machine/delivery/reports/',
        body: payload,
      );
      final deliveryId = _dynamicInt(_asMap(response)['id']);
      if (deliveryId == null) {
        throw ApiException('missing_delivery_id');
      }
      if (_checklistChoices.isNotEmpty) {
        final items = _checklistChoices.entries
            .map((entry) => {'checklist': entry.key, 'choice': entry.value})
            .toList();
        await appRepository.api.post(
          '/machine/delivery/report/checklists/bulk/',
          body: {'delivery': deliveryId, 'items': items},
        );
      }
      if (!mounted) return;
      _showSnack('صورتجلسه تحویل با موفقیت ثبت شد.');
      Navigator.of(context).pop();
    } catch (error) {
      _showSnack(
        _nativeApiErrorMessage(
          error,
          fallback: 'ثبت صورتجلسه تحویل با خطا مواجه شد.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}

class MachineRepairRequestNativePage extends StatefulWidget {
  const MachineRepairRequestNativePage({
    super.key,
    required this.machineId,
    required this.machineTitle,
  });

  final int machineId;
  final String machineTitle;

  @override
  State<MachineRepairRequestNativePage> createState() =>
      _MachineRepairRequestNativePageState();
}

class _MachineRepairRequestNativePageState
    extends State<MachineRepairRequestNativePage>
    with _FormFieldMixin, _NativePageHelpers<MachineRepairRequestNativePage> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _activeTimeController = TextEditingController();
  final _costController = TextEditingController();
  final _stopDescriptionController = TextEditingController();

  MachineOption? _machine;
  DateTime? _requestDate;
  DateTime? _activityStart;
  DateTime? _activityEnd;
  SelectionOption? _requester;
  SelectionOption? _requiredPart;
  SelectionOption? _providerCompany;
  bool _companyDoable = true;
  bool _stopRepair = true;
  int _emergencyTime = 210;
  List<SelectionOption> _personOptions = [];
  List<SelectionOption> _partOptions = [];
  List<SelectionOption> _companyOptions = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _activeTimeController.dispose();
    _costController.dispose();
    _stopDescriptionController.dispose();
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
      final partResponse = await appRepository.api.get(
        '/machine/parts/',
        query: {
          'page': '1',
          'page_size': '200',
          'machine_type': machine.machineType.toString(),
        },
      );
      final companyResponse = await appRepository.api.get(
        '/machine/service/company/',
        query: const {'page': '1', 'page_size': '200'},
      );
      final partMaps = _asMapList(_asMap(partResponse)['results']);
      final companyMaps = _asMapList(_asMap(companyResponse)['results']);
      if (!mounted) return;
      setState(() {
        _machine = machine;
        _personOptions = persons
            .map(
              (item) => SelectionOption(
                id: item.id,
                title: item.fullName,
                raw: item.raw,
              ),
            )
            .toList();
        _partOptions = partMaps
            .map(
              (item) => SelectionOption(
                id: _dynamicInt(item['id']) ?? 0,
                title: _dynamicString(item['title']),
                raw: item,
              ),
            )
            .where((item) => item.id > 0 && item.title.trim().isNotEmpty)
            .toList();
        _companyOptions = companyMaps
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
          fallback: 'دریافت اطلاعات فرم درخواست تعمیر با خطا مواجه شد.',
        );
      });
    }
  }

  Future<void> _addPart() async {
    final title = await _promptSimpleText(
      title: 'افزودن قطعه',
      label: 'نام قطعه',
    );
    if (title == null || _machine == null) return;
    try {
      final response = await appRepository.api.post(
        '/machine/parts/',
        body: {
          'title': title,
          'machine_type': _machine!.machineType,
          'code': 'N/A',
          'unit': 'N/A',
        },
      );
      final map = _asMap(response);
      final option = SelectionOption(
        id: _dynamicInt(map['id']) ?? 0,
        title: _dynamicString(map['title']),
        raw: map,
      );
      if (option.id <= 0 || option.title.isEmpty) return;
      if (!mounted) return;
      setState(() {
        _partOptions = [..._partOptions, option];
        _requiredPart = option;
      });
    } catch (error) {
      _showSnack(
        _nativeApiErrorMessage(error, fallback: 'افزودن قطعه با خطا مواجه شد.'),
      );
    }
  }

  Future<void> _addCompany() async {
    final title = await _promptSimpleText(
      title: 'افزودن شرکت تجهیزکننده',
      label: 'نام شرکت',
    );
    if (title == null) return;
    try {
      final response = await appRepository.api.post(
        '/machine/service/company/',
        body: {'title': title},
      );
      final map = _asMap(response);
      final option = SelectionOption(
        id: _dynamicInt(map['id']) ?? 0,
        title: _dynamicString(map['title']),
        raw: map,
      );
      if (option.id <= 0 || option.title.isEmpty) return;
      if (!mounted) return;
      setState(() {
        _companyOptions = [..._companyOptions, option];
        if (!_companyDoable) {
          _providerCompany = option;
        }
      });
    } catch (error) {
      _showSnack(
        _nativeApiErrorMessage(error, fallback: 'افزودن شرکت با خطا مواجه شد.'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ثبت درخواست تعمیر ماشین'),
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
                    icon: Icons.build_outlined,
                  ),
                  const SizedBox(height: 16),
                  _selectionField(
                    label: 'درخواست‌دهنده',
                    value: _requester?.title,
                    placeholder: 'انتخاب درخواست‌دهنده',
                    onTap: () async {
                      final item = await _pickOption(
                        title: 'درخواست‌دهنده',
                        options: _personOptions,
                        initialId: _requester?.id,
                        isLoading: _isLoading,
                      );
                      if (item != null) {
                        setState(() => _requester = item);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _selectionField(
                    label: 'تاریخ درخواست',
                    value: formatJalaliDate(_requestDate),
                    placeholder: 'انتخاب تاریخ',
                    icon: Icons.event,
                    onTap: () async {
                      final date = await pickJalaliDate(
                        initialDate: _requestDate,
                      );
                      if (date != null) {
                        setState(() => _requestDate = date);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    _descriptionController,
                    'شرح فعالیت درخواستی',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  _buildNumberField(
                    _activeTimeController,
                    'مدت زمان فعالیت (دقیقه)',
                  ),
                  const SizedBox(height: 16),
                  _selectionField(
                    label: 'شروع کار',
                    value: formatJalaliDate(_activityStart, includeTime: true),
                    placeholder: 'انتخاب تاریخ و ساعت',
                    icon: Icons.play_circle_outline,
                    onTap: () async {
                      final value = await pickJalaliDateTime(
                        initialDate: _activityStart,
                      );
                      if (value != null) {
                        setState(() => _activityStart = value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _selectionField(
                    label: 'پایان کار',
                    value: formatJalaliDate(_activityEnd, includeTime: true),
                    placeholder: 'انتخاب تاریخ و ساعت',
                    icon: Icons.stop_circle_outlined,
                    onTap: () async {
                      final value = await pickJalaliDateTime(
                        initialDate: _activityEnd,
                      );
                      if (value != null) {
                        setState(() => _activityEnd = value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'میزان فوریت',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 8),
                          SegmentedButton<int>(
                            segments: const [
                              ButtonSegment<int>(
                                value: 210,
                                label: Text('عادی'),
                              ),
                              ButtonSegment<int>(
                                value: 211,
                                label: Text('ضروری'),
                              ),
                            ],
                            selected: {_emergencyTime},
                            onSelectionChanged: (selection) {
                              if (selection.isNotEmpty) {
                                setState(
                                  () => _emergencyTime = selection.first,
                                );
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'امکان انجام داخل شرکت وجود دارد',
                            ),
                            value: _companyDoable,
                            onChanged: (value) {
                              setState(() {
                                _companyDoable = value;
                                if (value) {
                                  _providerCompany = null;
                                }
                              });
                            },
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _selectionField(
                                  label: 'قطعه تجهیزاتی',
                                  value: _requiredPart?.title,
                                  placeholder: 'انتخاب قطعه',
                                  onTap: () async {
                                    final item = await _pickOption(
                                      title: 'قطعه تجهیزاتی',
                                      options: _partOptions,
                                      initialId: _requiredPart?.id,
                                      isLoading: _isLoading,
                                    );
                                    if (item != null) {
                                      setState(() => _requiredPart = item);
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton.filledTonal(
                                onPressed: _isLoading ? null : _addPart,
                                icon: const Icon(Icons.add),
                                tooltip: 'افزودن قطعه',
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _selectionField(
                                  label: 'شرکت تجهیزکننده (اختیاری)',
                                  value: _providerCompany?.title,
                                  placeholder: _companyDoable
                                      ? 'در حالت داخل شرکت غیرفعال است'
                                      : 'انتخاب شرکت',
                                  onTap: () async {
                                    if (_companyDoable) {
                                      _showSnack(
                                        'در حالت داخل شرکت، شرکت تجهیزکننده لازم نیست.',
                                      );
                                      return;
                                    }
                                    final item = await _pickOption(
                                      title: 'شرکت تجهیزکننده',
                                      options: _companyOptions,
                                      initialId: _providerCompany?.id,
                                      isLoading: _isLoading,
                                    );
                                    if (item != null) {
                                      setState(() => _providerCompany = item);
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton.filledTonal(
                                onPressed: _isLoading ? null : _addCompany,
                                icon: const Icon(Icons.add_business_outlined),
                                tooltip: 'افزودن شرکت',
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildNumberField(_costController, 'هزینه تعمیرات'),
                          const SizedBox(height: 12),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('تعمیرات باعث توقف شده است'),
                            value: _stopRepair,
                            onChanged: (value) =>
                                setState(() => _stopRepair = value),
                          ),
                          const SizedBox(height: 8),
                          _buildTextField(
                            _stopDescriptionController,
                            'علت توقف (اختیاری)',
                            maxLines: 2,
                            validator: (_) => null,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isSubmitting ? null : _submit,
                      icon: const Icon(Icons.handyman_outlined),
                      label: Text(
                        _isSubmitting ? 'در حال ثبت...' : 'ثبت درخواست تعمیر',
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
    if (_requester == null ||
        _requestDate == null ||
        _activityStart == null ||
        _activityEnd == null) {
      _showSnack('فیلدهای اصلی فرم را کامل کنید.');
      return;
    }
    if (_activityEnd!.isBefore(_activityStart!)) {
      _showSnack('پایان کار باید بعد از شروع کار باشد.');
      return;
    }
    if (_requiredPart == null) {
      _showSnack('قطعه تجهیزاتی را انتخاب کنید.');
      return;
    }
    final activeTime = _parseInt(_activeTimeController.text);
    final cost = _parseInt(_costController.text);
    if (activeTime == null || cost == null) {
      _showSnack('مقادیر عددی فرم معتبر نیست.');
      return;
    }
    final payload = <String, dynamic>{
      'machine': widget.machineId,
      'requester': _requester!.id,
      'request_date': _formatApiDate(_requestDate!),
      'description': _descriptionController.text.trim(),
      'active_time': activeTime,
      'activity_start': _formatApiDateTime(_activityStart!),
      'activity_end': _formatApiDateTime(_activityEnd!),
      'emergency_time': _emergencyTime,
      'company_doable': _companyDoable,
      'required_part': _requiredPart!.id,
      if (!_companyDoable && _providerCompany != null)
        'provider_company': _providerCompany!.id,
      'cost': cost,
      'stop_repair': _stopRepair,
      if (_stopDescriptionController.text.trim().isNotEmpty)
        'stop_description': _stopDescriptionController.text.trim(),
    };
    setState(() => _isSubmitting = true);
    try {
      await appRepository.api.post('/machine/repair/requests/', body: payload);
      if (!mounted) return;
      _showSnack('درخواست تعمیر با موفقیت ثبت شد.');
      Navigator.of(context).pop();
    } catch (error) {
      _showSnack(
        _nativeApiErrorMessage(
          error,
          fallback: 'ثبت درخواست تعمیر با خطا مواجه شد.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
