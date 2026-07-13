import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/dummy/dummy_state.dart';
import '../../../core/dummy/dummy_sites.dart';
import '../../../core/utils/dummy_auth.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/stat_card.dart';
import '../../../shared/widgets/qc_module_card.dart';
import '../../../shared/widgets/report_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _state = DummyState();
  late String _selectedLocation;

  @override
  void initState() {
    super.initState();
    _selectedLocation = _state.currentSite.name;
  }

  void _showSitePicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return SafeArea(
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.78,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(24, 24, 24, 12),
                        child: Text(
                          'Pilih Site Penugasan',
                          style: TextStyle(
                            color: AppColors.textMain,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      Flexible(
                        child: ListView.separated(
                          padding: EdgeInsets.fromLTRB(24, 0, 24, MediaQuery.of(context).viewInsets.bottom + 32),
                          itemCount: dummySites.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final site = dummySites[index];
                            final isSelected = site.name == _selectedLocation;
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                Icons.location_on,
                                color: isSelected ? AppColors.primary : AppColors.textSoft,
                              ),
                              title: Text(
                                site.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.textMain,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: site.area != null
                                  ? Text(
                                      site.area!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12),
                                    )
                                  : null,
                              trailing: isSelected
                                  ? const Icon(Icons.check_circle, color: AppColors.primary)
                                  : null,
                              onTap: () {
                                setModalState(() {
                                  _selectedLocation = site.name;
                                });
                                setState(() {
                                  _selectedLocation = site.name;
                                  _state.currentSite = site;
                                });
                                Navigator.pop(context);
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Recalculate stats dynamically from DummyState based on current user NIK
    final userReports = _state.reports.where((r) => r.createdByNik == DummyAuth.current.nik).toList();
    final totalQc = userReports.length;
    final waitingQc = userReports.where((r) => r.status == QCReportStatus.SUBMITTED).length;
    final revisionQc = userReports.where((r) => r.status == QCReportStatus.NEEDS_FOLLOW_UP).length;
    final approvedQc = userReports.where((r) => r.status == QCReportStatus.APPROVED).length;

    // Filter recent reports based on currently selected site and current user
    final recentReports = userReports
        .where((r) => r.siteId == _state.currentSite.id)
        .take(3)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          color: AppColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Lokasi Aktif Card
                AppCard(
                  onTap: _showSitePicker,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, color: AppColors.primary, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Lokasi Aktif',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _selectedLocation,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textMain,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: AppColors.primary, size: 18),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Greeting section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Selamat Pagi,',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          _state.currentUser.name,
                          style: const TextStyle(
                            color: AppColors.textMain,
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                          ),
                        ),
                      ],
                    ),
                    const CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.primarySoft,
                      child: Icon(Icons.person, color: AppColors.primary, size: 24),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Summary Stats Section Grid
                const Text(
                  'Ringkasan Laporan',
                  style: TextStyle(
                    color: AppColors.textMain,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.30,
                  children: [
                    StatCard(
                      title: 'Total Laporan',
                      value: '$totalQc',
                      icon: Icons.assignment_outlined,
                      color: AppColors.infoBg,
                      textColor: AppColors.infoText,
                      onTap: () => context.go('/reports?status=Semua'),
                    ),
                    StatCard(
                      title: 'Menunggu Review',
                      value: '$waitingQc',
                      icon: Icons.hourglass_empty,
                      color: AppColors.waitingBg,
                      textColor: AppColors.waitingText,
                      onTap: () => context.go('/reports?status=Menunggu Review'),
                    ),
                    StatCard(
                      title: 'Perlu Perbaikan',
                      value: '$revisionQc',
                      icon: Icons.edit_note,
                      color: AppColors.rejectedBg,
                      textColor: AppColors.rejectedText,
                      onTap: () => context.go('/reports?status=Perlu Perbaikan'),
                    ),
                    StatCard(
                      title: 'Disetujui',
                      value: '$approvedQc',
                      icon: Icons.check_circle_outline,
                      color: AppColors.approvedBg,
                      textColor: AppColors.approvedText,
                      onTap: () => context.go('/reports?status=Disetujui'),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // QC Modules Category Cards
                const Text(
                  'Pilih Kategori Quality Control',
                  style: TextStyle(
                    color: AppColors.textMain,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: QCModuleCard(
                        title: 'QC Material',
                        description: 'Pencatatan & inspeksi material masuk di gudang.',
                        icon: Icons.inventory_2_outlined,
                        onTap: () => context.push('/qc-material'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: QCModuleCard(
                        title: 'QC Pekerjaan',
                        description: 'Inspeksi mutu instalasi, redaman & konstruksi fisik.',
                        icon: Icons.engineering_outlined,
                        onTap: () => context.push('/qc-pekerjaan'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Recent Activities list
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Aktivitas Terakhir',
                      style: TextStyle(
                        color: AppColors.textMain,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go('/reports'),
                      child: const Text(
                        'Lihat Semua',
                        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (recentReports.isEmpty)
                  AppCard(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.assignment_turned_in_outlined, color: AppColors.textSoft, size: 36),
                          const SizedBox(height: 8),
                          const Text(
                            'Belum ada laporan di site ini',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...recentReports.map((report) {
                    return ReportCard(
                      reportId: report.id,
                      title: report.title,
                      date: report.date,
                      location: report.detailLocation.isNotEmpty ? report.detailLocation : report.siteName,
                      status: report.status,
                      type: report.type,
                      onTap: () => context.push('/reports/${report.id}'),
                    );
                  }).toList(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
