import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

class ApiDownloadPage extends StatefulWidget {
  const ApiDownloadPage({super.key});

  @override
  State<ApiDownloadPage> createState() =>
      _ApiDownloadPageState();
}

class _ApiDownloadPageState extends State<ApiDownloadPage> {
  /*
   * 공공데이터포털 15003029
   * 국가기술자격 종목별 시험정보
   *
   * 사용 기능:
   * 종목별 시행일정 목록 조회
   *
   * WADL 기본 주소:
   * https://openapi.q-net.or.kr/api/service/rest/
   * InquiryTestInformationNTQSVC?_wadl&_type=xml
   *
   * 실제 데이터 호출은 서비스 경로 뒤에
   * 상세 기능명을 붙여 호출해야 한다.
   */
  static const String _scheduleEndpoint =
      'http://openapi.q-net.or.kr/api/service/rest/'
      'InquiryTestInformationNTQSVC/getJMList';

  static const String _certificateCollection =
      'certifications';

  static const String _scheduleCollection =
      'schedules';

  /*
   * 전체 조회 시 API 서버에 너무 빠르게 요청하지 않도록
   * 요청 사이에 대기 시간을 둔다.
   */
  static const Duration _requestDelay =
  Duration(milliseconds: 400);

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final TextEditingController _jmcdController =
  TextEditingController();

  bool _isLoading = false;

  String _statusMessage =
      '자격증 종목 코드를 입력하거나 전체 조회를 실행하세요.';

  int _processedCount = 0;
  int _successCount = 0;
  int _failureCount = 0;
  int _previewScheduleCount = 0;
  int _savedScheduleCount = 0;

  /*
   * 개별 자격증 조회 결과
   */
  CertificateSchedulePreview? _singlePreview;

  /*
   * 전체 자격증 조회 결과
   *
   * key: jmcd
   * value: 해당 자격증과 일정 목록
   */
  final Map<String, CertificateSchedulePreview>
  _allPreviews = {};

  final List<String> _failureLogs = [];
  final List<String> _logs = [];

  /*
   * none   : 조회 결과 없음
   * single : 개별 조회 결과
   * all    : 전체 조회 결과
   */
  String _previewType = 'none';

  String get _serviceKey {
    return dotenv.env['QNET_SERVICE_KEY']?.trim() ?? '';
  }

  @override
  void dispose() {
    _jmcdController.dispose();
    super.dispose();
  }

