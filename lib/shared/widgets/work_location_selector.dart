import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/dummy/dummy_sites.dart';
import '../../shared/models/site_model.dart';
import 'app_card.dart';
import 'app_input.dart';

class WorkLocationSelector extends StatefulWidget {
  final SiteModel? selectedSite;
  final bool isCustom;
  final TextEditingController nameController;
  final TextEditingController areaController;
  final TextEditingController segmentController;
  final TextEditingController noteController;
  final Function(SiteModel) onSiteChanged;
  final Function(bool) onModeChanged;

  const WorkLocationSelector({
    super.key,
    required this.selectedSite,
    required this.isCustom,
    required this.nameController,
    required this.areaController,
    required this.segmentController,
    required this.noteController,
    required this.onSiteChanged,
    required this.onModeChanged,
  });

  @override
  State<WorkLocationSelector> createState() => _WorkLocationSelectorState();
}

class _WorkLocationSelectorState extends State<WorkLocationSelector> {
  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lokasi Kerja',
            style: TextStyle(
              color: AppColors.textMain,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          
          // Site Dropdown selection
          if (!widget.isCustom) ...[
            const Text(
              'Pilih Site Terdaftar',
              style: TextStyle(
                color: AppColors.textMain,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<SiteModel>(
                  dropdownColor: Colors.white,
                  value: (widget.selectedSite != null && dummySites.contains(widget.selectedSite))
                      ? widget.selectedSite
                      : dummySites[0],
                  isExpanded: true,
                  icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
                  onChanged: (SiteModel? newSite) {
                    if (newSite != null) {
                      widget.onSiteChanged(newSite);
                    }
                  },
                  items: dummySites.map((SiteModel site) {
                    return DropdownMenuItem<SiteModel>(
                      value: site,
                      child: Text(
                        site.name,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
          
          const SizedBox(height: 12),
          
          // Toggle "Gunakan Lokasi Custom"
          Row(
            children: [
              Checkbox(
                value: widget.isCustom,
                activeColor: AppColors.primary,
                onChanged: (val) {
                  if (val != null) {
                    widget.onModeChanged(val);
                  }
                },
              ),
              const Expanded(
                child: Text(
                  'Gunakan Lokasi Custom (Tulis manual)',
                  style: TextStyle(
                    color: AppColors.textMain,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          // Conditional Custom Fields
          if (widget.isCustom) ...[
            const SizedBox(height: 12),
            AppInput(
              label: 'Nama Lokasi *',
              hintText: 'Misal: Pabrikasi Baru Cikarang',
              controller: widget.nameController,
              prefixIcon: Icons.business_outlined,
            ),
            const SizedBox(height: 12),
            AppInput(
              label: 'Area / Zona *',
              hintText: 'Misal: Sektor Timur - Jalur 2',
              controller: widget.areaController,
              prefixIcon: Icons.map_outlined,
            ),
            const SizedBox(height: 12),
            AppInput(
              label: 'Titik / Segmen *',
              hintText: 'Misal: Dekat Tiang No. 05',
              controller: widget.segmentController,
              prefixIcon: Icons.location_searching_outlined,
            ),
            const SizedBox(height: 12),
            AppInput(
              label: 'Catatan Lokasi (Opsional)',
              hintText: 'Misal: Akses masuk dekat pos satpam',
              controller: widget.noteController,
              prefixIcon: Icons.notes_outlined,
            ),
          ],
        ],
      ),
    );
  }
}
