import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme.dart';
import '../../appwidgets/goal_schedule_app_widget.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_main_background.dart';
import '../../widgets/app_state_views.dart';
import '../../widgets/app_top_bar.dart';
import '../services/certificate_detail_service.dart';
import '../services/certificate_category_content_service.dart';
import '../services/certificate_search_service.dart';
import '../services/other_certificate_detail_service.dart';
import '../services/technical_certificate_service.dart';
import '../widgets/certificate_common_widgets.dart';
import '../widgets/certificate_detail_widgets.dart';
import '../widgets/certificate_schedule_notice_content_card.dart';
import '../widgets/other_certificate_detail_widgets.dart';
import '../widgets/professional_certificate_widgets.dart';

class OtherCertificateDetailPage extends StatefulWidget {
  final String certificationId;
  final bool openGoalSettingOnLoad;

  const OtherCertificateDetailPage({
    super.key,
    required this.certificationId,
    this.openGoalSettingOnLoad = false,
  });

  @override
  State<OtherCertificateDetailPage> createState() =>
      _OtherCertificateDetailPageState();
}

class _OtherCertificateDetailPageState extends State<OtherCertificateDetailPage>
    with SingleTickerProviderStateMixin {
  final OtherCertificateDetailService _service =
      OtherCertificateDetailService();
  final CertificateDetailService _certificateDetailService =
      CertificateDetailService();
  final CertificateCategoryContentService _categoryContentService =
      CertificateCategoryContentService();
  late final TabController _tabController;

  Certification? _certificate;
  List<TechnicalCertificateSchedule> _schedules = [];
  OtherCertificateExamDetails? _examDetails;
  String _overview = '';
  OtherCertificateStatistics _statistics =
      const OtherCertificateStatistics.empty();
  bool _isLoading = true;
  String? _errorMessage;
  int _selectedTabIndex = 0;
  bool _isRegisteringGoal = false;
  bool _didOpenGoalSettingOnLoad = false;

  bool get _hasPracticalSchedule => _schedules.any(_scheduleHasPractical);

  bool get _hasCombinedExamSchedule => _schedules.any(
    (schedule) =>
        _scheduleHasWritten(schedule) && _scheduleHasPractical(schedule),
  );

  bool _scheduleHasWritten(TechnicalCertificateSchedule schedule) =>
      schedule.writtenRegistrationStartAt != null ||
      schedule.writtenRegistrationEndAt != null ||
      schedule.writtenExamStartAt != null ||
      schedule.writtenExamEndAt != null ||
      schedule.writtenPassAt != null;

  bool _scheduleHasPractical(TechnicalCertificateSchedule schedule) =>
      schedule.practicalRegistrationStartAt != null ||
      schedule.practicalRegistrationEndAt != null ||
      schedule.practicalExamStartAt != null ||
      schedule.practicalExamEndAt != null ||
      schedule.practicalPassStartAt != null ||
      schedule.practicalPassEndAt != null;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this)
      ..addListener(_handleTabChanged);
    _loadDetail();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChanged() {
    if (!_tabController.indexIsChanging &&
        _selectedTabIndex != _tabController.index) {
      setState(() => _selectedTabIndex = _tabController.index);
    }
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final certificate = await _service.getCertificate(widget.certificationId);
      final results = await Future.wait([
        _service.getSchedules(widget.certificationId),
        _service.getExamDetails(widget.certificationId),
        _service.getStatistics(widget.certificationId),
        _certificateDetailService.getCertificationOverview(
          widget.certificationId,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _certificate = certificate;
        _schedules = results[0] as List<TechnicalCertificateSchedule>;
        _examDetails = results[1] as OtherCertificateExamDetails;
        _statistics = results[2] as OtherCertificateStatistics;
        _overview = results[3] as String;
        _isLoading = false;
      });
      _openGoalSettingAfterLoad();
    } on CertificateDetailException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '자격증 정보를 불러오지 못했습니다.';
        _isLoading = false;
      });
    }
  }

  void _openGoalSettingAfterLoad() {
    if (!widget.openGoalSettingOnLoad || _didOpenGoalSettingOnLoad) {
      return;
    }
    _didOpenGoalSettingOnLoad = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _openGoalSettingSheet();
      }
    });
  }

  List<CertificateGoalOption> _buildGoalOptions() {
    final today = _dateOnly(DateTime.now());
    final options = <CertificateGoalOption>[];
    for (final schedule in _schedules) {
      _addGoalOption(
        options: options,
        today: today,
        schedule: schedule,
        examType: 'WRITTEN',
        examTypeName: _hasPracticalSchedule ? '필기' : '통합',
        examStartDate: schedule.writtenExamStartAt,
        examEndDate: schedule.writtenExamEndAt,
        registrationStartDate: schedule.writtenRegistrationStartAt,
        registrationEndDate: schedule.writtenRegistrationEndAt,
        passAnnouncementDate: schedule.writtenPassAt,
        passAnnouncementEndDate: null,
      );
      _addGoalOption(
        options: options,
        today: today,
        schedule: schedule,
        examType: 'PRACTICAL',
        examTypeName: '실기/면접',
        examStartDate: schedule.practicalExamStartAt,
        examEndDate: schedule.practicalExamEndAt,
        registrationStartDate: schedule.practicalRegistrationStartAt,
        registrationEndDate: schedule.practicalRegistrationEndAt,
        passAnnouncementDate: schedule.practicalPassStartAt,
        passAnnouncementEndDate: schedule.practicalPassEndAt,
      );
    }
    options.sort((first, second) => first.examDate.compareTo(second.examDate));
    return options;
  }

  void _addGoalOption({
    required List<CertificateGoalOption> options,
    required DateTime today,
    required TechnicalCertificateSchedule schedule,
    required String examType,
    required String examTypeName,
    required DateTime? examStartDate,
    required DateTime? examEndDate,
    required DateTime? registrationStartDate,
    required DateTime? registrationEndDate,
    required DateTime? passAnnouncementDate,
    required DateTime? passAnnouncementEndDate,
  }) {
    final displayStartDate = examStartDate ?? examEndDate;
    final filterDate = examEndDate ?? examStartDate;
    if (displayStartDate == null ||
        filterDate == null ||
        _dateOnly(filterDate).isBefore(today)) {
      return;
    }
    options.add(
      CertificateGoalOption(
        scheduleId: schedule.id,
        targetRound: schedule.title,
        examType: examType,
        examTypeName: examTypeName,
        examDate: displayStartDate,
        examStartDate: displayStartDate,
        examEndDate: examEndDate,
        registrationStartDate: registrationStartDate,
        registrationEndDate: registrationEndDate,
        passAnnouncementDate: passAnnouncementDate,
        passAnnouncementEndDate: passAnnouncementEndDate,
      ),
    );
  }

  Future<void> _openGoalSettingSheet() async {
    final certificate = _certificate;
    if (certificate == null || _isRegisteringGoal) return;
    final options = _buildGoalOptions();
    if (options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('목표로 등록할 수 있는 예정 시험이 없습니다.')),
      );
      return;
    }
    try {
      final registeredKeys = await _certificateDetailService
          .getActiveGoalScheduleKeys(certificateId: widget.certificationId);
      if (!mounted) return;
      final option = await showModalBottomSheet<CertificateGoalOption>(
        context: context,
        builder: (sheetContext) => _OtherGoalSelectionSheet(
          options: options,
          registeredGoalKeys: registeredKeys,
        ) /* SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
            children: [
              Text('목표 시험 선택', style: TextStyle(color: context.colors.textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              ...options.map((item) {
                final registered = registeredKeys.contains(
                  CertificateDetailService.goalScheduleKey(scheduleId: item.scheduleId, examType: item.examType),
                );
                return ListTile(
                  enabled: !registered,
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.targetRound),
                  subtitle: Text('${item.examTypeName} · ${formatCertificateGoalDateRange(item.examDate, item.examEndDate)}'),
                  trailing: registered ? const Text('등록됨') : const Icon(Icons.chevron_right_rounded),
                  onTap: registered ? null : () => Navigator.pop(sheetContext, item),
                );
              }),
            ],
          ),
        ), */,
      );
      if (option == null || !mounted) return;
      final selectedDate = await selectCertificateGoalExamDate(
        context: context,
        option: option,
      );
      if (selectedDate != null && mounted) await _registerGoal(selectedDate);
    } on CertificateGoalException catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _registerGoal(CertificateGoalOption option) async {
    final certificate = _certificate;
    if (certificate == null) return;
    setState(() => _isRegisteringGoal = true);
    try {
      final goalId = await _certificateDetailService.addCertificateGoal(
        certificateId: widget.certificationId,
        scheduleId: option.scheduleId,
        certificateName: certificate.name,
        qualificationType: certificate.isProfessional
            ? 'PROFESSIONAL'
            : 'TECHNICAL',
        targetExamDate: option.examDate,
        targetExamStartDate: option.examStartDate,
        targetExamEndDate: option.examEndDate ?? option.examStartDate,
        targetRound: option.targetRound,
        targetExamType: option.examType,
        targetExamTypeName: option.examTypeName,
        targetRegistrationStartDate: option.registrationStartDate,
        targetRegistrationEndDate: option.registrationEndDate,
        targetPassAnnouncementDate: option.passAnnouncementDate,
        targetPassAnnouncementEndDate: option.passAnnouncementEndDate,
        includeExamTypeInDuplicateCheck: true,
      );
      await GoalScheduleAppWidget.sync();
      if (!mounted) return;
      final linkCalendar = await showCertificateCalendarLinkDialog(
        context: context,
        option: option,
      );
      if (linkCalendar == true) {
        final added = await addCertificateGoalToDeviceCalendar(
          certificateName: certificate.name,
          option: option,
        );
        if (added)
          await _certificateDetailService.updateGoalCalendarLinked(
            goalId: goalId,
            calendarLinked: true,
          );
      }
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('목표 자격증을 등록했습니다.')));
    } on CertificateGoalException catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _isRegisteringGoal = false);
    }
  }

  static DateTime _dateOnly(DateTime value) {
    final date = value.toLocal();
    return DateTime(date.year, date.month, date.day);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppTopBar(
        title: _certificate == null ? '자격증 상세' : '${_certificate!.name} 상세',
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
    if (_isLoading) return AppLoadingView(message: '자격증 정보를 불러오는 중입니다.');
    if (_errorMessage != null)
      return CertificateLoadError(
        message: _errorMessage!,
        onRetry: _loadDetail,
      );
    final certificate = _certificate;
    if (certificate == null)
      return CertificateLoadError(
        message: '자격증 정보를 찾을 수 없습니다.',
        onRetry: _loadDetail,
      );

    return ListView(
      padding: EdgeInsets.fromLTRB(24, 18, 24, 40),
      children: [
        CertificateDetailHeader(
          name: certificate.name,
          qualificationName: '그 외',
          isTechnical: certificate.isTechnical,
          isOther: true,
          action: _buildGoalSettingButton(),
        ),
        SizedBox(height: 24),
        CertificateInfoCard(
          items: [
            CertificateInfoItem(label: '자격 구분', value: certificate.qualgbnm),
            CertificateInfoItem(label: '직무 분야', value: certificate.obligfldnm),
            CertificateInfoItem(label: '분류', value: certificate.mdobligfldnm),
          ],
        ),
        SizedBox(height: 28),
        _buildTabBar(),
        SizedBox(height: 20),
        AnimatedSwitcher(
          duration: Duration(milliseconds: 200),
          child: KeyedSubtree(
            key: ValueKey(_selectedTabIndex),
            child: _buildTab(),
          ),
        ),
      ],
    );
  }

  Widget _buildGoalSettingButton() {
    return InkWell(
      onTap: _isRegisteringGoal ? null : _openGoalSettingSheet,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        decoration: BoxDecoration(
          color: _isRegisteringGoal
              ? context.colors.surfaceMuted
              : context.colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isRegisteringGoal
                ? context.colors.border
                : context.colors.pinkDeep.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isRegisteringGoal)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.colors.textSecondary,
                ),
              )
            else
              Icon(
                Icons.flag_outlined,
                size: 18,
                color: context.colors.pinkDeep,
              ),
            SizedBox(width: 7),
            Text(
              _isRegisteringGoal ? '등록 중...' : '목표 자격증 설정',
              style: TextStyle(
                color: _isRegisteringGoal
                    ? context.colors.textSecondary
                    : context.colors.pinkDeep,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      padding: EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: context.colors.surfaceTransparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
      ),
      child: TabBar(
        controller: _tabController,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        labelPadding: EdgeInsets.zero,
        indicator: BoxDecoration(
          color: context.colors.pinkSoft,
          borderRadius: BorderRadius.circular(12),
        ),
        labelColor: context.colors.pinkDeep,
        unselectedLabelColor: context.colors.textSecondary,
        labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        unselectedLabelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        tabs: const [
          Tab(height: 44, text: '시험 일정'),
          Tab(height: 44, text: '자격 정보'),
          Tab(height: 44, text: '통계'),
        ],
      ),
    );
  }

  Widget _buildTab() {
    switch (_selectedTabIndex) {
      case 0:
        return _buildScheduleTab();
      case 1:
        final details = _examDetails;
        return CertificateExamInformationCard(
          overview: _overview,
          writtenFee: details?.writtenFee,
          practicalFee: details?.practicalFee,
          examTrends: details?.examTrends ?? '',
          howToObtain: details?.howToObtain ?? '',
          examFeeLinks: details?.examFeeLinks ?? const [],
          examTrendsLinks: details?.examTrendsLinks ?? const [],
          howToObtainLinks: details?.howToObtainLinks ?? const [],
          onOpenLink: _openScheduleNoticeUrl,
        );
      default:
        return _buildStatisticsTab();
    }
  }

  Widget _buildStatisticsTab() {
    if (!_statistics.hasDocuments) {
      return const OtherCertificateEmptyContent(message: '등록된 통계 정보가 없습니다.');
    }
    return CertificateStatisticsSection(
      baseYear: _statistics.baseYear,
      showWritten: _statistics.hasWrittenDocument,
      isLoadingWritten: false,
      writtenError: null,
      writtenStatistics: _statistics.writtenStatistics,
      onRetryWritten: _loadDetail,
      showPractical: _statistics.hasPracticalDocument,
      isLoadingPractical: false,
      practicalError: null,
      practicalStatistics: _statistics.practicalStatistics,
      onRetryPractical: _loadDetail,
      showIntegrated: _statistics.hasIntegratedDocument,
      isLoadingIntegrated: false,
      integratedError: null,
      integratedStatistics: _statistics.integratedStatistics,
      onRetryIntegrated: _loadDetail,
    );
  }

  Widget _buildScheduleTab() {
    return Column(
      children: [
        StreamBuilder<CertificateCategoryScheduleNotice>(
          stream: _categoryContentService.watchScheduleNotice(
            CertificateCategory.other,
            fallback: CertificateCategoryScheduleNotice(
              items: ['시험 일정은 종목별, 지역별로 상이할 수 있습니다.'],
            ),
          ),
          builder: (context, snapshot) => CertificateScheduleNoticeContentCard(
            items: snapshot.data?.items ?? const [],
            links: [
              ...(snapshot.data?.links ?? const []),
              ...(_examDetails?.scheduleLinks ?? const []),
            ],
            onOpenLink: _openScheduleNoticeUrl,
          ),
        ),
        const SizedBox(height: 16),
        if (_schedules.isEmpty)
          const ProfessionalEmptyTab(
            icon: Icons.event_busy_outlined,
            title: '등록된 시험 일정이 없습니다.',
            description: '시험 일정이 등록되면 이곳에서 확인할 수 있습니다.',
          )
        else
          ..._schedules.map(
            (schedule) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: CertificateScheduleCard(
                title: schedule.title,
                writtenRegistrationStartAt: schedule.writtenRegistrationStartAt,
                writtenRegistrationEndAt: schedule.writtenRegistrationEndAt,
                writtenExamStartAt: schedule.writtenExamStartAt,
                writtenExamEndAt: schedule.writtenExamEndAt,
                writtenPassAt: schedule.writtenPassAt,
                documentSubmitStartAt: schedule.documentSubmitStartAt,
                documentSubmitEndAt: schedule.documentSubmitEndAt,
                practicalRegistrationStartAt:
                    schedule.practicalRegistrationStartAt,
                practicalRegistrationEndAt: schedule.practicalRegistrationEndAt,
                practicalExamStartAt: schedule.practicalExamStartAt,
                practicalExamEndAt: schedule.practicalExamEndAt,
                practicalPassStartAt: schedule.practicalPassStartAt,
                practicalPassEndAt: schedule.practicalPassEndAt,
                showExamTypeLabels: _hasCombinedExamSchedule,
                links: schedule.links,
                onOpenLink: _openScheduleNoticeUrl,
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _openScheduleNoticeUrl(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _OtherGoalSelectionSheet extends StatefulWidget {
  final List<CertificateGoalOption> options;
  final Set<String> registeredGoalKeys;

  const _OtherGoalSelectionSheet({
    required this.options,
    required this.registeredGoalKeys,
  });

  @override
  State<_OtherGoalSelectionSheet> createState() =>
      _OtherGoalSelectionSheetState();
}

class _OtherGoalSelectionSheetState extends State<_OtherGoalSelectionSheet> {
  CertificateGoalOption? _selectedOption;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        padding: EdgeInsets.fromLTRB(
          24,
          14,
          24,
          24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: BoxDecoration(
          color: context.colors.surfaceElevated,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: context.colors.border,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            SizedBox(height: 22),
            Text(
              '목표 시험 선택',
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 21,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            SizedBox(height: 7),
            Text(
              '목표로 준비할 회차와 시험 유형을 선택해주세요.',
              style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
            SizedBox(height: 20),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: widget.options.length,
                separatorBuilder: (_, _) => SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final option = widget.options[index];
                  final isAlreadyRegistered = widget.registeredGoalKeys
                      .contains(
                        CertificateDetailService.goalScheduleKey(
                          scheduleId: option.scheduleId,
                          examType: option.examType,
                        ),
                      );
                  final isSelected = _selectedOption == option;
                  return InkWell(
                    onTap: isAlreadyRegistered
                        ? null
                        : () => setState(() => _selectedOption = option),
                    borderRadius: BorderRadius.circular(16),
                    child: Opacity(
                      opacity: isAlreadyRegistered ? 0.48 : 1,
                      child: AnimatedContainer(
                        duration: Duration(milliseconds: 160),
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? context.colors.pinkSoft
                              : context.colors.surfaceMuted,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isAlreadyRegistered
                                ? context.colors.textDisabled
                                : isSelected
                                ? context.colors.pinkDeep
                                : context.colors.border,
                            width: isSelected ? 1.4 : 1,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              margin: EdgeInsets.only(top: 1),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected
                                    ? context.colors.pinkDeep
                                    : context.colors.surface,
                                border: Border.all(
                                  color: isSelected
                                      ? context.colors.pinkDeep
                                      : context.colors.textSecondary,
                                ),
                              ),
                              child: isSelected
                                  ? Icon(
                                      Icons.check_rounded,
                                      size: 15,
                                      color: context.colors.onPrimary,
                                    )
                                  : null,
                            ),
                            SizedBox(width: 13),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isAlreadyRegistered
                                        ? '${option.targetRound} (등록됨)'
                                        : option.targetRound,
                                    style: TextStyle(
                                      color: isAlreadyRegistered
                                          ? context.colors.textDisabled
                                          : context.colors.textPrimary,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  SizedBox(height: 9),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _GoalTypeBadge(
                                        label: option.examTypeName,
                                      ),
                                      if (getCertificateGoalScheduleStatus(
                                            option,
                                          )
                                          case final status?)
                                        CertificateScheduleStatusBadge(
                                          label: status.label,
                                          isActive: status.isActive,
                                        ),
                                    ],
                                  ),
                                  SizedBox(height: 9),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.event_outlined,
                                        size: 16,
                                        color: context.colors.textSecondary,
                                      ),
                                      SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          formatCertificateGoalDateRange(
                                            option.examDate,
                                            option.examEndDate,
                                          ),
                                          style: TextStyle(
                                            color: context.colors.textSecondary,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    text: '취소',
                    type: AppButtonType.gray,
                    height: 52,
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    text: '목표 등록',
                    type: _selectedOption == null
                        ? AppButtonType.gray
                        : AppButtonType.primaryPink,
                    height: 52,
                    onPressed: _selectedOption == null
                        ? null
                        : () => Navigator.pop(context, _selectedOption),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalTypeBadge extends StatelessWidget {
  final String label;

  const _GoalTypeBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: context.colors.pinkDeep,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
