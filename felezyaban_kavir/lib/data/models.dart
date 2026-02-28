class AuthTokens {
  const AuthTokens({required this.access, required this.refresh});

  final String access;
  final String refresh;
}

class ProfileLogEntry {
  const ProfileLogEntry({
    required this.id,
    required this.message,
    required this.createdAt,
  });

  final int id;
  final String message;
  final DateTime createdAt;
}

class FormSubmission {
  FormSubmission({
    this.id,
    required this.formType,
    required this.title,
    required this.description,
    required this.payload,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
    this.remoteId,
    this.lastError,
  });

  final int? id;
  final String formType;
  final String title;
  final String description;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String status;
  final int? remoteId;
  final String? lastError;

  FormSubmission copyWith({String? status, int? remoteId, String? lastError}) {
    return FormSubmission(
      id: id,
      formType: formType,
      title: title,
      description: description,
      payload: payload,
      createdAt: createdAt,
      updatedAt: updatedAt,
      status: status ?? this.status,
      remoteId: remoteId ?? this.remoteId,
      lastError: lastError ?? this.lastError,
    );
  }
}

class SelectionOption {
  const SelectionOption({
    required this.id,
    required this.title,
    required this.raw,
  });

  final int id;
  final String title;
  final Map<String, dynamic> raw;
}

class ProjectOption {
  const ProjectOption({
    required this.id,
    required this.name,
    required this.raw,
  });

  final int id;
  final String name;
  final Map<String, dynamic> raw;

  factory ProjectOption.fromJson(Map<String, dynamic> json) {
    return ProjectOption(
      id: json['id'] as int? ?? 0,
      name: (json['name'] ?? json['title'] ?? '').toString(),
      raw: json,
    );
  }
}

class ConjectureOption {
  const ConjectureOption({
    required this.id,
    required this.name,
    required this.projectId,
    required this.raw,
  });

  final int id;
  final String name;
  final int? projectId;
  final Map<String, dynamic> raw;

  factory ConjectureOption.fromJson(Map<String, dynamic> json) {
    return ConjectureOption(
      id: json['id'] as int? ?? 0,
      name: (json['name'] ?? json['title'] ?? '').toString(),
      projectId: json['project'] as int?,
      raw: json,
    );
  }
}

class MachineOption {
  const MachineOption({
    required this.id,
    required this.name,
    required this.machineType,
    required this.machineTypeDisplay,
    required this.projectId,
    required this.plaque,
    required this.raw,
  });

  final int id;
  final String name;
  final int machineType;
  final String machineTypeDisplay;
  final int? projectId;
  final String? plaque;
  final Map<String, dynamic> raw;

  factory MachineOption.fromJson(Map<String, dynamic> json) {
    return MachineOption(
      id: json['id'] as int? ?? 0,
      name: (json['name'] ?? json['title'] ?? '').toString(),
      machineType: json['machine_type'] as int? ?? 0,
      machineTypeDisplay: (json['machine_type_display'] ?? '').toString(),
      projectId: json['project'] as int?,
      plaque: json['plaque']?.toString(),
      raw: json,
    );
  }

  String get displayName {
    if (plaque == null || plaque!.isEmpty) {
      return name;
    }
    return '$name (${plaque!})';
  }
}

class PersonOption {
  const PersonOption({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.jobName,
    required this.raw,
  });

  final int id;
  final String firstName;
  final String lastName;
  final String? jobName;
  final Map<String, dynamic> raw;

  factory PersonOption.fromJson(Map<String, dynamic> json) {
    return PersonOption(
      id: json['id'] as int? ?? 0,
      firstName: (json['first_name'] ?? '').toString(),
      lastName: (json['last_name'] ?? '').toString(),
      jobName: json['job_name']?.toString(),
      raw: json,
    );
  }

  String get fullName {
    final combined = ('$firstName $lastName').trim();
    return combined.isEmpty ? 'بدون نام' : combined;
  }
}

class MaterialOption {
  const MaterialOption({
    required this.id,
    required this.title,
    required this.raw,
  });

  final int id;
  final String title;
  final Map<String, dynamic> raw;

  factory MaterialOption.fromJson(Map<String, dynamic> json) {
    return MaterialOption(
      id: json['id'] as int? ?? 0,
      title: (json['title'] ?? json['name'] ?? '').toString(),
      raw: json,
    );
  }
}

class StorageOption {
  const StorageOption({
    required this.id,
    required this.title,
    required this.projectName,
    required this.raw,
  });

  final int id;
  final String title;
  final String? projectName;
  final Map<String, dynamic> raw;

