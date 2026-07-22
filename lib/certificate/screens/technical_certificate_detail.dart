import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../widgets/app_main_background.dart';
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

      final schedules = await schedulesFuture;
      final examDetails = await examDetailsFuture;

      if (!mounted) {
        return;
      }

      setState(() {
        _certificate = certificate;
        _schedules = schedules;
        _examDetails = examDetails;
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
      return const Center(
        child: CircularProgressIndicator(
          color: certificatePrimaryPink,
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
  return TechnicalExamSubjectLookupCard(
    isLoading: _isLoadingExamSubjects,
    hasRequested: _hasRequestedExamSubjects,
    errorMessage: _examSubjectError,
    subjects: _examSubjects,
    onLookup: _loadExamSubjects,
  );
}

  Widget _buildStatisticsTab() {
    return const _TechnicalDetailEmptyTab(
      icon: Icons.bar_chart_rounded,
      title: '자격증 통계',
      description:
      '연도별 응시자 수, 합격자 수, 합격률 통계가 추가될 예정입니다.',
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