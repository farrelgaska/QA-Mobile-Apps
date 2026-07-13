// Refactored QC Pekerjaan Form using Provider
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_input.dart';
import '../../../shared/widgets/checklist_item_card.dart';
import '../../../shared/widgets/screen_header.dart';
import '../../../shared/widgets/confirmation_modal.dart';
import '../../../shared/providers/qc_pekerjaan_form_provider.dart';
import '../../../shared/widgets/app_snackbar.dart';

class QCPekerjaanFormScreen extends StatelessWidget {
  final String pekerjaanId;
  const QCPekerjaanFormScreen({Key? key, required this.pekerjaanId})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => QCPekerjaanFormProvider()..init(pekerjaanId),
      child: Consumer<QCPekerjaanFormProvider>(
        builder: (context, provider, _) {
          if (!provider.isReady) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            );
          }
          return Scaffold(
            backgroundColor: AppColors.background,
            body: SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                    horizontal: 20.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ScreenHeader(
                      title: 'Inspeksi Pekerjaan',
                      subtitle: provider.pekerjaan.name as String,
                    ),
                    _buildDetailCard(provider),
                    const SizedBox(height: 24),
                    _buildChecklistSection(provider),
                    _buildStaffNoteCard(provider),
                    const SizedBox(height: 28),
                    _buildActionButtons(context, provider),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailCard(QCPekerjaanFormProvider p) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          AppInput(
            label: 'Lokasi Site (Aktif)',
            controller: TextEditingController(
                text: p.state.currentSite.name),
            prefixIcon: Icons.location_on_outlined,
          ),
          const SizedBox(height: 16),
          AppInput(
            label: 'Area / Zona Kerja',
            hintText: 'Misal: Area Pondasi Jalur Utama',
            controller: p.areaController,
            prefixIcon: Icons.map_outlined,
          ),
          const SizedBox(height: 16),
          AppInput(
            label: 'Detail Lokasi / Koordinat',
            hintText: 'Misal: Depan Ruko Blok C-4 / Tiang No. 12',
            controller: p.locationDetailController,
            prefixIcon: Icons.my_location_outlined,
          ),
          const SizedBox(height: 16),
          AppInput(
            label: 'Nama Mitra Pelaksana',
            hintText: 'Misal: CV Terang Abadi Jaya',
            controller: p.mitraController,
            prefixIcon: Icons.business_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistSection(QCPekerjaanFormProvider p) {
    final items = p.pekerjaan.checklistItems as List;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Parameter Checklist Pekerjaan',
            style: TextStyle(
                color: AppColors.textMain,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        const SizedBox(height: 12),
        ...List.generate(items.length, (index) {
          final item = items[index];
          // Map InputType → QCInputType
          QCInputType qcInputType;
          switch (item.inputType) {
            case InputType.number:
              qcInputType = QCInputType.number;
              break;
            case InputType.choice:
              qcInputType = QCInputType.choice;
              break;
            default:
              qcInputType = QCInputType.text;
          }
          // Map ChecklistStatus → QCResultStatus
          QCResultStatus qcStatus;
          switch (p.itemStatuses[index]) {
            case ChecklistStatus.lulus:
              qcStatus = QCResultStatus.pass;
              break;
            case ChecklistStatus.tidakSesuai:
              qcStatus = QCResultStatus.fail;
              break;
            case ChecklistStatus.perluTindakLanjut:
              qcStatus = QCResultStatus.needFollowUp;
              break;
            default:
              qcStatus = QCResultStatus.notFilled;
          }
          return ChecklistItemCard(
            itemNumber: index + 1,
            title: item.title,
            standardText: item.standard,
            inputType: qcInputType,
            unit: item.unit,
            choices: item.choices,
            currentStatus: qcStatus,
            resultValue: p.itemResults[index],
            issueDescription: p.itemIssues[index],
            photos: p.itemPhotos[index],
            warningMessage: p.itemWarnings[index],
            isLocked: false,
            onStatusChanged: (status) => p.updateStatus(index, status),
            onResultValueChanged: (val) => p.updateResult(index, val),
            onIssueDescriptionChanged: (val) => p.updateIssueNote(index, val),
            onAddPhoto: () => p.addPhoto(index),
            onDeletePhoto: (pIdx) => p.removePhoto(index, pIdx),
          );
        }),
      ],
    );
  }

  Widget _buildStaffNoteCard(QCPekerjaanFormProvider p) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: AppInput(
        label: 'Catatan QA Staff (Opsional)',
        hintText: 'Tuliskan catatan tambahan mengenai proses pengerjaan...',
        controller: p.staffNoteController,
        maxLines: 3,
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, QCPekerjaanFormProvider p) {
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: AppButton(
            text: 'Simpan Draft',
            variant: AppButtonVariant.secondary,
            onPressed: () {
              if (!p.hasAnyDraftContent) {
                AppSnackbar.warning(context, 'Isi minimal satu data pemeriksaan sebelum menyimpan draft.');
                return;
              }
              p.persistReport(QCReportStatus.DRAFT);
              AppSnackbar.success(context, 'Draft berhasil disimpan');
              context.pop();
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 6,
          child: AppButton(
            text: 'Submit Laporan',
            variant: AppButtonVariant.primary,
            onPressed: () {
              final err = p.validateForm();
              if (err != null) {
                AppSnackbar.error(context, err);
                return;
              }
              showDialog(
                context: context,
                builder: (c) => ConfirmationModal(
                  title: 'Submit Laporan QC',
                  message:
                      'Apakah seluruh data inspeksi pekerjaan konstruksi sudah lengkap dan siap dikirim?',
                  confirmText: 'Kirim',
                  onConfirm: () {
                    p.persistReport(QCReportStatus.SUBMITTED);
                    Navigator.pop(c);
                    context.pop();
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
