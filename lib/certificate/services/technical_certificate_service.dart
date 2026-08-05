import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import 'certificate_detail_service.dart';
import 'certificate_category_content_service.dart';

class TechnicalCertificateService {
  TechnicalCertificateService({
    FirebaseFirestore? firestore,
    http.Client? httpClient,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _httpClient = httpClient ?? http.Client();

  static const String _examSubjectHost = 'openapi.q-net.or.kr';
  static const String _examSubjectPath =
      '/api/service/rest/InquiryExamKmInfo/getList';

  static const String _practicalMaterialHost = 'openapi.q-net.or.kr';
  static const String _practicalMaterialPath =
      '/api/service/rest/InquiryPractExamCarrySVC/getList';

  static const String _statisticsHost = 'openapi.q-net.or.kr';
  static const String _writtenStatisticsPath =
      '/api/service/rest/InquiryStatSVC/getEventYearPiList';
  static const String _practicalStatisticsPath =
      '/api/service/rest/InquiryStatSVC/getEventYearSiList';
  static const String _genderStatisticsPath =
      '/api/service/rest/InquiryStatSVC/getEventCertYearList';
  static const int statisticsBaseYear = 2025;

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

      final schedules = snapshot.docs
          .map(TechnicalCertificateSchedule.fromFirestore)
          .toList();
      schedules.sort(TechnicalCertificateSchedule.compareForDisplay);
      return schedules;
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
        examFeeLinks: _readLinks(examFeeDocument.data()),
        examTrends: examTrendsDocument.exists
            ? _readString(
          examTrendsDocument.data()?['contents'],
        )
            : '',
        examTrendsLinks: _readLinks(examTrendsDocument.data()),
        howToObtain: howToObtainDocument.exists
            ? _readString(
          howToObtainDocument.data()?['contents'],
        )
            : '',
        howToObtainLinks: _readLinks(howToObtainDocument.data()),
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

  static List<CertificateContentLink> _readLinks(Map<String, dynamic>? data) {
    final links = (data?['links'] as List? ?? const [])
        .map(CertificateContentLink.fromMap)
        .where((link) => link.label.isNotEmpty && link.url.isNotEmpty)
        .toList();
    return links;
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



  Future<StoredPracticalMaterials?> getStoredPracticalMaterials({
    required String jmCd,
  }) async {
    final normalizedJmCd = jmCd.trim();

    if (normalizedJmCd.isEmpty) {
      return null;
    }

    try {
      final document = await _certificationsCollection
          .doc(normalizedJmCd)
          .collection('details')
          .doc('practicalMaterials')
          .get();

      if (!document.exists) {
        return null;
      }

      return StoredPracticalMaterials.fromMap(document.data() ?? {});
    } on FirebaseException catch (error) {
      throw CertificateDetailException(
        error.message ?? '저장된 실기/면접 시험 지참 준비물을 불러오지 못했습니다.',
      );
    } catch (_) {
      throw const CertificateDetailException(
        '저장된 실기/면접 시험 지참 준비물을 불러오는 중 오류가 발생했습니다.',
      );
    }
  }

  Future<List<TechnicalPracticalExamMaterial>> getPracticalExamMaterials({
    required String jmCd,
    required String implementationYear,
    required String implementationSequence,
  }) async {
    final normalizedJmCd = jmCd.trim();
    final normalizedYear = implementationYear.trim();
    final normalizedSequence = implementationSequence.trim();
    final apiKey = dotenv.env['QNET_SERVICE_KEY']?.trim() ?? '';

    if (normalizedJmCd.isEmpty) {
      throw const CertificateDetailException(
        '종목코드가 없어 실기/면접 시험 지참 준비물을 조회할 수 없습니다.',
      );
    }

    if (!RegExp(r'^\d{4}$').hasMatch(normalizedYear)) {
      throw const CertificateDetailException(
        '시행년도는 4자리 숫자로 입력해주세요.',
      );
    }

    final sequenceNumber = int.tryParse(normalizedSequence);
    if (sequenceNumber == null || sequenceNumber <= 0) {
      throw const CertificateDetailException(
        '시행회차는 1 이상의 숫자로 입력해주세요.',
      );
    }

    if (apiKey.isEmpty) {
      throw const CertificateDetailException(
        'Q-Net API 인증키가 설정되지 않았습니다.',
      );
    }

    final uri = Uri.http(
      _practicalMaterialHost,
      _practicalMaterialPath,
      {
        'serviceKey': apiKey,
        'implYY': normalizedYear,
        'implSeq': sequenceNumber.toString(),
        'jmCd': normalizedJmCd,
        'pageNo': '1',
        'numOfRows': '1000',
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
          '지참 준비물 조회 요청에 실패했습니다. (${response.statusCode})',
        );
      }

      final document = XmlDocument.parse(responseText);
      final resultCode = _readXmlText(document, 'resultCode');
      final resultMessage = _readXmlText(document, 'resultMsg');

      if (resultCode.isNotEmpty && resultCode != '00') {
        throw CertificateDetailException(
          resultMessage.isEmpty
              ? '실기/면접 시험 지참 준비물을 조회하지 못했습니다.'
              : resultMessage,
        );
      }

      final materials = document
          .findAllElements('item')
          .map(TechnicalPracticalExamMaterial.fromXml)
          .toList();

      materials.sort((a, b) {
        final dateCompare = a.examDate.compareTo(b.examDate);
        if (dateCompare != 0) {
          return dateCompare;
        }
        return a.materialName.compareTo(b.materialName);
      });

      return materials;
    } on CertificateDetailException {
      rethrow;
    } on XmlParserException {
      throw const CertificateDetailException(
        '지참 준비물 조회 응답을 처리하지 못했습니다.',
      );
    } catch (_) {
      throw const CertificateDetailException(
        '실기/면접 시험 지참 준비물을 불러오는 중 오류가 발생했습니다.',
      );
    }
  }

  Future<List<CertificateExamStatistic>> getWrittenStatistics({
    required String jmCd,
  }) {
    return _getExamStatistics(
      jmCd: jmCd,
      path: _writtenStatisticsPath,
      statisticsName: '필기시험',
    );
  }

  Future<List<CertificateExamStatistic>> getPracticalStatistics({
    required String jmCd,
  }) {
    return _getExamStatistics(
      jmCd: jmCd,
      path: _practicalStatisticsPath,
      statisticsName: '실기/면접 시험',
    );
  }

  Future<List<TechnicalGenderStatistic>> getGenderStatistics({
    required String jmCd,
  }) async {
    final document = await _requestStatisticsDocument(
      jmCd: jmCd,
      path: _genderStatisticsPath,
      statisticsName: '성별 자격취득자',
    );

    final items = document.findAllElements('item').toList();
    if (items.isEmpty) {
      return const [];
    }

    final maleByYear = <int, int>{};
    final femaleByYear = <int, int>{};

    for (final item in items) {
      final sexName = _readXmlText(item, 'sexnm').replaceAll(' ', '');
      final target = sexName == '남자' || sexName == '남성'
          ? maleByYear
          : sexName == '여자' || sexName == '여성'
          ? femaleByYear
          : null;

      if (target == null) {
        continue;
      }

      for (var index = 1; index <= 5; index++) {
        final year = statisticsBaseYear - (index - 1);
        target[year] = _readXmlInt(item, 'ilpcnt$index');
      }
    }

    return List.generate(5, (index) {
      final year = statisticsBaseYear - index;
      return TechnicalGenderStatistic(
        year: year,
        maleCount: maleByYear[year] ?? 0,
        femaleCount: femaleByYear[year] ?? 0,
      );
    }).where((item) => item.totalCount > 0).toList();
  }

  Future<List<CertificateExamStatistic>> _getExamStatistics({
    required String jmCd,
    required String path,
    required String statisticsName,
  }) async {
    final document = await _requestStatisticsDocument(
      jmCd: jmCd,
      path: path,
      statisticsName: statisticsName,
    );

    final items = document.findAllElements('item').toList();
    if (items.isEmpty) {
      return const [];
    }

    final item = items.first;
    return List.generate(5, (index) {
      final fieldIndex = index + 1;
      return CertificateExamStatistic(
        year: statisticsBaseYear - index,
        registrationCount: _readXmlInt(item, 'ilrcnt$fieldIndex'),
        examineeCount: _readXmlInt(item, 'ilecnt$fieldIndex'),
        passerCount: _readXmlInt(item, 'ilpcnt$fieldIndex'),
      );
    }).where((item) => item.hasData).toList();
  }

  Future<XmlDocument> _requestStatisticsDocument({
    required String jmCd,
    required String path,
    required String statisticsName,
  }) async {
    final normalizedJmCd = jmCd.trim();
    final apiKey = dotenv.env['QNET_SERVICE_KEY']?.trim() ?? '';

    if (normalizedJmCd.isEmpty) {
      throw CertificateDetailException(
        '종목코드가 없어 $statisticsName 통계를 조회할 수 없습니다.',
      );
    }

    if (apiKey.isEmpty) {
      throw const CertificateDetailException(
        'Q-Net API 인증키가 설정되지 않았습니다.',
      );
    }

    final uri = Uri.http(
      _statisticsHost,
      path,
      {
        'serviceKey': apiKey,
        'baseYY': statisticsBaseYear.toString(),
        'jmCd': normalizedJmCd,
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
          '$statisticsName 통계 조회 요청에 실패했습니다. '
              '(${response.statusCode})',
        );
      }

      final document = XmlDocument.parse(responseText);
      final resultCode = _readXmlText(document, 'resultCode');
      final resultMessage = _readXmlText(document, 'resultMsg');

      if (resultCode.isNotEmpty && resultCode != '00') {
        throw CertificateDetailException(
          resultMessage.isEmpty
              ? '$statisticsName 통계를 조회하지 못했습니다.'
              : resultMessage,
        );
      }

      return document;
    } on CertificateDetailException {
      rethrow;
    } on XmlParserException {
      throw CertificateDetailException(
        '$statisticsName 통계 응답을 처리하지 못했습니다.',
      );
    } catch (_) {
      throw CertificateDetailException(
        '$statisticsName 통계를 불러오는 중 오류가 발생했습니다.',
      );
    }
  }

  static int _readXmlInt(XmlNode node, String elementName) {
    final value = _readXmlText(node, elementName).replaceAll(',', '');
    return int.tryParse(value) ?? 0;
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
    if (value is List) {
      return value.map((item) => item.toString().trim()).where((item) => item.isNotEmpty).join('\n');
    }

    return value.toString().trim();
  }

}

class CertificateExamStatistic {
  final int year;
  final int registrationCount;
  final int examineeCount;
  final int passerCount;

