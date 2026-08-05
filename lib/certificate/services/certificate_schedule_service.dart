import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CertificateScheduleService {
  static const String _collectionName = 'integratedSchedules';

  static const String _technicalDocumentPrefix =
      'nationalTechnical_';

  static const String _professionalDocumentPrefix =
      'professionalQualification_';

  final FirebaseFirestore _firestore;

  CertificateScheduleService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<List<CertificateSchedule>> getSchedules() async {
    try {
      final snapshot = await _firestore
          .collection(_collectionName)
          .get();

      // 기존 문서는 isEnabled 필드가 없으므로 활성으로 간주한다. 관리자가
      // 비활성화한 문서는 일정 문서에 저장된 자격증 ID/jmcd와 대조해 제외한다.
      final certificates = await _firestore.collection('certifications').get();
      final disabledKeys = <String>{
        for (final document in certificates.docs)
          if (document.data()['isEnabled'] == false) ...[
            document.id,
            _readString(document.data(), const ['jmcd']),
          ],
      }..removeWhere((key) => key.isEmpty);

      final schedules = <CertificateSchedule>[];

      for (final document in snapshot.docs) {
        final documentId = document.id;
        final data = document.data();
        if (_isDisabledScheduleDocument(documentId, data, disabledKeys)) {
          continue;
        }

        if (documentId.startsWith(_technicalDocumentPrefix)) {
          schedules.addAll(
            _convertTechnicalDocument(
              documentId,
              data,
            ),
          );
          continue;
        }

        if (documentId.startsWith(_professionalDocumentPrefix)) {
          schedules.addAll(
            _convertProfessionalDocument(
              documentId,
              data,
            ),
          );
        }
      }

      schedules.sort((a, b) {
        final dateCompare = a.startDate.compareTo(b.startDate);

        if (dateCompare != 0) {
          return dateCompare;
        }

        final nameCompare =
        a.certificateName.compareTo(b.certificateName);

        if (nameCompare != 0) {
          return nameCompare;
        }

        return a.scheduleType.compareTo(b.scheduleType);
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

  bool _isDisabledScheduleDocument(
    String documentId,
    Map<String, dynamic> data,
    Set<String> disabledKeys,
  ) {
    if (disabledKeys.isEmpty) return false;
    final candidates = <String>{
      documentId,
      documentId.replaceFirst(_technicalDocumentPrefix, ''),
      documentId.replaceFirst(_professionalDocumentPrefix, ''),
      _readString(data, const ['certificateId', 'certificationId', 'jmcd']),
    }..removeWhere((value) => value.isEmpty);
    return candidates.any(disabledKeys.contains);
  }

  String _buildProfessionalDisplayName({
    required String certificateName,
    required String description,
  }) {
    final name = certificateName.trim();
    final scheduleDescription = description.trim();

    if (name.isEmpty && scheduleDescription.isEmpty) {
      return '국가전문자격 시험';
    }

    if (name.isEmpty) {
      return scheduleDescription;
    }

    if (scheduleDescription.isEmpty) {
      return name;
    }

    if (scheduleDescription.contains(name)) {
      return scheduleDescription;
    }

    final stagePattern = RegExp(
      r'(제?\s*\d+\s*차|필기|실기|면접)',
    );

    final stageMatch = stagePattern.firstMatch(
      scheduleDescription,
    );

    if (stageMatch != null) {
      final beforeStage = scheduleDescription
          .substring(0, stageMatch.start)
          .trim();

      final stageAndAfter = scheduleDescription
          .substring(stageMatch.start)
          .trim();

      return '$beforeStage $name $stageAndAfter'
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
    }

    return '$scheduleDescription $name'
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  List<CertificateSchedule> _convertTechnicalDocument(
      String documentId,
      Map<String, dynamic> data,
      ) {
    final schedules = <CertificateSchedule>[];

    final description = _readString(
      data,
      const [
        'description',
      ],
    );

    final gradeName = _readString(
      data,
      const [
        'gradeName',
      ],
    );

    final category = _readString(
      data,
      const [
        'category',
      ],
    );

    final writtenPassAnnouncement = _readString(
      data,
      const [
        'writtenPassAnnouncement',
      ],
    );

    final practicalPassAnnouncement = _readString(
      data,
      const [
        'practicalPassAnnouncement',
      ],
    );

    final displayName = description.isNotEmpty
        ? description
        : gradeName.isNotEmpty
        ? gradeName
        : '국가기술자격 시험';

    void addRangeSchedule({
      required String scheduleType,
      required List<String> startFields,
      required List<String> endFields,
      String scheduleDescription = '',
    }) {
      final startDate = _readDate(
        data,
        startFields,
      );

      if (startDate == null) {
        return;
      }

      final endDate = _readDate(
        data,
        endFields,
      ) ??
          startDate;

      schedules.add(
        CertificateSchedule(
          id: '$documentId-$scheduleType',
          certificateName: displayName,
          scheduleType: scheduleType,
          startDate: startDate,
          endDate: endDate,
          description: scheduleDescription,
          qualificationCode: 'T',
          qualificationName:
          gradeName.isNotEmpty ? gradeName : '기술자격',
        ),
      );
    }

    void addSingleDateSchedule({
      required String scheduleType,
      required List<String> fields,
      String scheduleDescription = '',
    }) {
      final date = _readDate(
        data,
        fields,
      );

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
          description: scheduleDescription,
          qualificationCode: 'T',
          qualificationName:
          gradeName.isNotEmpty ? gradeName : '기술자격',
        ),
      );
    }

    addRangeSchedule(
      scheduleType: '필기 원서접수',
      startFields: const [
        'writtenRegistrationStartDate',
      ],
      endFields: const [
        'writtenRegistrationEndDate',
      ],
    );

    addRangeSchedule(
      scheduleType: '필기 빈자리 접수',
      startFields: const [
        'writtenVacancyRegistrationStartDate',
      ],
      endFields: const [
        'writtenVacancyRegistrationEndDate',
      ],
    );

    addSingleDateSchedule(
      scheduleType: '필기시험',
      fields: const [
        'writtenExamDate',
      ],
    );

    addSingleDateSchedule(
      scheduleType: '필기 합격자 발표',
      fields: const [
        'writtenPassDate',
      ],
      scheduleDescription: writtenPassAnnouncement,
    );

    addRangeSchedule(
      scheduleType: '실기 원서접수',
      startFields: const [
        'practicalRegistrationStartDate',
      ],
      endFields: const [
        'practicalRegistrationEndDate',
      ],
    );

    addRangeSchedule(
      scheduleType: '실기 빈자리 접수',
      startFields: const [
        'practicalVacancyRegistrationStartDate',
      ],
      endFields: const [
        'practicalVacancyRegistrationEndDate',
      ],
    );

    addRangeSchedule(
      scheduleType: '실기시험',
      startFields: const [
        'practicalExamStartDate',
      ],
      endFields: const [
        'practicalExamEndDate',
      ],
    );

    addSingleDateSchedule(
      scheduleType: '최종 합격자 발표',
      fields: const [
        'practicalPassDate',
      ],
      scheduleDescription: practicalPassAnnouncement,
    );

    return schedules;
  }

  List<CertificateSchedule> _convertProfessionalDocument(
      String documentId,
      Map<String, dynamic> data,
      ) {
    final schedules = <CertificateSchedule>[];

    final description = _readString(
      data,
      const [
        'description',
      ],
    );

    final qualificationName = _readString(
      data,
      const [
        'qualgbnm',
        'qualgbNm',
        'qualificationName',
      ],
    );

    final certificateName = _readString(
      data,
      const [
        'certificateName',
        'jmNm',
        'jmnm',
        'seriesNm',
        'seriesnm',
      ],
    );

    /*
     * 현재 전문자격 저장 코드에는 별도의 종목명 필드가 없으므로
     * certificateName이 없으면 description을 카드 제목으로 사용한다.
     */
    final displayName = _buildProfessionalDisplayName(
      certificateName: certificateName,
      description: description,
    );

    void addRangeSchedule({
      required String scheduleType,
      required List<String> startFields,
      required List<String> endFields,
    }) {
      final startDate = _readDate(data, startFields);

      if (startDate == null) {
        return;
      }

      final endDate = _readDate(data, endFields) ?? startDate;

      schedules.add(
        CertificateSchedule(
          id: '$documentId-$scheduleType',
          certificateName: displayName,
          scheduleType: scheduleType,
          startDate: startDate,
          endDate: endDate,

          /*
           * description을 카드 제목으로 사용한 경우에는
           * 카드 아래에서 같은 문장이 중복 출력되지 않도록 비운다.
           */
          description: '',
          qualificationCode: 'S',
          qualificationName: qualificationName.isNotEmpty
              ? qualificationName
              : '전문자격',
        ),
      );
    }

    addRangeSchedule(
      scheduleType: '원서접수',
      startFields: const [
        'examregstartat',
        'examRegStartAt',
        'examRegStartDate',
      ],
      endFields: const [
        'examregendat',
        'examRegEndAt',
        'examRegEndDate',
      ],
    );

    addRangeSchedule(
      scheduleType: '시험',
      startFields: const [
        'examstartat',
        'examStartAt',
        'examStartDate',
      ],
      endFields: const [
        'examendat',
        'examEndAt',
        'examEndDate',
      ],
    );

    addRangeSchedule(
      scheduleType: '합격자 발표',
      startFields: const [
        'passstartat',
        'passStartAt',
        'passStartDate',
      ],
      endFields: const [
        'passendat',
        'passEndAt',
        'passEndDate',
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
    return qualificationCode != 'S';
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

    if (startDate.year == endDate.year) {
      return '${startDate.month}.${startDate.day}'
          ' - '
          '${endDate.month}.${endDate.day}';
    }

    return '${startDate.year}.${startDate.month}.${startDate.day}'
        ' - '
        '${endDate.year}.${endDate.month}.${endDate.day}';
  }
}

class CertificateScheduleException implements Exception {
  final String message;

  const CertificateScheduleException(this.message);

  @override
  String toString() => message;
}