  factory StorageOption.fromJson(Map<String, dynamic> json) {
    return StorageOption(
      id: json['id'] as int? ?? 0,
      title: (json['title'] ?? '').toString(),
      projectName: json['project_name']?.toString(),
      raw: json,
    );
  }

  String get displayName {
    if (projectName == null || projectName!.isEmpty) {
      return title;
    }
    return '$title (${projectName!})';
  }
}

class StopCauseOption {
  const StopCauseOption({
    required this.id,
    required this.title,
    required this.raw,
  });

  final int id;
  final String title;
  final Map<String, dynamic> raw;

  factory StopCauseOption.fromJson(Map<String, dynamic> json) {
    return StopCauseOption(
      id: json['id'] as int? ?? 0,
      title: (json['title'] ?? '').toString(),
      raw: json,
    );
  }
}

class StoneTypeOption {
  const StoneTypeOption({
    required this.id,
    required this.title,
    required this.fullTitle,
    required this.raw,
  });

  final int id;
  final String title;
  final String? fullTitle;
  final Map<String, dynamic> raw;

  factory StoneTypeOption.fromJson(Map<String, dynamic> json) {
    return StoneTypeOption(
      id: json['id'] as int? ?? 0,
      title: (json['title'] ?? '').toString(),
      fullTitle: json['full_title']?.toString(),
      raw: json,
    );
  }

  String get displayName {
    if (fullTitle == null || fullTitle!.isEmpty) {
      return title;
    }
    return fullTitle!;
  }
}

class ChecklistOption {
  const ChecklistOption({
    required this.id,
    required this.title,
    required this.machineType,
    required this.raw,
  });

  final int id;
  final String title;
  final int? machineType;
  final Map<String, dynamic> raw;

  factory ChecklistOption.fromJson(Map<String, dynamic> json) {
    return ChecklistOption(
      id: json['id'] as int? ?? 0,
      title: (json['title'] ?? '').toString(),
      machineType: json['machine_type'] as int?,
      raw: json,
    );
  }
}

class CityOption {
  const CityOption({
    required this.id,
    required this.name,
    required this.state,
    required this.raw,
  });

  final int id;
  final String name;
  final int? state;
  final Map<String, dynamic> raw;

  factory CityOption.fromJson(Map<String, dynamic> json) {
    return CityOption(
      id: json['id'] as int? ?? 0,
      name: (json['name'] ?? '').toString(),
      state: json['state'] as int?,
      raw: json,
    );
  }
}

class DailyReportOption {
  const DailyReportOption({
    required this.id,
    required this.conjectureName,
    required this.machineName,
    required this.reportDate,
    required this.raw,
  });

  final int id;
  final String? conjectureName;
  final String? machineName;
  final String? reportDate;
  final Map<String, dynamic> raw;

  factory DailyReportOption.fromJson(Map<String, dynamic> json) {
    return DailyReportOption(
      id: json['id'] as int? ?? 0,
      conjectureName: json['conjecture_name']?.toString(),
      machineName: json['machine_name']?.toString(),
      reportDate: json['report_date']?.toString(),
      raw: json,
    );
  }

  String get displayName {
    final parts = <String>[];
    final conjecture = conjectureName?.trim() ?? '';
    if (conjecture.isNotEmpty) {
      parts.add(conjecture);
    }
    final machine = machineName?.trim() ?? '';
    if (machine.isNotEmpty) {
      parts.add(machine);
    }
    final date = reportDate?.trim() ?? '';
    if (date.isNotEmpty) {
      parts.add(date);
    }
    final shiftDisplay =
        (raw['shift_display'] ?? raw['shift_label'])?.toString().trim() ?? '';
    if (shiftDisplay.isNotEmpty) {
      parts.add('شیفت $shiftDisplay');
    } else {
      final shiftValue = int.tryParse((raw['shift'] ?? '').toString());
      if (shiftValue == 220) {
        parts.add('شیفت روز');
      } else if (shiftValue == 221) {
        parts.add('شیفت شب');
      }
    }
    if (parts.isEmpty) {
      return 'گزارش حفاری $id';
    }
    return parts.join(' - ');
  }
}

class DailyReportNameOption {
  const DailyReportNameOption({
    required this.id,
    required this.name,
    required this.raw,
  });

  final int id;
  final String name;
  final Map<String, dynamic> raw;

  factory DailyReportNameOption.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final id = rawId is int
        ? rawId
        : int.tryParse(rawId?.toString() ?? '') ?? 0;
    return DailyReportNameOption(
      id: id,
      name: (json['name'] ?? '').toString(),
      raw: json,
    );
  }
}