  const CertificateExamStatistic({
    required this.year,
    required this.registrationCount,
    required this.examineeCount,
    required this.passerCount,
  });

  bool get hasData {
    return registrationCount > 0 || examineeCount > 0 || passerCount > 0;
  }

  double get passRate {
    if (examineeCount <= 0) {
      return 0;
    }
    return passerCount / examineeCount * 100;
  }
}

class TechnicalGenderStatistic {
  final int year;
  final int maleCount;
  final int femaleCount;

  const TechnicalGenderStatistic({
    required this.year,
    required this.maleCount,
    required this.femaleCount,
  });

  int get totalCount => maleCount + femaleCount;
}

class StoredPracticalMaterials {
  final int? implementationYear;
  final List<TechnicalPracticalExamMaterial> items;
  final PracticalMaterialPrecautions precautions;

  const StoredPracticalMaterials({
    required this.implementationYear,
    required this.items,
    required this.precautions,
  });

  factory StoredPracticalMaterials.fromMap(
      Map<String, dynamic> map,
      ) {
    final rawItems = map['items'];

    return StoredPracticalMaterials(
      implementationYear: _readInt(
        map['implementationYear'],
      ),
      items: rawItems is List
          ? rawItems
          .whereType<Map>()
          .map(
            (item) =>
            TechnicalPracticalExamMaterial.fromStoredMap(
              Map<String, dynamic>.from(item),
            ),
      )
          .toList()
          : const [],
      precautions:
      PracticalMaterialPrecautions.fromDynamic(
        map['precautions'],
      ),
    );
  }

