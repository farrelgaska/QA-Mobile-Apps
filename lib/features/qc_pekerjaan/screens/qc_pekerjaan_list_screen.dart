import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/dummy/dummy_pekerjaan.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/widgets/screen_header.dart';
import '../../../shared/widgets/search_bar_field.dart';
import '../../../shared/widgets/status_badge.dart';

class QCPekerjaanListScreen extends StatefulWidget {
  final String segment;

  const QCPekerjaanListScreen({
    Key? key,
    required this.segment,
  }) : super(key: key);

  @override
  State<QCPekerjaanListScreen> createState() => _QCPekerjaanListScreenState();
}

class _QCPekerjaanListScreenState extends State<QCPekerjaanListScreen> {
  String _searchQuery = '';

  WorkSegment _parseSegment(String seg) {
    switch (seg.toLowerCase()) {
      case 'provisioning':
        return WorkSegment.provisioning;
      case 'assurance':
        return WorkSegment.assurance;
      case 'construction':
        return WorkSegment.construction;
      default:
        return WorkSegment.provisioning;
    }
  }

  String _getSegmentDisplayTitle(String seg) {
    switch (seg.toLowerCase()) {
      case 'provisioning':
        return 'Provisioning';
      case 'assurance':
        return 'Assurance';
      case 'construction':
        return 'Construction';
      default:
        return 'Pekerjaan';
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeSegment = _parseSegment(widget.segment);
    final displayTitle = _getSegmentDisplayTitle(widget.segment);

    final filteredJobs = dummyPekerjaan.where((job) {
      final matchesSegment = job.segment == activeSegment;
      final matchesSearch = job.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          job.description.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesSegment && matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScreenHeader(
                title: '$displayTitle Pekerjaan',
                subtitle: 'Pilih jenis pekerjaan untuk dilakukan inspeksi QC',
              ),
              SearchBarField(
                placeholder: 'Cari pekerjaan...',
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
              ),
              const SizedBox(height: 20),
              Expanded(
                child: filteredJobs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.engineering_outlined, color: AppColors.textSoft, size: 48),
                            const SizedBox(height: 12),
                            const Text(
                              'Pekerjaan tidak ditemukan',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredJobs.length,
                        physics: const BouncingScrollPhysics(),
                        itemBuilder: (context, index) {
                          final job = filteredJobs[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14.0),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(22),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 16,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              job.name,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: AppColors.textMain,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 16,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              job.description,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: AppColors.textMuted,
                                                fontSize: 12,
                                                height: 1.3,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      StatusBadge(status: job.status),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.checklist_rounded,
                                              size: 18,
                                              color: AppColors.textSoft,
                                            ),
                                            const SizedBox(width: 6),
                                            Flexible(
                                              child: Text(
                                                '${job.checklistItems.length} Parameter Inspeksi',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.textSoft,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          minWidth: 96,
                                          maxWidth: 118,
                                        ),
                                        child: SizedBox(
                                          height: 42,
                                          child: ElevatedButton(
                                            onPressed: () {
                                              context.push('/qc-pekerjaan/form/${job.id}');
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.primary,
                                              foregroundColor: Colors.white,
                                              elevation: 0,
                                              padding: const EdgeInsets.symmetric(horizontal: 14),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(16),
                                              ),
                                            ),
                                            child: const FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Text(
                                                'Mulai QC',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
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
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
