import 'package:flutter/material.dart';
import '../models.dart';
import '../services/api_client.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  List<AdminUser>? _users;
  bool _isLoading = true;
  final _tmdbController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  @override
  void dispose() {
    _tmdbController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    final users = await ApiClient.instance.fetchAllUsers();
    if (mounted) {
      setState(() {
        _users = users;
        _isLoading = false;
      });
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _handleSyncAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sync All Series'),
        content: const Text(
          'This will trigger a full metadata sync for all series in the database. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sync'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await ApiClient.instance.syncAllSeries();
      _showSnackBar(
        success ? 'Full sync job added to queue' : 'Failed to trigger sync',
      );
    }
  }

  Future<void> _handleSyncSingle() async {
    final text = _tmdbController.text.trim();
    if (text.isEmpty) return;

    final tmdbId = int.tryParse(text);
    if (tmdbId == null) {
      _showSnackBar('Invalid TMDB ID');
      return;
    }

    final success = await ApiClient.instance.syncSingleSeries(tmdbId);
    _showSnackBar(
      success
          ? 'Sync job for $tmdbId added to queue'
          : 'Failed to trigger sync',
    );
    _tmdbController.clear();
  }

  Future<void> _showUserDialog({AdminUser? user}) async {
    final isNew = user == null;
    final usernameController = TextEditingController(text: user?.username);
    final nameController = TextEditingController(text: user?.name);
    final passwordController = TextEditingController();
    bool isAdmin = user?.isAdmin ?? false;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isNew ? 'Create User' : 'Edit User'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: usernameController,
                      decoration: const InputDecoration(labelText: 'Username'),
                    ),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                    if (isNew)
                      TextField(
                        controller: passwordController,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                        ),
                        obscureText: true,
                      ),
                    SwitchListTile(
                      title: const Text('Admin'),
                      value: isAdmin,
                      onChanged: (val) => setDialogState(() => isAdmin = val),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    bool success;
                    if (isNew) {
                      if (passwordController.text.length < 8) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Password must be at least 8 characters',
                            ),
                          ),
                        );
                        return;
                      }
                      success = await ApiClient.instance.createAdminUser(
                        usernameController.text,
                        passwordController.text,
                        nameController.text,
                        isAdmin,
                      );
                    } else {
                      success = await ApiClient.instance.updateAdminUser(
                        user.id,
                        username: usernameController.text,
                        name: nameController.text,
                        isAdmin: isAdmin,
                      );
                    }
                    if (context.mounted) Navigator.pop(context, success);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) _fetchUsers();
  }

  Future<void> _resetPasswordDialog(AdminUser user) async {
    final passwordController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Reset Password for ${user.username}'),
        content: TextField(
          controller: passwordController,
          decoration: const InputDecoration(labelText: 'New Password'),
          obscureText: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final success = await ApiClient.instance.resetUserPassword(
                user.id,
                passwordController.text,
              );
              if (mounted) Navigator.pop(context, success);
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (result == true) _showSnackBar('Password reset successfully');
  }

  Future<void> _deleteUserDialog(AdminUser user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete User'),
        content: Text(
          'Are you sure you want to permanently delete ${user.username}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final success = await ApiClient.instance.deleteAdminUser(user.id);
              if (mounted) Navigator.pop(context, success);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) _fetchUsers();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Dashboard'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.people), text: 'Users'),
              Tab(icon: Icon(Icons.sync), text: 'Jobs & Sync'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // USERS TAB
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _fetchUsers,
                    child: ListView.builder(
                      itemCount: _users?.length ?? 0,
                      itemBuilder: (context, index) {
                        final user = _users![index];
                        return ListTile(
                          leading: CircleAvatar(
                            child: Icon(
                              user.isAdmin
                                  ? Icons.admin_panel_settings
                                  : Icons.person,
                            ),
                          ),
                          title: Text(user.username),
                          subtitle: Text(user.name),
                          trailing: PopupMenuButton<String>(
                            onSelected: (val) {
                              if (val == 'edit') _showUserDialog(user: user);
                              if (val == 'reset') _resetPasswordDialog(user);
                              if (val == 'delete') _deleteUserDialog(user);
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit'),
                              ),
                              const PopupMenuItem(
                                value: 'reset',
                                child: Text('Reset Password'),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text(
                                  'Delete',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
            // SYNC TAB
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView(
                children: [
                  Card(
                    child: ListTile(
                      title: const Text('Full Database Sync'),
                      subtitle: const Text(
                        'Run metadata updates on all tracked series.',
                      ),
                      trailing: FilledButton(
                        onPressed: _handleSyncAll,
                        child: const Text('Run'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Sync Specific Series',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _tmdbController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'TMDB ID',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              FilledButton(
                                onPressed: _handleSyncSingle,
                                child: const Text('Sync'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: Builder(
          builder: (context) {
            final tabController = DefaultTabController.of(context);
            return AnimatedBuilder(
              animation: tabController,
              builder: (context, _) {
                return tabController.index == 0
                    ? FloatingActionButton(
                        onPressed: () => _showUserDialog(),
                        child: const Icon(Icons.person_add),
                      )
                    : const SizedBox.shrink();
              },
            );
          },
        ),
      ),
    );
  }
}
