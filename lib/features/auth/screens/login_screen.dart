import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/dummy/dummy_state.dart';
import '../../../core/dummy/dummy_users.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_input.dart';
import '../../../shared/widgets/app_card.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nikController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;
  String? _nikError;
  String? _passwordError;
  bool _isLoading = false;

  void _handleLogin() {
    setState(() {
      _nikError = null;
      _passwordError = null;
    });

    if (_nikController.text.trim().isEmpty) {
      setState(() => _nikError = 'NIK tidak boleh kosong');
      return;
    }
    if (_passwordController.text.isEmpty) {
      setState(() => _passwordError = 'Password tidak boleh kosong');
      return;
    }

    setState(() => _isLoading = true);

    final nikInput = _nikController.text.trim();
    final matchingUserIndex = dummyUsers.indexWhere(
      (u) => u.nik.toLowerCase() == nikInput.toLowerCase() || 
             u.name.toLowerCase().contains(nikInput.toLowerCase()),
    );

    if (matchingUserIndex == -1) {
      setState(() {
        _isLoading = false;
        _nikError = 'Akun tidak ditemukan';
      });
      return;
    }

    final matchingUser = dummyUsers[matchingUserIndex];
    DummyState().currentUser = matchingUser;

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() => _isLoading = false);
        context.go('/home');
      }
    });
  }

  @override
  void dispose() {
    _nikController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Image.asset(
                  'assets/images/logo_qa.png',
                  height: 72,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 16),
                const Text(
                  'QA Mobile Apps',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Masuk dengan akun SSO',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 32),

                // Form card
                AppCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      AppInput(
                        label: 'NIK / Username',
                        hintText: 'Masukkan NIK Anda',
                        controller: _nikController,
                        prefixIcon: Icons.person_outline,
                        errorText: _nikError,
                      ),
                      const SizedBox(height: 20),
                      AppInput(
                        label: 'Password',
                        hintText: 'Masukkan Password',
                        controller: _passwordController,
                        isObscure: true,
                        prefixIcon: Icons.lock_outline,
                        errorText: _passwordError,
                      ),
                      const SizedBox(height: 16),
                      
                      // Remember me & forgot password
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: Checkbox(
                                  value: _rememberMe,
                                  onChanged: (val) {
                                    setState(() {
                                      _rememberMe = val ?? false;
                                    });
                                  },
                                  activeColor: const Color(0xFF006B5A),
                                  checkColor: Colors.white,
                                  side: const BorderSide(
                                    color: Color(0xFF9CA3AF),
                                    width: 1.5,
                                  ),
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Ingat Saya',
                                style: TextStyle(
                                  color: Color(0xFF6B7280),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          GestureDetector(
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Silakan hubungi IT Support untuk reset password')),
                              );
                            },
                            child: const Text(
                              'Lupa Password?',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      AppButton(
                        text: 'Masuk',
                        isLoading: _isLoading,
                        onPressed: _handleLogin,
                      ),
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.waitingBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.waitingText.withOpacity(0.3)),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Demo Akun Kredensial (QA Staff):',
                              style: TextStyle(
                                color: AppColors.waitingText,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              '• Staff 1: NIK-908271 (atau ketik "yanuar")',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '• Staff 2: NIK-908272 (atau ketik "budi")',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 48),
                const Text(
                  '© Quality Assurance & Innovation',
                  style: TextStyle(color: AppColors.textSoft, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Internal Use Only • v1.0.0',
                  style: TextStyle(color: AppColors.textSoft, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
