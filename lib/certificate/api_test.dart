import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

class QualificationApiTestPage extends StatefulWidget {
  const QualificationApiTestPage({super.key});

  @override
  State<QualificationApiTestPage> createState() =>
      _QualificationApiTestPageState();
}

class _QualificationApiTestPageState
    extends State<QualificationApiTestPage> {
  bool _isLoading = false;
  String? _errorMessage;
  String _rawXml = '';
  List<Map<String, String>> _items = [];

  String get _serviceKey {
    return dotenv.env['QNET_SERVICE_KEY']?.trim() ?? '';
  }

  static const String _baseUrl =
      'http://openapi.q-net.or.kr/api/service/rest/'
      'InquiryListNationalQualifcationSVC/getList';

  Future<void> _requestApi() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _rawXml = '';
      _items = [];
    });

    try {
      final serviceKey = _serviceKey;

      if (serviceKey.isEmpty) {
        throw Exception(
          '.env에 QNET_SERVICE_KEY가 설정되지 않았습니다.',
        );
      }

      final uri = Uri.parse(_baseUrl).replace(
        queryParameters: {
          'serviceKey': serviceKey,
        },
      );

      debugPrint('Q-Net 자격증 목록 API 요청');

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/xml',
        },
      );

      debugPrint('상태 코드: ${response.statusCode}');

      if (response.statusCode != 200) {
        throw Exception(
          'HTTP 요청 실패: ${response.statusCode}',
        );
      }

      final xmlText = utf8.decode(
        response.bodyBytes,
      );

      debugPrint(
        '응답 앞부분: '
            '${xmlText.substring(
          0,
          xmlText.length > 300 ? 300 : xmlText.length,
        )}',
      );

      final document = XmlDocument.parse(xmlText);

      final resultCode = _findFirstText(
        document,
        'resultCode',
      );

      final resultMessage = _findFirstText(
        document,
        'resultMsg',
      );

      if (resultCode.isNotEmpty && resultCode != '00') {
        throw Exception(
          'API 오류\n'
              '코드: $resultCode\n'
              '메시지: $resultMessage',
        );
      }

      final parsedItems = document
          .findAllElements('item')
          .map((item) {
        return {
          'qualgbcd': _findChildText(item, 'qualgbcd'),
          'qualgbnm': _findChildText(item, 'qualgbnm'),
          'seriescd': _findChildText(item, 'seriescd'),
          'seriesnm': _findChildText(item, 'seriesnm'),
          'jmcd': _findChildText(item, 'jmcd'),
          'jmfldnm': _findChildText(item, 'jmfldnm'),
          'obligfldcd':
          _findChildText(item, 'obligfldcd'),
          'obligfldnm':
          _findChildText(item, 'obligfldnm'),
          'mdobligfldcd':
          _findChildText(item, 'mdobligfldcd'),
          'mdobligfldnm':
          _findChildText(item, 'mdobligfldnm'),
        };
      }).toList();

      if (!mounted) return;

      setState(() {
        _rawXml = xmlText;
        _items = parsedItems;
      });
    } on FormatException catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage =
        'XML 파싱 실패\n'
            'API가 XML이 아닌 오류 페이지를 반환했을 수 있습니다.\n\n'
            '$e';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _findFirstText(
      XmlDocument document,
      String elementName,
      ) {
    final elements = document.findAllElements(elementName);

    if (elements.isEmpty) {
      return '';
    }

    return elements.first.innerText.trim();
  }

  String _findChildText(
      XmlElement parent,
      String elementName,
      ) {
    final elements = parent.findElements(elementName);

    if (elements.isEmpty) {
      return '';
    }

    return elements.first.innerText.trim();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('자격증 API 테스트'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '목록 보기'),
              Tab(text: 'XML 원문'),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed:
                  _isLoading ? null : _requestApi,
                  icon: const Icon(Icons.download),
                  label: Text(
                    _isLoading
                        ? '불러오는 중...'
                        : 'API 호출하기',
                  ),
                ),
              ),
            ),
            Expanded(
              child: _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          _errorMessage!,
          style: const TextStyle(
            color: Colors.red,
          ),
        ),
      );
    }

    if (_rawXml.isEmpty) {
      return const Center(
        child: Text(
          'API 호출하기 버튼을 눌러주세요.',
        ),
      );
    }

    return TabBarView(
      children: [
        _buildItemList(),
        _buildRawXml(),
      ],
    );
  }

  Widget _buildItemList() {
    if (_items.isEmpty) {
      return const Center(
        child: Text('조회된 데이터가 없습니다.'),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            16,
            8,
            16,
            8,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '조회 개수: ${_items.length}개',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: _items.length,
            separatorBuilder: (_, __) =>
            const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = _items[index];

              return ExpansionTile(
                leading: CircleAvatar(
                  child: Text('${index + 1}'),
                ),
                title: Text(
                  item['jmfldnm'] ?? '',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  '${item['qualgbnm']} · ${item['seriesnm']}',
                ),
                childrenPadding:
                const EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  16,
                ),
                children: [
                  _fieldRow(
                    '자격 구분 코드',
                    item['qualgbcd'],
                  ),
                  _fieldRow(
                    '자격 구분명',
                    item['qualgbnm'],
                  ),
                  _fieldRow(
                    '계열 코드',
                    item['seriescd'],
                  ),
                  _fieldRow(
                    '계열명',
                    item['seriesnm'],
                  ),
                  _fieldRow(
                    '종목 코드',
                    item['jmcd'],
                  ),
                  _fieldRow(
                    '종목명',
                    item['jmfldnm'],
                  ),
                  _fieldRow(
                    '대직무 분야 코드',
                    item['obligfldcd'],
                  ),
                  _fieldRow(
                    '대직무 분야명',
                    item['obligfldnm'],
                  ),
                  _fieldRow(
                    '중직무 분야 코드',
                    item['mdobligfldcd'],
                  ),
                  _fieldRow(
                    '중직무 분야명',
                    item['mdobligfldnm'],
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _fieldRow(
      String label,
      String? value,
      ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value?.isNotEmpty == true ? value! : '-',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRawXml() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SelectableText(
        _rawXml,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
        ),
      ),
    );
  }
}