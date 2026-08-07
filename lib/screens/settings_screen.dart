import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/auth_service.dart';
import '../services/settings_service.dart';
import '../services/widget_updater.dart';
import '../services/api_client.dart';
import './admin_screen.dart';

enum SettingsResult { none, logout }

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _endpointController = TextEditingController();
  AppThemeChoice _choice = SettingsService.instance.themeChoice.value;
  bool _savingEndpoint = false;
  int _widgetInterval = SettingsService.instance.widgetIntervalMinutes;
  String _appVersion = '';

  static const Map<int, String> _widgetIntervals = {
    15: 'Every 15 minutes',
    30: 'Every 30 minutes',
    60: 'Every hour',
    180: 'Every 3 hours',
    360: 'Every 6 hours',
    720: 'Every 12 hours',
    1440: 'Once a day',
  };

  @override
  void initState() {
    super.initState();
    _endpointController.text =
        SettingsService.instance.siteUrlOverride ??
        AuthService.instance.siteUrl ??
        '';
        
    _loadVersion();
  }
  
  Future<void> _loadVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appVersion = '${packageInfo.version} (${packageInfo.buildNumber})';
      });
    }
  }

  @override
  void dispose() {
    _endpointController.dispose();
    super.dispose();
  }

  Future<void> _saveEndpoint() async {
    final text = _endpointController.text.trim();
    if (text.isEmpty) {
      return;
    }
    setState(() => _savingEndpoint = true);
    final changed = await SettingsService.instance.updateSiteUrl(text);
    if (changed) {
      await AuthService.instance.updateSiteUrl(text);
    }
    setState(() => _savingEndpoint = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(changed ? 'Endpoint updated' : 'Endpoint unchanged'),
        ),
      );
    }
  }

  Future<void> _openGithub() async {
    const url = 'https://github.com/seanwlk/mywatchcalendar-app';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _selectTheme(AppThemeChoice choice) async {
    setState(() => _choice = choice);
    await SettingsService.instance.updateTheme(choice);
  }

  Future<void> _selectWidgetInterval(int minutes) async {
    setState(() => _widgetInterval = minutes);
    await SettingsService.instance.updateWidgetInterval(minutes);
    await WidgetUpdater.initialize(intervalMinutes: minutes);
  }

  void _logout() {
    Navigator.of(context).pop(SettingsResult.logout);
  }

  Future<void> _showChangePasswordDialog() async {
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    final success = await showDialog<bool>(
      context: context,
      builder: (context) {
        bool isSubmitting = false;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Change Password'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: passwordController,
                    decoration: const InputDecoration(
                      labelText: 'New Password',
                      hintText: 'Min. 8 characters',
                    ),
                    obscureText: true,
                    enabled: !isSubmitting,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: confirmPasswordController,
                    decoration: const InputDecoration(
                      labelText: 'Confirm Password',
                    ),
                    obscureText: true,
                    enabled: !isSubmitting,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final newPassword = passwordController.text;
                          final confirmPassword =
                              confirmPasswordController.text;

                          if (newPassword.length < 8) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Password must be at least 8 characters',
                                ),
                              ),
                            );
                            return;
                          }

                          if (newPassword != confirmPassword) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Passwords do not match'),
                              ),
                            );
                            return;
                          }

                          setState(() => isSubmitting = true);
                          final result = await ApiClient.instance
                              .selfChangePassword(newPassword);

                          if (context.mounted) {
                            Navigator.pop(context, result);
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted) return;

    if (success == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password changed successfully')),
      );
    } else if (success == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to change password')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            if (!kIsWeb) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _endpointController,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Server URL',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _savingEndpoint ? null : _saveEndpoint,
                child: _savingEndpoint
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save Server URL'),
              ),
              const SizedBox(height: 24),
            ],
            const Text(
              'Theme',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            RadioGroup<AppThemeChoice>(
              groupValue: _choice,
              onChanged: (value) {
                if (value != null) {
                  _selectTheme(value);
                }
              },
              child: Column(
                children: [
                  RadioListTile<AppThemeChoice>(
                    title: const Text('AMOLED with blue accent'),
                    value: AppThemeChoice.amoledBlue,
                  ),
                  RadioListTile<AppThemeChoice>(
                    title: const Text('AMOLED with red accent'),
                    value: AppThemeChoice.amoledRed,
                  ),
                  RadioListTile<AppThemeChoice>(
                    title: const Text('White theme with blue accent'),
                    value: AppThemeChoice.whiteBlue,
                  ),
                  RadioListTile<AppThemeChoice>(
                    title: const Text('White theme with red accent'),
                    value: AppThemeChoice.whiteRed,
                  ),
                  RadioListTile<AppThemeChoice>(
                    title: const Text('Material You style'),
                    value: AppThemeChoice.materialYou,
                  ),
                ],
              ),
            ),

            if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) ...[
              const SizedBox(height: 24),
              const Text(
                'Home screen widget',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Refresh interval'),
                subtitle: const Text(
                  'How often the widget updates in the background',
                ),
                trailing: DropdownButton<int>(
                  value: _widgetInterval,
                  onChanged: (value) {
                    if (value != null) {
                      _selectWidgetInterval(value);
                    }
                  },
                  items: _widgetIntervals.entries
                      .map(
                        (e) => DropdownMenuItem<int>(
                          value: e.key,
                          child: Text(e.value),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
            if (AuthService.instance.isAdmin) ...[
              const SizedBox(height: 24),
              ListTile(
                title: const Text('Admin Dashboard'),
                leading: const Icon(Icons.admin_panel_settings),
                iconColor: Theme.of(context).colorScheme.primary,
                textColor: Theme.of(context).colorScheme.primary,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminScreen()),
                  );
                },
              ),
            ],
            const SizedBox(height: 24),
            ListTile(
              title: const Text('Open GitHub page'),
              leading: const Icon(Icons.open_in_new),
              onTap: _openGithub,
            ),
            ListTile(
              title: const Text('Change Password'),
              leading: const Icon(Icons.lock_reset),
              onTap: _showChangePasswordDialog,
            ),
            ListTile(
              title: const Text('Logout'),
              leading: const Icon(Icons.logout),
              onTap: _logout,
            ),
            if (_appVersion.isNotEmpty) ...[
              const SizedBox(height: 24),
              Center(
                child: Text(
                  'Version $_appVersion',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }
}
