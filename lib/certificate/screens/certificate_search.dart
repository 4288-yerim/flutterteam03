import 'package:flutter/material.dart';

import '../../theme.dart';

import '../../widgets/app_main_background.dart';
import '../../widgets/app_state_views.dart';
import '../../widgets/app_top_bar.dart';
import '../services/certificate_search_service.dart';
import '../widgets/certificate_common_widgets.dart';
import '../widgets/certificate_search_widgets.dart';
import 'professional_certificate_detail.dart';
import 'technical_certificate_detail.dart';
import 'other_certificate_detail.dart';

class CertificateSearchPage extends StatefulWidget {
  const CertificateSearchPage({super.key});

  @override
  State<CertificateSearchPage> createState() => _CertificateSearchPageState();
}

class _CertificateSearchPageState extends State<CertificateSearchPage> {
  final CertificateSearchService _certificateSearchService =
      CertificateSearchService();

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Certification> _certifications = [];

  bool _isLoading = true;
  bool _isTechnicalJobFieldCollapsed = false;
  bool _isTechnicalCategoryCollapsed = false;
  bool _isProfessionalSeriesCollapsed = false;

  String? _loadError;

  String? _selectedTopLevelCategory;
  String _selectedQualificationCode = 'T';

  String? _selectedJobFieldCode;
  String? _selectedCategoryCode;
  String? _selectedProfessionalSeriesCode;
  String? _selectedOtherQualificationName;
  String? _selectedOtherJobFieldName;
  String? _selectedOtherCategoryName;
  bool _isOtherQualificationCollapsed = false;
  bool _isOtherJobFieldCollapsed = false;
  bool _isOtherCategoryCollapsed = false;

  final Map<String, String> _topLevelCategories = const {
    'hrd': '산업인력공단',
    'other': '그 외',
  };

  final Map<String, String> _qualificationTypes = const {
    'T': '국가기술자격',
    'S': '국가전문자격',
  };

  bool get _isTechnicalQualification {
    return _selectedQualificationCode == 'T';
  }

  bool get _isHumanResourcesDevelopmentService {
    return _selectedTopLevelCategory == 'hrd';
  }

  bool get _isSearching {
    return _searchController.text.trim().isNotEmpty;
  }

  List<_FilterOption> get _technicalJobFields {
    final Map<String, String> groupedFields = {};

    for (final certificate in _certifications) {
      if (!certificate.isHumanResourcesDevelopmentService ||
          !certificate.isTechnical) {
        continue;
      }

      if (certificate.obligfldcd.isEmpty || certificate.obligfldnm.isEmpty) {
        continue;
      }

      groupedFields.putIfAbsent(
        certificate.obligfldcd,
        () => certificate.obligfldnm,
      );
    }

    final fields = groupedFields.entries
        .map((entry) => _FilterOption(code: entry.key, name: entry.value))
        .toList();

    fields.sort((a, b) => a.name.compareTo(b.name));

    return fields;
  }

  List<_FilterOption> get _technicalCategories {
    if (_selectedJobFieldCode == null) {
      return [];
    }

    final Map<String, String> groupedCategories = {};

    for (final certificate in _certifications) {
      if (!certificate.isHumanResourcesDevelopmentService ||
          !certificate.isTechnical) {
        continue;
      }

      if (certificate.obligfldcd != _selectedJobFieldCode) {
        continue;
      }

      if (certificate.mdobligfldcd.isEmpty ||
          certificate.mdobligfldnm.isEmpty) {
        continue;
      }

      groupedCategories.putIfAbsent(
        certificate.mdobligfldcd,
        () => certificate.mdobligfldnm,
      );
    }

    final categories = groupedCategories.entries
        .map((entry) => _FilterOption(code: entry.key, name: entry.value))
        .toList();

    categories.sort((a, b) => a.name.compareTo(b.name));

    return categories;
  }

