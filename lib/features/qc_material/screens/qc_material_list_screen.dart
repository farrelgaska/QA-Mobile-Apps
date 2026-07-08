import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/dummy/dummy_qc_material_templates.dart';
import '../../../shared/widgets/screen_header.dart';
import '../../../shared/widgets/search_bar_field.dart';
import '../../../shared/widgets/status_badge.dart';

class QCMaterialListScreen extends StatefulWidget {
  const QCMaterialListScreen({Key? key}) : super(key: key);

  @override
  State<QCMaterialListScreen> createState() => _QCMaterialListScreenState();
}

class _QCMaterialListScreenState extends State<QCMaterialListScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final filteredTemplates = dummyQCMaterialTemplates.where((m) {
      final matchesSearch = m.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          m.code.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ScreenHeader(
                title: 'QC Material',
                subtitle: 'Pilih material untuk dilakukan Quality Control',
              ),
              SearchBarField(
                placeholder: 'Cari material...',
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
              ),
              const SizedBox(height: 20),
              Expanded(
                child: filteredTemplates.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.inventory_2_outlined, color: AppColors.textSoft, size: 48),
                            const SizedBox(height: 12),
                            const Text(
                              'Material tidak ditemukan',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredTemplates.length,
                        physics: const BouncingScrollPhysics(),
                        itemBuilder: (context, index) {
                          final template = filteredTemplates[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
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
                                              template.name,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: AppColors.textMain,
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Kode Form: ${template.code}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.textMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      const StatusBadge(status: 'Aktif'),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
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
                                                '${template.checklistItems.length} Poin Checklist',
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
                                      const SizedBox(width: 12),
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          minWidth: 96,
                                          maxWidth: 120,
                                        ),
                                        child: SizedBox(
                                          height: 44,
                                          child: ElevatedButton(
                                            onPressed: () {
                                              context.push('/qc-material/form/${template.id}');
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
                                                maxLines: 1,
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
