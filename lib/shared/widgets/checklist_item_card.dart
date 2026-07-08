import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../shared/models/enums.dart';
import 'app_card.dart';
import 'photo_upload_box.dart';
import 'photo_grid.dart';
import 'standard_info_box.dart';
import 'validation_warning_box.dart';

class ChecklistItemCard extends StatefulWidget {
  final int itemNumber;
  final String title;
  final String standardText;
  final QCInputType inputType;
  final String? unit;
  final List<String>? choices;
  
  final QCResultStatus currentStatus;
  final String resultValue;
  final String issueDescription;
  final List<String> photos;
  final String? warningMessage;
  final bool isLocked; // locked if auto-validation fails/succeeds on numerics

  final Function(QCResultStatus) onStatusChanged;
  final ValueChanged<String> onResultValueChanged;
  final ValueChanged<String> onIssueDescriptionChanged;
  final VoidCallback onAddPhoto;
  final Function(int) onDeletePhoto;

  const ChecklistItemCard({
    Key? key,
    required this.itemNumber,
    required this.title,
    required this.standardText,
    required this.inputType,
    this.unit,
    this.choices,
    required this.currentStatus,
    required this.resultValue,
    required this.issueDescription,
    required this.photos,
    this.warningMessage,
    required this.isLocked,
    required this.onStatusChanged,
    required this.onResultValueChanged,
    required this.onIssueDescriptionChanged,
    required this.onAddPhoto,
    required this.onDeletePhoto,
  }) : super(key: key);

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
    final showIssueField = widget.currentStatus == QCResultStatus.fail || 
        widget.currentStatus == QCResultStatus.needFollowUp;

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
            
            // Render Warning Message if fail
            if (widget.warningMessage != null && widget.warningMessage!.isNotEmpty) ...[
              ValidationWarningBox(message: widget.warningMessage!),
              const SizedBox(height: 12),
            ],

            // 2. Selection for QCResultStatus or Auto-status
            _buildAutoStatusSection(widget.currentStatus),

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
                  style: const TextStyle(fontSize: 12, color: AppColors.textMain),
                  decoration: const InputDecoration(
                    hintText: 'Jelaskan detail ketidaksesuaian material...',
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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

  Widget _buildInputField() {
    if (widget.inputType == QCInputType.number || widget.inputType == QCInputType.text) {
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
                        ? const TextInputType.numberWithOptions(decimal: true) 
                        : TextInputType.text,
                    style: const TextStyle(fontSize: 13, color: AppColors.textMain),
                    decoration: InputDecoration(
                      hintText: widget.inputType == QCInputType.number ? 'Masukkan angka' : 'Masukkan teks',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                  ),
                ),
              ),
              if (widget.unit != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
      final bool isSesuai = widget.resultValue == 'Sesuai' || widget.resultValue == 'Ya' || widget.resultValue == 'OK';
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
    } else if (widget.inputType == QCInputType.choice && widget.choices != null) {
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
            children: widget.choices!.map((ch) {
              final isSel = widget.resultValue == ch;
              return _buildChoiceChip(
                label: ch,
                selected: isSel,
                onTap: () => widget.onResultValueChanged(ch),
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

  Widget _buildAutoStatusSection(QCResultStatus status) {
    Color bgColor;
    Color textColor;
    String label;
    String helperText;

    if (status == QCResultStatus.pass) {
      bgColor = const Color(0xFFE8F7F1);
      textColor = const Color(0xFF006B5A);
      label = 'Lulus';
      helperText = 'Kondisi sesuai standar';
    } else if (status == QCResultStatus.fail || status == QCResultStatus.needFollowUp) {
      bgColor = const Color(0xFFFDECEC);
      textColor = const Color(0xFFEF4444);
      label = 'Perlu Perbaikan';
      helperText = 'Kondisi tidak sesuai standar';
    } else {
      bgColor = const Color(0xFFF3F4F6);
      textColor = const Color(0xFF6B7280);
      label = 'Belum Dinilai';
      helperText = 'Pilih parameter terlebih dahulu';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Hasil Inspeksi',
          style: TextStyle(
            color: AppColors.textMain,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                helperText,
                style: TextStyle(
                  color: status == QCResultStatus.notFilled ? AppColors.textSoft : textColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