  // =========================================================
  // 화면
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('국가기술자격 일정 다운로드'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildStatusCard(),
            const SizedBox(height: 16),
            _buildSingleSearchCard(),
            const SizedBox(height: 16),
            _buildAllSearchCard(),
            const SizedBox(height: 16),
            _buildPreviewCard(),
            const SizedBox(height: 16),
            _buildLogCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '처리 상태',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(_statusMessage),
            if (_isLoading) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                Text('처리: $_processedCount'),
                Text('조회 성공: $_successCount'),
                Text('조회 실패: $_failureCount'),
                Text('조회 일정: $_previewScheduleCount'),
                Text('저장 일정: $_savedScheduleCount'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleSearchCard() {
    final canSave = !_isLoading &&
        _singlePreview != null &&
        _singlePreview!.schedules.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '자격증 한 개 조회',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'certificates 문서 ID와 동일한 종목 코드를 입력합니다.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _jmcdController,
              enabled: !_isLoading,
              decoration: const InputDecoration(
                labelText: '종목 코드',
                hintText: '예: 1320',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading
                        ? null
                        : _previewSingleCertificate,
                    child: const Text('일정 조회'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: canSave
                        ? _saveSinglePreview
                        : null,
                    child: const Text('조회 결과 저장'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllSearchCard() {
    final canSave = !_isLoading &&
        _allPreviews.values.any(
              (preview) => preview.schedules.isNotEmpty,
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '국가기술자격 전체 조회',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'certificates에서 qualgbcd가 T인 문서를 조회한 뒤, '
                  '각 문서 ID를 jmcd로 사용하여 API를 호출합니다.\n\n'
                  '전체 조회 버튼만 누르면 Firestore에는 저장되지 않습니다.',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading
                        ? null
                        : _previewAllCertificates,
                    child: const Text('전체 일정 조회'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed:
                    canSave ? _saveAllPreviews : null,
                    child: const Text('전체 조회 결과 저장'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '저장 예정 데이터',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (_previewType == 'none')
              const Text(
                '일정을 조회하면 Firestore에 저장될 내용을 '
                    '여기에서 먼저 확인할 수 있습니다.',
              ),
            if (_previewType == 'single' &&
                _singlePreview != null)
              _buildSinglePreview(_singlePreview!),
            if (_previewType == 'all')
              _buildAllPreview(),
          ],
        ),
      ),
    );
  }

  Widget _buildSinglePreview(
      CertificateSchedulePreview preview,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _previewRow(
          label: '저장 경로',
          value:
          'certifications/${preview.certificate.jmcd}/schedules',
        ),
        _previewRow(
          label: '종목 코드',
          value: preview.certificate.jmcd,
        ),
        _previewRow(
          label: '종목명',
          value: preview.certificate.jmfldnm,
        ),
        _previewRow(
          label: '조회 일정',
          value: '${preview.schedules.length}건',
        ),
        const SizedBox(height: 12),
        ...preview.schedules.asMap().entries.map(
              (entry) {
            return _buildScheduleCard(
              index: entry.key,
              schedule: entry.value,
              certificate: preview.certificate,
            );
          },
        ),
      ],
    );
  }

  Widget _buildAllPreview() {
    final previews = _allPreviews.values.toList();

    final totalScheduleCount = previews.fold<int>(
      0,
          (sum, preview) =>
      sum + preview.schedules.length,
    );

    /*
     * 전체 데이터를 전부 렌더링하면 화면이 느려질 수 있으므로
     * 일정이 존재하는 자격증 중 최대 20개만 화면에 표시한다.
     *
     * 실제 저장은 조회된 전체 데이터를 저장한다.
     */
    final visiblePreviews = previews
        .where(
          (preview) => preview.schedules.isNotEmpty,
    )
        .take(20)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _previewRow(
          label: '조회 자격증',
          value: '${_allPreviews.length}개',
        ),
        _previewRow(
          label: '전체 일정',
          value: '$totalScheduleCount건',
        ),
        _previewRow(
          label: '조회 실패',
          value: '${_failureLogs.length}건',
        ),
        const SizedBox(height: 12),
        const Divider(),
        const SizedBox(height: 8),
        const Text(
          '저장 예정 데이터 일부',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...visiblePreviews.map(
              (preview) {
            return ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(
                preview.certificate.jmfldnm.isEmpty
                    ? preview.certificate.jmcd
                    : preview.certificate.jmfldnm,
              ),
              subtitle: Text(
                '${preview.certificate.jmcd} · '
                    '${preview.schedules.length}건',
              ),
              children: preview.schedules
                  .take(10)
                  .toList()
                  .asMap()
                  .entries
                  .map(
                    (entry) => _buildScheduleCard(
                  index: entry.key,
                  schedule: entry.value,
                  certificate:
                  preview.certificate,
                ),
              )
                  .toList(),
            );
          },
        ),
        if (_allPreviews.length > 20) ...[
          const SizedBox(height: 12),
          Text(
            '화면에는 최대 20개 자격증만 표시합니다. '
                '저장 시에는 조회된 $totalScheduleCount건 전체를 저장합니다.',
          ),
        ],
        if (_failureLogs.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          const Text(
            '조회 실패 목록',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ..._failureLogs.take(20).map(
                (failure) => Padding(
              padding:
              const EdgeInsets.only(bottom: 6),
              child: Text(
                '• $failure',
                style: const TextStyle(
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildScheduleCard({
    required int index,
    required TechnicalSchedule schedule,
    required CertificateInfo certificate,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Theme.of(context)
          .colorScheme
          .surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              schedule.description.isEmpty
                  ? '일정 ${index + 1}'
                  : schedule.description,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            _previewRow(
              label: '문서 ID',
              value: schedule.documentId,
            ),
            _previewRow(
              label: '저장 경로',
              value:
              'certifications/${certificate.jmcd}/'
                  'schedules/${schedule.documentId}',
            ),
            _previewRow(
              label: '필기 접수',
              value: _dateRangeText(
                schedule.docRegStartDate,
                schedule.docRegEndDate,
              ),
            ),
            _previewRow(
              label: '필기시험',
              value: _dateRangeText(
                schedule.docExamDate,
                schedule.docExamDate,
              ),
            ),
            _previewRow(
              label: '필기 합격 발표',
              value: _dateRangeText(
                schedule.docPassDate,
                schedule.docPassDate,
              ),
            ),
            _previewRow(
              label: '서류 제출',
              value: _dateRangeText(
                schedule.docSubmitStartDate,
                schedule.docSubmitEndDate,
              ),
            ),
            _previewRow(
              label: '실기 접수',
              value: _dateRangeText(
                schedule.pracRegStartDate,
                schedule.pracRegEndDate,
              ),
            ),
            _previewRow(
              label: '실기시험',
              value: _dateRangeText(
                schedule.pracExamStartDate,
                schedule.pracExamEndDate,
              ),
            ),
            _previewRow(
              label: '최종 발표',
              value: _dateRangeText(
                schedule.pracPassDate,
                schedule.pracPassDate,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _previewRow({
    required String label,
    required String value,
  }) {
    if (value.trim().isEmpty || value == '-') {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 105,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(value),
          ),
        ],
      ),
    );
  }

  Widget _buildLogCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '처리 로그',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (_logs.isEmpty)
              const Text('로그가 없습니다.')
            else
              ..._logs.reversed.take(100).map(
                    (log) => Padding(
                  padding:
                  const EdgeInsets.only(
                    bottom: 6,
                  ),
                  child: Text(
                    log,
                    style: const TextStyle(
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // 개별 조회
  // =========================================================

  Future<void> _previewSingleCertificate() async {
    final inputJmcd =
    _jmcdController.text.trim();

    if (inputJmcd.isEmpty) {
      _showMessage('종목 코드를 입력하세요.');
      return;
    }

    await _runTask(
      taskName: '개별 자격증 일정 조회',
      task: () async {
        final certificate =
        await _findCertificate(inputJmcd);

        if (certificate == null) {
          throw Exception(
            'certifications/$inputJmcd 문서를 찾지 못했습니다.',
          );
        }

        if (certificate.qualgbcd != 'T') {
          throw Exception(
            '${certificate.jmfldnm}은 '
                '국가기술자격이 아닙니다.',
          );
        }

        /*
         * 문서 ID를 API 요청 jmCd로 사용한다.
         */
        final schedules = await _fetchSchedules(
          certificate: certificate,
        );

        if (!mounted) {
          return;
        }

        setState(() {
          _previewType = 'single';

          _singlePreview =
              CertificateSchedulePreview(
                certificate: certificate,
                schedules: schedules,
              );

          _allPreviews.clear();
          _failureLogs.clear();

          _processedCount = 1;
          _successCount = 1;
          _previewScheduleCount =
              schedules.length;

          _statusMessage =
          '${certificate.jmfldnm} 일정 '
              '${schedules.length}건 조회 완료';
        });
      },
    );
  }

  // =========================================================
  // 전체 조회
  // =========================================================

  Future<void> _previewAllCertificates() async {
    await _runTask(
      taskName: '국가기술자격 전체 일정 조회',
      task: () async {
        final snapshot = await _firestore
            .collection(_certificateCollection)
            .where(
          'qualgbcd',
          isEqualTo: 'T',
        )
            .get();

        final previews =
        <String, CertificateSchedulePreview>{};

        final failures = <String>[];

        var processedCount = 0;
        var successCount = 0;
        var failureCount = 0;
        var scheduleCount = 0;

        for (final document in snapshot.docs) {
          /*
           * certificates 문서 ID를 jmcd로 사용한다.
           */
          final certificate =
          CertificateInfo.fromFirestore(
            document,
          );

          try {
            _setStatus(
              '전체 일정 조회 중\n'
                  '${certificate.jmfldnm}'
                  '(${certificate.jmcd})\n'
                  '${processedCount + 1}/${snapshot.docs.length}',
            );

            final schedules =
            await _fetchSchedules(
              certificate: certificate,
            );

            previews[certificate.jmcd] =
                CertificateSchedulePreview(
                  certificate: certificate,
                  schedules: schedules,
                );

            successCount++;
            scheduleCount += schedules.length;
          } catch (error) {
            failureCount++;

            final failure =
                '${certificate.jmfldnm}'
                '(${certificate.jmcd}): $error';

            failures.add(failure);
            _addLog('[조회 실패] $failure');
          }

          processedCount++;

          if (mounted) {
            setState(() {
              _processedCount = processedCount;
              _successCount = successCount;
              _failureCount = failureCount;
              _previewScheduleCount =
                  scheduleCount;
            });
          }

          await Future<void>.delayed(
            _requestDelay,
          );
        }

        if (!mounted) {
          return;
        }

        setState(() {
          _previewType = 'all';

          _singlePreview = null;

          _allPreviews
            ..clear()
            ..addAll(previews);

          _failureLogs
            ..clear()
            ..addAll(failures);

          _statusMessage =
          '전체 조회 완료\n'
              '자격증 ${previews.length}개\n'
              '일정 $scheduleCount건\n'
              '실패 $failureCount건';
        });

        _addLog(
          '[전체 조회 완료] '
              '자격증 ${previews.length}개, '
              '일정 $scheduleCount건, '
              '실패 $failureCount건',
        );
      },
    );
  }

  // =========================================================
  // API 호출
  // =========================================================

  Future<List<TechnicalSchedule>> _fetchSchedules({
    required CertificateInfo certificate,
  }) async {
    _validateServiceKey();

    final uri = _buildApiUri(
      endpoint: _scheduleEndpoint,
      parameters: {
        /*
         * API 요청변수 이름은 jmCd다.
         */
        'jmCd': certificate.jmcd,
      },
    );

    _addLog(
      '[API 요청] ${certificate.jmfldnm}'
          '(${certificate.jmcd})',
    );

    debugPrint('Q-Net 요청 URL: $uri');
    _addLog(
      '[요청 URL] '
          '$_scheduleEndpoint?serviceKey=***&jmCd=${certificate.jmcd}',
    );

    final response = await http
        .get(
      uri,
      headers: const {
        'Accept': 'application/xml',
      },
    )
        .timeout(
      const Duration(seconds: 30),
    );

    final responseText = utf8.decode(
      response.bodyBytes,
      allowMalformed: true,
    );

    debugPrint(
      'Q-Net 응답 상태: ${response.statusCode}',
    );

    debugPrint(
      'Q-Net 응답 내용: $responseText',
    );

    if (response.statusCode != 200) {
      throw Exception(
        'HTTP ${response.statusCode}\n'
            '${_safePreview(responseText)}',
      );
    }

    _validateXmlResponse(responseText);

    final items = _parseXmlItems(responseText);

    final schedules = <TechnicalSchedule>[];

    for (var index = 0;
    index < items.length;
    index++) {
      final schedule =
      TechnicalSchedule.fromApiItem(
        item: items[index],
        certificate: certificate,
        itemIndex: index,
      );

      if (schedule.hasAnyDate) {
        schedules.add(schedule);
      }
    }

    _addLog(
      '[API 응답] ${certificate.jmfldnm}: '
          '${schedules.length}건',
    );

    return schedules;
  }

  Uri _buildApiUri({
    required String endpoint,
    required Map<String, String> parameters,
  }) {
    /*
     * 공공데이터포털에서 받은 인증키가 이미 URL 인코딩되어 있으면
     * queryParameters를 사용했을 때 %가 %25로 이중 인코딩될 수 있다.
     *
     * serviceKey는 원문 그대로 붙이고,
     * 나머지 값만 URL 인코딩한다.
     */
    final queryParts = <String>[
      'serviceKey=$_serviceKey',
      ...parameters.entries.map(
            (entry) =>
        '${Uri.encodeQueryComponent(entry.key)}='
            '${Uri.encodeQueryComponent(entry.value)}',
      ),
    ];

    return Uri.parse(
      '$endpoint?${queryParts.join('&')}',
    );
  }

  void _validateXmlResponse(String xmlText) {
    XmlDocument document;

    try {
      document = XmlDocument.parse(xmlText);
    } catch (_) {
      throw Exception(
        'XML 형식이 아닙니다.\n'
            '${_safePreview(xmlText)}',
      );
    }

    final resultCode = _findElementText(
      document,
      const [
        'resultCode',
        'returnReasonCode',
      ],
    );

    final resultMessage = _findElementText(
      document,
      const [
        'resultMsg',
        'returnAuthMsg',
      ],
    );

    final normalizedCode =
    resultCode.trim();

    final isSuccess =
        normalizedCode.isEmpty ||
            normalizedCode == '00' ||
            normalizedCode == '0000';

    if (!isSuccess) {
      throw Exception(
        'Q-Net API 오류\n'
            '코드: $resultCode\n'
            '메시지: $resultMessage',
      );
    }
  }

  List<Map<String, String>> _parseXmlItems(
      String xmlText,
      ) {
    final document = XmlDocument.parse(xmlText);

    final itemElements =
    document.findAllElements('item');

    return itemElements.map((element) {
      final result = <String, String>{};

      for (final child in element.children) {
        if (child is XmlElement) {
          result[child.name.local] =
              child.innerText.trim();
        }
      }

      return result;
    }).toList();
  }

  String _findElementText(
      XmlDocument document,
      List<String> names,
      ) {
    for (final name in names) {
      final elements =
      document.findAllElements(name);

      if (elements.isNotEmpty) {
        return elements.first.innerText.trim();
      }
    }

    return '';
  }

  // =========================================================
  // 개별 저장
  // =========================================================

  Future<void> _saveSinglePreview() async {
    final preview = _singlePreview;

    if (preview == null ||
        preview.schedules.isEmpty) {
      _showMessage('먼저 일정을 조회하세요.');
      return;
    }

    await _runTask(
      taskName: '개별 자격증 일정 저장',
      task: () async {
        final savedCount =
        await _saveCertificateSchedules(
          preview,
        );

        if (!mounted) {
          return;
        }

        setState(() {
          _processedCount = 1;
          _savedScheduleCount = savedCount;
          _statusMessage =
          '${preview.certificate.jmfldnm} '
              '일정 $savedCount건 저장 완료';
        });
      },
    );
  }

  // =========================================================
  // 전체 저장
  // =========================================================

  Future<void> _saveAllPreviews() async {
    final previews = _allPreviews.values
        .where(
          (preview) => preview.schedules.isNotEmpty,
    )
        .toList();

    if (previews.isEmpty) {
      _showMessage('먼저 전체 일정을 조회하세요.');
      return;
    }

    await _runTask(
      taskName: '전체 조회 결과 저장',
      task: () async {
        var processedCount = 0;
        var savedCount = 0;

        for (final preview in previews) {
          _setStatus(
            '전체 일정 저장 중\n'
                '${preview.certificate.jmfldnm}\n'
                '${processedCount + 1}/${previews.length}',
          );

          savedCount +=
          await _saveCertificateSchedules(
            preview,
          );

          processedCount++;

          if (mounted) {
            setState(() {
              _processedCount = processedCount;
              _savedScheduleCount = savedCount;
            });
          }
        }

        _addLog(
          '[전체 저장 완료] '
              '자격증 ${previews.length}개, '
              '일정 $savedCount건',
        );

        if (!mounted) {
          return;
        }

        setState(() {
          _statusMessage =
          '전체 저장 완료\n'
              '자격증 ${previews.length}개\n'
              '일정 $savedCount건';
        });
      },
    );
  }

  Future<int> _saveCertificateSchedules(
      CertificateSchedulePreview preview,
      ) async {
    var savedCount = 0;

    /*
     * Firestore batch는 최대 500개의 쓰기 작업 제한이 있으므로
     * 일정 400건마다 나누어 저장한다.
     */
    const batchLimit = 400;

    for (var startIndex = 0;
    startIndex < preview.schedules.length;
    startIndex += batchLimit) {
      final endIndex =
      (startIndex + batchLimit <
          preview.schedules.length)
          ? startIndex + batchLimit
          : preview.schedules.length;

      final schedules = preview.schedules.sublist(
        startIndex,
        endIndex,
      );

      final batch = _firestore.batch();

      for (final schedule in schedules) {
        final reference = _firestore
            .collection(_certificateCollection)
            .doc(preview.certificate.jmcd)
            .collection(_scheduleCollection)
            .doc(schedule.documentId);

        batch.set(
          reference,
          schedule.toFirestore(),
          SetOptions(merge: true),
        );
      }

      await batch.commit();

      savedCount += schedules.length;
    }

    _addLog(
      '[저장 완료] ${preview.certificate.jmfldnm}: '
          '$savedCount건',
    );

    return savedCount;
  }

  // =========================================================
  // certificates 조회
  // =========================================================

  Future<CertificateInfo?> _findCertificate(
      String jmcd,
      ) async {
    /*
     * 먼저 certificates/{jmcd} 문서 ID로 조회한다.
     */
    final document = await _firestore
        .collection(_certificateCollection)
        .doc(jmcd)
        .get();

    if (document.exists) {
      return CertificateInfo.fromFirestore(
        document,
      );
    }

    /*
     * 문서 ID가 jmcd가 아닌 과거 데이터가 있을 수 있으므로
     * jmcd 필드로 한 번 더 조회한다.
     */
    final query = await _firestore
        .collection(_certificateCollection)
        .where(
      'jmcd',
      isEqualTo: jmcd,
    )
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      return null;
    }

    return CertificateInfo.fromFirestore(
      query.docs.first,
    );
  }

  // =========================================================
  // 공통 처리
  // =========================================================

  Future<void> _runTask({
    required String taskName,
    required Future<void> Function() task,
  }) async {
    if (_isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = '$taskName 시작';
      _processedCount = 0;
      _successCount = 0;
      _failureCount = 0;
      _previewScheduleCount = 0;
      _savedScheduleCount = 0;
      _logs.clear();
    });

    try {
      await task();

      if (!mounted) {
        return;
      }

      _showMessage('$taskName 완료');
    } catch (error, stackTrace) {
      _addLog('[오류] $error');

      debugPrintStack(
        stackTrace: stackTrace,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _statusMessage =
        '$taskName 실패\n$error';
      });

      _showMessage(
        '$taskName 실패\n$error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _validateServiceKey() {
    if (_serviceKey.isEmpty) {
      throw Exception(
        '.env 파일에 QNET_SERVICE_KEY가 없습니다.',
      );
    }
  }

  void _setStatus(String message) {
    if (!mounted) {
      return;
    }

    setState(() {
      _statusMessage = message;
    });
  }

  void _addLog(String message) {
    final now = DateTime.now();

    final time =
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';

    if (mounted) {
      setState(() {
        _logs.add('[$time] $message');
      });
    } else {
      _logs.add('[$time] $message');
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }
}

// ===========================================================
// 자격증 기본정보 모델
// ===========================================================

class CertificateInfo {
  const CertificateInfo({
    required this.jmcd,
    required this.jmfldnm,
    required this.qualgbcd,
    required this.qualgbnm,
    required this.seriescd,
    required this.seriesnm,
  });

  final String jmcd;
  final String jmfldnm;
  final String qualgbcd;
  final String qualgbnm;
  final String seriescd;
  final String seriesnm;

  factory CertificateInfo.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> document,
      ) {
    final data = document.data() ?? {};

    /*
     * certificates 문서 ID를 우선 jmcd로 사용한다.
     */
    final documentJmcd = document.id.trim();

    final fieldJmcd =
    _stringValue(data['jmcd']);

    return CertificateInfo(
      jmcd: documentJmcd.isNotEmpty
          ? documentJmcd
          : fieldJmcd,
      jmfldnm:
      _stringValue(data['jmfldnm']),
      qualgbcd: _stringValue(
        data['qualgbcd'],
      ).toUpperCase(),
      qualgbnm:
      _stringValue(data['qualgbnm']),
      seriescd:
      _stringValue(data['seriescd']),
      seriesnm:
      _stringValue(data['seriesnm']),
    );
  }
}

// ===========================================================
// 자격증별 조회 결과
// ===========================================================

class CertificateSchedulePreview {
  const CertificateSchedulePreview({
    required this.certificate,
    required this.schedules,
  });

  final CertificateInfo certificate;
  final List<TechnicalSchedule> schedules;
}

// ===========================================================
// 국가기술자격 일정 모델
// ===========================================================

class TechnicalSchedule {
  const TechnicalSchedule({
    required this.documentId,
    required this.jmcd,
    required this.description,
    required this.docRegStartDate,
    required this.docRegEndDate,
    required this.docExamDate,
    required this.docPassDate,
    required this.docSubmitStartDate,
    required this.docSubmitEndDate,
    required this.pracRegStartDate,
    required this.pracRegEndDate,
    required this.pracExamStartDate,
    required this.pracExamEndDate,
    required this.pracPassDate,
  });

  final String documentId;
  final String jmcd;
  final String description;

  final DateTime? docRegStartDate;
  final DateTime? docRegEndDate;
  final DateTime? docExamDate;
  final DateTime? docPassDate;
  final DateTime? docSubmitStartDate;
  final DateTime? docSubmitEndDate;
  final DateTime? pracRegStartDate;
  final DateTime? pracRegEndDate;
  final DateTime? pracExamStartDate;
  final DateTime? pracExamEndDate;
  final DateTime? pracPassDate;

  factory TechnicalSchedule.fromApiItem({
    required Map<String, String> item,
    required CertificateInfo certificate,
    required int itemIndex,
  }) {
    final description = _mapValue(
      item,
      const [
        'description',
      ],
    );

    final docRegStartDate = _parseDate(
      _mapValue(
        item,
        const [
          'docRegStartDt',
          'docregstartdt',
        ],
      ),
    );

    final docRegEndDate = _parseDate(
      _mapValue(
        item,
        const [
          'docRegEndDt',
          'docregenddt',
        ],
      ),
    );

    final docExamDate = _parseDate(
      _mapValue(
        item,
        const [
          'docExamDt',
          'docexamdt',
        ],
      ),
    );

    final docPassDate = _parseDate(
      _mapValue(
        item,
        const [
          'docPassDt',
          'docpassdt',
        ],
      ),
    );

    final docSubmitStartDate = _parseDate(
      _mapValue(
        item,
        const [
          'docSubmitStartDt',
          'docsubmitstartdt',
        ],
      ),
    );

    /*
     * 공식 출력 필드명이 docSubmitEnDt이므로
     * End가 아닌 En 형태도 함께 처리한다.
     */
    final docSubmitEndDate = _parseDate(
      _mapValue(
        item,
        const [
          'docSubmitEnDt',
          'docSubmitEndDt',
          'docsubmitendt',
          'docsubmitenddt',
        ],
      ),
    );

    final pracRegStartDate = _parseDate(
      _mapValue(
        item,
        const [
          'pracRegStartDt',
          'pracregstartdt',
        ],
      ),
    );

    final pracRegEndDate = _parseDate(
      _mapValue(
        item,
        const [
          'pracRegEndDt',
          'pracregenddt',
        ],
      ),
    );

    final pracExamStartDate = _parseDate(
      _mapValue(
        item,
        const [
          'pracExamStartDt',
          'pracexamstartdt',
        ],
      ),
    );

    final pracExamEndDate = _parseDate(
      _mapValue(
        item,
        const [
          'pracExamEndDt',
          'pracexamenddt',
        ],
      ),
    );

    final pracPassDate = _parseDate(
      _mapValue(
        item,
        const [
          'pracPassDt',
          'pracpassdt',
        ],
      ),
    );

    final firstDate = _firstDate([
      docRegStartDate,
      docExamDate,
      docPassDate,
      docSubmitStartDate,
      pracRegStartDate,
      pracExamStartDate,
      pracPassDate,
    ]);

    final dateKey = firstDate == null
        ? 'nodate'
        : _dateString(firstDate);

    final documentId = _safeDocumentId(
      '${certificate.jmcd}_'
          '${dateKey}_'
          '${description}_'
          '$itemIndex',
    );

    return TechnicalSchedule(
      documentId: documentId,
      jmcd: certificate.jmcd,
      description: description,
      docRegStartDate: docRegStartDate,
      docRegEndDate: docRegEndDate,
      docExamDate: docExamDate,
      docPassDate: docPassDate,
      docSubmitStartDate:
      docSubmitStartDate,
      docSubmitEndDate:
      docSubmitEndDate,
      pracRegStartDate:
      pracRegStartDate,
      pracRegEndDate:
      pracRegEndDate,
      pracExamStartDate:
      pracExamStartDate,
      pracExamEndDate:
      pracExamEndDate,
      pracPassDate:
      pracPassDate,
    );
  }

  bool get hasAnyDate {
    return [
      docRegStartDate,
      docRegEndDate,
      docExamDate,
      docPassDate,
      docSubmitStartDate,
      docSubmitEndDate,
      pracRegStartDate,
      pracRegEndDate,
      pracExamStartDate,
      pracExamEndDate,
      pracPassDate,
    ].any((date) => date != null);
  }

  DateTime? get sortDate {
    return _firstDate([
      docRegStartDate,
      docExamDate,
      docPassDate,
      docSubmitStartDate,
      pracRegStartDate,
      pracExamStartDate,
      pracPassDate,
    ]);
  }

  int? get year => sortDate?.year;

  Map<String, dynamic> toFirestore() {
    return {
      'jmcd': jmcd,
      'description': description,
      'year': year,
      'sortdate': _timestamp(sortDate),

      'docregstartdt':
      _nullableDateString(docRegStartDate),
      'docregenddt':
      _nullableDateString(docRegEndDate),
      'docregstartat':
      _timestamp(docRegStartDate),
      'docregendat':
      _timestamp(docRegEndDate),

      'docexamdt':
      _nullableDateString(docExamDate),
      'docexamat':
      _timestamp(docExamDate),

      'docpassdt':
      _nullableDateString(docPassDate),
      'docpassat':
      _timestamp(docPassDate),

      'docsubmitstartdt':
      _nullableDateString(
        docSubmitStartDate,
      ),
      'docsubmitenddt':
      _nullableDateString(
        docSubmitEndDate,
      ),
      'docsubmitstartat':
      _timestamp(docSubmitStartDate),
      'docsubmitendat':
      _timestamp(docSubmitEndDate),

      'pracregstartdt':
      _nullableDateString(pracRegStartDate),
      'pracregenddt':
      _nullableDateString(pracRegEndDate),
      'pracregstartat':
      _timestamp(pracRegStartDate),
      'pracregendat':
      _timestamp(pracRegEndDate),

      'pracexamstartdt':
      _nullableDateString(
        pracExamStartDate,
      ),
      'pracexamenddt':
      _nullableDateString(
        pracExamEndDate,
      ),
      'pracexamstartat':
      _timestamp(pracExamStartDate),
      'pracexamendat':
      _timestamp(pracExamEndDate),

      'pracpassdt':
      _nullableDateString(pracPassDate),
      'pracpassat':
      _timestamp(pracPassDate),

      'updatedat':
      FieldValue.serverTimestamp(),
    };
  }
}

// ===========================================================
// 유틸
// ===========================================================

String _stringValue(
    dynamic value, {
      String fallback = '',
    }) {
  if (value == null) {
    return fallback;
  }

  final text = value.toString().trim();

  return text.isEmpty ? fallback : text;
}

String _mapValue(
    Map<String, String> data,
    List<String> keys,
    ) {
  for (final key in keys) {
    final directValue = data[key];

    if (directValue != null &&
        directValue.trim().isNotEmpty) {
      return directValue.trim();
    }

    for (final entry in data.entries) {
      if (entry.key.toLowerCase() ==
          key.toLowerCase()) {
        final value = entry.value.trim();

        if (value.isNotEmpty) {
          return value;
        }
      }
    }
  }

  return '';
}

DateTime? _parseDate(String value) {
  final digits = value.replaceAll(
    RegExp(r'[^0-9]'),
    '',
  );

  if (digits.length < 8) {
    return null;
  }

  try {
    final year = int.parse(
      digits.substring(0, 4),
    );

    final month = int.parse(
      digits.substring(4, 6),
    );

    final day = int.parse(
      digits.substring(6, 8),
    );

    final date = DateTime(year, month, day);

    /*
     * DateTime은 2026-13-40 같은 값도 자동 보정하므로
     * 원본 월·일과 같은지 확인한다.
     */
    if (date.year != year ||
        date.month != month ||
        date.day != day) {
      return null;
    }

    return date;
  } catch (_) {
    return null;
  }
}

DateTime? _firstDate(List<DateTime?> dates) {
  for (final date in dates) {
    if (date != null) {
      return date;
    }
  }

  return null;
}

Timestamp? _timestamp(DateTime? date) {
  if (date == null) {
    return null;
  }

  return Timestamp.fromDate(date);
}

String _dateString(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}'
      '${date.month.toString().padLeft(2, '0')}'
      '${date.day.toString().padLeft(2, '0')}';
}

String? _nullableDateString(DateTime? date) {
  if (date == null) {
    return null;
  }

  return _dateString(date);
}

String _displayDate(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}.'
      '${date.month.toString().padLeft(2, '0')}.'
      '${date.day.toString().padLeft(2, '0')}';
}

String _dateRangeText(
    DateTime? startDate,
    DateTime? endDate,
    ) {
  if (startDate == null && endDate == null) {
    return '-';
  }

  final normalizedStart =
      startDate ?? endDate!;

  final normalizedEnd =
      endDate ?? startDate!;

  final startText =
  _displayDate(normalizedStart);

  final endText =
  _displayDate(normalizedEnd);

  if (startText == endText) {
    return startText;
  }

  return '$startText ~ $endText';
}

String _safeDocumentId(String value) {
  var result = value
      .trim()
      .replaceAll(
    RegExp(r'\s+'),
    '_',
  )
      .replaceAll('/', '_')
      .replaceAll(
    RegExp(r'[^a-zA-Z0-9가-힣_-]'),
    '',
  );

  if (result.isEmpty) {
    result = DateTime.now()
        .millisecondsSinceEpoch
        .toString();
  }

  if (result.length > 300) {
    result = result.substring(0, 300);
  }

  return result;
}

String _safePreview(String value) {
  if (value.length <= 500) {
    return value;
  }

  return '${value.substring(0, 500)}...';
}