  static int? _readInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
      value?.toString() ?? '',
    );
  }
}


class PracticalMaterialPrecautions {
  final String format;
  final List<PracticalMaterialPrecautionBlock> blocks;

  const PracticalMaterialPrecautions({
    required this.format,
    required this.blocks,
  });

  const PracticalMaterialPrecautions.empty()
      : format = 'structured',
        blocks = const [];

  bool get isEmpty => blocks.isEmpty;

  bool get isNotEmpty => blocks.isNotEmpty;

  factory PracticalMaterialPrecautions.fromDynamic(
      dynamic value,
      ) {
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      final rawBlocks = map['blocks'];

      return PracticalMaterialPrecautions(
        format: _readString(
          map['format'],
          fallback: 'structured',
        ),
        blocks: rawBlocks is List
            ? rawBlocks
            .whereType<Map>()
            .map(
              (block) =>
              PracticalMaterialPrecautionBlock.fromMap(
                Map<String, dynamic>.from(block),
              ),
        )
            .toList()
            : const [],
      );
    }

    if (value is List) {
      final items = value
          .map(
        PracticalMaterialPrecautionItem.fromDynamic,
      )
          .where((item) => item.text.isNotEmpty)
          .toList();

      if (items.isEmpty) {
        return const PracticalMaterialPrecautions.empty();
      }

      return PracticalMaterialPrecautions(
        format: 'structured',
        blocks: [
          PracticalMaterialPrecautionBlock(
            type: 'section',
            title: '주의사항',
            columns: const [],
            items: items,
            rows: const [],
            footerNotes: const [],
          ),
        ],
      );
    }

