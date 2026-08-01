import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'settings_screen.dart';
import 'series_info_screen.dart';
import 'followed_series_screen.dart';
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
  List<FollowedSeriesItem>? _followedSeries;
  bool _isLoading = true;

  final ScrollController _carouselScrollController = ScrollController();
  int _carouselPage = 1;
  bool _isCarouselLoading = false;
  bool _carouselHasMore = true;
  static const int _carouselPageSize = 15;

  @override
  void initState() {
    super.initState();
    _carouselScrollController.addListener(_onCarouselScroll);
    _loadProfileData();
  }

  @override
  void dispose() {
    _carouselScrollController.dispose();
    super.dispose();
  }

  void _onCarouselScroll() {
    if (!_isCarouselLoading &&
        _carouselHasMore &&
        _carouselScrollController.position.pixels >=
            _carouselScrollController.position.maxScrollExtent - 120) {
      _loadNextCarouselPage();
    }
  }

  Future<void> _loadNextCarouselPage() async {
    if (_isCarouselLoading || !_carouselHasMore) return;

    setState(() => _isCarouselLoading = true);

    try {
      final nextItems = await ApiClient.instance.fetchFollowedSeries(
        page: _carouselPage,
        pageSize: _carouselPageSize,
      );

      if (!mounted) return;

      setState(() {
        if (nextItems != null && nextItems.isNotEmpty) {
          _followedSeries?.addAll(nextItems);
          _carouselPage++;

          if (nextItems.length < _carouselPageSize) {
            _carouselHasMore = false;
          }
        } else {
          _carouselHasMore = false;
        }
      });
    } finally {
      if (mounted) setState(() => _isCarouselLoading = false);
    }
  }

  Future<void> _loadProfileData() async {
    if (_stats == null || _followedSeries == null) {
      setState(() => _isLoading = true);
    }

    _carouselPage = 1;
    _carouselHasMore = true;

    try {
      final results = await Future.wait([
        ApiClient.instance.fetchUserStats(),
        ApiClient.instance.fetchFollowedSeries(
          page: _carouselPage,
          pageSize: _carouselPageSize,
        ),
      ]);

      if (!mounted) return;

      setState(() {
        _stats = results[0] as UserStats?;
        _followedSeries = results[1] as List<FollowedSeriesItem>?;

        if (_followedSeries != null) {
          _carouselPage++;
          if (_followedSeries!.length < _carouselPageSize) {
            _carouselHasMore = false;
          }
        }
      });
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
            onPressed: _isLoading ? null : _loadProfileData,
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
          : (_stats == null && _followedSeries == null)
          ? RefreshIndicator(
              onRefresh: _loadProfileData,
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
                          onPressed: _loadProfileData,
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
              onRefresh: _loadProfileData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    _buildProfileHeader(colorScheme),
                    const SizedBox(height: 32),
                    _buildStatsSection(colorScheme),
                    const SizedBox(height: 32),
                    _buildFollowedCarousel(colorScheme),
                    const SizedBox(height: 32),
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

  Widget _buildFollowedCarousel(ColorScheme colorScheme) {
    if (_followedSeries == null || _followedSeries!.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FollowedSeriesScreen()),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Followed Series',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 180,
          child: ListView.builder(
            controller: _carouselScrollController,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            itemCount: _followedSeries!.length + (_isCarouselLoading ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= _followedSeries!.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final item = _followedSeries![index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: GestureDetector(
                  onTap: () {
                    final placeholderSeries = Series(
                      id: item.id,
                      title: item.title,
                      posterUrl: item.posterUrl,
                      description: '',
                      releaseDate: null,
                      seasons: [],
                      isFollowed: true,
                      isDropped: item.isDropped,
                    );

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            SeriesInfoScreen(series: placeholderSeries),
                      ),
                    ).then((_) => _loadProfileData());
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: item.posterUrl,
                      width: 120,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => Container(
                        width: 120,
                        color: colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.broken_image),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
