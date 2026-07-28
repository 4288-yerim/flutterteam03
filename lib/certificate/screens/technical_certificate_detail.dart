import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../appwidgets/goal_schedule_app_widget.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_main_background.dart';
import '../../widgets/app_state_views.dart';
import '../../widgets/app_top_bar.dart';
import '../services/certificate_detail_service.dart';
import '../services/technical_certificate_service.dart';
import '../services/certificate_search_service.dart';
import '../widgets/certificate_common_widgets.dart';
import '../widgets/certificate_detail_widgets.dart';
import '../widgets/technical_certificate_widgets.dart';


class TechnicalCertificateDetailPage extends StatefulWidget {
  final String certificationId;

  const TechnicalCertificateDetailPage({
    super.key,
    required this.certificationId,
  });

  @override
  State<TechnicalCertificateDetailPage> createState() =>
      _TechnicalCertificateDetailPageState();
}

class _TechnicalCertificateDetailPageState
    extends State<TechnicalCertificateDetailPage>
    with SingleTickerProviderStateMixin {
  static final Uri _examStandardUri = Uri.parse(
    'https://www.q-net.or.kr/cst006.do'
        '?id=cst00601'
        '&code=1202'
        '&gSite=Q'
        '&gId=',
  );

  static final Uri _otherInformationUri = Uri.parse(
    'https://www.q-net.or.kr/crf005.do'
        '?id=crf00501'
        '&gSite=Q'
        '&gId=',
  );

  static final Uri _scheduleNoticeUri = Uri.parse(
    'https://www.q-net.or.kr/man004.do'
        '?id=man00401'
        '&notiType=10'
        '&gSite='
        '&gId=',
  );

  static final Uri _noScheduleUri = Uri.parse(
    'https://www.q-net.or.kr/crf021.do'
        '?id=crf02103'
        '&gSite='
        '&gId='
        '&CST_ID=CRF_Stns_06',
  );

  final CertificateDetailService _certificateDetailService =
  CertificateDetailService();

  final TechnicalCertificateService _technicalCertificateService =
  TechnicalCertificateService();

  late final TabController _tabController;

  int _selectedTabIndex = 0;

  bool _isLoading = true;

  String? _loadError;
  Certification? _certificate;

  List<TechnicalCertificateSchedule> _schedules = [];

  TechnicalCertificateExamDetails? _examDetails;

  bool _isLoadingExamSubjects = false;
  bool _hasRequestedExamSubjects = false;
  String? _examSubjectError;
  List<TechnicalExamSubject> _examSubjects = [];

  bool _isLoadingPracticalMaterials = false;
  bool _hasRequestedPracticalMaterials = false;
  String? _practicalMaterialError;
  List<TechnicalPracticalExamMaterial> _practicalMaterials = [];
  bool _hasStoredPracticalMaterials = false;
  int? _storedPracticalMaterialsYear;

  PracticalMaterialPrecautions
  _practicalMaterialPrecautions =
  const PracticalMaterialPrecautions.empty();
  bool _isRegisteringGoal = false;

  bool _hasRequestedStatistics = false;

  bool _isLoadingWrittenStatistics = false;
  String? _writtenStatisticsError;
  List<TechnicalExamStatistic> _writtenStatistics = [];

  bool _isLoadingPracticalStatistics = false;
  String? _practicalStatisticsError;
  List<TechnicalExamStatistic> _practicalStatistics = [];

  @override
  void initState() {
    super.initState();

    _tabController = TabController(
      length: 4,
      vsync: this,
    );

    _tabController.addListener(_handleTabChanged);

    _loadCertificate();
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

    if (_tabController.index == 3 && !_hasRequestedStatistics) {
      _hasRequestedStatistics = true;
      _loadAllStatistics();
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCertificate() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final certificateFuture =
      _certificateDetailService.getCertificationById(
        widget.certificationId,
      );

      final schedulesFuture =
      _technicalCertificateService.getTechnicalSchedules(
        widget.certificationId,
      );

      final examDetailsFuture =
      _technicalCertificateService.getTechnicalExamDetails(
        widget.certificationId,
      );

      final certificate = await certificateFuture;

      if (!certificate.isTechnical) {
        if (!mounted) {
          return;
        }

        setState(() {
          _isLoading = false;
          _loadError = '국가기술자격 정보가 아닙니다.';
        });

        return;
      }

      final storedPracticalMaterialsFuture =
      _technicalCertificateService.getStoredPracticalMaterials(
        jmCd: certificate.jmcd,
      );

      final schedules = await schedulesFuture;
      final examDetails = await examDetailsFuture;
      final storedPracticalMaterials = await storedPracticalMaterialsFuture;

      if (!mounted) {
        return;
      }

      setState(() {
        _certificate = certificate;
        _schedules = schedules;
        _examDetails = examDetails;
        _hasStoredPracticalMaterials = storedPracticalMaterials != null;
        _storedPracticalMaterialsYear =
            storedPracticalMaterials?.implementationYear;
        _practicalMaterials =
            storedPracticalMaterials?.items ?? [];

        _practicalMaterialPrecautions =
            storedPracticalMaterials?.precautions ??
                const PracticalMaterialPrecautions.empty();

        _hasRequestedPracticalMaterials =
            storedPracticalMaterials != null;
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

    if (certificate == null) {
      return;
    }

    setState(() {
      _isLoadingExamSubjects = true;
      _examSubjectError = null;
    });

    try {
      final subjects =
      await _technicalCertificateService.getExamSubjects(
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


  Future<void> _loadPracticalMaterials({
    required String implementationYear,
    required String implementationSequence,
  }) async {
    final certificate = _certificate;

    if (certificate == null || _isLoadingPracticalMaterials) {
      return;
    }

    setState(() {
      _isLoadingPracticalMaterials = true;
      _practicalMaterialError = null;
    });

    try {
      final materials =
      await _technicalCertificateService.getPracticalExamMaterials(
        jmCd: certificate.jmcd,
        implementationYear: implementationYear,
        implementationSequence: implementationSequence,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _practicalMaterials = materials;
        _hasRequestedPracticalMaterials = true;
        _isLoadingPracticalMaterials = false;
      });
    } on CertificateDetailException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _practicalMaterials = [];
        _hasRequestedPracticalMaterials = true;
        _isLoadingPracticalMaterials = false;
        _practicalMaterialError = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _practicalMaterials = [];
        _hasRequestedPracticalMaterials = true;
        _isLoadingPracticalMaterials = false;
        _practicalMaterialError =
        '실기시험 지참 준비물을 불러오지 못했습니다.';
      });
    }
  }

  void _loadAllStatistics() {
    _loadWrittenStatistics();
    _loadPracticalStatistics();
  }

  Future<void> _loadWrittenStatistics() async {
    final certificate = _certificate;
    if (certificate == null || _isLoadingWrittenStatistics) {
      return;
    }

    setState(() {
      _isLoadingWrittenStatistics = true;
      _writtenStatisticsError = null;
    });

    try {
      final statistics =
      await _technicalCertificateService.getWrittenStatistics(
        jmCd: certificate.jmcd,
      );

      if (!mounted) return;
      setState(() {
        _writtenStatistics = statistics;
        _isLoadingWrittenStatistics = false;
      });
    } on CertificateDetailException catch (error) {
      if (!mounted) return;
      setState(() {
        _writtenStatistics = [];
        _writtenStatisticsError = error.message;
        _isLoadingWrittenStatistics = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _writtenStatistics = [];
        _writtenStatisticsError = '필기시험 통계를 불러오지 못했습니다.';
        _isLoadingWrittenStatistics = false;
      });
    }
  }

  Future<void> _loadPracticalStatistics() async {
    final certificate = _certificate;
    if (certificate == null || _isLoadingPracticalStatistics) {
      return;
    }

    setState(() {
      _isLoadingPracticalStatistics = true;
      _practicalStatisticsError = null;
    });

    try {
      final statistics =
      await _technicalCertificateService.getPracticalStatistics(
        jmCd: certificate.jmcd,
      );

      if (!mounted) return;
      setState(() {
        _practicalStatistics = statistics;
        _isLoadingPracticalStatistics = false;
      });
    } on CertificateDetailException catch (error) {
      if (!mounted) return;
      setState(() {
        _practicalStatistics = [];
        _practicalStatisticsError = error.message;
        _isLoadingPracticalStatistics = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _practicalStatistics = [];
        _practicalStatisticsError = '실기시험 통계를 불러오지 못했습니다.';
        _isLoadingPracticalStatistics = false;
      });
    }
  }

  Future<void> _openGoalSettingSheet() async {
    final certificate = _certificate;

    if (certificate == null || _isRegisteringGoal) {
      return;
    }

    final options = _buildGoalExamOptions();

    if (options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '목표로 등록할 수 있는 예정 시험이 없습니다.',
          ),
        ),
      );

      return;
    }

    CertificateGoalOption? selectedOption;

    final result = await showModalBottomSheet<CertificateGoalOption>(
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
                  maxHeight:
                  MediaQuery.of(context).size.height * 0.82,
                ),
                padding: EdgeInsets.fromLTRB(
                  24,
                  14,
                  24,
                  24 + MediaQuery.of(context).viewInsets.bottom,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(26),
                  ),
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
                          color: certificateBorderColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      '목표 시험 선택',
                      style: TextStyle(
                        color: certificateDarkText,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 7),
                    const Text(
                      '목표로 준비할 회차와 시험 유형을 선택해주세요.',
                      style: TextStyle(
                        color: certificateGrayText,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: options.length,
                        separatorBuilder: (_, __) {
                          return const SizedBox(height: 10);
                        },
                        itemBuilder: (context, index) {
                          final option = options[index];
                          final isSelected =
                              selectedOption == option;

                          return InkWell(
                            onTap: () {
                              setBottomSheetState(() {
                                selectedOption = option;
                              });
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: AnimatedContainer(
                              duration:
                              const Duration(milliseconds: 160),
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? certificatePinkSoft
                                    : const Color(0xFFFAFAFC),
                                borderRadius:
                                BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected
                                      ? certificatePrimaryPink
                                      : certificateBorderColor,
                                  width: isSelected ? 1.4 : 1,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 22,
                                    height: 22,
                                    margin:
                                    const EdgeInsets.only(top: 1),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isSelected
                                          ? certificatePrimaryPink
                                          : Colors.white,
                                      border: Border.all(
                                        color: isSelected
                                            ? certificatePrimaryPink
                                            : certificateGrayText,
                                      ),
                                    ),
                                    child: isSelected
                                        ? const Icon(
                                      Icons.check_rounded,
                                      size: 15,
                                      color: Colors.white,
                                    )
                                        : null,
                                  ),
                                  const SizedBox(width: 13),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          option.targetRound,
                                          style: const TextStyle(
                                            color:
                                            certificateDarkText,
                                            fontSize: 15,
                                            fontWeight:
                                            FontWeight.w800,
                                            height: 1.35,
                                          ),
                                        ),
                                        const SizedBox(height: 7),
                                        Row(
                                          children: [
                                            Container(
                                              padding:
                                              const EdgeInsets
                                                  .symmetric(
                                                horizontal: 9,
                                                vertical: 5,
                                              ),
                                              decoration:
                                              BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                BorderRadius
                                                    .circular(20),
                                              ),
                                              child: Text(
                                                option.examTypeName,
                                                style:
                                                const TextStyle(
                                                  color:
                                                  certificatePrimaryPink,
                                                  fontSize: 12,
                                                  fontWeight:
                                                  FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 9),
                                            Expanded(
                                              child: Text(
                                                formatCertificateGoalDate(
                                                  option.examDate,
                                                ),
                                                style:
                                                const TextStyle(
                                                  color:
                                                  certificateBodyText,
                                                  fontSize: 13,
                                                  fontWeight:
                                                  FontWeight.w600,
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
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            text: '취소',
                            type: AppButtonType.gray,
                            height: 52,
                            onPressed: () {
                              Navigator.pop(bottomSheetContext);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppButton(
                            text: '목표 등록',
                            type: selectedOption == null
                                ? AppButtonType.gray
                                : AppButtonType.primaryPink,
                            height: 52,
                            onPressed: selectedOption == null
                                ? null
                                : () {
                              Navigator.pop(
                                bottomSheetContext,
                                selectedOption,
                              );
                            },
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

    await _registerGoal(result);
  }

  List<CertificateGoalOption> _buildGoalExamOptions() {
    final options = <CertificateGoalOption>[];
    final today = _dateOnly(DateTime.now());

    for (final schedule in _schedules) {
      final writtenExamDate = schedule.writtenExamStartAt;

      if (writtenExamDate != null &&
          !_dateOnly(writtenExamDate).isBefore(today)) {
        options.add(
          CertificateGoalOption(
            scheduleId: schedule.id,
            targetRound: schedule.title,
            examType: 'WRITTEN',
            examTypeName: '필기',
            examDate: writtenExamDate,
            passAnnouncementDate: schedule.writtenPassAt,
            passAnnouncementEndDate: null,
          ),
        );
      }

      final practicalExamDate = schedule.practicalExamStartAt;

      if (practicalExamDate != null &&
          !_dateOnly(practicalExamDate).isBefore(today)) {
        options.add(
          CertificateGoalOption(
            scheduleId: schedule.id,
            targetRound: schedule.title,
            examType: 'PRACTICAL',
            examTypeName: '실기',
            examDate: practicalExamDate,
            passAnnouncementDate:
            schedule.practicalPassStartAt,
            passAnnouncementEndDate:
            schedule.practicalPassEndAt,
          ),
        );
      }
    }

    options.sort(
          (a, b) => a.examDate.compareTo(b.examDate),
    );

    return options;
  }

  Future<void> _registerGoal(
      CertificateGoalOption option,
      ) async {
    final certificate = _certificate;

    if (certificate == null || _isRegisteringGoal) {
      return;
    }

    TechnicalCertificateSchedule? selectedSchedule;

    for (final schedule in _schedules) {
      if (schedule.id == option.scheduleId) {
        selectedSchedule = schedule;
        break;
      }
    }

    if (selectedSchedule == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '선택한 시험 일정 정보를 찾을 수 없습니다.',
          ),
        ),
      );
      return;
    }

    final DateTime? registrationStartDate;
    final DateTime? registrationEndDate;

    if (option.examType == 'WRITTEN') {
      registrationStartDate =
          selectedSchedule.writtenRegistrationStartAt;
      registrationEndDate =
          selectedSchedule.writtenRegistrationEndAt;
    } else {
      registrationStartDate =
          selectedSchedule.practicalRegistrationStartAt;
      registrationEndDate =
          selectedSchedule.practicalRegistrationEndAt;
    }

    setState(() {
      _isRegisteringGoal = true;
    });

    try {
      final goalId =
      await _certificateDetailService.addCertificateGoal(
        certificateId: widget.certificationId,
        scheduleId: option.scheduleId,
        certificateName: certificate.name,
        qualificationType: 'TECHNICAL',
        targetExamDate: option.examDate,
        targetRound: option.targetRound,
        targetExamType: option.examType,

        targetRegistrationStartDate:
        registrationStartDate,
        targetRegistrationEndDate:
        registrationEndDate,

        targetPassAnnouncementDate:
        option.passAnnouncementDate,
        targetPassAnnouncementEndDate:
        option.passAnnouncementEndDate,
        includeExamTypeInDuplicateCheck: true,
      );

      await GoalScheduleAppWidget.sync();

      if (!mounted) {
        return;
      }

      await _handleCalendarLink(
        goalId: goalId,
        certificateName: certificate.name,
        option: option,
      );
    } on CertificateGoalException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
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

  Future<void> _handleCalendarLink({
    required CertificateGoalOption option,
    required String goalId,
    required String certificateName,
  }) async {
    final shouldLinkCalendar = await showCertificateCalendarLinkDialog(
      context: context,
      option: option,
    );

    if (!mounted) {
      return;
    }

    if (shouldLinkCalendar != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${option.targetRound} ${option.examTypeName} 시험을 '
            '목표로 등록했습니다.',
          ),
        ),
      );
      return;
    }

    try {
      final added = await addCertificateGoalToDeviceCalendar(
        certificateName: certificateName,
        option: option,
      );

      if (!mounted) {
        return;
      }

      if (!added) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('캘린더 일정 추가가 취소되었습니다.'),
          ),
        );
        return;
      }

      await _certificateDetailService.updateGoalCalendarLinked(
        goalId: goalId,
        calendarLinked: true,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('시험 일정을 휴대폰 캘린더에 추가했습니다.'),
        ),
      );
    } on CertificateGoalException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('휴대폰 캘린더에 일정을 추가하지 못했습니다.'),
        ),
      );
    }
  }

  static DateTime _dateOnly(DateTime date) {
    final localDate = date.toLocal();

    return DateTime(
      localDate.year,
      localDate.month,
      localDate.day,
    );
  }

  Future<void> _openExamStandard() async {
    try {
      final opened = await launchUrl(
        _examStandardUri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened && mounted) {
        _showLinkError();
      }
    } catch (_) {
      if (mounted) {
        _showLinkError();
      }
    }
  }

  Future<void> _openOtherInformation() async {
    try {
      final opened = await launchUrl(
        _otherInformationUri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Q-Net 그외 사항 페이지를 열지 못했습니다.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Q-Net 그외 사항 페이지를 열지 못했습니다.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _openScheduleNotice() async {
    try {
      final opened = await launchUrl(
        _scheduleNoticeUri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened && mounted) {
        _showScheduleNoticeLinkError();
      }
    } catch (_) {
      if (mounted) {
        _showScheduleNoticeLinkError();
      }
    }
  }

  Future<void> _openNoSchedulePage() async {
    try {
      final opened = await launchUrl(
        _noScheduleUri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Q-Net 시험 일정 페이지를 열지 못했습니다.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Q-Net 시험 일정 페이지를 열지 못했습니다.',
            ),
          ),
        );
      }
    }
  }

  void _showScheduleNoticeLinkError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Q-Net 공지사항 페이지를 열지 못했습니다.',
        ),
      ),
    );
  }

  void _showLinkError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Q-Net 출제기준 페이지를 열지 못했습니다.',
        ),
      ),
    );
  }

  Widget _buildGoalSettingButton() {
    return InkWell(
      onTap: _isRegisteringGoal
          ? null
          : _openGoalSettingSheet,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: _isRegisteringGoal
              ? const Color(0xFFF3F4F7)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isRegisteringGoal
                ? certificateBorderColor
                : certificatePrimaryPink.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isRegisteringGoal)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: certificateGrayText,
                ),
              )
            else
              const Icon(
                Icons.flag_outlined,
                size: 18,
                color: certificatePrimaryPink,
              ),
            const SizedBox(width: 7),
            Text(
              _isRegisteringGoal
                  ? '등록 중...'
                  : '목표 자격증 설정',
              style: TextStyle(
                color: _isRegisteringGoal
                    ? certificateGrayText
                    : certificatePrimaryPink,
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
        title: certificateName.isEmpty
            ? '국가기술자격 상세'
            : '$certificateName 상세',
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
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
      return const AppLoadingView(
        message: '기술자격 정보를 불러오는 중입니다.',
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
        message: '자격증 정보를 찾을 수 없습니다.',
        onRetry: _loadCertificate,
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 40),
      children: [
        CertificateDetailHeader(
          name: certificate.name,
          qualificationName: certificate.qualificationName,
          isTechnical: true,
          action: _buildGoalSettingButton(),
        ),

        const SizedBox(height: 24),

        CertificateInfoCard(
          items: [
            CertificateInfoItem(
              label: '자격 구분',
              value: certificate.qualificationName,
            ),
            if (certificate.seriesnm.trim().isNotEmpty)
              CertificateInfoItem(
                label: '등급',
                value: certificate.seriesnm,
              ),
            if (certificate.obligfldnm.trim().isNotEmpty ||
                certificate.mdobligfldnm.trim().isNotEmpty)
              CertificateInfoItem(
                label: '분야',
                value: [
                  certificate.obligfldnm.trim(),
                  certificate.mdobligfldnm.trim(),
                ].where((value) => value.isNotEmpty).join(' > '),
              ),
          ],
        ),

        const SizedBox(height: 28),

        _buildDetailTabBar(),

        const SizedBox(height: 20),

        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
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
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: certificateBorderColor,
        ),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: false,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        labelPadding: EdgeInsets.zero,
        indicator: BoxDecoration(
          color: certificatePinkSoft,
          borderRadius: BorderRadius.circular(12),
        ),
        labelColor: certificatePrimaryPink,
        unselectedLabelColor: certificateGrayText,
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        tabs: const [
          Tab(
            height: 44,
            text: '시험 일정',
          ),
          Tab(
            height: 44,
            text: '자격 정보',
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
        return _buildStatisticsTab();

      default:
        return _buildScheduleTab();
    }
  }

  Widget _buildScheduleTab() {
    if (_schedules.isEmpty) {
      return _TechnicalDetailEmptyTab(
        icon: Icons.event_busy_outlined,
        title: '등록된 시험 일정이 없습니다.',
        description: '시험 일정이 등록되면 이곳에서 확인할 수 있습니다.',
        actionLabel: 'Q-Net 시험 일정 확인하기',
        onAction: _openNoSchedulePage,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...List.generate(
          _schedules.length,
              (index) {
            final schedule = _schedules[index];

            return Padding(
              padding: EdgeInsets.only(
                bottom:
                index == _schedules.length - 1 ? 0 : 14,
              ),
              child: TechnicalScheduleCard(
                title: schedule.title,
                writtenRegistrationStartAt:
                schedule.writtenRegistrationStartAt,
                writtenRegistrationEndAt:
                schedule.writtenRegistrationEndAt,
                writtenExamStartAt:
                schedule.writtenExamStartAt,
                writtenExamEndAt:
                schedule.writtenExamEndAt,
                writtenPassAt:
                schedule.writtenPassAt,
                documentSubmitStartAt:
                schedule.documentSubmitStartAt,
                documentSubmitEndAt:
                schedule.documentSubmitEndAt,
                practicalRegistrationStartAt:
                schedule.practicalRegistrationStartAt,
                practicalRegistrationEndAt:
                schedule.practicalRegistrationEndAt,
                practicalExamStartAt:
                schedule.practicalExamStartAt,
                practicalExamEndAt:
                schedule.practicalExamEndAt,
                practicalPassStartAt:
                schedule.practicalPassStartAt,
                practicalPassEndAt:
                schedule.practicalPassEndAt,
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        CertificateScheduleNoticeCard(
          onOpenNotice: _openScheduleNotice,
        ),
      ],
    );
  }

  Widget _buildExamInformationTab() {
    final examDetails = _examDetails;
    final examFee = examDetails?.examFee;

    return TechnicalExamInformationCard(
      writtenFee: examFee?.hasWrittenFee == true
          ? examFee!.writtenFee
          : null,
      practicalFee: examFee?.hasPracticalFee == true
          ? examFee!.practicalFee
          : null,
      examTrends: examDetails?.examTrends ?? '',
      howToObtain: examDetails?.howToObtain ?? '',
      onOpenExamStandard: _openExamStandard,
      onOpenOtherInformation: _openOtherInformation,
    );
  }

  Widget _buildAdditionalInformationTab() {
    return Column(
      children: [
        TechnicalExamSubjectLookupCard(
          isLoading: _isLoadingExamSubjects,
          hasRequested: _hasRequestedExamSubjects,
          errorMessage: _examSubjectError,
          subjects: _examSubjects,
          onLookup: _loadExamSubjects,
        ),
        const SizedBox(height: 14),
        TechnicalPracticalMaterialLookupCard(
          isLoading: _isLoadingPracticalMaterials,
          hasRequested: _hasRequestedPracticalMaterials,
          errorMessage: _practicalMaterialError,
          materials: _practicalMaterials,
          usesStoredData: _hasStoredPracticalMaterials,
          storedImplementationYear: _storedPracticalMaterialsYear,
          precautions: _practicalMaterialPrecautions,
          onLookup: _loadPracticalMaterials,
        ),
      ],
    );
  }

  Widget _buildStatisticsTab() {
    return TechnicalCertificateStatisticsSection(
      baseYear: TechnicalCertificateService.statisticsBaseYear,
      isLoadingWritten: _isLoadingWrittenStatistics,
      writtenError: _writtenStatisticsError,
      writtenStatistics: _writtenStatistics,
      onRetryWritten: _loadWrittenStatistics,
      isLoadingPractical: _isLoadingPracticalStatistics,
      practicalError: _practicalStatisticsError,
      practicalStatistics: _practicalStatistics,
      onRetryPractical: _loadPracticalStatistics,
    );
  }
}

class _TechnicalDetailEmptyTab extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _TechnicalDetailEmptyTab({
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final hasAction =
        actionLabel != null &&
            actionLabel!.trim().isNotEmpty &&
            onAction != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 42,
      ),
      decoration: certificateCardDecoration(),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: certificatePinkSoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              icon,
              color: certificatePrimaryPink,
              size: 29,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: certificateDarkText,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: certificateGrayText,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.55,
            ),
          ),
          if (hasAction) ...[
            const SizedBox(height: 20),
            InkWell(
              onTap: onAction,
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      actionLabel!,
                      style: const TextStyle(
                        color: certificatePrimaryPink,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 7),
                    const Icon(
                      Icons.open_in_new_rounded,
                      color: certificatePrimaryPink,
                      size: 17,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
