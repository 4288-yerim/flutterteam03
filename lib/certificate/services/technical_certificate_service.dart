import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'dart:convert';

import 'certificate_detail_service.dart';

class TechnicalCertificateService {
  TechnicalCertificateService({
    FirebaseFirestore? firestore,
    http.Client? httpClient,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _httpClient = httpClient ?? http.Client();

  static const String _examSubjectHost = 'openapi.q-net.or.kr';
  static const String _examSubjectPath =
      '/api/service/rest/InquiryExamKmInfo/getList';

  final FirebaseFirestore _firestore;
  final http.Client _httpClient;

  CollectionReference<Map<String, dynamic>>
      get _certificationsCollection {
    return _firestore.collection('certifications');
  }

  Future<List<TechnicalCertificateSchedule>>
  getTechnicalSchedules(
      String certificationId,
      ) async {
    try {
      final snapshot = await _certificationsCollection
          .doc(certificationId)
          .collection('schedules')
          .orderBy('sortdate')
          .get();

      return snapshot.docs
          .map(TechnicalCertificateSchedule.fromFirestore)
          .toList();
    } on FirebaseException catch (error) {
      throw CertificateDetailException(
        error.message ?? '시험 일정을 불러오지 못했습니다.',
      );
    } catch (_) {
      throw const CertificateDetailException(
        '시험 일정을 불러오는 중 오류가 발생했습니다.',
      );
    }
  }

  Future<TechnicalCertificateExamDetails>
  getTechnicalExamDetails(
      String certificationId,
      ) async {
    try {
      final detailsCollection = _certificationsCollection
          .doc(certificationId)
          .collection('details');

      final documents = await Future.wait([
        detailsCollection.doc('examFee').get(),
        detailsCollection.doc('examTrends').get(),
        detailsCollection.doc('howToObtain').get(),
      ]);

      final examFeeDocument = documents[0];
      final examTrendsDocument = documents[1];
      final howToObtainDocument = documents[2];

      return TechnicalCertificateExamDetails(
        examFee: examFeeDocument.exists
            ? TechnicalCertificateExamFee.fromMap(
          examFeeDocument.data() ?? {},
        )
            : null,
        examTrends: examTrendsDocument.exists
            ? _readString(
          examTrendsDocument.data()?['contents'],
        )
            : '',
        howToObtain: howToObtainDocument.exists
            ? _readString(
          howToObtainDocument.data()?['contents'],
        )
            : '',
      );
    } on FirebaseException catch (error) {
      throw CertificateDetailException(
        error.message ?? '시험 정보를 불러오지 못했습니다.',
      );
    } catch (_) {
      throw const CertificateDetailException(
        '시험 정보를 불러오는 중 오류가 발생했습니다.',
      );
    }
  }

  Future<List<TechnicalExamSubject>> getExamSubjects({
    required String jmCd,
  }) async {
    final normalizedJmCd = jmCd.trim();
    final apiKey = dotenv.env['QNET_SERVICE_KEY']?.trim() ?? '';

    if (normalizedJmCd.isEmpty) {
      throw const CertificateDetailException(
        '종목코드가 없어 과목 정보를 조회할 수 없습니다.',
      );
    }

    if (apiKey.isEmpty) {
      throw const CertificateDetailException(
        'Q-Net API 인증키가 설정되지 않았습니다.',
      );
    }

    final uri = Uri.http(
      _examSubjectHost,
      _examSubjectPath,
      {
        'serviceKey': apiKey,
        'jmCd': normalizedJmCd,
        'pageNo': '1',
        'numOfRows': '45',
      },
    );

    try {
      final response = await _httpClient.get(uri);

      final responseText = utf8.decode(
        response.bodyBytes,
        allowMalformed: true,
      );

      if (responseText.contains(
        'Failed to validate a newly established connection',
      )) {
        throw const CertificateDetailException(
          '서버 연결이 일시적으로 불안정합니다. 잠시 후 다시 시도해주세요.',
        );
      }

      if (response.statusCode != 200) {
        throw CertificateDetailException(
          '과목 조회 요청에 실패했습니다. (${response.statusCode})',
        );
      }

      final document = XmlDocument.parse(responseText);
      final resultCode = _readXmlText(document, 'resultCode');
      final resultMessage = _readXmlText(document, 'resultMsg');

      if (resultCode.isNotEmpty && resultCode != '00') {
        throw CertificateDetailException(
          resultMessage.isEmpty
              ? '과목 정보를 조회하지 못했습니다.'
              : resultMessage,
        );
      }

      final subjects = document
          .findAllElements('item')
          .map(TechnicalExamSubject.fromXml)
          .toList();

      subjects.sort((a, b) {
        final sequenceCompare =
            (a.sequenceNumber ?? 0).compareTo(b.sequenceNumber ?? 0);
        if (sequenceCompare != 0) {
          return sequenceCompare;
        }

        final lessonCompare =
            (a.lessonNumber ?? 0).compareTo(b.lessonNumber ?? 0);
        if (lessonCompare != 0) {
          return lessonCompare;
        }

        return a.subjectName.compareTo(b.subjectName);
      });

      return subjects;
    } on CertificateDetailException {
      rethrow;
    } on XmlParserException {
      throw const CertificateDetailException(
        '과목 조회 응답을 처리하지 못했습니다.',
      );
    } catch (_) {
      throw const CertificateDetailException(
        '과목 정보를 불러오는 중 오류가 발생했습니다.',
      );
    }
  }

  static String _readXmlText(XmlNode node, String elementName) {
    final elements = node.findAllElements(elementName);
    if (elements.isEmpty) {
      return '';
    }

    return elements.first.innerText.trim();
  }

  static String _readString(dynamic value) {
    if (value == null) {
      return '';
    }

    return value.toString().trim();
  }
}

class TechnicalExamSubject {
  final String detailTypeName;
  final String qualificationName;
  final String subjectName;
  final String requiredSubjectName;
  final int? lessonNumber;
  final int? shortAnswerQuestionCount;
  final int? omrStandardScore;
  final int? questionCount;
  final String selectionFieldName;
  final int? sequenceNumber;
  final int? examTimeMinutes;

  const TechnicalExamSubject({
    required this.detailTypeName,
    required this.qualificationName,
    required this.subjectName,
    required this.requiredSubjectName,
    required this.lessonNumber,
    required this.shortAnswerQuestionCount,
    required this.omrStandardScore,
    required this.questionCount,
    required this.selectionFieldName,
    required this.sequenceNumber,
    required this.examTimeMinutes,
  });

  factory TechnicalExamSubject.fromXml(XmlElement element) {
    return TechnicalExamSubject(
      detailTypeName: _readText(element, 'dtlTypNm'),
      qualificationName: _readText(element, 'jmNm'),
      subjectName: _readText(element, 'kmNm'),
      requiredSubjectName: _readText(element, 'kmYn'),
      lessonNumber: _readInt(element, 'lssnNo'),
      shortAnswerQuestionCount: _readInt(element, 'omrQitemCnt'),
      omrStandardScore: _readInt(element, 'omrStdPnt'),
      questionCount: _readInt(element, 'qitemCnt'),
      selectionFieldName: _readText(element, 'selfldNm'),
      sequenceNumber: _readInt(element, 'seqNo'),
      examTimeMinutes: _readInt(element, 'suhmTmMi'),
    );
  }

  static String _readText(XmlElement element, String name) {
    final children = element.findElements(name);
    if (children.isEmpty) {
      return '';
    }

    return children.first.innerText.trim();
  }

  static int? _readInt(XmlElement element, String name) {
    final value = _readText(element, name);
    return value.isEmpty ? null : int.tryParse(value);
  }
}

class TechnicalCertificateSchedule {
  final String id;
  final String title;

  final DateTime? writtenRegistrationStartAt;
  final DateTime? writtenRegistrationEndAt;

  final DateTime? writtenExamStartAt;
  final DateTime? writtenExamEndAt;

  final DateTime? writtenPassAt;

  final DateTime? documentSubmitStartAt;
  final DateTime? documentSubmitEndAt;

  final DateTime? practicalRegistrationStartAt;
  final DateTime? practicalRegistrationEndAt;

  final DateTime? practicalExamStartAt;
  final DateTime? practicalExamEndAt;

  final DateTime? practicalPassStartAt;
  final DateTime? practicalPassEndAt;

  final DateTime? sortDate;

  const TechnicalCertificateSchedule({
    required this.id,
    required this.title,
    required this.writtenRegistrationStartAt,
    required this.writtenRegistrationEndAt,
    required this.writtenExamStartAt,
    required this.writtenExamEndAt,
    required this.writtenPassAt,
    required this.documentSubmitStartAt,
    required this.documentSubmitEndAt,
    required this.practicalRegistrationStartAt,
    required this.practicalRegistrationEndAt,
    required this.practicalExamStartAt,
    required this.practicalExamEndAt,
    required this.practicalPassStartAt,
    required this.practicalPassEndAt,
    required this.sortDate,
  });

  factory TechnicalCertificateSchedule.fromFirestore(
      QueryDocumentSnapshot<Map<String, dynamic>> document,
      ) {
    final data = document.data();

    return TechnicalCertificateSchedule(
      id: document.id,
      title: _readString(data['implplannm']),
      writtenRegistrationStartAt:
      _readDate(data['docregstartat']),
      writtenRegistrationEndAt:
      _readDate(data['docregendat']),
      writtenExamStartAt:
      _readDate(data['docexamstartat']),
      writtenExamEndAt:
      _readDate(data['docexamendat']),
      writtenPassAt:
      _readDate(data['docpassat']),
      documentSubmitStartAt:
      _readDate(data['docsubmitstartat']),
      documentSubmitEndAt:
      _readDate(data['docsubmitendat']),
      practicalRegistrationStartAt:
      _readDate(data['pracregstartat']),
      practicalRegistrationEndAt:
      _readDate(data['pracregendat']),
      practicalExamStartAt:
      _readDate(data['pracexamstartat']),
      practicalExamEndAt:
      _readDate(data['pracexamendat']),
      practicalPassStartAt:
      _readDate(data['pracpassstartat']),
      practicalPassEndAt:
      _readDate(data['pracpassendat']),
      sortDate:
      _readDate(data['sortdate']),
    );
  }

  static String _readString(dynamic value) {
    if (value == null) {
      return '';
    }

    return value.toString().trim();
  }

  static DateTime? _readDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }

    return null;
  }
}

class TechnicalCertificateExamFee {
  final int? writtenFee;
  final int? practicalFee;

  const TechnicalCertificateExamFee({
    required this.writtenFee,
    required this.practicalFee,
  });

  bool get hasWrittenFee {
    return writtenFee != null;
  }

  bool get hasPracticalFee {
    return practicalFee != null;
  }

  bool get hasAnyFee {
    return hasWrittenFee || hasPracticalFee;
  }

  factory TechnicalCertificateExamFee.fromMap(
      Map<String, dynamic> data,
      ) {
    return TechnicalCertificateExamFee(
      writtenFee: _readInt(data['feeRound1']),
      practicalFee: _readInt(data['feeRound2']),
    );
  }

  static int? _readInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    if (value is String) {
      return int.tryParse(
        value.replaceAll(',', '').trim(),
      );
    }

    return null;
  }
}

class TechnicalCertificateExamDetails {
  final TechnicalCertificateExamFee? examFee;
  final String examTrends;
  final String howToObtain;

  const TechnicalCertificateExamDetails({
    required this.examFee,
    required this.examTrends,
    required this.howToObtain,
  });
}
