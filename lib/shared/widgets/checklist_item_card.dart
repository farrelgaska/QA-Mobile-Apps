import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../shared/models/enums.dart';
import 'app_card.dart';
import 'photo_upload_box.dart';
import 'photo_grid.dart';
import 'standard_info_box.dart';
import 'validation_warning_box.dart';
import '../models/template_choice_option.dart';

enum _NumericStandardCompliance { compliant, nonCompliant }

class ChecklistItemCard extends StatefulWidget {
  final int itemNumber;
  final String title;
  final String standardText;
  final QCInputType inputType;
  final String? unit;
  final double? minValue;
  final double? maxValue;
  final List<String>? choices;
  final List<TemplateChoiceOption> choiceOptions;

  final QCResultStatus currentStatus;
  final String resultValue;
  final String issueDescription;
  final List<String> photos;
  final List<XFile> localPhotos;
  final List<Uint8List> localPhotoBytes;
  final Map<String, Uint8List> uploadedPhotoPreviewBytes;
  final String? warningMessage;
  final bool isLocked; // locked if auto-validation fails/succeeds on numerics

  final Function(QCResultStatus) onStatusChanged;
  final ValueChanged<String> onResultValueChanged;
  final ValueChanged<String> onIssueDescriptionChanged;
  final VoidCallback onAddPhoto;
  final Function(int) onDeletePhoto;

  const ChecklistItemCard({
    super.key,
    required this.itemNumber,
    required this.title,
    required this.standardText,
    required this.inputType,
    this.unit,
    this.minValue,
    this.maxValue,
    this.choices,
    this.choiceOptions = const [],
    required this.currentStatus,
    required this.resultValue,
    required this.issueDescription,
    required this.photos,
    this.localPhotos = const [],
    this.localPhotoBytes = const [],
    this.uploadedPhotoPreviewBytes = const {},
    this.warningMessage,
    required this.isLocked,
    required this.onStatusChanged,
    required this.onResultValueChanged,
    required this.onIssueDescriptionChanged,
    required this.onAddPhoto,
    required this.onDeletePhoto,
  });

  @override
  State<ChecklistItemCard> createState() => _ChecklistItemCardState();
}

class _ChecklistItemCardState extends State<ChecklistItemCard> {
  late TextEditingController _resultController;
  late TextEditingController _issueController;

  @override
  void initState() {
    super.initState();
    _resultController = TextEditingController(text: widget.resultValue);
    _issueController = TextEditingController(text: widget.issueDescription);
  }