    return const PracticalMaterialPrecautions.empty();
  }

  static String _readString(
      dynamic value, {
        String fallback = '',
      }) {
    final result = value?.toString().trim() ?? '';

    return result.isEmpty ? fallback : result;
  }
}

class PracticalMaterialPrecautionBlock {
  final String type;
  final String title;
  final List<String> columns;
  final List<PracticalMaterialPrecautionItem> items;
  final List<PracticalMaterialPrecautionRow> rows;
  final List<PracticalMaterialPrecautionItem> footerNotes;

  const PracticalMaterialPrecautionBlock({
    required this.type,
    required this.title,
    required this.columns,
    required this.items,
    required this.rows,
    required this.footerNotes,
  });

  factory PracticalMaterialPrecautionBlock.fromMap(
      Map<String, dynamic> map,
      ) {
    return PracticalMaterialPrecautionBlock(
      type: _readString(
        map['type'],
        fallback: 'section',
      ),
      title: _readString(map['title']),
      columns: _readStringList(map['columns']),
      items: _readItemList(map['items']),
      rows: _readRowList(map['rows']),
      footerNotes: _readItemList(
        map['footerNotes'],
      ),
    );
  }

  static List<String> _readStringList(
      dynamic value,
      ) {
    if (value is! List) {
      return const [];
    }

    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static List<PracticalMaterialPrecautionItem>
  _readItemList(dynamic value) {
    if (value is! List) {
      return const [];
    }

    return value
        .map(
      PracticalMaterialPrecautionItem.fromDynamic,
    )
        .where((item) => item.text.isNotEmpty)
        .toList();
  }

  static List<PracticalMaterialPrecautionRow>
  _readRowList(dynamic value) {
    if (value is! List) {
      return const [];
    }

    return value
        .whereType<Map>()
        .map(
          (row) =>
          PracticalMaterialPrecautionRow.fromMap(
            Map<String, dynamic>.from(row),
          ),
    )
        .toList();
  }

  static String _readString(
      dynamic value, {
        String fallback = '',
      }) {
    final result = value?.toString().trim() ?? '';

    return result.isEmpty ? fallback : result;
  }
}

class PracticalMaterialPrecautionItem {
  final String type;
  final String text;

  const PracticalMaterialPrecautionItem({
    required this.type,
    required this.text,
  });

  factory PracticalMaterialPrecautionItem.fromDynamic(
      dynamic value,
      ) {
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);

      return PracticalMaterialPrecautionItem(
        type: _readString(
          map['type'],
          fallback: 'normal',
        ),
        text: _readString(map['text']),
      );
    }

    return PracticalMaterialPrecautionItem(
      type: 'normal',
      text: _readString(value),
    );
  }

  static String _readString(
      dynamic value, {
        String fallback = '',
      }) {
    final result = value?.toString().trim() ?? '';

    return result.isEmpty ? fallback : result;
  }
}

class PracticalMaterialPrecautionRow {
  final int? number;
  final String group;
  final String groupNote;
  final String category;
  final List<PracticalMaterialPrecautionItem> contents;

  const PracticalMaterialPrecautionRow({
    required this.number,
    required this.group,
    required this.groupNote,
    required this.category,
    required this.contents,
  });

  factory PracticalMaterialPrecautionRow.fromMap(
      Map<String, dynamic> map,
      ) {
    final rawContents = map['contents'];

    return PracticalMaterialPrecautionRow(
      number: _readInt(map['number']),
      group: _readString(map['group']),
      groupNote: _readString(map['groupNote']),
      category: _readString(map['category']),
      contents: rawContents is List
          ? rawContents
          .map(
        PracticalMaterialPrecautionItem.fromDynamic,
      )
          .where((item) => item.text.isNotEmpty)
          .toList()
          : const [],
    );
  }

  static int? _readInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
      value?.toString() ?? '',
    );
  }

  static String _readString(dynamic value) {
    return value?.toString().trim() ?? '';
  }
}

