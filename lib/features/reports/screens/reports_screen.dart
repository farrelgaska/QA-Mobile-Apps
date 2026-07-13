import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/dummy/dummy_state.dart';
import '../../../core/utils/dummy_auth.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/widgets/filter_tabs.dart';
import '../../../shared/widgets/report_card.dart';
import '../../../shared/widgets/search_bar_field.dart';

class ReportsScreen extends StatefulWidget {
  final String? initialStatus;

  const ReportsScreen({
    Key? key,
    this.initialStatus,
  }) : super(key: key);

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _state = DummyState();
  String _selectedTab = 'Semua';
  String _searchQuery = '';

  final List<String> _tabs = [
    'Semua',
    'Draft',
    'Menunggu Review',
    'Disetujui',
    'Perlu Tindak Lanjut'
  ];

  String _mapInputStatus(String input) {
    final norm = input.toLowerCase().trim();
    if (norm == 'draft') return 'Draft';
    if (norm == 'disetujui' || norm == 'approved' || norm == 'selesai' || norm == 'lulus') return 'Disetujui';
    if (norm == 'perlu perbaikan' || norm == 'needfollowup' || norm == 'tidak sesuai' || norm == 'revisi' || norm == 'perlu tindak lanjut') return 'Perlu Tindak Lanjut';
    return 'Menunggu Review';
  }

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialStatus != null) {
      final mappedInit = _mapInputStatus(widget.initialStatus!);
      if (_tabs.contains(mappedInit)) {
        _selectedTab = mappedInit;
      }
    }
    _fetchData();
  }

  Future<void> _fetchData() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });
    await _state.fetchReportsFromApi();
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void didUpdateWidget(covariant ReportsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialStatus != null && widget.initialStatus != oldWidget.initialStatus) {
      final mappedInit = _mapInputStatus(widget.initialStatus!);
      if (_tabs.contains(mappedInit)) {
        setState(() {
          _selectedTab = mappedInit;
        });
      }
    }
  }

  QCReportStatus? _mapTabToReportStatus(String tab) {
    switch (tab) {
      case 'Draft':
        return QCReportStatus.DRAFT;
      case 'Menunggu Review':
        return QCReportStatus.SUBMITTED;
      case 'Disetujui':
        return QCReportStatus.APPROVED;
      case 'Perlu Tindak Lanjut':
        return QCReportStatus.NEEDS_FOLLOW_UP;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredReports = _state.reports.where((report) {
      // Filter: QA Staff hanya boleh melihat laporan yang dibuat oleh dirinya sendiri
      if (report.createdByNik != DummyAuth.current.nik) return false;

      final matchesSearch = report.id.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          report.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          report.detailLocation.toLowerCase().contains(_searchQuery.toLowerCase());

      if (!matchesSearch) return false;

      final tabStatus = _mapTabToReportStatus(_selectedTab);
      if (tabStatus != null) {
        if (tabStatus == QCReportStatus.NEEDS_FOLLOW_UP) {
          return report.status == QCReportStatus.NEEDS_FOLLOW_UP;
        }
        return report.status == tabStatus;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Riwayat Laporan',
                style: TextStyle(
                  color: AppColors.textMain,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 16),
              SearchBarField(
                placeholder: 'Cari berdasarkan ID, nama, lokasi...',
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
              ),
              const SizedBox(height: 16),
              FilterTabs(
                items: _tabs,
                selectedItem: _selectedTab,
                onSelected: (tab) {
                  setState(() {
                    _selectedTab = tab;
                  });
                },
              ),
              const SizedBox(height: 16),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _fetchData,
                  color: AppColors.primary,
                  child: filteredReports.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.assignment_outlined, color: AppColors.textSoft, size: 48),
                                  const SizedBox(height: 12),
                                  Text(
                                    _selectedTab == 'Semua'
                                        ? 'Belum ada laporan'
                                        : 'Laporan dengan status "$_selectedTab" kosong',
                                    style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          itemCount: filteredReports.length,
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemBuilder: (context, index) {
                            final report = filteredReports[index];
                            return ReportCard(
                              reportId: report.id,
                              title: report.title,
                              date: report.date,
                              location: report.detailLocation.isNotEmpty ? report.detailLocation : report.siteName,
                              status: report.status,
                              type: report.type,
                              onTap: () async {
                                await context.push('/reports/${report.id}');
                                _fetchData();
                              },
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
