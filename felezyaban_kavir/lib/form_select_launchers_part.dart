part of 'main.dart';

class _ProjectSelectionLauncherPage extends StatefulWidget {
  const _ProjectSelectionLauncherPage({
    required this.formTitle,
    required this.formBuilder,
    this.initialProjectId,
  });

  final String formTitle;
  final Widget Function(SelectionOption project) formBuilder;
  final int? initialProjectId;

  @override
  State<_ProjectSelectionLauncherPage> createState() =>
      _ProjectSelectionLauncherPageState();
}

class _ProjectSelectionLauncherPageState
    extends State<_ProjectSelectionLauncherPage>
    with _FormFieldMixin, _NativePageHelpers<_ProjectSelectionLauncherPage> {
  bool _isLoading = true;
  String? _error;
  SelectionOption? _selectedProject;
  List<SelectionOption> _projectOptions = [];

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      var projects = await appRepository.getProjects();
      if (projects.isEmpty) {
        try {
          await appRepository.syncLookups();
        } catch (_) {}
        projects = await appRepository.getProjects();
      }
      if (!mounted) return;
      final options =
          projects
              .map(
                (project) => SelectionOption(
                  id: project.id,
                  title: project.name,
                  raw: project.raw,
                ),
              )
              .where((item) => item.id > 0 && item.title.trim().isNotEmpty)
              .toList()
            ..sort((a, b) => a.title.compareTo(b.title));
      SelectionOption? preselected;
      if (widget.initialProjectId != null) {
        for (final option in options) {
          if (option.id == widget.initialProjectId) {
            preselected = option;
            break;
          }
        }
      }
      setState(() {
        _projectOptions = options;
        _selectedProject = preselected ?? _selectedProject;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = _nativeApiErrorMessage(
          error,
          fallback: 'دریافت لیست پروژه‌ها با خطا مواجه شد.',
        );
      });
    }
  }

  Future<void> _selectProject() async {
    final result = await _pickOption(
      title: 'پروژه',
      options: _projectOptions,
      initialId: _selectedProject?.id,
      isLoading: _isLoading,
    );
    if (result != null) {
      setState(() => _selectedProject = result);
    }
  }

  Future<void> _continue() async {
    final project = _selectedProject;
    if (project == null) {
      _showSnack('ابتدا پروژه را انتخاب کنید.');
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => widget.formBuilder(project)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: Text(widget.formTitle), centerTitle: true),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: _pagePadding(context),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'انتخاب پروژه',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    if (_isLoading) ...[
                      const LinearProgressIndicator(),
                      const SizedBox(height: 12),
                    ],
                    if (_error != null) ...[
                      Text(
                        _error!,
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
                      value: _selectedProject?.title,
                      placeholder: 'انتخاب پروژه',
                      icon: Icons.business_center_outlined,
                      onTap: _selectProject,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isLoading ? null : _continue,
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('ادامه'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _MachineSelectorCategory { drilling, lightHeavy }

class _MachineSelectionLauncherPage extends StatefulWidget {
  const _MachineSelectionLauncherPage({
    required this.formTitle,
    required this.category,
    required this.formBuilder,
    this.initialProjectId,
    this.initialMachineId,
  });

  final String formTitle;
  final _MachineSelectorCategory category;
  final Widget Function(MachineOption machine, SelectionOption? project)
  formBuilder;
  final int? initialProjectId;
  final int? initialMachineId;

  @override
  State<_MachineSelectionLauncherPage> createState() =>
      _MachineSelectionLauncherPageState();
}

class _MachineSelectionLauncherPageState
    extends State<_MachineSelectionLauncherPage>
    with _FormFieldMixin, _NativePageHelpers<_MachineSelectionLauncherPage> {
  bool _isLoading = true;
  String? _error;
  SelectionOption? _selectedProject;
  SelectionOption? _selectedMachine;
  List<ProjectOption> _projects = [];
  List<MachineOption> _machines = [];

  List<SelectionOption> get _projectOptions =>
      _projects
          .map(
            (project) => SelectionOption(
              id: project.id,
              title: project.name,
              raw: project.raw,
            ),
          )
          .toList()
        ..sort((a, b) => a.title.compareTo(b.title));

  bool _matchesCategory(MachineOption machine) {
    if (widget.category == _MachineSelectorCategory.drilling) {
      return machine.machineType == 100;
    }
    return machine.machineType != 100;
  }

  List<MachineOption> get _filteredMachines {
    final selectedProjectId = _selectedProject?.id;
    return _machines.where((machine) {
      if (!_matchesCategory(machine)) return false;
      if (selectedProjectId == null) return true;
      return machine.projectId == selectedProjectId;
    }).toList()..sort((a, b) => a.displayName.compareTo(b.displayName));
  }

  List<SelectionOption> get _filteredMachineOptions => _filteredMachines
      .map(
        (machine) => SelectionOption(
          id: machine.id,
          title: machine.displayName,
          raw: machine.raw,
        ),
      )
      .toList();

  String get _machineLabel =>
      widget.category == _MachineSelectorCategory.drilling
      ? 'ماشین حفاری'
      : 'ماشین سبک/سنگین';

  @override
  void initState() {
    super.initState();
    _loadLookups();
  }

  Future<void> _loadLookups() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      var projects = await appRepository.getProjects();
      var machines = await appRepository.getMachines();
      if (projects.isEmpty || machines.isEmpty) {
        try {
          await appRepository.syncLookups();
        } catch (_) {}
        projects = await appRepository.getProjects();
        machines = await appRepository.getMachines();
      }
      if (!mounted) return;
      final filteredMachineList = machines
          .where((item) => item.id > 0 && item.displayName.trim().isNotEmpty)
          .toList();
      SelectionOption? projectSelection = _selectedProject;
      if (widget.initialProjectId != null) {
        for (final project in projects) {
          if (project.id == widget.initialProjectId) {
            projectSelection = SelectionOption(
              id: project.id,
              title: project.name,
              raw: project.raw,
            );
            break;
          }
        }
      }
      setState(() {
        _projects = projects;
        _machines = filteredMachineList;
        _selectedProject = projectSelection;
        _isLoading = false;
      });
      if (widget.initialMachineId != null && _selectedMachine == null) {
        final matched = _filteredMachines
            .where((item) => item.id == widget.initialMachineId)
            .toList();
        if (matched.isNotEmpty && mounted) {
          setState(() {
            _selectedMachine = SelectionOption(
              id: matched.first.id,
              title: matched.first.displayName,
              raw: matched.first.raw,
            );
          });
        }
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = _nativeApiErrorMessage(
          error,
          fallback: 'دریافت اطلاعات ماشین‌ها با خطا مواجه شد.',
        );
      });
    }
  }

  Future<void> _selectProject() async {
    final result = await _pickOption(
      title: 'پروژه',
      options: _projectOptions,
      initialId: _selectedProject?.id,
      isLoading: _isLoading,
    );
    if (result == null) return;
    setState(() {
      _selectedProject = result;
      final stillValid = _filteredMachineOptions.any(
        (item) => item.id == _selectedMachine?.id,
      );
      if (!stillValid) {
        _selectedMachine = null;
      }
    });
  }

  Future<void> _selectMachine() async {
    final options = _filteredMachineOptions;
    if (options.isEmpty) {
      _showSnack(
        _selectedProject == null
            ? 'ماشینی برای انتخاب یافت نشد.'
            : 'در پروژه انتخاب‌شده، ماشینی برای انتخاب یافت نشد.',
      );
      return;
    }
    final result = await _pickOption(
      title: _machineLabel,
      options: options,
      initialId: _selectedMachine?.id,
      isLoading: _isLoading,
    );
    if (result != null) {
      setState(() => _selectedMachine = result);
    }
  }

  Future<void> _continue() async {
    final selectedMachineId = _selectedMachine?.id;
    if (selectedMachineId == null) {
      _showSnack('ابتدا $_machineLabel را انتخاب کنید.');
      return;
    }
    MachineOption? machine;
    for (final item in _filteredMachines) {
      if (item.id == selectedMachineId) {
        machine = item;
        break;
      }
    }
    if (machine == null) {
      _showSnack('ماشین انتخاب‌شده معتبر نیست.');
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => widget.formBuilder(machine!, _selectedProject),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final machineOptions = _filteredMachineOptions;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: Text(widget.formTitle), centerTitle: true),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: _pagePadding(context),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'انتخاب پروژه و $_machineLabel',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    if (_isLoading) ...[
                      const LinearProgressIndicator(),
                      const SizedBox(height: 12),
                    ],
                    if (_error != null) ...[
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _loadLookups,
                          icon: const Icon(Icons.refresh),
                          label: const Text('تلاش مجدد'),
                        ),
                      ),
                    ],
                    _selectionField(
                      label: 'پروژه (اختیاری)',
                      value: _selectedProject?.title,
                      placeholder: 'انتخاب پروژه',
                      icon: Icons.business_center_outlined,
                      onTap: _selectProject,
                    ),
                    if (_selectedProject != null) ...[
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => setState(() {
                            _selectedProject = null;
                            final stillValid = _filteredMachineOptions.any(
                              (item) => item.id == _selectedMachine?.id,
                            );
                            if (!stillValid) {
                              _selectedMachine = null;
                            }
                          }),
                          icon: const Icon(Icons.clear),
                          label: const Text('نمایش همه پروژه‌ها'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    _selectionField(
                      label: _machineLabel,
                      value: _selectedMachine?.title,
                      placeholder: 'انتخاب $_machineLabel',
                      icon: Icons.precision_manufacturing_outlined,
                      onTap: _selectMachine,
                    ),
                    if (!_isLoading && machineOptions.isEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'موردی برای انتخاب یافت نشد.',
                        style: TextStyle(color: Theme.of(context).hintColor),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isLoading ? null : _continue,
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('ادامه'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
