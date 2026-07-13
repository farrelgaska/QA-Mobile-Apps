import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/dummy/dummy_qc_material_templates.dart';
import '../../../core/services/api_service.dart';
import '../../../shared/models/qc_material_template_model.dart';
import '../../../shared/models/enums.dart';
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
  List<QCMaterialTemplate> _templates = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  /// Converts a raw API template JSON map to a [QCMaterialTemplate].
  /// Returns null if the required fields are missing.
  QCMaterialTemplate _mapApiTemplate(Map<String, dynamic> json) {
    final checklistItems = (json['checklistItems'] as List<dynamic>? ?? [])
        .map<QCChecklistItem>((item) {
      final inputTypeStr = (item['input_type'] as String? ?? 'choice').toLowerCase();
      final QCInputType inputType;
      if (inputTypeStr == 'number') {
        inputType = QCInputType.number;
      } else if (inputTypeStr == 'text') {
        inputType = QCInputType.text;
      } else {
        inputType = QCInputType.choice;
      }

      final standardText = item['standard_text'] as String? ?? '';
      final unit = (item['unit'] as String?)?.isNotEmpty == true ? item['unit'] as String : null;

      QCValidationRule? validationRule;
      if (inputType == QCInputType.number && unit != null) {
        validationRule = QCValidationRule(
          type: QCValidationType.min,
          minValue: 0,
        );
      }

      return QCChecklistItem(
        id: item['id'] as String? ?? '',
        label: item['parameter_name'] as String? ?? '',
        category: 'Parameter',
        inputType: inputType,
        unit: unit,
        standardText: standardText,
        validationRule: validationRule,
        required: item['is_required'] as bool? ?? true,
        requiredPhoto: false,
      );
    }).toList();

    return QCMaterialTemplate(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      code: json['formCode'] as String? ?? '',
      description: json['category'] as String? ?? '',
      checklistItems: checklistItems,
    );
  }

  Future<void> _loadTemplates() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final rawTemplates = await ApiService().fetchTemplates();

      if (rawTemplates != null) {
        // Filter only MATERIAL type and active templates
        final materialTemplates = rawTemplates
            .where((t) =>
                t['type'] == 'MATERIAL' && (t['isActive'] == true))
            .map(_mapApiTemplate)
            .toList();

        if (mounted) {
          setState(() {
            _templates = materialTemplates.isNotEmpty
                ? materialTemplates
                : dummyQCMaterialTemplates;
            _isLoading = false;
          });
        }
      } else {
        // API unavailable — fall back to local dummy data
        if (mounted) {
          setState(() {
            _templates = dummyQCMaterialTemplates;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _templates = dummyQCMaterialTemplates;
          _errorMessage = 'Koneksi API gagal. Menampilkan data lokal.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredTemplates = _templates.where((m) {
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
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.amber.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(fontSize: 12, color: Colors.amber.shade800),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text(
                              'Memuat template...',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : filteredTemplates.isEmpty
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
                                const SizedBox(height: 16),
                                TextButton.icon(
                                  onPressed: _loadTemplates,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Coba lagi'),
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