  List<_FilterOption> get _professionalSeries {
    final Map<String, String> groupedSeries = {};

    for (final certificate in _certifications) {
      if (!certificate.isHumanResourcesDevelopmentService ||
          !certificate.isProfessional) {
        continue;
      }

      if (certificate.seriescd.isEmpty || certificate.seriesnm.isEmpty) {
        continue;
      }

      groupedSeries.putIfAbsent(
        certificate.seriescd,
        () => certificate.seriesnm,
      );
    }

    final series = groupedSeries.entries
        .map((entry) => _FilterOption(code: entry.key, name: entry.value))
        .toList();

    series.sort((a, b) => a.name.compareTo(b.name));

    return series;
  }

  List<_FilterOption> get _otherQualificationTypes => _groupOptions(
    _certifications.where((certificate) =>
        !certificate.isHumanResourcesDevelopmentService),
    (certificate) => certificate.qualgbnm,
  );

  List<_FilterOption> get _otherJobFields {
    final qualificationName = _selectedOtherQualificationName;
    if (qualificationName == null) return [];
    return _groupOptions(
      _certifications.where((certificate) =>
          !certificate.isHumanResourcesDevelopmentService &&
          certificate.qualgbnm == qualificationName),
      (certificate) => certificate.obligfldnm,
    );
  }

  List<_FilterOption> get _otherCategories {
    final qualificationName = _selectedOtherQualificationName;
    final jobFieldName = _selectedOtherJobFieldName;
    if (qualificationName == null || jobFieldName == null) return [];
    return _groupOptions(
      _certifications.where((certificate) =>
          !certificate.isHumanResourcesDevelopmentService &&
          certificate.qualgbnm == qualificationName &&
          certificate.obligfldnm == jobFieldName),
      (certificate) => certificate.mdobligfldnm,
    );
  }

  List<Certification> get _selectedOtherCertificates {
    final qualificationName = _selectedOtherQualificationName;
    final jobFieldName = _selectedOtherJobFieldName;
    final categoryName = _selectedOtherCategoryName;
    if (qualificationName == null || jobFieldName == null || categoryName == null) {
      return [];
    }
    final certificates = _certifications.where((certificate) {
      return !certificate.isHumanResourcesDevelopmentService &&
          certificate.qualgbnm == qualificationName &&
          certificate.obligfldnm == jobFieldName &&
          certificate.mdobligfldnm == categoryName;
    }).toList()..sort((a, b) => a.name.compareTo(b.name));
    return certificates;
  }

