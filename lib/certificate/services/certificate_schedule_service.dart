import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CertificateScheduleService {
  final FirebaseFirestore _firestore;

  CertificateScheduleService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<List<CertificateSchedule>> getSchedules() async {
    try {
      final snapshot = await _firestore
          .collection('examSchedules')
          .get();

      final schedules = <CertificateSchedule>[];

      for (final document in snapshot.docs) {
        schedules.addAll(
          _convertDocumentToSchedules(
            document.id,
            document.data(),
          ),
        );
      }

      schedules.sort((a, b) {
        final dateCompare = a.startDate.compareTo(b.startDate);

        if (dateCompare != 0) {
          return dateCompare;
        }

        return a.certificateName.compareTo(b.certificateName);
      });

      return schedules;
    } on FirebaseException catch (error) {
      throw CertificateScheduleException(
        '자격증 일정 정보를 불러오지 못했습니다. (${error.code})',
      );
    } catch (_) {
      throw const CertificateScheduleException(
        '자격증 일정 정보를 불러오지 못했습니다.',
      );
    }
  }

  List<CertificateSchedule> _convertDocumentToSchedules(
      String documentId,
      Map<String, dynamic> data,
      ) {
    final qualificationCode = _readString(
      data,
      const [
        'qualgbCd',
        'qualgbcd',
        'qualgbCD',
      ],
    ).toUpperCase();

    final qualificationName = _readString(
      data,
      const [
        'qualgbNm',
        'qualgbnm',
      ],
    );

    final description = _readString(
      data,
      const ['description'],
    );

    final certificateName = _readString(
      data,
      const [
        'jmNm',
        'jmnm',
        'jmfldnm',
        'certificateName',
      ],
    );

    final displayName = certificateName.isNotEmpty
        ? certificateName
        : qualificationName.isNotEmpty
        ? qualificationName
        : '국가자격 시험';

    final schedules = <CertificateSchedule>[];

    void addRangeSchedule({
      required String scheduleType,
      required List<String> startFields,
      required List<String> endFields,
    }) {
      final startDate = _readDate(data, startFields);

      if (startDate == null) {
        return;
      }

      final endDate =
          _readDate(data, endFields) ?? startDate;

      schedules.add(
        CertificateSchedule(
          id: '$documentId-$scheduleType',
          certificateName: displayName,
          scheduleType: scheduleType,
          startDate: startDate,
          endDate: endDate,
          description: description,
          qualificationCode: qualificationCode,
          qualificationName: qualificationName,
        ),
      );
    }

    void addSingleDateSchedule({
      required String scheduleType,
      required List<String> fields,
    }) {
      final date = _readDate(data, fields);

      if (date == null) {
        return;
      }

      schedules.add(
        CertificateSchedule(
          id: '$documentId-$scheduleType',
          certificateName: displayName,
          scheduleType: scheduleType,
          startDate: date,
          endDate: date,
          description: description,
          qualificationCode: qualificationCode,
          qualificationName: qualificationName,
        ),
      );
    }

    addRangeSchedule(
      scheduleType: '필기 원서접수',
      startFields: const [
        'docregstartat',
      ],
      endFields: const [
        'docregendat',
      ],
    );

    addRangeSchedule(
      scheduleType: '필기시험',
      startFields: const [
        'docexamstartat',
      ],
      endFields: const [
        'docexamendat',
      ],
    );

    addSingleDateSchedule(
      scheduleType: '필기 합격자 발표',
      fields: const [
        'docpassat',
      ],
    );

    addRangeSchedule(
      scheduleType: '실기·면접 원서접수',
      startFields: const [
        'pracregstartat',
      ],
      endFields: const [
        'pracregendat',
      ],
    );

    addRangeSchedule(
      scheduleType: '실기·면접시험',
      startFields: const [
        'pracexamstartat',
      ],
      endFields: const [
        'pracexamendat',
      ],
    );

    addSingleDateSchedule(
      scheduleType: '최종 합격자 발표',
      fields: const [
        'pracpassat',
      ],
    );

    return schedules;
  }

  String _readString(
      Map<String, dynamic> data,
      List<String> fieldNames,
      ) {
    for (final fieldName in fieldNames) {
      final value = data[fieldName];

      if (value == null) {
        continue;
      }

      final text = value.toString().trim();

      if (text.isNotEmpty && text.toLowerCase() != 'null') {
        return text;
      }
    }

    return '';
  }

  DateTime? _readDate(
      Map<String, dynamic> data,
      List<String> fieldNames,
      ) {
    for (final fieldName in fieldNames) {
      final value = data[fieldName];
      final parsedDate = _parseDate(value);

      if (parsedDate != null) {
        return parsedDate;
      }
    }

    return null;
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is Timestamp) {
      final date = value.toDate();

      return DateTime(
        date.year,
        date.month,
        date.day,
      );
    }

    if (value is DateTime) {
      return DateTime(
        value.year,
        value.month,
        value.day,
      );
    }

    final normalized = value
        .toString()
        .trim()
        .replaceAll(RegExp(r'[^0-9]'), '');

    if (normalized.length != 8) {
      return null;
    }

    final year = int.tryParse(normalized.substring(0, 4));
    final month = int.tryParse(normalized.substring(4, 6));
    final day = int.tryParse(normalized.substring(6, 8));

    if (year == null || month == null || day == null) {
      return null;
    }

    final date = DateTime(year, month, day);

    if (date.year != year ||
        date.month != month ||
        date.day != day) {
      return null;
    }

    return date;
  }
}

class CertificateSchedule {
  final String id;
  final String certificateName;
  final String scheduleType;
  final DateTime startDate;
  final DateTime endDate;
  final String description;
  final String qualificationCode;
  final String qualificationName;

  const CertificateSchedule({
    required this.id,
    required this.certificateName,
    required this.scheduleType,
    required this.startDate,
    required this.endDate,
    required this.description,
    required this.qualificationCode,
    required this.qualificationName,
  });

  DateTime get date => startDate;

  bool get isTechnical {
    return qualificationCode == 'T' ||
        qualificationCode == 'C' ||
        qualificationCode == 'W';
  }

  bool get isProfessional {
    return qualificationCode == 'S';
  }

  bool occursOn(DateTime day) {
    final normalizedDay = DateTime(
      day.year,
      day.month,
      day.day,
    );

    final normalizedStart = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
    );

    final normalizedEnd = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
    );

    return !normalizedDay.isBefore(normalizedStart) &&
        !normalizedDay.isAfter(normalizedEnd);
  }

  String get dateText {
    if (DateUtils.isSameDay(startDate, endDate)) {
      return '${startDate.month}.${startDate.day}';
    }

    return '${startDate.month}.${startDate.day}'
        ' - '
        '${endDate.month}.${endDate.day}';
  }
}

class CertificateScheduleException implements Exception {
  final String message;

  const CertificateScheduleException(this.message);

  @override
  String toString() => message;
}
