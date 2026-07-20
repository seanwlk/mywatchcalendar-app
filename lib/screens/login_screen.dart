import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class LoginScreen extends StatefulWidget {
  final Future<void> Function(String username, String password, String siteUrl)
  onLogin;
  final String? initialSiteUrl;

  const LoginScreen({super.key, required this.onLogin, this.initialSiteUrl});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _endpointController = TextEditingController();
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _endpointController.text = widget.initialSiteUrl ?? '';
  }

  void _submit() async {
    final endpoint = kIsWeb ? Uri.base.origin : _endpointController.text.trim();

    if (_userController.text.trim().isEmpty ||
        _passController.text.isEmpty ||
        endpoint.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill out all fields.')),
      );
      return;
    }

    setState(() => _loading = true);
    await widget.onLogin(
      _userController.text.trim(),
      _passController.text,
      endpoint,
    );
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgGradient = const LinearGradient(
      colors: [Colors.black, Color(0xFF121212)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: bgGradient),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.topCenter,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 48),
                    child: Card(
                      elevation: 12,
                      shadowColor: Colors.black45,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(32, 64, 32, 32),
                        child: AutofillGroup(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'MyWatchCalendar',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 24),
                              if (!kIsWeb) ...[
                                TextField(
                                  controller: _endpointController,
                                  decoration: InputDecoration(
                                    labelText: 'Server URL',
                                    prefixIcon: const Icon(
                                      Icons.cloud_outlined,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    filled: true,
                                    fillColor: Theme.of(
                                      context,
                                    ).colorScheme.surface,
                                  ),
                                  keyboardType: TextInputType.url,
                                  autofillHints: const [AutofillHints.url],
                                  textInputAction: TextInputAction.next,
                                ),
                                const SizedBox(height: 16),
                              ],
                              TextField(
                                controller: _userController,
                                decoration: InputDecoration(
                                  labelText: 'Username',
                                  prefixIcon: const Icon(Icons.person_outline),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: Theme.of(
                                    context,
                                  ).colorScheme.surface,
                                ),
                                keyboardType: TextInputType.text,
                                autofillHints: const [AutofillHints.username],
                                textInputAction: TextInputAction.next,
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _passController,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: Theme.of(
                                    context,
                                  ).colorScheme.surface,
                                ),
                                obscureText: true,
                                keyboardType: TextInputType.visiblePassword,
                                autofillHints: const [AutofillHints.password],
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _loading ? null : _submit(),
                              ),
                              const SizedBox(height: 32),
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    foregroundColor: Theme.of(
                                      context,
                                    ).colorScheme.onPrimary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 4,
                                  ),
                                  onPressed: _loading ? null : _submit,
                                  child: _loading
                                      ? SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onPrimary,
                                          ),
                                        )
                                      : const Text(
                                          'Sign In',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color.fromARGB(193, 0, 0, 0),
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor: Theme.of(context).primaryColor,
                        child: ClipOval(
                          child: Image.asset(
                            'assets/launcher-icon.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _endpointController.dispose();
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }
}
