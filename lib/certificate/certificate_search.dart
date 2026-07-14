import 'package:flutter/material.dart';

import '../widgets/app_main_background.dart';
import '../widgets/app_top_bar.dart';

class CertificateSearchPage extends StatefulWidget {
  const CertificateSearchPage({super.key});

  @override
  State<CertificateSearchPage> createState() =>
      _CertificateSearchPageState();
}

class _CertificateSearchPageState extends State<CertificateSearchPage> {
  static const Color _primaryPink = Color(0xFFF286A2);
  static const Color _darkText = Color(0xFF302C2E);
  static const Color _grayText = Color(0xFF817B7D);
  static const Color _softPink = Color(0xFFFBE7ED);

  final TextEditingController _searchController = TextEditingController();

  String _selectedQualificationType = '국가기술자격';
  String? _selectedJobField;
  String? _selectedCategory;

  final List<String> _qualificationTypes = const [
    '국가기술자격',
    '국가전문자격',
    '민간자격',
  ];

  /*
   * TODO:
   * 추후 공공데이터 API 응답으로 교체
   *
   * 직무 분야 → obligfldnm
   * 분류 → mdobligfldnm 또는 API 분류 항목
   * 시행 종목 → jmfldnm
   */
  final Map<String, Map<String, List<String>>> _technicalData = const {
    '경영·회계·사무': {
      '경영': [
        '사회조사분석사 1급',
        '사회조사분석사 2급',
        '소비자전문상담사 1급',
        '소비자전문상담사 2급',
        '컨벤션기획사 1급',
        '컨벤션기획사 2급',
      ],
      '회계': [
        '전산회계운용사 1급',
        '전산회계운용사 2급',
        '전산회계운용사 3급',
      ],
      '사무': [
        '비서 1급',
        '비서 2급',
        '비서 3급',
        '워드프로세서',
      ],
      '생산관리': [
        '품질경영기사',
        '품질경영산업기사',
        '공장관리기술사',
      ],
    },
    '교육·자연·과학·사회과학': {
      '교육': [
        '평생교육사',
      ],
      '자연과학': [
        '기상기사',
        '기상감정기사',
      ],
    },
    '보건·의료': {
      '보건': [
        '위생사',
        '보건교육사',
      ],
      '의료': [
        '임상병리사',
        '방사선사',
      ],
    },
    '문화·예술·디자인·방송': {
      '디자인': [
        '시각디자인기사',
        '시각디자인산업기사',
        '제품디자인기사',
        '컬러리스트기사',
      ],
      '방송': [
        '방송통신기사',
        '방송통신산업기사',
      ],
    },
    '영업·판매': {
      '판매': [
        '텔레마케팅관리사',
        '전자상거래관리사 1급',
        '전자상거래관리사 2급',
      ],
    },
    '이용·숙박·여행·오락·스포츠': {
      '이용·미용': [
        '미용사(일반)',
        '미용사(피부)',
        '이용사',
      ],
      '숙박·여행': [
        '국내여행안내사',
        '관광통역안내사',
        '호텔경영사',
      ],
      '스포츠': [
        '스포츠경영관리사',
      ],
    },
    '건설': {
      '건축': [
        '건축기사',
        '건축산업기사',
        '건축설비기사',
      ],
      '토목': [
        '토목기사',
        '토목산업기사',
        '건설재료시험기사',
      ],
      '조경': [
        '조경기사',
        '조경산업기사',
        '조경기능사',
      ],
    },
    '기계': {
      '기계제작': [
        '일반기계기사',
        '기계설계기사',
        '컴퓨터응용가공산업기사',
      ],
      '자동차': [
        '자동차정비기사',
        '자동차정비산업기사',
        '자동차정비기능사',
      ],
      '설비': [
        '건설기계설비기사',
        '공조냉동기계기사',
      ],
    },
    '화학': {
      '화공': [
        '화공기사',
        '화약류제조기사',
      ],
      '위험물': [
        '위험물산업기사',
        '위험물기능사',
      ],
    },
    '전기·전자': {
      '전기': [
        '전기기사',
        '전기산업기사',
        '전기기능사',
        '전기공사기사',
      ],
      '전자': [
        '전자기사',
        '전자산업기사',
        '전자기기기능사',
      ],
    },
    '정보통신': {
      '정보기술': [
        '정보처리기사',
        '정보처리산업기사',
        '정보처리기능사',
        '빅데이터분석기사',
      ],
      '통신': [
        '정보통신기사',
        '정보통신산업기사',
        '무선설비기사',
        '통신선로산업기사',
      ],
      '방송': [
        '방송통신기사',
        '방송통신산업기사',
      ],
    },
    '식품·가공': {
      '식품': [
        '식품기사',
        '식품산업기사',
        '식품가공기능사',
      ],
      '제과·제빵': [
        '제과기능사',
        '제빵기능사',
      ],
    },
    '농림어업': {
      '농업': [
        '종자기사',
        '유기농업기사',
        '시설원예기사',
      ],
      '산림': [
        '산림기사',
        '산림산업기사',
        '산림기능사',
      ],
      '수산': [
        '수산양식기사',
        '어업생산관리기사',
      ],
    },
    '안전관리': {
      '산업안전': [
        '산업안전기사',
        '산업안전산업기사',
        '건설안전기사',
      ],
      '소방': [
        '소방설비기사(기계분야)',
        '소방설비기사(전기분야)',
        '소방설비산업기사',
      ],
      '가스': [
        '가스기사',
        '가스산업기사',
        '가스기능사',
      ],
    },
    '환경·에너지': {
      '환경': [
        '대기환경기사',
        '수질환경기사',
        '폐기물처리기사',
        '소음진동기사',
      ],
      '에너지': [
        '에너지관리기사',
        '신재생에너지발전설비기사',
      ],
    },
    '음식서비스': {
      '조리': [
        '한식조리기능사',
        '양식조리기능사',
        '중식조리기능사',
        '일식조리기능사',
      ],
      '제과·제빵': [
        '제과기능사',
        '제빵기능사',
      ],
    },
  };

