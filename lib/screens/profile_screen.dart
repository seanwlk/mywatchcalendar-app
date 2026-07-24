import 'package:flutter/material.dart';
import 'settings_screen.dart';
import '../services/api_client.dart';
import '../models.dart';

class ProfileScreen extends StatefulWidget {
  final String username;
  final VoidCallback onLogout;

  const ProfileScreen({
    super.key,
    required this.username,
    required this.onLogout,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserStats? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    // Only show the full-screen spinner when there is nothing to display;
    // a pull-to-refresh over existing stats keeps them visible.
    if (_stats == null) setState(() => _isLoading = true);
    try {
      final stats = await ApiClient.instance.fetchUserStats();
      if (!mounted) return;
      setState(() => _stats = stats);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatWatchTime(int totalMinutes) {
    if (totalMinutes == 0) return '0h';

    const int minutesInHour = 60;
    const int minutesInDay = 24 * minutesInHour;
    const int minutesInMonth = 30 * minutesInDay;

    final months = totalMinutes ~/ minutesInMonth;
    final remainingAfterMonths = totalMinutes % minutesInMonth;

    final days = remainingAfterMonths ~/ minutesInDay;
    final remainingAfterDays = remainingAfterMonths % minutesInDay;

    final hours = remainingAfterDays ~/ minutesInHour;

    if (months > 0) {
      return '${months}mo ${days}d ${hours}h';
    } else if (days > 0) {
      return '${days}d ${hours}h';
    }
    return '${hours}h';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadStats,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              final result = await Navigator.of(context).push<SettingsResult>(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
              if (result == SettingsResult.logout) {
                widget.onLogout();
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _stats == null
          ? RefreshIndicator(
              onRefresh: _loadStats,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.sizeOf(context).height * 0.25),
                  Center(
                    child: Column(
                      children: [
                        const Icon(Icons.cloud_off, size: 48),
                        const SizedBox(height: 12),
                        const Text("Couldn't load your stats"),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _loadStats,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadStats,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    _buildProfileHeader(colorScheme),
                    const SizedBox(height: 32),
                    _buildStatsSection(colorScheme),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildProfileHeader(ColorScheme colorScheme) {
    final initial = widget.username.isNotEmpty
        ? widget.username[0].toUpperCase()
        : 'U';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colorScheme.primary.withValues(alpha: 0.2),
            colorScheme.surface,
          ],
        ),
      ),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 50,
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              child: Text(
                initial,
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.username,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(ColorScheme colorScheme) {
    final seriesCount = _stats?.totalSeries.toString() ?? '0';
    final episodesCount = _stats?.totalEpisodesWatched.toString() ?? '0';
    final timeSpent = _formatWatchTime(_stats?.totalTimeMinutes ?? 0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Statistics',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _statCard(
                label: 'Series Tracked',
                value: seriesCount,
                icon: Icons.tv_rounded,
                color: Colors.blueAccent,
              ),
              const SizedBox(width: 12),
              _statCard(
                label: 'Episodes Seen',
                value: episodesCount,
                icon: Icons.play_circle_fill_rounded,
                color: Colors.redAccent,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _statCard(
                label: 'Time Spent Watching',
                value: timeSpent,
                icon: Icons.timer_rounded,
                color: Colors.amber.shade700,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Card(
        elevation: 4,
        shadowColor: Colors.black26,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