class TechnicalPracticalExamMaterial {
  final String commonUseQuantity;
  final String drawingYn;
  final String examDate;
  final String implementationPlanName;
  final String qualificationName;
  final String specification;
  final String materialName;
  final String multipleToolYn;
  final String selectionFieldName;
  final String standardRemark;
  final String unitCode;

  const TechnicalPracticalExamMaterial({
    required this.commonUseQuantity,
    required this.drawingYn,
    required this.examDate,
    required this.implementationPlanName,
    required this.qualificationName,
    required this.specification,
    required this.materialName,
    required this.multipleToolYn,
    required this.selectionFieldName,
    required this.standardRemark,
    required this.unitCode,
  });

  factory TechnicalPracticalExamMaterial.fromXml(XmlElement element) {
    return TechnicalPracticalExamMaterial(
      commonUseQuantity: _readText(element, 'comuseQty'),
      drawingYn: _readText(element, 'dwgYnCcd').toUpperCase(),
      examDate: _readText(element, 'examDt'),
      implementationPlanName: _readText(element, 'implPlanNm'),
      qualificationName: _readText(element, 'jmNm'),
      specification: _readText(element, 'mtrlExpl'),
      materialName: _readText(element, 'mtrlNm'),
      multipleToolYn: _readText(element, 'myn').toUpperCase(),
      selectionFieldName: _readText(element, 'selfldNm'),
      standardRemark: _readText(element, 'stdRmk'),
      unitCode: _readText(element, 'unitCd'),
    );
  }


  factory TechnicalPracticalExamMaterial.fromStoredMap(
      Map<String, dynamic> map,
      ) {
    String readString(String key) => map[key]?.toString().trim() ?? '';

    final quantity = readString('quantity');

    return TechnicalPracticalExamMaterial(
      commonUseQuantity: quantity,
      drawingYn: '',
      examDate: '',
      implementationPlanName: '',
      qualificationName: '',
      specification: readString('specification'),
      materialName: readString('materialName'),
      multipleToolYn: '',
      selectionFieldName: '',
      standardRemark: readString('note'),
      unitCode: readString('unit'),
    );
  }

  String get quantityText {
    final values = <String>[
      if (commonUseQuantity.isNotEmpty) commonUseQuantity,
      if (unitCode.isNotEmpty) unitCode,
    ];
    return values.join(' ');
  }

  String get formattedExamDate {
    if (!RegExp(r'^\d{8}$').hasMatch(examDate)) {
      return examDate;
    }

    return '${examDate.substring(0, 4)}.'
        '${examDate.substring(4, 6)}.'
        '${examDate.substring(6, 8)}';
  }

  static String _readText(XmlElement element, String name) {
    final children = element.findElements(name);
    if (children.isEmpty) {
      return '';
    }
    return children.first.innerText.trim();
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
  final List<CertificateContentLink> links;

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
    this.links = const [],
  });

  DateTime? get lastPassAnnouncementDate =>
      practicalPassEndAt ?? practicalPassStartAt ?? writtenPassAt;

  static int compareForDisplay(
    TechnicalCertificateSchedule first,
    TechnicalCertificateSchedule second,
  ) {
    final today = _dateOnly(DateTime.now());
    final firstFinished = first._isFinished(today);
    final secondFinished = second._isFinished(today);
    if (firstFinished != secondFinished) return firstFinished ? 1 : -1;
    return _sortDate(first).compareTo(_sortDate(second));
  }

  bool _isFinished(DateTime today) {
    final lastDate = lastPassAnnouncementDate;
    return lastDate != null && _dateOnly(lastDate).isBefore(today);
  }

  static DateTime _sortDate(TechnicalCertificateSchedule schedule) =>
      schedule.sortDate ??
      schedule.writtenExamStartAt ??
      schedule.practicalExamStartAt ??
      DateTime(9999);

  static DateTime _dateOnly(DateTime date) {
    final local = date.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

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
      links: (data['links'] as List? ?? const [])
          .map(CertificateContentLink.fromMap)
          .where((link) => link.label.isNotEmpty && link.url.isNotEmpty)
          .toList(),
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
  final List<CertificateContentLink> examFeeLinks;
  final List<CertificateContentLink> examTrendsLinks;
  final List<CertificateContentLink> howToObtainLinks;

  const TechnicalCertificateExamDetails({
    required this.examFee,
    required this.examTrends,
    required this.howToObtain,
    this.examFeeLinks = const [],
    this.examTrendsLinks = const [],
    this.howToObtainLinks = const [],
  });
}