  final Map<String, Map<String, List<String>>> _professionalData = const {
    '보건·의료': {
      '의료': [
        '간호사',
        '치과의사',
        '약사',
        '물리치료사',
      ],
      '보건': [
        '영양사',
        '위생사',
      ],
    },
    '법률·경찰·소방·교도·국방': {
      '법률': [
        '변호사',
        '법무사',
        '변리사',
      ],
      '행정': [
        '행정사',
      ],
    },
    '사회복지·종교': {
      '사회복지': [
        '사회복지사 1급',
      ],
    },
    '교육·자연·과학·사회과학': {
      '교육': [
        '한국어교육능력검정시험',
      ],
    },
    '경영·회계·사무': {
      '경영': [
        '경영지도사',
      ],
      '회계': [
        '공인회계사',
        '세무사',
      ],
    },
  };

  final Map<String, Map<String, List<String>>> _privateQualificationData =
  const {
    '정보통신': {
      '데이터': [
        'SQLD',
        'SQLP',
        '데이터분석 준전문가',
        '데이터분석 전문가',
      ],
      '네트워크': [
        '네트워크관리사 1급',
        '네트워크관리사 2급',
      ],
    },
    '경영·회계·사무': {
      '회계': [
        '전산회계 1급',
        '전산회계 2급',
        '전산세무 1급',
        '전산세무 2급',
      ],
      '사무': [
        '컴퓨터활용능력 1급',
        '컴퓨터활용능력 2급',
      ],
    },
    '교육·자연·과학·사회과학': {
      '한국사': [
        '한국사능력검정시험 심화',
        '한국사능력검정시험 기본',
      ],
    },
  };

  Map<String, Map<String, List<String>>> get _currentData {
    switch (_selectedQualificationType) {
      case '국가전문자격':
        return _professionalData;

      case '민간자격':
        return _privateQualificationData;

      case '국가기술자격':
      default:
        return _technicalData;
    }
  }

  List<String> get _jobFields {
    return _currentData.keys.toList();
  }

  List<String> get _categories {
    if (_selectedJobField == null) {
      return [];
    }

    return _currentData[_selectedJobField]?.keys.toList() ?? [];
  }

  List<String> get _selectedCertificates {
    if (_selectedJobField == null || _selectedCategory == null) {
      return [];
    }

    return _currentData[_selectedJobField]?[_selectedCategory] ?? [];
  }

  List<_SearchResultItem> get _searchResults {
    final keyword = _searchController.text.trim().toLowerCase();

    if (keyword.isEmpty) {
      return [];
    }

    final results = <_SearchResultItem>[];

    for (final qualificationEntry in _allData.entries) {
      final qualificationType = qualificationEntry.key;
      final jobFieldMap = qualificationEntry.value;

      for (final jobFieldEntry in jobFieldMap.entries) {
        final jobField = jobFieldEntry.key;
        final categoryMap = jobFieldEntry.value;

        for (final categoryEntry in categoryMap.entries) {
          final category = categoryEntry.key;

          for (final certificateName in categoryEntry.value) {
            if (certificateName.toLowerCase().contains(keyword)) {
              results.add(
                _SearchResultItem(
                  qualificationType: qualificationType,
                  jobField: jobField,
                  category: category,
                  certificateName: certificateName,
                ),
              );
            }
          }
        }
      }
    }

    return results;
  }

