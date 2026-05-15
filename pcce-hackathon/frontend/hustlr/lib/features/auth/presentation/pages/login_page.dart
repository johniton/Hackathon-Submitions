import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hustlr/core/theme/app_colors.dart';
import 'package:hustlr/core/widgets/primary_button.dart';
import 'package:hustlr/core/widgets/custom_text_field.dart';
import 'package:hustlr/core/widgets/glass_card.dart';
import 'package:hustlr/core/app_session.dart';
import 'package:hustlr/core/services/session_service.dart';
import 'package:hustlr/main.dart';
import 'package:hustlr/features/company_board/presentation/pages/company_dashboard_placeholder.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isCompany = false;
  bool _isLoading = false;

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final table = _isCompany ? 'companies' : 'users';
      final response = await Supabase.instance.client
          .from(table)
          .select()
          .eq('email', email)
          .eq('password', password)
          .maybeSingle();

      if (!mounted) return;

      if (response == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid credentials')));
      } else {
        // Save session locally
        await SessionService.save(
          id: response['id'] as String,
          name: (response['name'] as String?) ?? email,
          email: email,
          role: _isCompany ? 'company' : 'user',
        );

        // Store session so features (e.g. Skill Swap) can access the user's ID
        if (!_isCompany) {
          final rawId   = response['id'];
          final rawName = response['name'] ?? response['email'] ?? 'User';
          AppSession.instance.login(
            userId: rawId?.toString() ?? '',
            name:   rawName.toString(),
            email:  email,
          );
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Login successful!')));
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => _isCompany ? const CompanyDashboardPlaceholder() : const MainAppShell()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // Background decorations
          Positioned(
            top: -100, right: -100,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [AppColors.primary.withValues(alpha: 0.3), Colors.transparent]),
              ),
            ),
          ),
          Positioned(
            bottom: -50, left: -100,
            child: Container(
              width: 250, height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [AppColors.accent.withValues(alpha: 0.2), Colors.transparent]),
              ),
            ),
          ),
          
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                        child: const Icon(LucideIcons.map, size: 48, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    Text('Welcome Back', style: Theme.of(context).textTheme.headlineLarge, textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text('Sign in to access your AI career engine', style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
                    const SizedBox(height: 32),

                    // Role Toggle
                    Row(
                      children: [
                        Expanded(child: _roleChip('User', LucideIcons.user, !_isCompany, isDark)),
                        const SizedBox(width: 12),
                        Expanded(child: _roleChip('Company', LucideIcons.building2, _isCompany, isDark)),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Login Form inside GlassCard
                    GlassCard(
                      child: Column(
                        children: [
                          CustomTextField(
                            controller: _emailCtrl,
                            hintText: 'Email Address',
                            prefixIcon: LucideIcons.mail,
                          ),
                          const SizedBox(height: 16),
                          CustomTextField(
                            controller: _passCtrl,
                            hintText: 'Password',
                            prefixIcon: LucideIcons.lock,
                            isPassword: true,
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {},
                              child: const Text('Forgot Password?', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                            ),
                          ),
                          const SizedBox(height: 24),
                          _isLoading
                              ? const CircularProgressIndicator()
                              : PrimaryButton(
                                  text: 'Sign In',
                                  onPressed: _login,
                                ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Register Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Don't have an account?", style: Theme.of(context).textTheme.bodyMedium),
                        TextButton(
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterPage()));
                          },
                          child: const Text('Sign Up', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _roleChip(String label, IconData icon, bool selected, bool isDark) {
    return GestureDetector(
      onTap: () => setState(() => _isCompany = label == 'Company'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.08) : (isDark ? AppColors.surfaceDark : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? AppColors.primary : (isDark ? Colors.white12 : Colors.black12)),
        ),
        child: Column(children: [
          Icon(icon, color: selected ? AppColors.primary : AppColors.textSecondaryLight, size: 20),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: selected ? AppColors.primary : AppColors.textSecondaryLight)),
        ]),
      ),
    );
  }
}
