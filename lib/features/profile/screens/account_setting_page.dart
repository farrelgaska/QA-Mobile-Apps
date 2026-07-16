import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/dummy/dummy_state.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/screen_header.dart';
import '../../../shared/widgets/confirmation_modal.dart';
import 'package:image_picker/image_picker.dart';
import '../profile_photo_controller.dart';

class AccountSettingPage extends StatefulWidget {
  final ProfilePhotoPicker? photoPicker;
  final ProfilePhotoPersistence? photoPersistence;

  const AccountSettingPage({
    super.key,
    this.photoPicker,
    this.photoPersistence,
  });

  @override
  State<AccountSettingPage> createState() => _AccountSettingPageState();
}

class _AccountSettingPageState extends State<AccountSettingPage> {
  final _state = DummyState();
  late final ProfilePhotoController _photoController;

  @override
  void initState() {
    super.initState();
    _photoController = ProfilePhotoController(
      nik: _state.currentUser.nik,
      picker: widget.photoPicker,
      persistence: widget.photoPersistence,
    )..addListener(_onPhotoChanged);
    _photoController.restore();
  }

  void _onPhotoChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _photoController
      ..removeListener(_onPhotoChanged)
      ..dispose();
    super.dispose();
  }

  Future<void> _selectPhoto(ImageSource source) async {
    try {
      final result = await _photoController.select(source);
      if (!mounted || result == ProfilePhotoSelection.cancelled) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto profil berhasil diperbarui.')),
      );
    } on ProfilePhotoException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto gagal dipilih. Coba lagi.')),
      );
    }
  }

  Future<void> _deletePhoto() async {
    await _photoController.remove();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Foto profil berhasil dihapus.')),
    );
  }

  void _handleLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => ConfirmationModal(
        title: 'Logout Akun',
        message: 'Apakah Anda yakin ingin keluar dari akun QA Staff Anda?',
        confirmText: 'Keluar',
        isDanger: true,
        onConfirm: () {
          // Pop the dialog and go to login
          Navigator.pop(context);
          context.go('/login');
        },
      ),
    );
  }

  void _showPhotoPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              const Text(
                'Ubah Foto Profil',
                style: TextStyle(
                  color: AppColors.textMain,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(
                  Icons.camera_alt_outlined,
                  color: AppColors.primary,
                ),
                title: const Text('Ambil Foto'),
                onTap: () {
                  Navigator.pop(context);
                  _selectPhoto(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_outlined,
                  color: AppColors.primary,
                ),
                title: const Text('Pilih dari Galeri'),
                onTap: () {
                  Navigator.pop(context);
                  _selectPhoto(ImageSource.gallery);
                },
              ),
              if (_photoController.hasPhoto)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text(
                    'Hapus Foto',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await _deletePhoto();
                  },
                ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _state.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScreenHeader(
                title: 'Pengaturan Akun',
                subtitle: 'Informasi personal, penugasan, dan keamanan akun.',
              ),
              const SizedBox(height: 8),

              // Header Avatar Profile Summary
              AppCard(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _showPhotoPicker,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: AppColors.primarySoft,
                            backgroundImage: _photoController.bytes != null
                                ? MemoryImage(_photoController.bytes!)
                                : null,
                            child: _photoController.bytes == null
                                ? const Icon(
                                    Icons.person,
                                    color: AppColors.primary,
                                    size: 30,
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name,
                            style: const TextStyle(
                              color: AppColors.textMain,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user.role,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.approvedBg,
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: const Text(
                              'Akun Aktif',
                              style: TextStyle(
                                color: AppColors.approvedText,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // SECTION: UBAH FOTO PROFIL ROW
              const _SectionHeader(title: 'Foto Profil'),
              AppCard(
                padding: const EdgeInsets.all(16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 320;

                    if (isNarrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Ubah Foto Profil Anda',
                            style: TextStyle(
                              color: AppColors.textMain,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 40,
                            child: ElevatedButton(
                              onPressed: _showPhotoPicker,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Ubah Foto'),
                            ),
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Ubah Foto Profil Anda',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.textMain,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ConstrainedBox(
                          constraints: const BoxConstraints(
                            minWidth: 100,
                            maxWidth: 120,
                          ),
                          child: SizedBox(
                            height: 40,
                            child: ElevatedButton(
                              onPressed: _showPhotoPicker,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('Ubah Foto'),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),

              // SECTION A: INFORMASI AKUN
              const _SectionHeader(title: 'A. Informasi Akun'),
              AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Column(
                  children: [
                    _buildDetailRow(
                      icon: Icons.badge_outlined,
                      label: 'Nama Lengkap',
                      value: user.name,
                    ),
                    const Divider(color: AppColors.borderSoft),
                    _buildDetailRow(
                      icon: Icons.fingerprint_outlined,
                      label: 'NIK / ID Staff',
                      value: user.nik,
                    ),
                    const Divider(color: AppColors.borderSoft),
                    _buildDetailRow(
                      icon: Icons.mail_outline,
                      label: 'Email SSO',
                      value: 'yanuar.luthfi@telkom.co.id',
                    ),
                    const Divider(color: AppColors.borderSoft),
                    _buildDetailRow(
                      icon: Icons.phone_android_outlined,
                      label: 'Nomor HP',
                      value: '+62 812-3456-7890',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // SECTION B: INFORMASI PENUGASAN
              const _SectionHeader(title: 'B. Informasi Penugasan'),
              AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Column(
                  children: [
                    _buildDetailRow(
                      icon: Icons.location_on_outlined,
                      label: 'Lokasi Aktif',
                      value: _state.currentSite.name,
                    ),
                    const Divider(color: AppColors.borderSoft),
                    _buildDetailRow(
                      icon: Icons.business_outlined,
                      label: 'Unit Kerja',
                      value: 'Regional 2 - Jakarta',
                    ),
                    const Divider(color: AppColors.borderSoft),
                    _buildDetailRow(
                      icon: Icons.schedule_outlined,
                      label: 'Shift Kerja',
                      value: 'Pagi (08:00 - 17:00 WIB)',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // SECTION C: KEAMANAN
              const _SectionHeader(title: 'C. Keamanan'),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _buildActionRow(
                      context,
                      icon: Icons.lock_outline,
                      title: 'Ubah Password Akun',
                      subtitle: 'Diperbarui 3 bulan lalu',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // SECTION D: AKSI AKUN
              AppButton(
                text: 'Keluar Akun (Logout)',
                variant: AppButtonVariant.danger,
                icon: Icons.logout,
                onPressed: () => _handleLogout(context),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.textMain,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary, size: 22),
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.textMain,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppColors.textSoft, fontSize: 11),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: AppColors.textSoft,
        size: 16,
      ),
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fitur "$title" disimulasikan.'),
            duration: const Duration(seconds: 1),
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.textMain,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }
}
