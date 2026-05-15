import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hustlr/core/theme/app_colors.dart';
import 'package:hustlr/core/widgets/custom_text_field.dart';
import 'package:hustlr/core/widgets/primary_button.dart';
import 'package:hustlr/core/widgets/glass_card.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  
  bool _isCompany = false;
  bool _isLoading = false;

  Future<void> _register() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final password = _passCtrl.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all required fields')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final table = _isCompany ? 'companies' : 'users';
      
      // Check if email exists
      final existing = await Supabase.instance.client
          .from(table)
          .select()
          .eq('email', email)
          .maybeSingle();
          
      if (existing != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email already exists')));
        return;
      }

      await Supabase.instance.client.from(table).insert({
        'name': name,
        'email': email,
        'phone': phone,
        'password': password,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registration successful! Please login.')));
      Navigator.pop(context); // Go back to login
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Stack(children: [
        Positioned(
          top: -80, left: -80,
          child: Container(width: 250, height: 250, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [AppColors.accent.withValues(alpha: 0.25), Colors.transparent]))),
        ),
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(LucideIcons.arrowLeft), alignment: Alignment.centerLeft),
              const SizedBox(height: 16),
              Text('Create Account', style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 6),
              Text('Start your AI career journey today', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 32),
              
              // Role selector
              Text('I am a...', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _roleChip('User', LucideIcons.user, !_isCompany, isDark)),
                const SizedBox(width: 10),
                Expanded(child: _roleChip('Company', LucideIcons.building2, _isCompany, isDark)),
              ]),
              const SizedBox(height: 24),
              
              GlassCard(
                child: Column(children: [
                  CustomTextField(controller: _nameCtrl, hintText: _isCompany ? 'Company Name' : 'Full Name', prefixIcon: LucideIcons.user),
                  const SizedBox(height: 14),
                  CustomTextField(controller: _emailCtrl, hintText: 'Email Address', prefixIcon: LucideIcons.mail),
                  const SizedBox(height: 14),
                  CustomTextField(controller: _phoneCtrl, hintText: 'Phone Number (Optional)', prefixIcon: LucideIcons.phone),
                  const SizedBox(height: 14),
                  CustomTextField(controller: _passCtrl, hintText: 'Password', prefixIcon: LucideIcons.lock, isPassword: true),
                  const SizedBox(height: 24),
                  _isLoading
                      ? const CircularProgressIndicator()
                      : PrimaryButton(text: 'Create Account', onPressed: _register),
                ]),
              ),
              const SizedBox(height: 24),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('Already have an account? ', style: Theme.of(context).textTheme.bodyMedium),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Text('Sign In', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                ),
              ]),
            ]),
          ),
        ),
      ]),
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
