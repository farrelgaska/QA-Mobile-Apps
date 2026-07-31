import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/dummy/dummy_state.dart';
import '../../../core/utils/dummy_auth.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/models/qc_report_model.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/stat_card.dart';
import '../../../shared/widgets/material_summary_card.dart';
import '../../../shared/widgets/work_status_card.dart';

class DashboardScreen extends StatefulWidget {
  final DateTime? now;
  final bool refreshOnInit;

  const DashboardScreen({super.key, this.now, this.refreshOnInit = true});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _state = DummyState();
  String _selectedPeriod = 'Minggu Ini';
  String _selectedKpiTab = 'QC Material';

  final List<String> _periods = [
    'Hari Ini',
    'Minggu Ini',
    'Bulan Ini',
    'Custom',
  ];

  late DateTime _customStartDate;
  late DateTime _customEndDate;

  DateTime get _now => widget.now ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    final now = _now;
    _customStartDate = DateTime(now.year, now.month, 1);
    _customEndDate = DateTime(now.year, now.month, now.day);
    if (widget.refreshOnInit) {
      unawaited(_refreshReports());
    }
  }

  Future<void> _refreshReports() async {
    try {
      await _state.fetchReportsFromApi();
      if (mounted) setState(() {});
    } catch (_) {
      // Keep the locally cached reports usable when the dashboard is offline.
    }
  }

  Future<void> _selectCustomDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(
        start: _customStartDate,
        end: _customEndDate,
      ),
      firstDate: DateTime(2026, 1, 1),
      lastDate: DateTime(2027, 12, 31),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: AppColors.primary,
            colorScheme: const ColorScheme.light(primary: AppColors.primary),
            buttonTheme: const ButtonThemeData(
              textTheme: ButtonTextTheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _customStartDate = picked.start;
        _customEndDate = picked.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. TOP HEADER & FILTER WAKTU
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Dashboard Ringkas',
                    style: TextStyle(
                      color: AppColors.textMain,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border, width: 0.5),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        dropdownColor: Colors.white,
                        value: _selectedPeriod,
                        icon: const Icon(
                          Icons.keyboard_arrow_down,
                          color: AppColors.primary,
                          size: 16,
                        ),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedPeriod = newValue;
                            });
                          }
                        },
                        items: _periods.map<DropdownMenuItem<String>>((
                          String value,
                        ) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(
                              value,
                              style: const TextStyle(
                                color: Color(0xFF111827),
                                fontSize: 12,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Conditional Custom Date Range Picker UI
              if (_selectedPeriod == 'Custom') ...[
                GestureDetector(
                  onTap: () => _selectCustomDateRange(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.date_range_outlined,
                              color: AppColors.primary,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Rentang: ${_formatDate(_customStartDate)} - ${_formatDate(_customEndDate)}',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const Icon(
                          Icons.edit,
                          color: AppColors.primary,
                          size: 14,
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // 2. TOGGLE QC MATERIAL / QC PEKERJAAN
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.backgroundSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(child: _buildKpiTab('QC Material')),
                    const SizedBox(width: 4),
                    Expanded(child: _buildKpiTab('QC Pekerjaan')),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 3. SECTIONS RENDERED ACCORDING TO CURRENT TAB
              if (_selectedKpiTab == 'QC Material')
                _buildQcMaterialSections()
              else
                _buildQcPekerjaanSections(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQcMaterialSections() {
    final materialReports = filterDashboardReports(
      _state.reports
          .where(
            (r) =>
                r.type == QCType.material &&
                r.createdByNik == DummyAuth.current.nik,
          )
          .toList(),
      period: _selectedPeriod,
      now: _now,
      customStart: _customStartDate,
      customEnd: _customEndDate,
    );
    final totalMat = materialReports.length;
    final matApproved = materialReports
        .where((r) => r.status == QCReportStatus.APPROVED)
        .length;
    final matPending = materialReports
        .where((r) => r.status == QCReportStatus.SUBMITTED)
        .length;
    final matNeedsRepair = materialReports
        .where((r) => r.status == QCReportStatus.NEEDS_FOLLOW_UP)
        .length;
    final materialNeedsRepairReports = materialReports
        .where((r) => r.status == QCReportStatus.NEEDS_FOLLOW_UP)
        .toList();
    final materialPassRate = totalMat == 0
        ? 0.0
        : (matApproved / totalMat).clamp(0.0, 1.0).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // KPI Cards Grid
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.5,
          children: [
            StatCard(
              title: 'Total Material Dicek',
              value: '$totalMat',
              icon: Icons.inventory_2_outlined,
              color: AppColors.infoBg,
              textColor: AppColors.infoText,
            ),
            StatCard(
              title: 'Disetujui',
              value: '$matApproved',
              icon: Icons.check_circle_outline,
              color: AppColors.approvedBg,
              textColor: AppColors.approvedText,
            ),
            StatCard(
              title: 'Menunggu Review',
              value: '$matPending',
              icon: Icons.hourglass_empty,
              color: const Color(0xFFFFF4E5),
              textColor: const Color(0xFFF59E0B),
            ),
            StatCard(
              title: 'Perlu Perbaikan',
              value: '$matNeedsRepair',
              icon: Icons.warning_amber_outlined,
              color: AppColors.rejectedBg,
              textColor: AppColors.rejectedText,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Pass Rate Card
        AppCard(
          padding: const EdgeInsets.all(16),
          borderRadius: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Pass Rate Keseluruhan',
                    style: TextStyle(
                      color: AppColors.textMain,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '${(materialPassRate * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: SizedBox(
                  width: double.infinity,
                  height: 8,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.infoBg,
                          borderRadius: BorderRadius.all(Radius.circular(100)),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: materialPassRate,
                          child: const SizedBox(
                            height: 8,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: AppColors.approvedText,
                                borderRadius: BorderRadius.all(
                                  Radius.circular(100),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _buildLegendItem(AppColors.approvedText, 'Disetujui'),
                  _buildLegendItem(const Color(0xFFF59E0B), 'Menunggu Review'),
                  _buildLegendItem(AppColors.rejectedText, 'Perlu Perbaikan'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 1. Daftar Material QC Minggu Ini
        Text(
          'Daftar Material QC $_selectedPeriod',
          style: const TextStyle(
            color: AppColors.textMain,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 10),
        ...materialReports.map((report) {
          String statusText = 'Disetujui';
          if (report.status == QCReportStatus.NEEDS_FOLLOW_UP) {
            statusText = 'Perlu Tindak Lanjut';
          } else if (report.status == QCReportStatus.SUBMITTED) {
            statusText = 'Menunggu Review';
          } else if (report.status == QCReportStatus.DRAFT) {
            statusText = 'Draft';
          }
          return MaterialSummaryCard(
            materialName: report.title,
            status: statusText,
            sampleCount: '1 batch',
          );
        }),
        const SizedBox(height: 16),

        // 2. Laporan Perlu Perbaikan
        MaterialNeedsRepairCard(reports: materialNeedsRepairReports),

        // 3. Aktivitas Terbaru QC Material
        ActivityTimelineCard(
          title: 'Aktivitas Terbaru QC Material',
          activities: buildDashboardActivities(materialReports, now: _now),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildQcPekerjaanSections() {
    final pekerjaanReports = filterDashboardReports(
      _state.reports
          .where(
            (r) =>
                r.type == QCType.pekerjaan &&
                r.createdByNik == DummyAuth.current.nik,
          )
          .toList(),
      period: _selectedPeriod,
      now: _now,
      customStart: _customStartDate,
      customEnd: _customEndDate,
    );
    final totalPek = pekerjaanReports.length;
    final pekApproved = pekerjaanReports
        .where((r) => r.status == QCReportStatus.APPROVED)
        .length;
    final pekOnProgress = pekerjaanReports
        .where((r) => r.status == QCReportStatus.SUBMITTED)
        .length;
    final pekNeedsRepair = pekerjaanReports
        .where((r) => r.status == QCReportStatus.NEEDS_FOLLOW_UP)
        .length;
    final pekerjaanNeedsRepairReports = pekerjaanReports
        .where((r) => r.status == QCReportStatus.NEEDS_FOLLOW_UP)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Grid KPI Cards
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.5,
          children: [
            StatCard(
              title: 'Total Pekerjaan Dicek',
              value: '$totalPek',
              icon: Icons.engineering_outlined,
              color: AppColors.infoBg,
              textColor: AppColors.infoText,
            ),
            StatCard(
              title: 'Disetujui',
              value: '$pekApproved',
              icon: Icons.check_circle_outline,
              color: AppColors.approvedBg,
              textColor: AppColors.approvedText,
            ),
            StatCard(
              title: 'Menunggu Review',
              value: '$pekOnProgress',
              icon: Icons.hourglass_bottom_outlined,
              color: AppColors.waitingBg,
              textColor: AppColors.waitingText,
            ),
            StatCard(
              title: 'Perlu Perbaikan',
              value: '$pekNeedsRepair',
              icon: Icons.warning_amber_outlined,
              color: AppColors.rejectedBg,
              textColor: AppColors.rejectedText,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Tingkat Penyelesaian Card
        AppCard(
          padding: const EdgeInsets.all(16),
          borderRadius: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Tingkat Penyelesaian',
                    style: TextStyle(
                      color: AppColors.textMain,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '${(totalPek > 0 ? (pekApproved / totalPek * 100) : 0.0).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: AppColors.approvedText,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: LinearProgressIndicator(
                  value: totalPek > 0 ? (pekApproved / totalPek) : 0.0,
                  minHeight: 8,
                  backgroundColor: AppColors.infoBg,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.approvedText,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$pekApproved dari $totalPek pekerjaan selesai',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Text(
                    'Target 90%',
                    style: TextStyle(
                      color: AppColors.textSoft,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 1. Daftar Status Pekerjaan
        const Text(
          'Daftar Status Pekerjaan',
          style: TextStyle(
            color: AppColors.textMain,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 10),
        ...pekerjaanReports.map((report) {
          String statusText = 'Menunggu Review';
          if (report.status == QCReportStatus.APPROVED) {
            statusText = 'Disetujui';
          } else if (report.status == QCReportStatus.NEEDS_FOLLOW_UP) {
            statusText = 'Perlu Tindak Lanjut';
          } else if (report.status == QCReportStatus.DRAFT) {
            statusText = 'Draft';
          }
          return WorkStatusCard(
            workName: report.title,
            locationName: report.area,
            status: statusText,
          );
        }),
        const SizedBox(height: 16),

        // 2. Laporan Perlu Perbaikan
        PekerjaanNeedsRepairCard(reports: pekerjaanNeedsRepairReports),
        const SizedBox(height: 16),

        // 3. Aktivitas Terbaru QC Pekerjaan
        ActivityTimelineCard(
          title: 'Aktivitas Terbaru QC Pekerjaan',
          activities: buildDashboardActivities(pekerjaanReports, now: _now),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildKpiTab(String tabName) {
    final isSelected = _selectedKpiTab == tabName;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedKpiTab = tabName;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          tabName,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? AppColors.primary : AppColors.textMuted,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime value) {
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${twoDigits(value.day)}/${twoDigits(value.month)}/${value.year}';
  }
}

List<QCReportModel> filterDashboardReports(
  Iterable<QCReportModel> reports, {
  required String period,
  required DateTime now,
  required DateTime customStart,
  required DateTime customEnd,
}) {
  final today = DateTime(now.year, now.month, now.day);
  late final DateTime start;
  late final DateTime endExclusive;

  switch (period) {
    case 'Hari Ini':
      start = today;
      endExclusive = today.add(const Duration(days: 1));
      break;
    case 'Bulan Ini':
      start = DateTime(now.year, now.month, 1);
      endExclusive = DateTime(now.year, now.month + 1, 1);
      break;
    case 'Custom':
      final normalizedStart = DateTime(
        customStart.year,
        customStart.month,
        customStart.day,
      );
      final normalizedEnd = DateTime(
        customEnd.year,
        customEnd.month,
        customEnd.day,
      );
      start = normalizedStart.isBefore(normalizedEnd)
          ? normalizedStart
          : normalizedEnd;
      final inclusiveEnd = normalizedStart.isAfter(normalizedEnd)
          ? normalizedStart
          : normalizedEnd;
      endExclusive = inclusiveEnd.add(const Duration(days: 1));
      break;
    case 'Minggu Ini':
    default:
      start = today.subtract(Duration(days: today.weekday - DateTime.monday));
      endExclusive = today.add(const Duration(days: 1));
      break;
  }

  final filtered = reports.where((report) {
    final date = report.submittedAt.toLocal();
    return !date.isBefore(start) && date.isBefore(endExclusive);
  }).toList();
  filtered.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
  return filtered;
}

class DashboardActivity {
  final String reportId;
  final String title;
  final String time;

  const DashboardActivity({
    required this.reportId,
    required this.title,
    required this.time,
  });
}

List<DashboardActivity> buildDashboardActivities(
  Iterable<QCReportModel> reports, {
  required DateTime now,
  int limit = 5,
}) {
  final sorted = reports.toList()
    ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
  return sorted.take(limit).map((report) {
    return DashboardActivity(
      reportId: report.id,
      title: '${_dashboardStatusAction(report.status)} ${report.title}',
      time: _dashboardTimeLabel(report.submittedAt.toLocal(), now.toLocal()),
    );
  }).toList();
}

String _dashboardStatusAction(QCReportStatus status) {
  switch (status) {
    case QCReportStatus.DRAFT:
      return 'Draft disimpan:';
    case QCReportStatus.SUBMITTED:
      return 'Laporan dikirim:';
    case QCReportStatus.APPROVED:
      return 'Admin menyetujui:';
    case QCReportStatus.NEEDS_FOLLOW_UP:
      return 'Perlu perbaikan:';
  }
}

String _dashboardTimeLabel(DateTime value, DateTime now) {
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  final valueDay = DateTime(value.year, value.month, value.day);
  final today = DateTime(now.year, now.month, now.day);
  final time = '${twoDigits(value.hour)}:${twoDigits(value.minute)}';
  if (valueDay == today) return time;
  if (valueDay == today.subtract(const Duration(days: 1))) {
    return 'Kemarin, $time';
  }
  return '${twoDigits(value.day)}/${twoDigits(value.month)}/${value.year} $time';
}

class MaterialNeedsRepairCard extends StatelessWidget {
  final List<dynamic> reports; // List of QCReportModel

  const MaterialNeedsRepairCard({super.key, required this.reports});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEC), // soft red
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFEF4444).withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.warning_amber_outlined,
                      color: Color(0xFFEF4444),
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Laporan Perlu Perbaikan',
                      style: TextStyle(
                        color: Color(0xFFEF4444),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    '${reports.length} Laporan',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFFFCA5A5), height: 1),
          // Items List
          if (reports.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Tidak ada laporan perlu tindak lanjut',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: reports.length,
              separatorBuilder: (context, index) => const Divider(
                color: Color(0xFFFCA5A5),
                height: 1,
                indent: 16,
                endIndent: 16,
              ),
              itemBuilder: (context, index) {
                final report = reports[index];
                final doNumber =
                    report.generalInfo?['doNumber'] ?? 'Batch #TG-0041';
                final reason =
                    report.adminNote ?? 'Parameter tidak sesuai standar';
                final timeStr =
                    "${report.date.hour.toString().padLeft(2, '0')}:${report.date.minute.toString().padLeft(2, '0')}";

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      context.push('/reports/${report.id}');
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  report.id,
                                  style: const TextStyle(
                                    color: Color(0xFFEF4444),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        report.title,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Color(0xFF991B1B), // dark red
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '— $doNumber',
                                      style: const TextStyle(
                                        color: Color(0xFFDC2626),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '$reason · $timeStr',
                                  style: const TextStyle(
                                    color: Color(0xFF7F1D1D),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.chevron_right,
                            color: Color(0xFFEF4444),
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class PekerjaanNeedsRepairCard extends StatelessWidget {
  final List<dynamic> reports; // List of QCReportModel

  const PekerjaanNeedsRepairCard({super.key, required this.reports});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEC), // soft red
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFEF4444).withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.warning_amber_outlined,
                      color: Color(0xFFEF4444),
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Laporan Perlu Perbaikan',
                      style: TextStyle(
                        color: Color(0xFFEF4444),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    '${reports.length} Laporan',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFFFCA5A5), height: 1),
          // Items List
          if (reports.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Tidak ada laporan perlu tindak lanjut',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: reports.length,
              separatorBuilder: (context, index) => const Divider(
                color: Color(0xFFFCA5A5),
                height: 1,
                indent: 16,
                endIndent: 16,
              ),
              itemBuilder: (context, index) {
                final report = reports[index];
                final segment =
                    report.generalInfo?['workSegment'] ?? 'Provisioning';
                final reason =
                    report.adminNote ?? 'Pekerjaan tidak sesuai standar';
                final timeStr =
                    "${report.date.hour.toString().padLeft(2, '0')}:${report.date.minute.toString().padLeft(2, '0')}";

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      context.push('/reports/${report.id}');
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  report.id,
                                  style: const TextStyle(
                                    color: Color(0xFFEF4444),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        report.title,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Color(0xFF991B1B), // dark red
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '— $segment',
                                      style: const TextStyle(
                                        color: Color(0xFFDC2626),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '$reason · $timeStr',
                                  style: const TextStyle(
                                    color: Color(0xFF7F1D1D),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.chevron_right,
                            color: Color(0xFFEF4444),
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class ActivityTimelineCard extends StatelessWidget {
  final String title;
  final List<DashboardActivity> activities;

  const ActivityTimelineCard({
    super.key,
    required this.title,
    required this.activities,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.history_outlined,
                color: AppColors.primary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textMain,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (activities.isEmpty)
            const Text(
              'Belum ada aktivitas pada periode ini.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: activities.length,
              separatorBuilder: (context, index) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final activity = activities[index];
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: Key('dashboard_activity_${activity.reportId}'),
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => context.push('/reports/${activity.reportId}'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 3),
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              activity.title,
                              style: const TextStyle(
                                color: AppColors.textMain,
                                fontSize: 12,
                                height: 1.3,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            activity.time,
                            style: const TextStyle(
                              color: AppColors.textSoft,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.chevron_right,
                            color: AppColors.textSoft,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class MaterialRepairDetailSheet extends StatelessWidget {
  final Map<String, dynamic> item;

  const MaterialRepairDetailSheet({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Material(
          color: Colors.transparent,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top drag indicator
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.borderSoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Title row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Detail Perlu Perbaikan',
                      style: TextStyle(
                        color: AppColors.textMain,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDE2E2),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: const Color(0xFFDC2626).withValues(alpha: 0.2),
                        ),
                      ),
                      child: const Text(
                        'Perlu Perbaikan',
                        style: TextStyle(
                          color: Color(0xFFDC2626),
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: AppColors.borderSoft, height: 1),
                const SizedBox(height: 16),

                // Content
                _buildInfoRow('Nama Material', item['name']),
                const SizedBox(height: 12),
                _buildInfoRow('Batch / Kode', item['batch']),
                const SizedBox(height: 12),
                _buildInfoRow('Waktu Deteksi', 'Hari ini, ${item['time']} WIB'),
                const SizedBox(height: 12),
                _buildInfoRow(
                  'Alasan Perbaikan',
                  item['reason'],
                  isWarning: true,
                ),
                const SizedBox(height: 12),
                _buildInfoRow(
                  'Catatan Staff Warehouse',
                  item['qaNote'] ??
                      'Segera lakukan tindak lanjut pengerjaan/coating ulang.',
                ),
                const SizedBox(height: 24),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          side: const BorderSide(color: AppColors.border),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'Kembali',
                          style: TextStyle(
                            color: AppColors.textSoft,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          context.go('/reports');
                        },
                        child: const Text(
                          'Lihat Laporan QC',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isWarning = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: isWarning ? const Color(0xFFDC2626) : AppColors.textMain,
            fontSize: 13,
            fontWeight: isWarning ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
