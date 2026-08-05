import 'package:flutter/material.dart';

import '../../theme.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../appwidgets/goal_schedule_app_widget.dart';
import '../../widgets/app_main_background.dart';
import '../../widgets/app_state_views.dart';
import '../../widgets/app_top_bar.dart';
import '../services/certificate_detail_service.dart';
import '../services/certificate_category_content_service.dart';
import '../services/certificate_search_service.dart';
import '../services/professional_certificate_service.dart';
import '../services/technical_certificate_service.dart';
import '../widgets/certificate_common_widgets.dart';
import '../widgets/certificate_detail_widgets.dart';
import '../widgets/certificate_schedule_notice_content_card.dart';
import '../widgets/professional_certificate_widgets.dart';
import '../widgets/technical_certificate_widgets.dart';

class ProfessionalCertificateDetailPage extends StatefulWidget {
  final String certificationId;

  const ProfessionalCertificateDetailPage({
    super.key,
    required this.certificationId,
  });

  @override
  State<ProfessionalCertificateDetailPage> createState() =>
      _ProfessionalCertificateDetailPageState();
}

class _ProfessionalCertificateDetailPageState
    extends State<ProfessionalCertificateDetailPage>
    with SingleTickerProviderStateMixin {
  final CertificateDetailService _certificateDetailService =
      CertificateDetailService();
  final CertificateCategoryContentService _categoryContentService =
      CertificateCategoryContentService();

  final ProfessionalCertificateService _professionalCertificateService =
      ProfessionalCertificateService();

  final TechnicalCertificateService _technicalCertificateService =
      TechnicalCertificateService();

  late final TabController _tabController;

  bool _isLoading = true;
  bool _isRegisteringGoal = false;

  int _selectedTabIndex = 0;

  String? _loadError;
  Certification? _certificate;

  List<ProfessionalCertificateSchedule> _schedules = [];

  bool get _hasPracticalSchedule => _schedules.any(_isPracticalSchedule);

  bool _isPracticalSchedule(ProfessionalCertificateSchedule schedule) =>
      schedule.description.contains('실기') ||
      schedule.description.contains('면접');

  bool _isLoadingExamSubjects = false;
  bool _hasRequestedExamSubjects = false;
  String? _examSubjectError;
  List<TechnicalExamSubject> _examSubjects = [];

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 4, vsync: this);

    _tabController.addListener(_handleTabChanged);

    _loadCertificate();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChanged);

    _tabController.dispose();

    super.dispose();
  }

  void _handleTabChanged() {
    if (_tabController.indexIsChanging) {
      return;
    }

    if (_selectedTabIndex == _tabController.index) {
      return;
    }

    setState(() {
      _selectedTabIndex = _tabController.index;
    });
  }

  Future<void> _loadCertificate() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final certificateFuture = _professionalCertificateService
          .getProfessionalCertificateById(widget.certificationId);

      final schedulesFuture = _professionalCertificateService
          .getProfessionalSchedules(widget.certificationId);

      final results = await Future.wait([certificateFuture, schedulesFuture]);

      final certificate = results[0] as Certification;

      final schedules = results[1] as List<ProfessionalCertificateSchedule>;

      if (!mounted) {
        return;
      }

      setState(() {
        _certificate = certificate;
        _schedules = schedules;
        _isLoading = false;
      });
    } on CertificateDetailException catch (error) {
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

  Future<void> _loadExamSubjects() async {
    final certificate = _certificate;

    if (certificate == null || _isLoadingExamSubjects) {
      return;
    }

    setState(() {
      _isLoadingExamSubjects = true;
      _examSubjectError = null;
    });

    try {
      final subjects = await _technicalCertificateService.getExamSubjects(
        jmCd: certificate.jmcd,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _examSubjects = subjects;
        _hasRequestedExamSubjects = true;
        _isLoadingExamSubjects = false;
      });
    } on CertificateDetailException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _examSubjects = [];
        _hasRequestedExamSubjects = true;
        _isLoadingExamSubjects = false;
        _examSubjectError = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _examSubjects = [];
        _hasRequestedExamSubjects = true;
        _isLoadingExamSubjects = false;
        _examSubjectError = '시험 교시·과목 정보를 불러오지 못했습니다.';
      });
    }
  }

  List<ProfessionalCertificateSchedule> get _availableGoalSchedules {
    final today = _dateOnly(DateTime.now());

    final schedules = _schedules.where((schedule) {
      final filterDate = schedule.examEndAt ?? schedule.examStartAt;

      if (filterDate == null) {
        return false;
      }

      return !_dateOnly(filterDate).isBefore(today);
    }).toList();

    schedules.sort((first, second) {
      final firstStartDate = first.examStartAt ?? first.examEndAt;

      final secondStartDate = second.examStartAt ?? second.examEndAt;

      if (firstStartDate == null && secondStartDate == null) {
        return 0;
      }

      if (firstStartDate == null) {
        return 1;
      }

      if (secondStartDate == null) {
        return -1;
      }

      return firstStartDate.compareTo(secondStartDate);
    });

    return schedules;
  }

  static DateTime _dateOnly(DateTime date) {
    final localDate = date.toLocal();

    return DateTime(localDate.year, localDate.month, localDate.day);
  }

  Future<void> _openQnetExamInformation() async {
    final certificate = _certificate;

    if (certificate == null) {
      return;
    }

    final seriesCode = certificate.seriescd.trim();

    if (seriesCode.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Q-Net 자격 정보 연결값이 등록되지 않았습니다.')));

      return;
    }

    final uri = Uri.parse(
      'https://www.q-net.or.kr/crf005.do'
      '?id=crf00503'
      '&gSite=L'
      '&gId=$seriesCode',
    );

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Q-Net 자격 정보 페이지를 열지 못했습니다.')));
    }
  }

  Future<void> _openScheduleNoticeUrl(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openGoalSettingSheet() async {
    final certificate = _certificate;

    if (certificate == null || _isRegisteringGoal) {
      return;
    }

    final schedules = _availableGoalSchedules;

    if (schedules.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('목표로 등록할 수 있는 예정 시험이 없습니다.')));

      return;
    }

    Set<String> registeredGoalKeys;
    try {
      registeredGoalKeys =
          await _certificateDetailService.getActiveGoalScheduleKeys(
        certificateId: widget.certificationId,
      );
    } on CertificateGoalException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
      return;
    }
    if (!mounted) return;

    ProfessionalCertificateSchedule? selectedSchedule;

    final result = await showModalBottomSheet<ProfessionalCertificateSchedule>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setBottomSheetState) {
            return SafeArea(
              top: false,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.82,
                ),
                padding: EdgeInsets.fromLTRB(24, 14, 24, 24),
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
                      ),
                    ),
                    SizedBox(height: 7),
                    Text(
                      '목표로 준비할 시험 일정을 선택해주세요.',
                      style: TextStyle(
                        color: context.colors.textSecondary,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: 20),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: schedules.length,
                        separatorBuilder: (_, _) => SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final schedule = schedules[index];
                          final scheduleExamType = _isPracticalSchedule(schedule)
                              ? 'PRACTICAL'
                              : 'WRITTEN';
                          final isAlreadyRegistered = registeredGoalKeys.contains(
                            CertificateDetailService.goalScheduleKey(
                              scheduleId: schedule.id,
                              examType: scheduleExamType,
                            ),
                          );

                          final isSelected =
                              selectedSchedule?.id == schedule.id;

                          return InkWell(
                            onTap: isAlreadyRegistered ? null : () {
                              setBottomSheetState(() {
                                selectedSchedule = schedule;
                              });
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Opacity(
                              opacity: isAlreadyRegistered ? 0.48 : 1,
                              child: AnimatedContainer(
                                duration: Duration(milliseconds: 160),
                                padding: EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isAlreadyRegistered
                                      ? context.colors.surfaceMuted
                                      : isSelected
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
                                children: [
                                  Icon(
                                    isSelected
                                        ? Icons.radio_button_checked_rounded
                                        : Icons.radio_button_off_rounded,
                                    color: isSelected
                                        ? context.colors.pinkDeep
                                        : context.colors.textSecondary,
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isAlreadyRegistered
                                              ? '${schedule.description} (등록됨)'
                                              : schedule.description,
                                          style: TextStyle(
                                            color: isAlreadyRegistered
                                                ? context.colors.textDisabled
                                                : context.colors.textPrimary,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),

                                        SizedBox(height: 9),

                                        if (getCertificateRegistrationStatus(
                                              registrationStartDate: schedule
                                                  .examRegistrationStartAt,
                                              registrationEndDate: schedule
                                                  .examRegistrationEndAt,
                                            )
                                            case final registrationStatus?)
                                          CertificateScheduleStatusBadge(
                                            label: registrationStatus.label,
                                            isActive:
                                                registrationStatus.isActive,
                                          ),

                                        SizedBox(height: 9),

                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Icon(
                                              Icons.event_outlined,
                                              size: 16,
                                              color:
                                                  context.colors.textSecondary,
                                            ),
                                            SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                formatCertificateGoalDateRange(
                                                  schedule.examStartAt ??
                                                      schedule.examEndAt!,
                                                  schedule.examStartAt == null
                                                      ? null
                                                      : schedule.examEndAt,
                                                ),
                                                style: TextStyle(
                                                  color: context
                                                      .colors
                                                      .textSecondary,
                                                  fontSize: 13,
                                                  height: 1.4,
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
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pop(bottomSheetContext);
                            },
                            child: Text('취소'),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: selectedSchedule == null
                                ? null
                                : () {
                                    Navigator.pop(
                                      bottomSheetContext,
                                      selectedSchedule,
                                    );
                                  },
                            style: FilledButton.styleFrom(
                              backgroundColor: context.colors.pinkDeep,
                              padding: EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text('목표 등록'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result == null || !mounted) {
      return;
    }

    final examStartDate = result.examStartAt ?? result.examEndAt!;
    final examType = _isPracticalSchedule(result) ? 'PRACTICAL' : 'WRITTEN';
    final option = CertificateGoalOption(
      scheduleId: result.id,
      targetRound: result.description,
      examType: examType,
      examTypeName: examType == 'WRITTEN'
          ? (_hasPracticalSchedule ? '필기' : '통합')
          : '실기/면접',
      examDate: examStartDate,
      examStartDate: examStartDate,
      examEndDate: result.examStartAt == null ? null : result.examEndAt,
      registrationStartDate: result.examRegistrationStartAt,
      registrationEndDate: result.examRegistrationEndAt,
      passAnnouncementDate: result.passStartAt,
      passAnnouncementEndDate: result.passEndAt,
    );
    final optionWithExamDate = await selectCertificateGoalExamDate(
      context: context,
      option: option,
    );
    if (optionWithExamDate == null || !mounted) return;
    await _registerGoal(result, optionWithExamDate);
  }

  Future<void> _registerGoal(
    ProfessionalCertificateSchedule schedule,
    CertificateGoalOption option,
  ) async {
    final certificate = _certificate;
    final examDate = option.examDate;

    if (certificate == null || _isRegisteringGoal) {
      return;
    }

    final examType = _isPracticalSchedule(schedule) ? 'PRACTICAL' : 'WRITTEN';

    setState(() {
      _isRegisteringGoal = true;
    });

    try {
      final goalId = await _certificateDetailService.addCertificateGoal(
        certificateId: widget.certificationId,
        scheduleId: schedule.id,
        certificateName: certificate.name,
        qualificationType: 'PROFESSIONAL',
        targetExamDate: examDate,
        targetExamStartDate: option.examStartDate,
        targetExamEndDate: option.examEndDate ?? option.examStartDate,
        targetRound: schedule.description,
        targetExamType: examType,
        targetExamTypeName: option.examTypeName,

        targetRegistrationStartDate: schedule.examRegistrationStartAt,
        targetRegistrationEndDate: schedule.examRegistrationEndAt,

        targetPassAnnouncementDate: schedule.passStartAt,
        targetPassAnnouncementEndDate: schedule.passEndAt,
        includeExamTypeInDuplicateCheck: false,
      );

      await GoalScheduleAppWidget.sync();

      if (!mounted) {
        return;
      }

      final shouldLinkCalendar = await showCertificateCalendarLinkDialog(
        context: context,
        option: option,
      );

      if (!mounted) {
        return;
      }

      if (shouldLinkCalendar != true) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('목표 자격증으로 등록했습니다.')));
        return;
      }

      final added = await addCertificateGoalToDeviceCalendar(
        certificateName: certificate.name,
        option: option,
      );

      if (!mounted) {
        return;
      }

      if (!added) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('캘린더 일정 추가가 취소되었습니다.')));
        return;
      }

      await _certificateDetailService.updateGoalCalendarLinked(
        goalId: goalId,
        calendarLinked: true,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('시험 일정을 휴대폰 캘린더에 추가했습니다.')));
    } on CertificateGoalException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('목표 자격증을 등록하지 못했습니다.')));
    } finally {
      if (mounted) {
        setState(() {
          _isRegisteringGoal = false;
        });
      }
    }
  }

  Widget _buildGoalSettingButton() {
    return InkWell(
      onTap: _isRegisteringGoal ? null : _openGoalSettingSheet,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: context.colors.pinkDeep.withValues(alpha: 0.5),
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

  @override
  Widget build(BuildContext context) {
    final certificateName = _certificate?.name.trim() ?? '';

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppTopBar(
        title: certificateName.isEmpty ? '국가전문자격 상세' : '$certificateName 상세',
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
      return AppLoadingView(message: '전문자격 정보를 불러오는 중입니다.');
    }

    if (_loadError != null) {
      return CertificateLoadError(
        message: _loadError!,
        onRetry: _loadCertificate,
      );
    }

    final certificate = _certificate;

    if (certificate == null) {
      return CertificateLoadError(
        message: '자격증 정보를 찾을 수 없습니다.',
        onRetry: _loadCertificate,
      );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(24, 18, 24, 40),
      children: [
        ProfessionalCertificateOverview(
          certificate: certificate,
          action: _buildGoalSettingButton(),
        ),
        SizedBox(height: 28),
        _buildDetailTabBar(),
        SizedBox(height: 20),
        AnimatedSwitcher(
          duration: Duration(milliseconds: 200),
          child: KeyedSubtree(
            key: ValueKey<int>(_selectedTabIndex),
            child: _buildSelectedTabContent(),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailTabBar() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: context.colors.surfaceTransparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: false,
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
        tabs: [
          Tab(height: 44, text: '시험 일정'),
          Tab(height: 44, text: '자격 정보'),
          Tab(height: 44, text: '추가 정보'),
          Tab(height: 44, text: '통계'),
        ],
      ),
    );
  }

  Widget _buildSelectedTabContent() {
    switch (_selectedTabIndex) {
      case 0:
        return _buildScheduleTab();

      case 1:
        return _buildExamInformationTab();

      case 2:
        return _buildAdditionalInformationTab();

      case 3:
        return ProfessionalEmptyTab(
          icon: Icons.bar_chart_rounded,
          title: '등록된 통계가 없습니다.',
          description: '전문자격 통계 정보가 등록되면 이곳에 표시됩니다.',
        );

      default:
        return _buildScheduleTab();
    }
  }

  Widget _buildExamInformationTab() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(22),
      decoration: certificateCardDecoration(context: context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.description_outlined,
                color: context.colors.pinkDeep,
                size: 22,
              ),
              SizedBox(width: 9),
              Text(
                '자격 정보',
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          SizedBox(height: 17),
          Text(
            '자격 정보는 Q-Net에서 확인 바랍니다.',
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
          SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              onTap: _openQnetExamInformation,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                decoration: BoxDecoration(
                  color: context.colors.pinkSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Q-Net에서 자격 정보 확인하기',
                      style: TextStyle(
                        color: context.colors.pinkDeep,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 7),
                    Icon(
                      Icons.open_in_new_rounded,
                      color: context.colors.pinkDeep,
                      size: 17,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalInformationTab() {
    return TechnicalExamSubjectLookupCard(
      isLoading: _isLoadingExamSubjects,
      hasRequested: _hasRequestedExamSubjects,
      errorMessage: _examSubjectError,
      subjects: _examSubjects,
      onLookup: _loadExamSubjects,
    );
  }

  Widget _buildScheduleTab() {
    return StreamBuilder<CertificateCategoryScheduleNotice>(
      stream: _categoryContentService.watchScheduleNotice(
        CertificateCategory.professional,
        fallback: CertificateCategoryScheduleNotice(
          items: ['원서 접수 시간은 원서 접수 첫날 09:00부터 마지막 날 18:00까지입니다.'],
        ),
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildLegacyScheduleTab();
        }
        return Column(
          children: [
              CertificateScheduleNoticeContentCard(
                items: snapshot.data?.items ?? const [],
                links: snapshot.data?.links ?? const [],
                onOpenLink: _openScheduleNoticeUrl,
            ),
            const SizedBox(height: 14),
            if (_schedules.isEmpty)
              ProfessionalEmptyTab(
                icon: Icons.event_busy_outlined,
                title: '등록된 시험 일정이 없습니다.',
                description: '전문자격 시험 일정이 등록되면 이곳에서 확인할 수 있습니다.',
              )
            else
              ...List.generate(_schedules.length, (index) {
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == _schedules.length - 1 ? 0 : 14,
                  ),
                  child: ProfessionalScheduleCard(
                    schedule: _schedules[index],
                    showExamTypeLabels: _hasPracticalSchedule,
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  Widget _buildLegacyScheduleTab() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(20),
          decoration: certificateCardDecoration(context: context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: context.colors.pinkDeep,
                    size: 21,
                  ),
                  SizedBox(width: 9),
                  Text(
                    '\uC2DC\uD5D8 \uC77C\uC815 \uC548\uB0B4',
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 17),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: Icon(
                  Icons.circle,
                  size: 5,
                  color: context.colors.textSecondary,
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  '원서 접수 시간은 원서 접수 첫날 09:00부터 '
                  '마지막 날 18:00까지입니다.',
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.55,
                  ),
                ),
              ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 14),
        if (_schedules.isEmpty)
          ProfessionalEmptyTab(
            icon: Icons.event_busy_outlined,
            title: '등록된 시험 일정이 없습니다.',
            description: '전문자격 시험 일정이 등록되면 이곳에서 확인할 수 있습니다.',
          )
        else
          ...List.generate(_schedules.length, (index) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: index == _schedules.length - 1 ? 0 : 14,
              ),
              child: ProfessionalScheduleCard(
                schedule: _schedules[index],
                showExamTypeLabels: _hasPracticalSchedule,
              ),
            );
          }),
      ],
    );
  }
}