  Map<String, Map<String, Map<String, List<String>>>> get _allData {
    return {
      '국가기술자격': _technicalData,
      '국가전문자격': _professionalData,
      '민간자격': _privateQualificationData,
    };
  }

  bool get _isSearching {
    return _searchController.text.trim().isNotEmpty;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _selectQualificationType(String value) {
    setState(() {
      _selectedQualificationType = value;
      _selectedJobField = null;
      _selectedCategory = null;
    });
  }

  void _selectJobField(String value) {
    setState(() {
      _selectedJobField = value;
      _selectedCategory = null;
    });
  }

  void _selectCategory(String value) {
    setState(() {
      _selectedCategory = value;
    });
  }

  void _clearSearch() {
    _searchController.clear();

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppTopBar(
        title: '자격증 검색',
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: _darkText,
            size: 21,
          ),
        ),
      ),
      body: AppMainBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 40),
          children: [
            _buildSearchField(),

            const SizedBox(height: 26),

            if (_isSearching)
              _buildSearchResultSection()
            else
              _buildCategorySelectionSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        onChanged: (_) {
          setState(() {});
        },
        decoration: InputDecoration(
          hintText: '자격증 이름을 검색해보세요',
          hintStyle: const TextStyle(
            color: Color(0xFFAAA3A5),
            fontSize: 15,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: _grayText,
            size: 24,
          ),
          suffixIcon: _isSearching
              ? IconButton(
            onPressed: _clearSearch,
            icon: const Icon(
              Icons.close_rounded,
              color: _grayText,
              size: 20,
            ),
          )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 17,
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySelectionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          number: '1',
          title: '자격 구분',
        ),

        const SizedBox(height: 13),

        _buildQualificationTypeSelector(),

        const SizedBox(height: 30),

        _buildSectionTitle(
          number: '2',
          title: '직무 분야',
        ),

        const SizedBox(height: 13),

        _buildJobFieldGrid(),

        if (_selectedJobField != null) ...[
          const SizedBox(height: 30),

          _buildSelectedPath(),

          const SizedBox(height: 30),

          _buildSectionTitle(
            number: '3',
            title: '분류',
          ),

          const SizedBox(height: 13),

          _buildCategorySelector(),
        ],

        if (_selectedCategory != null) ...[
          const SizedBox(height: 30),

          _buildSectionTitle(
            number: '4',
            title: '시행 종목',
            count: _selectedCertificates.length,
          ),

          const SizedBox(height: 13),

          _buildCertificateList(),
        ],
      ],
    );
  }

  Widget _buildQualificationTypeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF4EFF1),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: _qualificationTypes.map((type) {
          final isSelected =
              type == _selectedQualificationType;

          return Expanded(
            child: _QualificationTypeButton(
              label: type,
              selected: isSelected,
              onTap: () => _selectQualificationType(type),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildJobFieldGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _jobFields.length,
      gridDelegate:
      const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.35,
      ),
      itemBuilder: (context, index) {
        final jobField = _jobFields[index];
        final isSelected = _selectedJobField == jobField;

        return _JobFieldCard(
          label: jobField,
          selected: isSelected,
          onTap: () => _selectJobField(jobField),
        );
      },
    );
  }

  Widget _buildCategorySelector() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.93),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Wrap(
        spacing: 9,
        runSpacing: 10,
        children: _categories.map((category) {
          return _SelectionChip(
            label: category,
            selected: _selectedCategory == category,
            onTap: () => _selectCategory(category),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCertificateList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: List.generate(
          _selectedCertificates.length,
              (index) {
            final certificate = _selectedCertificates[index];
            final isLast =
                index == _selectedCertificates.length - 1;

            return Column(
              children: [
                _CertificateListTile(
                  certificateName: certificate,
                  qualificationType:
                  _selectedQualificationType,
                  jobField: _selectedJobField!,
                  category: _selectedCategory!,
                  onTap: () {
                    // TODO: 자격증 상세 페이지로 이동
                  },
                ),
                if (!isLast)
                  const Divider(
                    height: 1,
                    indent: 18,
                    endIndent: 18,
                    color: Color(0xFFF0EBED),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSelectedPath() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 17,
        vertical: 15,
      ),
      decoration: BoxDecoration(
        color: _softPink,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.account_tree_outlined,
            color: _primaryPink,
            size: 21,
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              _selectedCategory == null
                  ? '$_selectedQualificationType  ›  $_selectedJobField'
                  : '$_selectedQualificationType  ›  '
                  '$_selectedJobField  ›  $_selectedCategory',
              style: const TextStyle(
                color: _darkText,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResultSection() {
    final results = _searchResults;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '검색 결과',
              style: TextStyle(
                color: _darkText,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const Spacer(),
            Text(
              '${results.length}개',
              style: const TextStyle(
                color: _primaryPink,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        if (results.isEmpty)
          const _EmptySearchResult()
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              children: List.generate(
                results.length,
                    (index) {
                  final result = results[index];
                  final isLast = index == results.length - 1;

                  return Column(
                    children: [
                      _SearchResultTile(
                        result: result,
                        onTap: () {
                          // TODO: 자격증 상세 페이지로 이동
                        },
                      ),
                      if (!isLast)
                        const Divider(
                          height: 1,
                          indent: 18,
                          endIndent: 18,
                          color: Color(0xFFF0EBED),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSectionTitle({
    required String number,
    required String title,
    int? count,
  }) {
    return Row(
      children: [
        Container(
          width: 25,
          height: 25,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: _primaryPink,
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),

        const SizedBox(width: 9),

        Text(
          title,
          style: const TextStyle(
            color: _darkText,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),

        if (count != null) ...[
          const Spacer(),
          Text(
            '$count개',
            style: const TextStyle(
              color: _primaryPink,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

class _QualificationTypeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _QualificationTypeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 47,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: selected
                ? [
              BoxShadow(
                color:
                Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ]
                : null,
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected
                  ? const Color(0xFFF286A2)
                  : const Color(0xFF817B7D),
              fontSize: 13,
              fontWeight:
              selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _JobFieldCard extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _JobFieldCard({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? const Color(0xFFFBE7ED)
          : Colors.white.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 11,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: selected
                  ? const Color(0xFFF286A2)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFF302C2E),
                    fontSize: 13,
                    height: 1.25,
                    fontWeight: selected
                        ? FontWeight.w700
                        : FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                color: selected
                    ? const Color(0xFFF286A2)
                    : const Color(0xFFAAA3A5),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SelectionChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? const Color(0xFFF286A2)
          : const Color(0xFFF7F3F4),
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 17,
            vertical: 11,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? Colors.white
                  : const Color(0xFF302C2E),
              fontSize: 13,
              fontWeight: selected
                  ? FontWeight.w700
                  : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _CertificateListTile extends StatelessWidget {
  final String certificateName;
  final String qualificationType;
  final String jobField;
  final String category;
  final VoidCallback onTap;

  const _CertificateListTile({
    required this.certificateName,
    required this.qualificationType,
    required this.jobField,
    required this.category,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 16,
          ),
          child: Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: const Color(0xFFFBE7ED),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.workspace_premium_outlined,
                  color: Color(0xFFF286A2),
                  size: 22,
                ),
              ),

              const SizedBox(width: 13),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      certificateName,
                      style: const TextStyle(
                        color: Color(0xFF302C2E),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      '$jobField · $category',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF817B7D),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFAAA3A5),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  final _SearchResultItem result;
  final VoidCallback onTap;

  const _SearchResultTile({
    required this.result,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 16,
          ),
          child: Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: const Color(0xFFFBE7ED),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.workspace_premium_outlined,
                  color: Color(0xFFF286A2),
                  size: 22,
                ),
              ),

              const SizedBox(width: 13),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.certificateName,
                      style: const TextStyle(
                        color: Color(0xFF302C2E),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      '${result.qualificationType} · '
                          '${result.jobField} · '
                          '${result.category}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF817B7D),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFAAA3A5),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptySearchResult extends StatelessWidget {
  const _EmptySearchResult();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 42,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.search_off_rounded,
            color: Color(0xFFB7B0B2),
            size: 34,
          ),
          SizedBox(height: 12),
          Text(
            '검색 결과가 없습니다.',
            style: TextStyle(
              color: Color(0xFF817B7D),
              fontSize: 15,
            ),
          ),
          SizedBox(height: 6),
          Text(
            '다른 자격증 이름으로 검색해보세요.',
            style: TextStyle(
              color: Color(0xFFAAA3A5),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchResultItem {
  final String qualificationType;
  final String jobField;
  final String category;
  final String certificateName;

  const _SearchResultItem({
    required this.qualificationType,
    required this.jobField,
    required this.category,
    required this.certificateName,
  });
}