  List<_FilterOption> _groupOptions(
    Iterable<Certification> certificates,
    String Function(Certification certificate) valueOf,
  ) {
    final names = <String>{};
    for (final certificate in certificates) {
      final name = valueOf(certificate);
      if (name.isNotEmpty) names.add(name);
    }
    return names.map((name) => _FilterOption(code: name, name: name)).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  List<Certification> get _selectedTechnicalCertificates {
    if (_selectedJobFieldCode == null || _selectedCategoryCode == null) {
      return [];
    }

    final certificates = _certifications.where((certificate) {
      return certificate.isHumanResourcesDevelopmentService &&
          certificate.isTechnical &&
          certificate.obligfldcd == _selectedJobFieldCode &&
          certificate.mdobligfldcd == _selectedCategoryCode;
    }).toList();

    certificates.sort((a, b) => a.name.compareTo(b.name));

    return certificates;
  }

  List<Certification> get _selectedProfessionalCertificates {
    if (_selectedProfessionalSeriesCode == null) {
      return [];
    }

    final certificates = _certifications.where((certificate) {
      return certificate.isHumanResourcesDevelopmentService &&
          certificate.isProfessional &&
          certificate.seriescd == _selectedProfessionalSeriesCode;
    }).toList();

    certificates.sort((a, b) => a.name.compareTo(b.name));

    return certificates;
  }

  _FilterOption? get _selectedTechnicalJobField {
    final selectedCode = _selectedJobFieldCode;

    if (selectedCode == null) {
      return null;
    }

    for (final field in _technicalJobFields) {
      if (field.code == selectedCode) {
        return field;
      }
    }

    return null;
  }

  _FilterOption? get _selectedTechnicalCategory {
    final selectedCode = _selectedCategoryCode;

    if (selectedCode == null) {
      return null;
    }

    for (final category in _technicalCategories) {
      if (category.code == selectedCode) {
        return category;
      }
    }

    return null;
  }

  _FilterOption? get _selectedProfessionalSeries {
    final selectedCode = _selectedProfessionalSeriesCode;

    if (selectedCode == null) {
      return null;
    }

    for (final series in _professionalSeries) {
      if (series.code == selectedCode) {
        return series;
      }
    }

    return null;
  }

  List<_SearchResultItem> get _searchResults {
    final keyword = _searchController.text.trim().toLowerCase();

    if (keyword.isEmpty) {
      return [];
    }

    final results = _certifications
        .where((certificate) {
          return certificate.name.toLowerCase().contains(keyword);
        })
        .map(
          (certificate) => _SearchResultItem(
            certificationId: certificate.id,
            certificateName: certificate.name,
            qualificationType: certificate.qualificationName,
            qualificationCode: certificate.qualgbcd,
            hasSource: certificate.hasSource,
            detailText: certificate.searchDetailText,
          ),
        )
        .toList();

    results.sort((a, b) => a.certificateName.compareTo(b.certificateName));

    return results;
  }

  @override
  void initState() {
    super.initState();
    _loadCertifications();
  }

  Future<void> _loadCertifications() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final certifications = await _certificateSearchService
          .getCertifications();

      if (!mounted) {
        return;
      }

      setState(() {
        _certifications
          ..clear()
          ..addAll(certifications);

        _isLoading = false;
      });
    } on CertificateSearchException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _loadError = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _loadError = '자격증 정보를 불러오지 못했습니다.';
      });
    }
  }

  void _openCertificateDetail({
    required String certificationId,
    required String qualificationCode,
    required bool hasSource,
  }) {
    final Widget detailPage;

    if (hasSource) {
      detailPage = OtherCertificateDetailPage(certificationId: certificationId);
    } else if (qualificationCode == 'T') {
      detailPage = TechnicalCertificateDetailPage(
        certificationId: certificationId,
      );
    } else {
      detailPage = ProfessionalCertificateDetailPage(
        certificationId: certificationId,
      );
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => detailPage),
    );
  }

  void _selectQualificationType(String code) {
    setState(() {
      _selectedQualificationCode = code;

      _selectedJobFieldCode = null;
      _selectedCategoryCode = null;
      _selectedProfessionalSeriesCode = null;

      _isTechnicalJobFieldCollapsed = false;
      _isProfessionalSeriesCollapsed = false;
    });
  }

  void _selectTopLevelCategory(String code) {
    setState(() {
      _selectedTopLevelCategory = code;
      _selectedQualificationCode = 'T';
      _selectedJobFieldCode = null;
      _selectedCategoryCode = null;
      _selectedProfessionalSeriesCode = null;
      _selectedOtherQualificationName = null;
      _selectedOtherJobFieldName = null;
      _selectedOtherCategoryName = null;
      _isTechnicalJobFieldCollapsed = false;
      _isTechnicalCategoryCollapsed = false;
      _isProfessionalSeriesCollapsed = false;
      _isOtherQualificationCollapsed = false;
      _isOtherJobFieldCollapsed = false;
      _isOtherCategoryCollapsed = false;
    });
  }

  void _selectOtherQualificationType(String name) {
    setState(() {
      _selectedOtherQualificationName = name;
      _selectedOtherJobFieldName = null;
      _selectedOtherCategoryName = null;
      _isOtherQualificationCollapsed = true;
      _isOtherJobFieldCollapsed = false;
      _isOtherCategoryCollapsed = false;
    });
  }

  void _selectOtherJobField(String name) {
    setState(() {
      _selectedOtherJobFieldName = name;
      _selectedOtherCategoryName = null;
      _isOtherJobFieldCollapsed = true;
      _isOtherCategoryCollapsed = false;
    });
    _scrollToNextFilter();
  }

  void _selectOtherCategory(String name) {
    setState(() {
      _selectedOtherCategoryName = name;
      _isOtherCategoryCollapsed = true;
    });
    _scrollToNextFilter();
  }

  void _expandOtherQualificationTypes() {
    setState(() => _isOtherQualificationCollapsed = false);
  }

  void _expandOtherJobFields() {
    setState(() => _isOtherJobFieldCollapsed = false);
  }

  void _expandOtherCategories() {
    setState(() => _isOtherCategoryCollapsed = false);
  }

  void _selectTechnicalJobField(String code) {
    setState(() {
      _selectedJobFieldCode = code;
      _selectedCategoryCode = null;
      _isTechnicalJobFieldCollapsed = true;
      _isTechnicalCategoryCollapsed = false;
    });
    _scrollToNextFilter();
  }

  void _scrollToNextFilter() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _expandTechnicalJobFields() {
    setState(() {
      _isTechnicalJobFieldCollapsed = false;
    });
  }

  void _selectTechnicalCategory(String code) {
    setState(() {
      _selectedCategoryCode = code;
      _isTechnicalCategoryCollapsed = true;
    });
    _scrollToNextFilter();
  }

  void _expandTechnicalCategories() {
    setState(() => _isTechnicalCategoryCollapsed = false);
  }

  void _selectProfessionalSeries(String code) {
    setState(() {
      _selectedProfessionalSeriesCode = code;
      _isProfessionalSeriesCollapsed = true;
    });
    _scrollToNextFilter();
  }

  void _expandProfessionalSeries() {
    setState(() {
      _isProfessionalSeriesCollapsed = false;
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {});
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
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
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: context.colors.textPrimary,
            size: 21,
          ),
        ),
      ),
      body: AppMainBackground(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return AppLoadingView(message: '자격증 정보를 불러오는 중입니다.');
    }

    if (_loadError != null) {
      return CertificateLoadError(
        message: _loadError!,
        onRetry: _loadCertifications,
      );
    }

    return ListView(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(24, 16, 24, 40),
      children: [
        CertificatePageHeader(
          title: '원하는 자격증을 찾아보세요',
          subtitle: '이름으로 검색하거나 분야별로 확인할 수 있어요.',
        ),
        SizedBox(height: 22),
        CertificateSearchField(
          controller: _searchController,
          isSearching: _isSearching,
          onChanged: (_) {
            setState(() {});
          },
          onClear: _clearSearch,
        ),
        SizedBox(height: 30),
        if (_isSearching)
          _buildSearchResultSection()
        else
          _buildCategorySelectionSection(),
      ],
    );
  }

  Widget _buildCategorySelectionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CertificateSectionTitle(title: '카테고리', subtitle: '자격증 제공 기관을 선택하세요.'),
        SizedBox(height: 15),
        QualificationTypeSelector(
          qualificationTypes: _topLevelCategories,
          selectedCode: _selectedTopLevelCategory ?? '',
          onSelected: _selectTopLevelCategory,
        ),
        SizedBox(height: 34),
        if (_selectedTopLevelCategory == null)
          SizedBox.shrink()
        else if (_isHumanResourcesDevelopmentService)
          _buildHumanResourcesDevelopmentServiceSection()
        else
          _buildOtherCertificateSection(),
      ],
    );
  }

  Widget _buildHumanResourcesDevelopmentServiceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CertificateSectionTitle(title: '자격 구분', subtitle: '자격 유형을 선택하세요.'),
        SizedBox(height: 15),
        QualificationTypeSelector(
          qualificationTypes: _qualificationTypes,
          selectedCode: _selectedQualificationCode,
          onSelected: _selectQualificationType,
        ),
        SizedBox(height: 34),
        if (_isTechnicalQualification)
          _buildTechnicalQualificationSection()
        else
          _buildProfessionalQualificationSection(),
      ],
    );
  }

  Widget _buildOtherCertificateSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CertificateSectionTitle(title: '자격 구분', subtitle: '자격 구분을 선택하세요.'),
        SizedBox(height: 15),
        if (_isOtherQualificationCollapsed &&
            _selectedOtherQualificationName != null)
          CollapsedSelectionCard(
            title: '선택한 자격 구분',
            value: _selectedOtherQualificationName!,
            onReselect: _expandOtherQualificationTypes,
          )
        else
          _buildOtherOptionGrid(
            options: _otherQualificationTypes,
            selectedName: _selectedOtherQualificationName,
            onSelected: _selectOtherQualificationType,
          ),
        if (_selectedOtherQualificationName != null) ...[
          SizedBox(height: 34),
          CertificateSectionTitle(title: '직무 분야', subtitle: '직무 분야를 선택하세요.'),
          SizedBox(height: 15),
          if (_isOtherJobFieldCollapsed && _selectedOtherJobFieldName != null)
            CollapsedSelectionCard(
              title: '선택한 직무 분야',
              value: _selectedOtherJobFieldName!,
              onReselect: _expandOtherJobFields,
            )
          else
            _buildOtherOptionGrid(
              options: _otherJobFields,
              selectedName: _selectedOtherJobFieldName,
              onSelected: _selectOtherJobField,
            ),
        ],
        if (_selectedOtherJobFieldName != null) ...[
          SizedBox(height: 34),
          CertificateSectionTitle(title: '분류', subtitle: '세부 분류를 선택하세요.'),
          SizedBox(height: 15),
          if (_isOtherCategoryCollapsed && _selectedOtherCategoryName != null)
            CollapsedSelectionCard(
              title: '선택한 분류',
              value: _selectedOtherCategoryName!,
              onReselect: _expandOtherCategories,
            )
          else
            _buildOtherCategorySelector(),
        ],
        if (_selectedOtherCategoryName != null) ...[
          SizedBox(height: 34),
          CertificateSectionTitle(
            title: '시행 종목',
            subtitle: '자격증을 누르면 상세 정보를 확인할 수 있어요.',
            count: _selectedOtherCertificates.length,
          ),
          SizedBox(height: 15),
          _buildCertificateList(certificates: _selectedOtherCertificates),
        ],
      ],
    );
  }

  Widget _buildOtherOptionGrid({
    required List<_FilterOption> options,
    required String? selectedName,
    required ValueChanged<String> onSelected,
  }) {
    if (options.isEmpty) return EmptyFilterResult(message: '등록된 분류가 없습니다.');
    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: options.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.25,
      ),
      itemBuilder: (context, index) {
        final option = options[index];
        return CertificateCategoryCard(
          label: option.name,
          selected: selectedName == option.code,
          icon: Icons.category_outlined,
          onTap: () => onSelected(option.code),
        );
      },
    );
  }

  Widget _buildOtherCategorySelector() {
    final categories = _otherCategories;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18),
      decoration: certificateCardDecoration(context: context),
      child: categories.isEmpty
          ? EmptyInlineResult(message: '등록된 분류가 없습니다.')
          : Wrap(
              spacing: 10,
              runSpacing: 10,
              children: categories.map((category) => CertificateSelectionChip(
                label: category.name,
                selected: _selectedOtherCategoryName == category.code,
                onTap: () => _selectOtherCategory(category.code),
              )).toList(),
            ),
    );
  }

  Widget _buildTechnicalQualificationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CertificateSectionTitle(
          title: '직무 분야',
          subtitle: '국가기술자격 직무 분야를 선택하세요.',
        ),
        SizedBox(height: 15),

        if (_isTechnicalJobFieldCollapsed && _selectedTechnicalJobField != null)
          CollapsedSelectionCard(
            title: '선택한 직무 분야',
            value: _selectedTechnicalJobField!.name,
            onReselect: _expandTechnicalJobFields,
          )
        else
          _buildTechnicalJobFieldGrid(),

        if (_selectedJobFieldCode != null) ...[
          SizedBox(height: 22),
          _buildSelectedTechnicalPath(),
          SizedBox(height: 34),
          CertificateSectionTitle(
            title: '분류',
            subtitle: '선택한 직무 분야의 세부 분류입니다.',
          ),
          SizedBox(height: 15),
          if (_isTechnicalCategoryCollapsed &&
              _selectedTechnicalCategory != null)
            CollapsedSelectionCard(
              title: '선택한 분류',
              value: _selectedTechnicalCategory!.name,
              onReselect: _expandTechnicalCategories,
            )
          else
            _buildTechnicalCategorySelector(),
        ],

        if (_selectedCategoryCode != null) ...[
          SizedBox(height: 34),
          CertificateSectionTitle(
            title: '시행 종목',
            subtitle: '자격증을 누르면 상세 정보를 확인할 수 있어요.',
            count: _selectedTechnicalCertificates.length,
          ),
          SizedBox(height: 15),
          _buildCertificateList(certificates: _selectedTechnicalCertificates),
        ],
      ],
    );
  }

  Widget _buildProfessionalQualificationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CertificateSectionTitle(
          title: '직무 분야',
          subtitle: '국가전문자격 직무 분야를 선택하세요.',
        ),
        SizedBox(height: 15),

        if (_isProfessionalSeriesCollapsed &&
            _selectedProfessionalSeries != null)
          CollapsedSelectionCard(
            title: '선택한 분야',
            value: _selectedProfessionalSeries!.name,
            onReselect: _expandProfessionalSeries,
          )
        else
          _buildProfessionalSeriesGrid(),

        if (_selectedProfessionalSeriesCode != null) ...[
          SizedBox(height: 22),
          _buildSelectedProfessionalPath(),
          SizedBox(height: 34),
          CertificateSectionTitle(
            title: '시행 종목',
            subtitle: '자격증을 누르면 상세 정보를 확인할 수 있어요.',
            count: _selectedProfessionalCertificates.length,
          ),
          SizedBox(height: 15),
          _buildCertificateList(
            certificates: _selectedProfessionalCertificates,
          ),
        ],
      ],
    );
  }

  Widget _buildTechnicalJobFieldGrid() {
    final jobFields = _technicalJobFields;

    if (jobFields.isEmpty) {
      return EmptyFilterResult(message: '등록된 직무 분야가 없습니다.');
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: jobFields.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.25,
      ),
      itemBuilder: (context, index) {
        final jobField = jobFields[index];

        return CertificateCategoryCard(
          label: jobField.name,
          selected: _selectedJobFieldCode == jobField.code,
          icon: Icons.work_outline_rounded,
          onTap: () {
            _selectTechnicalJobField(jobField.code);
          },
        );
      },
    );
  }

  Widget _buildProfessionalSeriesGrid() {
    final seriesList = _professionalSeries;

    if (seriesList.isEmpty) {
      return EmptyFilterResult(message: '등록된 전문자격 분야가 없습니다.');
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: seriesList.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.25,
      ),
      itemBuilder: (context, index) {
        final series = seriesList[index];

        return CertificateCategoryCard(
          label: series.name,
          selected: _selectedProfessionalSeriesCode == series.code,
          icon: Icons.category_outlined,
          onTap: () {
            _selectProfessionalSeries(series.code);
          },
        );
      },
    );
  }

  Widget _buildTechnicalCategorySelector() {
    final categories = _technicalCategories;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18),
      decoration: certificateCardDecoration(context: context),
      child: categories.isEmpty
          ? EmptyInlineResult(message: '등록된 분류가 없습니다.')
          : Wrap(
              spacing: 10,
              runSpacing: 10,
              children: categories.map((category) {
                return CertificateSelectionChip(
                  label: category.name,
                  selected: _selectedCategoryCode == category.code,
                  onTap: () {
                    _selectTechnicalCategory(category.code);
                  },
                );
              }).toList(),
            ),
    );
  }

  Widget _buildCertificateList({required List<Certification> certificates}) {
    if (certificates.isEmpty) {
      return EmptyFilterResult(message: '해당 분야의 자격증이 없습니다.');
    }

    return Container(
      decoration: certificateCardDecoration(context: context),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: List.generate(certificates.length, (index) {
          final certificate = certificates[index];
          final isLast = index == certificates.length - 1;

          return Column(
            children: [
              CertificateListTile(
                certificateName: certificate.name,
                detailText: certificate.listDetailText,
                qualificationCode: certificate.qualgbcd,
                isOther: certificate.hasSource,
                onTap: () {
                  _openCertificateDetail(
                    certificationId: certificate.id,
                    qualificationCode: certificate.qualgbcd,
                    hasSource: certificate.hasSource,
                  );
                },
              ),
              if (!isLast)
                Divider(
                  height: 1,
                  indent: 73,
                  endIndent: 18,
                  color: context.colors.border,
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildSelectedTechnicalPath() {
    final selectedJobFieldName = _selectedTechnicalJobField?.name ?? '';

    final selectedCategoryName = _selectedTechnicalCategory?.name ?? '';

    return SelectedPathCard(
      text: _selectedCategoryCode == null
          ? '국가기술자격  ›  $selectedJobFieldName'
          : '국가기술자격  ›  '
                '$selectedJobFieldName  ›  '
                '$selectedCategoryName',
    );
  }

  Widget _buildSelectedProfessionalPath() {
    final selectedSeriesName = _selectedProfessionalSeries?.name ?? '';

    return SelectedPathCard(text: '국가전문자격  ›  $selectedSeriesName');
  }

  Widget _buildSearchResultSection() {
    final results = _searchResults;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CertificateSectionTitle(
          title: '검색 결과',
          subtitle: '검색어와 일치하는 자격증입니다.',
          count: results.length,
        ),
        SizedBox(height: 15),
        if (results.isEmpty)
          EmptySearchResult()
        else
          Container(
            decoration: certificateCardDecoration(context: context),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: List.generate(results.length, (index) {
                final result = results[index];
                final isLast = index == results.length - 1;

                return Column(
                  children: [
                    CertificateSearchResultTile(
                      certificateName: result.certificateName,
                      qualificationType: result.qualificationType,
                      detailText: result.detailText,
                      qualificationCode: result.qualificationCode,
                      isOther: result.hasSource,
                      onTap: () {
                        _openCertificateDetail(
                          certificationId: result.certificationId,
                          qualificationCode: result.qualificationCode,
                          hasSource: result.hasSource,
                        );
                      },
                    ),
                    if (!isLast)
                      Divider(
                        height: 1,
                        indent: 73,
                        endIndent: 18,
                        color: context.colors.border,
                      ),
                  ],
                );
              }),
            ),
          ),
      ],
    );
  }
}

class _FilterOption {
  final String code;
  final String name;

  const _FilterOption({required this.code, required this.name});
}

class _SearchResultItem {
  final String certificationId;
  final String certificateName;
  final String qualificationType;
  final String qualificationCode;
  final bool hasSource;
  final String detailText;

  const _SearchResultItem({
    required this.certificationId,
    required this.certificateName,
    required this.qualificationType,
    required this.qualificationCode,
    required this.hasSource,
    required this.detailText,
  });
}
