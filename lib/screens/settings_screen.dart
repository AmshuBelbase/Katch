import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  User? _user;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _user = Supabase.instance.client.auth.currentUser;
  }

  Future<void> _updateField(String field, String currentValue, Future<void> Function(String) onUpdate) async {
    final controller = TextEditingController(text: currentValue);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text('Update $field'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Enter new $field',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result != currentValue && result.isNotEmpty) {
      setState(() => _isLoading = true);
      try {
        await onUpdate(result);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$field updated successfully!'), backgroundColor: AppTheme.success),
          );
          setState(() {
            _user = Supabase.instance.client.auth.currentUser;
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update $field: $e'), backgroundColor: AppTheme.error),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _changePassword() async {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(hintText: 'New Password'),
              obscureText: true,
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmController,
              decoration: const InputDecoration(hintText: 'Confirm New Password'),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (passwordController.text == confirmController.text && passwordController.text.isNotEmpty) {
                Navigator.pop(context, true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Passwords do not match or are empty'), backgroundColor: AppTheme.error),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true) {
      setState(() => _isLoading = true);
      try {
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(password: passwordController.text),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Password updated successfully!'), backgroundColor: AppTheme.success),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update password: $e'), backgroundColor: AppTheme.error),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGoogleProvider = _user?.appMetadata['provider'] == 'google';
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text('Profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                ),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.person),
                        title: const Text('Name'),
                        subtitle: Text(_user?.userMetadata?['name'] ?? 'Not set'),
                        trailing: isGoogleProvider ? null : const Icon(Icons.edit, size: 20),
                        onTap: isGoogleProvider ? null : () => _updateField('Name', _user?.userMetadata?['name'] ?? '', (val) async {
                          await Supabase.instance.client.auth.updateUser(UserAttributes(data: {'name': val}));
                        }),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.email),
                        title: const Text('Email'),
                        subtitle: Text(_user?.email ?? 'Not set'),
                        trailing: isGoogleProvider ? null : const Icon(Icons.edit, size: 20),
                        onTap: isGoogleProvider ? null : () => _updateField('Email', _user?.email ?? '', (val) async {
                          await Supabase.instance.client.auth.updateUser(UserAttributes(email: val));
                        }),
                      ),
                    ],
                  ),
                ),
                if (!isGoogleProvider) ...[
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text('Security', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                  ),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.lock),
                      title: const Text('Change Password'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _changePassword,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text('App Experience', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                ),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.school),
                    title: const Text('Reset Tutorial'),
                    subtitle: const Text('Play the coach mark tutorial again'),
                    trailing: const Icon(Icons.refresh),
                    onTap: () async {
                      setState(() => _isLoading = true);
                      try {
                        await Supabase.instance.client.auth.updateUser(
                          UserAttributes(data: {
                            'has_seen_initial_onboarding': false, 
                            'last_seen_app_version': '0.0.0'
                          }),
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: const Text('Tutorial reset! Restart the app to see it.'), backgroundColor: AppTheme.success),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _isLoading = false);
                      }
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
