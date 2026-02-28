part of 'main.dart';

class WarehouseOverviewNativePage extends StatefulWidget {
  const WarehouseOverviewNativePage({super.key});

  @override
  State<WarehouseOverviewNativePage> createState() =>
      _WarehouseOverviewNativePageState();
}

class _WarehouseOverviewNativePageState
    extends State<WarehouseOverviewNativePage>
    with _FormFieldMixin, _NativePageHelpers<WarehouseOverviewNativePage> {
  SelectionOption? _material;
  DateTime? _fromDate;
  DateTime? _toDate;
  List<SelectionOption> _materialOptions = [];
  bool _isLoadingLookups = true;
  bool _isLoadingOverview = false;
  String? _lookupError;
  String? _overviewError;
  Map<String, dynamic>? _overview;

  @override
  void initState() {
    super.initState();
    _loadMaterials();
  }

  Future<void> _loadMaterials() async {
    setState(() {
      _isLoadingLookups = true;
      _lookupError = null;
    });
    try {
      var materials = await appRepository.getMaterials();
      if (materials.isEmpty) {
        try {
          await appRepository.syncLookups();
        } catch (_) {}
        materials = await appRepository.getMaterials();
      }
      if (!mounted) return;
      final options =
          materials
              .map(
                (item) => SelectionOption(
                  id: item.id,
                  title: item.title,
                  raw: item.raw,
                ),
              )
              .where((item) => item.id > 0 && item.title.trim().isNotEmpty)
              .toList()
            ..sort((a, b) => a.title.compareTo(b.title));
      setState(() {
        _materialOptions = options;
        _material ??= options.isNotEmpty ? options.first : null;
        _isLoadingLookups = false;
      });
      if (_material != null) {
        unawaited(_loadOverview());
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingLookups = false;
        _lookupError = _nativeApiErrorMessage(
          error,
          fallback: 'دریافت لیست کالاها با خطا مواجه شد.',
        );
      });
    }
  }

  Future<void> _loadOverview() async {
    if (_material == null) return;
    setState(() {
      _isLoadingOverview = true;
      _overviewError = null;
    });
    try {
      final response = await appRepository.api.get(
        '/vendoring/warehouse/overview/',
        query: {
          'material': _material!.id.toString(),
          if (_fromDate != null) 'from_date': _formatApiDate(_fromDate!),
          if (_toDate != null) 'to_date': _formatApiDate(_toDate!),
        },
      );
      if (!mounted) return;
      setState(() {
        _overview = _asMap(response);
        _isLoadingOverview = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingOverview = false;
        _overviewError = _nativeApiErrorMessage(
          error,
          fallback: 'دریافت گردش انبار با خطا مواجه شد.',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final overview = _overview ?? const <String, dynamic>{};
    final summary = _asMap(overview['summary']);
    final graph = _asMap(overview['graph']);
    final rows = _asMapList(overview['rows']);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('گردش انبار'), centerTitle: true),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadOverview,
            child: ListView(
              padding: _pagePadding(context),
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
                    child: TextButton.icon(
                      onPressed: _loadMaterials,
                      icon: const Icon(Icons.refresh),
                      label: const Text('تلاش مجدد'),
                    ),
                  ),
                ],
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _selectionField(
                          label: 'کالا',
                          value: _material?.title,
                          placeholder: 'انتخاب کالا',
                          onTap: () async {
                            final item = await _pickOption(
                              title: 'کالا',
                              options: _materialOptions,
                              initialId: _material?.id,
                              isLoading: _isLoadingLookups,
                            );
                            if (item != null) {
                              setState(() => _material = item);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _selectionField(
                                label: 'از تاریخ',
                                value: formatJalaliDate(_fromDate),
                                placeholder: 'انتخاب تاریخ',
                                icon: Icons.event,
                                onTap: () async {
                                  final value = await pickJalaliDate(
                                    initialDate: _fromDate,
                                  );
                                  if (value != null) {
                                    setState(() => _fromDate = value);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _selectionField(
                                label: 'تا تاریخ',
                                value: formatJalaliDate(_toDate),
                                placeholder: 'انتخاب تاریخ',
                                icon: Icons.event,
                                onTap: () async {
                                  final value = await pickJalaliDate(
                                    initialDate: _toDate,
                                  );
                                  if (value != null) {
                                    setState(() => _toDate = value);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _fromDate = null;
                                    _toDate = null;
                                  });
                                  _loadOverview();
                                },
                                icon: const Icon(Icons.clear_all),
                                label: const Text('پاکسازی فیلتر'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _isLoadingOverview
                                    ? null
                                    : _loadOverview,
                                icon: const Icon(Icons.filter_alt_outlined),
                                label: Text(
                                  _isLoadingOverview
                                      ? 'در حال بارگذاری...'
                                      : 'اعمال فیلتر',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (_overviewError != null)
                  Text(
                    _overviewError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (summary.isNotEmpty) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _SummaryMetricChip(
                            label: 'جمع خرید',
                            value: _formatFaNumber(
                              _dynamicDouble(
                                summary['total_purchase_quantity'],
                              ),
                            ),
                          ),
                          _SummaryMetricChip(
                            label: 'جمع انتقال',
                            value: _formatFaNumber(
                              _dynamicDouble(
                                summary['total_transfer_quantity'],
                              ),
                            ),
                          ),
                          _SummaryMetricChip(
                            label: 'جمع مصرف',
                            value: _formatFaNumber(
                              _dynamicDouble(
                                summary['total_consumed_quantity'],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (graph.isNotEmpty) ...[
                  _WarehouseGraphCard(
                    graph: graph,
                    rows: rows,
                    hasSelectedMaterial: _material != null,
                    hasDateFilter: _fromDate != null || _toDate != null,
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  'وضعیت انبارها',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (_isLoadingOverview)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (rows.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'برای فیلترهای انتخاب‌شده داده‌ای یافت نشد.',
                        style: TextStyle(color: Theme.of(context).hintColor),
                      ),
                    ),
                  )
                else
                  ...rows.map(_buildWarehouseRowCard),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWarehouseRowCard(Map<String, dynamic> row) {
    final title = _dynamicString(row['storage_title'], '-');
    final code = _dynamicString(row['storage_code'], '-');
    final role = _storageRoleLabel(_dynamicString(row['role']));
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Chip(label: Text(role), visualDensity: VisualDensity.compact),
              ],
            ),
            const SizedBox(height: 4),
            Text('کد: ${_toPersianDigits(code)}'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SummaryMetricChip(
                  label: 'ابتدای دوره',
                  value: _formatFaNumber(_dynamicDouble(row['opening'])),
                ),
                _SummaryMetricChip(
                  label: 'خرید',
                  value: _formatFaNumber(
                    _dynamicDouble(row['purchase_quantity']),
                  ),
                ),
                _SummaryMetricChip(
                  label: 'مصرف',
                  value: _formatFaNumber(
                    _dynamicDouble(row['consumed_quantity']),
                  ),
                ),
                _SummaryMetricChip(
                  label: 'پایان دوره',
                  value: _formatFaNumber(_dynamicDouble(row['closing'])),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryMetricChip extends StatelessWidget {
  const _SummaryMetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 120),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withAlpha(120),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 2),
          Text(value, style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }
}

class WarehouseTransferRequestNativePage extends StatefulWidget {
  const WarehouseTransferRequestNativePage({super.key, this.initialProjectId});

  final int? initialProjectId;

  @override
  State<WarehouseTransferRequestNativePage> createState() =>
      _WarehouseTransferRequestNativePageState();
}

class _WarehouseTransferRequestNativePageState
    extends State<WarehouseTransferRequestNativePage>
    with
        _FormFieldMixin,
        _NativePageHelpers<WarehouseTransferRequestNativePage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  SelectionOption? _project;
  SelectionOption? _requester;
  SelectionOption? _fromStorage;
  SelectionOption? _toStorage;
  SelectionOption? _material;
  DateTime? _requestDate;
  _NativeAttachmentFile? _attachment;

  List<SelectionOption> _projectOptions = [];
  List<SelectionOption> _requesterOptions = [];
  List<SelectionOption> _storageOptions = [];
  List<SelectionOption> _materialOptions = [];

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
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickAttachment() async {
    try {
      final selected = await _pickNativeAttachmentFile();
      if (!mounted || selected == null) return;
      setState(() => _attachment = selected);
    } catch (_) {
      _showSnack('انتخاب فایل با خطا مواجه شد.');
    }
  }

  void _clearAttachment() {
    setState(() => _attachment = null);
  }

  List<SelectionOption> get _fromStorageOptions => _storageOptions
      .where((item) => _normalizeStorageRole(item.title) != 'hot')
      .toList();

  List<SelectionOption> get _toStorageOptions =>
      _storageOptions.where((item) => item.id != _fromStorage?.id).toList();

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      var projects = await appRepository.getProjects();
      var persons = await appRepository.getPersons();
      var storages = await appRepository.getStorages();
      var materials = await appRepository.getMaterials();
      if (projects.isEmpty ||
          persons.isEmpty ||
          storages.isEmpty ||
          materials.isEmpty) {
        try {
          await appRepository.syncLookups();
        } catch (_) {}
        projects = await appRepository.getProjects();
        persons = await appRepository.getPersons();
        storages = await appRepository.getStorages();
        materials = await appRepository.getMaterials();
      }
      if (!mounted) return;
      final projectOptions = projects
          .map(
            (item) =>
                SelectionOption(id: item.id, title: item.name, raw: item.raw),
          )
          .toList();
      setState(() {
        _projectOptions = projectOptions;
        _requesterOptions = persons
            .map(
              (item) => SelectionOption(
                id: item.id,
                title: item.fullName,
                raw: item.raw,
              ),
            )
            .toList();
        _storageOptions = storages
            .map(
              (item) => SelectionOption(
                id: item.id,
                title: item.displayName,
                raw: item.raw,
              ),
            )
            .toList();
        _materialOptions = materials
            .map(
              (item) => SelectionOption(
                id: item.id,
                title: item.title,
                raw: item.raw,
              ),
            )
            .toList();
        if (widget.initialProjectId != null) {
          for (final option in _projectOptions) {
            if (option.id == widget.initialProjectId) {
              _project = option;
              break;
            }
          }
        }
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = _nativeApiErrorMessage(
          error,
          fallback: 'دریافت اطلاعات فرم درخواست انتقال با خطا مواجه شد.',
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
          title: const Text('ثبت درخواست انتقال کالا'),
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
                  ],
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
                    label: 'درخواست‌دهنده',
                    value: _requester?.title,
                    placeholder: 'انتخاب درخواست‌دهنده',
                    onTap: () async {
                      final item = await _pickOption(
                        title: 'درخواست‌دهنده',
                        options: _requesterOptions,
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
                    label: 'انبار مبدا',
                    value: _fromStorage?.title,
                    placeholder: 'انتخاب انبار مبدا',
                    onTap: () async {
                      final item = await _pickOption(
                        title: 'انبار مبدا',
                        options: _fromStorageOptions,
                        initialId: _fromStorage?.id,
                        isLoading: _isLoading,
                      );
                      if (item != null) {
                        setState(() {
                          _fromStorage = item;
                          if (_toStorage?.id == item.id) {
                            _toStorage = null;
                          }
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _selectionField(
                    label: 'انبار مقصد',
                    value: _toStorage?.title,
                    placeholder: 'انتخاب انبار مقصد',
                    onTap: () async {
                      final item = await _pickOption(
                        title: 'انبار مقصد',
                        options: _toStorageOptions,
                        initialId: _toStorage?.id,
                        isLoading: _isLoading,
                      );
                      if (item != null) {
                        setState(() => _toStorage = item);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _selectionField(
                    label: 'کالا',
                    value: _material?.title,
                    placeholder: 'انتخاب کالا',
                    onTap: () async {
                      final item = await _pickOption(
                        title: 'کالا',
                        options: _materialOptions,
                        initialId: _material?.id,
                        isLoading: _isLoading,
                      );
                      if (item != null) {
                        setState(() => _material = item);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildNumberField(
                    _amountController,
                    'مقدار',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
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
                    'توضیحات (اختیاری)',
                    maxLines: 3,
                    validator: (_) => null,
                  ),
                  const SizedBox(height: 12),
                  _AttachmentPickerCard(
                    file: _attachment,
                    enabled: !_isSubmitting,
                    onPick: _pickAttachment,
                    onClear: _attachment == null ? null : _clearAttachment,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isSubmitting ? null : _submit,
                      icon: const Icon(Icons.swap_horiz_outlined),
                      label: Text(
                        _isSubmitting ? 'در حال ثبت...' : 'ثبت درخواست انتقال',
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
        _requester == null ||
        _fromStorage == null ||
        _toStorage == null ||
        _material == null ||
        _requestDate == null) {
      _showSnack('فیلدهای اصلی فرم را کامل کنید.');
      return;
    }
    if (_fromStorage!.id == _toStorage!.id) {
      _showSnack('انبار مبدا و مقصد نباید یکسان باشند.');
      return;
    }
    final amount = _parseDouble(_amountController.text);
    if (amount == null || amount <= 0) {
      _showSnack('مقدار باید بزرگ‌تر از صفر باشد.');
      return;
    }
    final payload = <String, dynamic>{
      'project': _project!.id,
      'requester_personnel': _requester!.id,
      'from_storage': _fromStorage!.id,
      'to_storage': _toStorage!.id,
      'material': _material!.id,
      'amount': amount,
      'request_date': _formatApiDate(_requestDate!),
      if (_descriptionController.text.trim().isNotEmpty)
        'description': _descriptionController.text.trim(),
    };
    setState(() => _isSubmitting = true);
    try {
      await appRepository.api.postMultipart(
        '/vendoring/warehouse/transfer-requests/',
        fields: payload,
        files: [
          if (_attachment != null)
            ApiMultipartFile(
              field: 'attachment',
              path: _attachment!.path,
              filename: _attachment!.name,
            ),
        ],
      );
      if (!mounted) return;
      _showSnack('درخواست انتقال کالا با موفقیت ثبت شد.');
      Navigator.of(context).pop();
    } catch (error) {
      _showSnack(
        _nativeApiErrorMessage(
          error,
          fallback: 'ثبت درخواست انتقال با خطا مواجه شد.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}

class WarehouseConsumptionRequestNativePage extends StatefulWidget {
  const WarehouseConsumptionRequestNativePage({
    super.key,
    this.initialProjectId,
  });

  final int? initialProjectId;

  @override
  State<WarehouseConsumptionRequestNativePage> createState() =>
      _WarehouseConsumptionRequestNativePageState();
}

class _WarehouseConsumptionRequestNativePageState
    extends State<WarehouseConsumptionRequestNativePage>
    with
        _FormFieldMixin,
        _NativePageHelpers<WarehouseConsumptionRequestNativePage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  SelectionOption? _project;
  SelectionOption? _requester;
  SelectionOption? _storage;
  SelectionOption? _material;
  DateTime? _requestDate;
  _NativeAttachmentFile? _attachment;

  List<SelectionOption> _projectOptions = [];
  List<SelectionOption> _requesterOptions = [];
  List<SelectionOption> _storageOptions = [];
  List<SelectionOption> _materialOptions = [];

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
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickAttachment() async {
    try {
      final selected = await _pickNativeAttachmentFile();
      if (!mounted || selected == null) return;
      setState(() => _attachment = selected);
    } catch (_) {
      _showSnack('انتخاب فایل با خطا مواجه شد.');
    }
  }

  void _clearAttachment() {
    setState(() => _attachment = null);
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      var projects = await appRepository.getProjects();
      var persons = await appRepository.getPersons();
      var storages = await appRepository.getStorages();
      var materials = await appRepository.getMaterials();
      if (projects.isEmpty ||
          persons.isEmpty ||
          storages.isEmpty ||
          materials.isEmpty) {
        try {
          await appRepository.syncLookups();
        } catch (_) {}
        projects = await appRepository.getProjects();
        persons = await appRepository.getPersons();
        storages = await appRepository.getStorages();
        materials = await appRepository.getMaterials();
      }
      if (!mounted) return;
      setState(() {
        _projectOptions = projects
            .map(
              (item) =>
                  SelectionOption(id: item.id, title: item.name, raw: item.raw),
            )
            .toList();
        _requesterOptions = persons
            .map(
              (item) => SelectionOption(
                id: item.id,
                title: item.fullName,
                raw: item.raw,
              ),
            )
            .toList();
        _storageOptions = storages
            .map(
              (item) => SelectionOption(
                id: item.id,
                title: item.displayName,
                raw: item.raw,
              ),
            )
            .toList();
        _materialOptions = materials
            .map(
              (item) => SelectionOption(
                id: item.id,
                title: item.title,
                raw: item.raw,
              ),
            )
            .toList();
        if (widget.initialProjectId != null) {
          for (final option in _projectOptions) {
            if (option.id == widget.initialProjectId) {
              _project = option;
              break;
            }
          }
        }
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = _nativeApiErrorMessage(
          error,
          fallback: 'دریافت اطلاعات فرم درخواست مصرف با خطا مواجه شد.',
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
          title: const Text('ثبت درخواست مصرف کالا'),
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
                  ],
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
                    label: 'درخواست‌دهنده',
                    value: _requester?.title,
                    placeholder: 'انتخاب درخواست‌دهنده',
                    onTap: () async {
                      final item = await _pickOption(
                        title: 'درخواست‌دهنده',
                        options: _requesterOptions,
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
                    label: 'انبار',
                    value: _storage?.title,
                    placeholder: 'انتخاب انبار',
                    onTap: () async {
                      final item = await _pickOption(
                        title: 'انبار',
                        options: _storageOptions,
                        initialId: _storage?.id,
                        isLoading: _isLoading,
                      );
                      if (item != null) {
                        setState(() => _storage = item);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _selectionField(
                    label: 'کالا',
                    value: _material?.title,
                    placeholder: 'انتخاب کالا',
                    onTap: () async {
                      final item = await _pickOption(
                        title: 'کالا',
                        options: _materialOptions,
                        initialId: _material?.id,
                        isLoading: _isLoading,
                      );
                      if (item != null) {
                        setState(() => _material = item);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildNumberField(
                    _amountController,
                    'مقدار',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
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
                    'توضیحات (اختیاری)',
                    maxLines: 3,
                    validator: (_) => null,
                  ),
                  const SizedBox(height: 12),
                  _AttachmentPickerCard(
                    file: _attachment,
                    enabled: !_isSubmitting,
                    onPick: _pickAttachment,
                    onClear: _attachment == null ? null : _clearAttachment,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isSubmitting ? null : _submit,
                      icon: const Icon(Icons.inventory_2_outlined),
                      label: Text(
                        _isSubmitting ? 'در حال ثبت...' : 'ثبت درخواست مصرف',
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
        _requester == null ||
        _storage == null ||
        _material == null ||
        _requestDate == null) {
      _showSnack('فیلدهای اصلی فرم را کامل کنید.');
      return;
    }
    final amount = _parseDouble(_amountController.text);
    if (amount == null || amount <= 0) {
      _showSnack('مقدار باید بزرگ‌تر از صفر باشد.');
      return;
    }
    final payload = <String, dynamic>{
      'project': _project!.id,
      'requester_personnel': _requester!.id,
      'storage': _storage!.id,
      'material': _material!.id,
      'amount': amount,
      'request_date': _formatApiDate(_requestDate!),
      if (_descriptionController.text.trim().isNotEmpty)
        'description': _descriptionController.text.trim(),
    };
    setState(() => _isSubmitting = true);
    try {
      await appRepository.api.postMultipart(
        '/vendoring/warehouse/consumption-requests/',
        fields: payload,
        files: [
          if (_attachment != null)
            ApiMultipartFile(
              field: 'attachment',
              path: _attachment!.path,
              filename: _attachment!.name,
            ),
        ],
      );
      if (!mounted) return;
      _showSnack('درخواست مصرف کالا با موفقیت ثبت شد.');
      Navigator.of(context).pop();
    } catch (error) {
      _showSnack(
        _nativeApiErrorMessage(
          error,
          fallback: 'ثبت درخواست مصرف با خطا مواجه شد.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