  @override
  void didUpdateWidget(covariant ChecklistItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.resultValue != _resultController.text) {
      _resultController.text = widget.resultValue;
    }
    if (widget.issueDescription != _issueController.text) {
      _issueController.text = widget.issueDescription;
    }
  }

  @override
  void dispose() {
    _resultController.dispose();
    _issueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isBooleanOrChoice =
        widget.inputType == QCInputType.booleanCheck ||
        widget.inputType == QCInputType.choice;
    final selectedChoice = choiceOptionForValue(
      widget.choiceOptions,
      widget.resultValue,
    );
    final bool isNonIdeal = widget.inputType == QCInputType.choice
        ? selectedChoice?.outcome == 'FAIL'
        : widget.resultValue == 'Tidak' || widget.resultValue == 'Tidak Sesuai';

    final showIssueField = isBooleanOrChoice && isNonIdeal;
    final numericCompliance = _numericCompliance;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: AppCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Item Title
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.itemNumber}. ',
                  style: const TextStyle(
                    color: AppColors.textMain,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      color: AppColors.textMain,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Standard Info Box
            StandardInfoBox(
              standardText: widget.standardText,
              unit: widget.unit,
            ),
            const SizedBox(height: 12),
            const Divider(color: AppColors.borderSoft, height: 1),
            const SizedBox(height: 12),

            // 1. Render Input Field by inputType
            _buildInputField(),

            if (numericCompliance != null) ...[
              _buildNumericComplianceIndicator(numericCompliance),
              const SizedBox(height: 12),
            ],

            // Render Warning Message if fail (only show formatting/filling errors to staff, not standard failures)
            if (widget.warningMessage != null &&
                widget.warningMessage!.isNotEmpty &&
                widget.warningMessage != 'Kondisi tidak sesuai standar' &&
                widget.warningMessage != 'Nilai tidak sesuai standar' &&
                !widget.warningMessage!.contains('kurang dari') &&
                !widget.warningMessage!.contains('melebihi') &&
                !widget.warningMessage!.contains('standar')) ...[
              ValidationWarningBox(message: widget.warningMessage!),
              const SizedBox(height: 12),
            ],

            // 3. Conditional Issue Note Input Field
            if (showIssueField) ...[
              const SizedBox(height: 14),
              const Text(
                'Keterangan Masalah *',
                style: TextStyle(
                  color: AppColors.rejectedText,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 52,
                child: TextField(
                  controller: _issueController,
                  onChanged: widget.onIssueDescriptionChanged,
                  maxLines: 2,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF111827),
                    fontWeight: FontWeight.w500,
                  ),
                  cursorColor: const Color(0xFF006B5A),
                  decoration: const InputDecoration(
                    hintText: 'Jelaskan detail ketidaksesuaian material...',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    hintStyle: TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],

            // 4. Photo Evidence Box
            const SizedBox(height: 14),
            const Text(
              'Foto Dokumentasi',
              style: TextStyle(
                color: AppColors.textMain,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                PhotoUploadBox(onTap: widget.onAddPhoto),
                const SizedBox(width: 10),
                Expanded(
                  child: PhotoGrid(
                    photos: widget.photos,
                    localPhotos: widget.localPhotos,
                    localPhotoBytes: widget.localPhotoBytes,
                    uploadedPhotoPreviewBytes: widget.uploadedPhotoPreviewBytes,
                    onDelete: widget.onDeletePhoto,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  _NumericStandardCompliance? get _numericCompliance {
    if (widget.inputType != QCInputType.number ||
        (widget.minValue == null && widget.maxValue == null)) {
      return null;
    }

    final normalizedValue = widget.resultValue.trim().replaceAll(',', '.');
    if (normalizedValue.isEmpty) return null;

    final actualValue = double.tryParse(normalizedValue);
    if (actualValue == null || !actualValue.isFinite) return null;
    if (widget.minValue != null && actualValue < widget.minValue!) {
      return _NumericStandardCompliance.nonCompliant;
    }
    if (widget.maxValue != null && actualValue > widget.maxValue!) {
      return _NumericStandardCompliance.nonCompliant;
    }
    return _NumericStandardCompliance.compliant;
  }

  Widget _buildNumericComplianceIndicator(
    _NumericStandardCompliance compliance,
  ) {
    final isCompliant = compliance == _NumericStandardCompliance.compliant;
    return Container(
      key: const Key('numeric-standard-compliance'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: isCompliant ? AppColors.approvedBg : AppColors.rejectedBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCompliant ? AppColors.approvedText : AppColors.rejectedText,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCompliant ? Icons.check_circle_outline : Icons.error_outline,
            size: 16,
            color: isCompliant
                ? AppColors.approvedText
                : AppColors.rejectedText,
          ),
          const SizedBox(width: 6),
          Text(
            isCompliant ? 'Sesuai Standar' : 'Tidak Sesuai Standar',
            style: TextStyle(
              color: isCompliant
                  ? AppColors.approvedText
                  : AppColors.rejectedText,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField() {
    if (widget.inputType == QCInputType.number ||
        widget.inputType == QCInputType.text) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Input Nilai Aktual',
            style: TextStyle(
              color: AppColors.textMain,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    controller: _resultController,
                    onChanged: widget.onResultValueChanged,
                    keyboardType: widget.inputType == QCInputType.number
                        ? const TextInputType.numberWithOptions(
                            signed: true,
                            decimal: true,
                          )
                        : TextInputType.text,
                    inputFormatters: widget.inputType == QCInputType.number
                        ? [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^-?\d*[,.]?\d*$'),
                            ),
                          ]
                        : null,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF111827),
                      fontWeight: FontWeight.w500,
                    ),
                    cursorColor: const Color(0xFF006B5A),
                    decoration: InputDecoration(
                      hintText: widget.inputType == QCInputType.number
                          ? 'Masukkan angka'
                          : 'Masukkan teks',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      hintStyle: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.unit != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundSoft,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.borderSoft),
                  ),
                  child: Text(
                    widget.unit!,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (widget.title.toLowerCase().contains('redaman')) ...[
            const SizedBox(height: 4),
            const Text(
              'Masukkan nilai dalam dBm',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 12),
        ],
      );
    } else if (widget.inputType == QCInputType.booleanCheck) {
      // Sesuai / Tidak Sesuai or Ya / Tidak toggle button style
      final bool isSesuai =
          widget.resultValue == 'Sesuai' ||
          widget.resultValue == 'Ya' ||
          widget.resultValue == 'OK';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kesesuaian Fisik',
            style: TextStyle(
              color: AppColors.textMain,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildChoiceChip(
                label: 'Sesuai (Ya)',
                selected: isSesuai && widget.resultValue.isNotEmpty,
                onTap: () {
                  widget.onResultValueChanged('Ya');
                },
              ),
              _buildChoiceChip(
                label: 'Tidak Sesuai (Tidak)',
                selected: !isSesuai && widget.resultValue.isNotEmpty,
                onTap: () {
                  widget.onResultValueChanged('Tidak');
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      );
    } else if (widget.inputType == QCInputType.choice) {
      if (widget.choiceOptions.isEmpty) {
        return const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'Opsi belum dikonfigurasi. Hubungi admin template.',
            style: TextStyle(color: AppColors.rejectedText, fontSize: 12),
          ),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pilih Opsi Kriteria',
            style: TextStyle(
              color: AppColors.textMain,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.choiceOptions.map((option) {
              final isSel = widget.resultValue == option.value;
              return _buildChoiceChip(
                label: option.label,
                selected: isSel,
                onTap: () {
                  if (option.outcome == 'PASS' &&
                      widget.issueDescription.isNotEmpty) {
                    _issueController.clear();
                    widget.onIssueDescriptionChanged('');
                  }
                  widget.onResultValueChanged(option.value);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildChoiceChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySoft : AppColors.backgroundSoft,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.transparent,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.primary : AppColors.textMuted,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}
