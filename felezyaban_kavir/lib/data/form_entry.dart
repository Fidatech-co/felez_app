import 'package:flutter/material.dart';

enum FormStatus { approved, pending, needsRevision, error }

extension FormStatusInfo on FormStatus {
  String get label {
    switch (this) {
      case FormStatus.approved:
        return 'ارسال شده به مخزن داده';
      case FormStatus.pending:
        return 'در انتظار اتصال به شبکه';
      case FormStatus.needsRevision:
        return 'نیاز به اصلاح';
      case FormStatus.error:
        return '\u062e\u0637\u0627 \u062f\u0631 \u0627\u0631\u0633\u0627\u0644 \u0628\u0647 \u0633\u0631\u0648\u0631';
    }
  }

  Color get color {
    switch (this) {
      case FormStatus.approved:
        return Colors.green;
      case FormStatus.pending:
        return Colors.orange;
      case FormStatus.needsRevision:
        return Colors.deepOrange;
      case FormStatus.error:
        return Colors.red;
    }
  }
}

class FormEntry {
  FormEntry({
    required this.id,
    this.localId,
    required this.title,
    required this.description,
    required this.formType,
    required this.payload,
    required this.offlineSubmittedAt,
    required this.onlineSubmittedAt,
    required this.status,
    this.lastError,
  });

  final int id;
  final int? localId;
  final String title;
  final String description;
  final String formType;
  final Map<String, dynamic> payload;
  final DateTime offlineSubmittedAt;
  final DateTime onlineSubmittedAt;
  final FormStatus status;
  final String? lastError;
}
