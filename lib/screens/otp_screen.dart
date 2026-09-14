import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/api_provider.dart';
import '../theme.dart';

class OtpScreen extends StatefulWidget {
  final String email;
  final OtpType type;
  final String? password;

  const OtpScreen({Key? key, required this.email, required this.type, this.password}) : super(key: key);

  @override
  _OtpScreenState createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _codeController = TextEditingController();
  bool _isLoading = false;

  Future<void> _verifyOTP() async {
    final code = _codeController.text.trim();
    if (code.isEmpty || code.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Please enter a valid verification code.'), backgroundColor: Theme.of(context).colorScheme.error),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (widget.type == OtpType.signup) {
        // Custom OTP flow for signup
        await Provider.of<ApiProvider>(context, listen: false).verifyOTP(widget.email, code);
        // After backend successfully verifies and creates the user, log them in natively!
        if (widget.password != null) {
          await Supabase.instance.client.auth.signInWithPassword(
            email: widget.email,
            password: widget.password!,
          );
        }
      } else {
        // Fallback for other OTP types (like recovery) if needed later
        await Supabase.instance.client.auth.verifyOTP(
          type: widget.type,
          email: widget.email,
          token: code,
        );
      }
      
      // Once verified and logged in, AuthWrapper automatically routes to Dashboard.
      if (mounted) {
        Navigator.pop(context); // Pop OTP screen, AuthWrapper will handle the rest.
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString().replaceAll('Exception: ', '')), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Verify Email'),
        backgroundColor: AppTheme.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.primary),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.mark_email_unread, size: 80, color: AppTheme.primary),
              const SizedBox(height: 24),
              const Text(
                'Enter Verification Code',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'A verification code has been sent to\n${widget.email}',
                style: const TextStyle(fontSize: 16, color: Colors.black87),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              TextField(
                controller: _codeController,
                decoration: InputDecoration(
                  hintText: 'Code',
                  filled: true,
                  fillColor: Colors.black.withOpacity(0.03),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.password, color: Colors.grey),
                ),
                style: const TextStyle(color: Colors.black87, fontSize: 24, letterSpacing: 8),
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 10,
              ),
              const SizedBox(height: 24),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else
                ElevatedButton(
                  onPressed: _verifyOTP,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Verify', style: TextStyle(fontSize: 16, color: Colors.white)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }
}
