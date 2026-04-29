import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/auth_provider.dart';
import '../../../shared/widgets/common_widgets.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _sent = false;

  @override
  void dispose() { _emailCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.forgotPassword(_emailCtrl.text.trim());
    if (!mounted) return;
    if (ok) {
      setState(() => _sent = true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(auth.error ?? 'Failed'), backgroundColor: AppTheme.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Forgot Password'), backgroundColor: AppTheme.primaryDark, foregroundColor: Colors.white),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: _sent
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(color: AppTheme.success.withValues(alpha: 0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.mark_email_read_outlined, color: AppTheme.success, size: 40),
                    ),
                    const SizedBox(height: 20),
                    const Text('Email Sent!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    Text('Password reset instructions have been sent to ${_emailCtrl.text}', textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textMuted)),
                    const SizedBox(height: 28),
                    GradientButton(label: 'Back to Login', onPressed: () => Navigator.pop(context)),
                  ],
                )
              : Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Reset Password', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      const Text('Enter your email and we\'ll send you a reset link.', style: TextStyle(color: AppTheme.textMuted)),
                      const SizedBox(height: 28),
                      AppTextField(
                        label: 'Email Address',
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: Icons.email_outlined,
                        validator: (v) { if (v == null || v.isEmpty) return 'Email required'; if (!v.contains('@')) return 'Invalid email'; return null; },
                      ),
                      const SizedBox(height: 24),
                      GradientButton(label: 'Send Reset Link', icon: Icons.send_outlined, loading: auth.loading, onPressed: _submit),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
