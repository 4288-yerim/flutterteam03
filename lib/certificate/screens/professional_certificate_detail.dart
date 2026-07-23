import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../widgets/app_main_background.dart';
import '../../widgets/app_top_bar.dart';
import '../services/certificate_detail_service.dart';
import '../services/certificate_search_service.dart';
import '../services/professional_certificate_service.dart';
import '../services/technical_certificate_service.dart';
import '../widgets/certificate_common_widgets.dart';
import '../widgets/professional_certificate_widgets.dart';
import '../widgets/technical_certificate_widgets.dart';

class ProfessionalCertificateDetailPage
    extends StatefulWidget {
  final String certificationId;

  const ProfessionalCertificateDetailPage({
    super.key,
    required this.certificationId,
  });

  @override
  State<ProfessionalCertificateDetailPage>
  createState() =>
      _ProfessionalCertificateDetailPageState();
}

class _ProfessionalCertificateDetailPageState
    extends State<ProfessionalCertificateDetailPage>
    with SingleTickerProviderStateMixin {
  final ProfessionalCertificateService
  _professionalCertificateService =
  ProfessionalCertificateService();

  final TechnicalCertificateService
  _technicalCertificateService =
  TechnicalCertificateService();

  late final TabController _tabController;

  bool _isLoading = true;
  bool _isRegisteringGoal = false;

  int _selectedTabIndex = 0;

  String? _loadError;
  Certification? _certificate;

  List<ProfessionalCertificateSchedule>
  _schedules = [];

  bool _isLoadingExamSubjects = false;
  bool _hasRequestedExamSubjects = false;
  String? _examSubjectError;
  List<TechnicalExamSubject> _examSubjects = [];

  @override
  void initState() {
    super.initState();

    _tabController = TabController(
      length: 4,
      vsync: this,
    );

    _tabController.addListener(
      _handleTabChanged,
    );

    _loadCertificate();
  }

  @override
  void dispose() {
    _tabController.removeListener(
      _handleTabChanged,
    );

    _tabController.dispose();

    super.dispose();
  }

  void _handleTabChanged() {
    if (_tabController.indexIsChanging) {
      return;
    }

    if (_selectedTabIndex ==
        _tabController.index) {
      return;
    }

    setState(() {
      _selectedTabIndex =
          _tabController.index;
    });
  }

  Future<void> _loadCertificate() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final certificateFuture =
      _professionalCertificateService
          .getProfessionalCertificateById(
        widget.certificationId,
      );

      final schedulesFuture =
      _professionalCertificateService
          .getProfessionalSchedules(
        widget.certificationId,
      );

      final results = await Future.wait([
        certificateFuture,
        schedulesFuture,
      ]);

      final certificate =
      results[0] as Certification;

      final schedules =
      results[1]
      as List<ProfessionalCertificateSchedule>;

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
        _loadError =
        '자격증 정보를 불러오지 못했습니다.';
      });
    }
  }

  Future<void> _loadExamSubjects() async {
    final certificate = _certificate;

    if (certificate == null ||
        _isLoadingExamSubjects) {
      return;
    }

    setState(() {
      _isLoadingExamSubjects = true;
      _examSubjectError = null;
    });

    try {
      final subjects =
      await _technicalCertificateService
          .getExamSubjects(
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
        _examSubjectError =
        '시험 교시·과목 정보를 불러오지 못했습니다.';
      });
    }
  }

  List<ProfessionalCertificateSchedule>
  get _availableGoalSchedules {
    return _schedules
        .where((schedule) {
      final examDate =
          schedule.examStartAt ??
              schedule.examEndAt;

      if (examDate == null) {
        return false;
      }

      final local = examDate.toLocal();
      final now = DateTime.now();

      final examDay = DateTime(
        local.year,
        local.month,
        local.day,
      );

      final today = DateTime(
        now.year,
        now.month,
        now.day,
      );

      return !examDay.isBefore(today);
    })
        .toList();
  }

  Future<void> _openQnetExamInformation() async {
    final certificate = _certificate;

    if (certificate == null) {
      return;
    }

    final seriesCode = certificate.seriescd.trim();

    if (seriesCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Q-Net 시험 정보 연결값이 등록되지 않았습니다.',
          ),
        ),
      );

      return;
    }

    final uri = Uri.parse(
      'https://www.q-net.or.kr/crf005.do'
          '?id=crf00503'
          '&gSite=L'
          '&gId=$seriesCode',
    );

    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Q-Net 시험 정보 페이지를 열지 못했습니다.',
          ),
        ),
      );
    }
  }

  Future<void> _openGoalSettingSheet() async {
    final certificate = _certificate;

    if (certificate == null ||
        _isRegisteringGoal) {
      return;
    }

    final schedules =
        _availableGoalSchedules;

    if (schedules.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            '목표로 등록할 수 있는 예정 시험이 없습니다.',
          ),
        ),
      );

      return;
    }

    ProfessionalCertificateSchedule?
    selectedSchedule;

    final result = await showModalBottomSheet<
        ProfessionalCertificateSchedule>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (
              context,
              setBottomSheetState,
              ) {
            return SafeArea(
              top: false,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight:
                  MediaQuery.of(context)
                      .size
                      .height *
                      0.82,
                ),
                padding:
                const EdgeInsets.fromLTRB(
                  24,
                  14,
                  24,
                  24,
                ),
                decoration:
                const BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                  BorderRadius.vertical(
                    top: Radius.circular(26),
                  ),
                ),
                child: Column(
                  mainAxisSize:
                  MainAxisSize.min,
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration:
                        BoxDecoration(
                          color:
                          certificateBorderColor,
                          borderRadius:
                          BorderRadius.circular(
                            20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      '목표 시험 선택',
                      style: TextStyle(
                        color:
                        certificateDarkText,
                        fontSize: 21,
                        fontWeight:
                        FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 7),
                    const Text(
                      '목표로 준비할 시험 일정을 선택해주세요.',
                      style: TextStyle(
                        color:
                        certificateGrayText,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Flexible(
                      child:
                      ListView.separated(
                        shrinkWrap: true,
                        itemCount:
                        schedules.length,
                        separatorBuilder:
                            (_, __) =>
                        const SizedBox(
                          height: 10,
                        ),
                        itemBuilder:
                            (context, index) {
                          final schedule =
                          schedules[index];

                          final isSelected =
                              selectedSchedule
                                  ?.id ==
                                  schedule.id;

                          return InkWell(
                            onTap: () {
                              setBottomSheetState(
                                    () {
                                  selectedSchedule =
                                      schedule;
                                },
                              );
                            },
                            borderRadius:
                            BorderRadius.circular(
                              16,
                            ),
                            child:
                            AnimatedContainer(
                              duration:
                              const Duration(
                                milliseconds: 160,
                              ),
                              padding:
                              const EdgeInsets.all(
                                16,
                              ),
                              decoration:
                              BoxDecoration(
                                color: isSelected
                                    ? certificatePinkSoft
                                    : const Color(
                                  0xFFFAFAFC,
                                ),
                                borderRadius:
                                BorderRadius.circular(
                                  16,
                                ),
                                border:
                                Border.all(
                                  color: isSelected
                                      ? certificatePrimaryPink
                                      : certificateBorderColor,
                                  width: isSelected
                                      ? 1.4
                                      : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isSelected
                                        ? Icons
                                        .radio_button_checked_rounded
                                        : Icons
                                        .radio_button_off_rounded,
                                    color: isSelected
                                        ? certificatePrimaryPink
                                        : certificateGrayText,
                                  ),
                                  const SizedBox(
                                    width: 12,
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment
                                          .start,
                                      children: [
                                        Text(
                                          schedule
                                              .description,
                                          style:
                                          const TextStyle(
                                            color:
                                            certificateDarkText,
                                            fontSize:
                                            15,
                                            fontWeight:
                                            FontWeight
                                                .w800,
                                          ),
                                        ),
                                        const SizedBox(
                                          height: 6,
                                        ),
                                        Text(
                                          _formatScheduleDate(
                                            schedule
                                                .examStartAt ??
                                                schedule
                                                    .examEndAt,
                                          ),
                                          style:
                                          const TextStyle(
                                            color:
                                            certificateGrayText,
                                            fontSize:
                                            13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pop(
                                bottomSheetContext,
                              );
                            },
                            child:
                            const Text('취소'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed:
                            selectedSchedule ==
                                null
                                ? null
                                : () {
                              Navigator.pop(
                                bottomSheetContext,
                                selectedSchedule,
                              );
                            },
                            style:
                            FilledButton.styleFrom(
                              backgroundColor:
                              certificatePrimaryPink,
                              padding:
                              const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                            ),
                            child: const Text(
                              '목표 등록',
                            ),
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

    if (result == null) {
      return;
    }

    await _registerGoal(result);
  }

  Future<void> _registerGoal(
      ProfessionalCertificateSchedule schedule,
      ) async {
    final certificate = _certificate;

    if (certificate == null) {
      return;
    }

    setState(() {
      _isRegisteringGoal = true;
    });

    try {
      await _professionalCertificateService
          .addProfessionalCertificateGoal(
        certificateId:
        widget.certificationId,
        scheduleId: schedule.id,
        certificateName:
        certificate.name,
        schedule: schedule,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            '목표 자격증으로 등록했습니다.',
          ),
        ),
      );
    } on ProfessionalCertificateGoalException
    catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(error.message),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            '목표 자격증을 등록하지 못했습니다.',
          ),
        ),
      );
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
      onTap: _isRegisteringGoal
          ? null
          : _openGoalSettingSheet,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding:
        const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
          BorderRadius.circular(12),
          border: Border.all(
            color: certificatePrimaryPink
                .withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isRegisteringGoal)
              const SizedBox(
                width: 16,
                height: 16,
                child:
                CircularProgressIndicator(
                  strokeWidth: 2,
                  color:
                  certificateGrayText,
                ),
              )
            else
              const Icon(
                Icons.flag_outlined,
                size: 18,
                color:
                certificatePrimaryPink,
              ),
            const SizedBox(width: 7),
            Text(
              _isRegisteringGoal
                  ? '등록 중...'
                  : '목표 자격증 설정',
              style: TextStyle(
                color:
                _isRegisteringGoal
                    ? certificateGrayText
                    : certificatePrimaryPink,
                fontSize: 13,
                fontWeight:
                FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final certificateName =
        _certificate?.name.trim() ?? '';

    return Scaffold(
      backgroundColor:
      Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppTopBar(
        title: certificateName.isEmpty
            ? '국가전문자격 상세'
            : '$certificateName 상세',
        centerTitle: true,
        leading: IconButton(
          onPressed: () =>
              Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: certificateDarkText,
            size: 21,
          ),
        ),
      ),
      body: AppMainBackground(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child:
        CircularProgressIndicator(
          color:
          certificatePrimaryPink,
        ),
      );
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
        message:
        '자격증 정보를 찾을 수 없습니다.',
        onRetry: _loadCertificate,
      );
    }

    return ListView(
      padding:
      const EdgeInsets.fromLTRB(
        24,
        18,
        24,
        40,
      ),
      children: [
        ProfessionalCertificateOverview(
          certificate: certificate,
          action:
          _buildGoalSettingButton(),
        ),
        const SizedBox(height: 28),
        _buildDetailTabBar(),
        const SizedBox(height: 20),
        AnimatedSwitcher(
          duration:
          const Duration(
            milliseconds: 200,
          ),
          child: KeyedSubtree(
            key: ValueKey<int>(
              _selectedTabIndex,
            ),
            child:
            _buildSelectedTabContent(),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailTabBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white
            .withValues(alpha: 0.72),
        borderRadius:
        BorderRadius.circular(16),
        border: Border.all(
          color:
          certificateBorderColor,
        ),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: false,
        dividerColor:
        Colors.transparent,
        indicatorSize:
        TabBarIndicatorSize.tab,
        labelPadding: EdgeInsets.zero,
        indicator: BoxDecoration(
          color: certificatePinkSoft,
          borderRadius:
          BorderRadius.circular(12),
        ),
        labelColor:
        certificatePrimaryPink,
        unselectedLabelColor:
        certificateGrayText,
        labelStyle:
        const TextStyle(
          fontSize: 13,
          fontWeight:
          FontWeight.w800,
        ),
        unselectedLabelStyle:
        const TextStyle(
          fontSize: 13,
          fontWeight:
          FontWeight.w600,
        ),
        tabs: const [
          Tab(
            height: 44,
            text: '시험 일정',
          ),
          Tab(
            height: 44,
            text: '시험 정보',
          ),
          Tab(
            height: 44,
            text: '추가 정보',
          ),
          Tab(
            height: 44,
            text: '통계',
          ),
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
        return const ProfessionalEmptyTab(
          icon: Icons.bar_chart_rounded,
          title: '등록된 통계가 없습니다.',
          description:
          '전문자격 통계 정보가 등록되면 이곳에 표시됩니다.',
        );

      default:
        return _buildScheduleTab();
    }
  }

  Widget _buildExamInformationTab() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: certificateCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.description_outlined,
                color: certificatePrimaryPink,
                size: 22,
              ),
              SizedBox(width: 9),
              Text(
                '시험 정보',
                style: TextStyle(
                  color: certificateDarkText,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          const Text(
            '시험 정보는 Q-Net에서 확인 바랍니다.',
            style: TextStyle(
              color: certificateDarkText,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              onTap: _openQnetExamInformation,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: certificatePinkSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Q-Net에서 시험 정보 확인하기',
                      style: TextStyle(
                        color: certificatePrimaryPink,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 7),
                    Icon(
                      Icons.open_in_new_rounded,
                      color: certificatePrimaryPink,
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
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: certificateCardDecoration(),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: certificatePrimaryPink,
                size: 21,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  '원서접수시간은 원서접수 첫날 09:00부터 '
                      '마지막 날 18:00까지입니다.',
                  style: TextStyle(
                    color: certificateDarkText,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.55,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (_schedules.isEmpty)
          const ProfessionalEmptyTab(
            icon: Icons.event_busy_outlined,
            title: '등록된 시험 일정이 없습니다.',
            description:
            '전문자격 시험 일정이 등록되면 이곳에서 확인할 수 있습니다.',
          )
        else
          ...List.generate(
            _schedules.length,
                (index) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == _schedules.length - 1
                      ? 0
                      : 14,
                ),
                child: ProfessionalScheduleCard(
                  schedule: _schedules[index],
                ),
              );
            },
          ),
      ],
    );
  }

  static String _formatScheduleDate(
      DateTime? date,
      ) {
    if (date == null) {
      return '시험일 미정';
    }

    final local = date.toLocal();

    return '${local.year}.'
        '${local.month.toString().padLeft(2, '0')}.'
        '${local.day.toString().padLeft(2, '0')}';
  }
}