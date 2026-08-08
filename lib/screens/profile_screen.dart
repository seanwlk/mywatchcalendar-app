import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'settings_screen.dart';
import 'series_info_screen.dart';
import 'followed_series_screen.dart';
import '../services/api_client.dart';
import '../models.dart';

class GraphBarData {
  final String label;
  final DateTime start;
  final DateTime end;
  int episodes = 0;
  int watchTime = 0;

  final List<WatchHistoryRecord> records = [];

  GraphBarData(this.label, this.start, this.end);
}

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

  String _graphPeriod = 'day'; 
  String _graphMetric = 'episodes'; 
  
  final List<GraphBarData> _graphData = [];
  bool _isGraphLoading = false;
  bool _graphHasMore = true;
  DateTime? _currentGraphEndDate;
  final ScrollController _graphScrollController = ScrollController();

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  static const List<String> _fullMonths = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  static const List<String> _weekdays = [
    '', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
  ];

  static const List<String> _fullWeekdays = [
    '', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];

  @override
  void initState() {
    super.initState();
    _carouselScrollController.addListener(_onCarouselScroll);
    _graphScrollController.addListener(_onGraphScroll);
    _loadProfileData();
    _loadGraphData(reset: true);
  }

  @override
  void dispose() {
    _carouselScrollController.dispose();
    _graphScrollController.dispose();
    super.dispose();
  }

  void _onGraphScroll() {
    if (!_isGraphLoading &&
        _graphHasMore &&
        _graphScrollController.position.pixels >=
            _graphScrollController.position.maxScrollExtent - 120) {
      _loadGraphData();
    }
  }

  Future<void> _loadGraphData({bool reset = false}) async {
    if (_isGraphLoading) return;
    if (reset) {
      _currentGraphEndDate = DateTime.now();
      _graphData.clear();
      _graphHasMore = true;
    }
    if (!_graphHasMore) return;

    setState(() => _isGraphLoading = true);

    try {
      DateTime end = _currentGraphEndDate ?? DateTime.now();
      List<GraphBarData> newBars = [];
      DateTime currentBinEnd = end;

      int numBins = 0;
      if (_graphPeriod == 'day') {
        numBins = 60;
      } else if (_graphPeriod == 'week') {
        numBins = 24;
      } else if (_graphPeriod == 'month') {
        numBins = 12;
      } else if (_graphPeriod == 'year') {
        numBins = 5;
      }

      DateTime chunkStart = end;

      for (int i = 0; i < numBins; i++) {
        DateTime binStart;
        String label;
        if (_graphPeriod == 'day') {
           binStart = DateTime(currentBinEnd.year, currentBinEnd.month, currentBinEnd.day);
           label = '${_months[binStart.month - 1]} ${binStart.day}';
        } else if (_graphPeriod == 'week') {
           int daysToSubtract = currentBinEnd.weekday - 1;
           binStart = DateTime(currentBinEnd.year, currentBinEnd.month, currentBinEnd.day - daysToSubtract);
           label = '${_months[binStart.month - 1]} ${binStart.day}';
        } else if (_graphPeriod == 'month') {
           binStart = DateTime(currentBinEnd.year, currentBinEnd.month, 1);
           label = _months[binStart.month - 1]; 
        } else { 
           binStart = DateTime(currentBinEnd.year, 1, 1);
           label = '${binStart.year}';
        }

        newBars.add(GraphBarData(label, binStart, currentBinEnd));
        chunkStart = binStart;
        currentBinEnd = binStart.subtract(const Duration(milliseconds: 1));
      }

      final response = await ApiClient.instance.fetchWatchHistory(
        start: chunkStart, 
        end: end,
      );

      if (response != null) {
        for (var record in response.records) {
          for (var bar in newBars) {
             if (record.date.isAfter(bar.start.subtract(const Duration(milliseconds: 1))) && 
                 record.date.isBefore(bar.end.add(const Duration(milliseconds: 1)))) {
                bar.episodes++;
                bar.watchTime += record.runtime;
                bar.records.add(record);
                break;
             }
          }
        }
        
        if (mounted) {
          setState(() {
            _graphData.addAll(newBars);
            _currentGraphEndDate = currentBinEnd;
            _graphHasMore = response.hasMore; 
            _isGraphLoading = false;
          });
          
          WidgetsBinding.instance.addPostFrameCallback((_) {
             if (mounted && _graphHasMore && _graphScrollController.hasClients) {
               if (_graphScrollController.position.pixels >= _graphScrollController.position.maxScrollExtent - 120) {
                 _loadGraphData();
               }
             }
          });
        }
      } else {
         if (mounted) {
           setState(() {
             _isGraphLoading = false;
             _graphHasMore = false;
           });
         }
      }

    } catch (e) {
      if (mounted) setState(() => _isGraphLoading = false);
    }
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

  void _showBarDetails(GraphBarData bar, BuildContext context) {
    if (bar.episodes == 0) return; 

    String modalTitle = '';
    
    if (_graphPeriod == 'year') {
      modalTitle = '${bar.start.year}';
    } else if (_graphPeriod == 'month') {
      modalTitle = '${_fullMonths[bar.start.month - 1]} ${bar.start.year}';
    } else if (_graphPeriod == 'week') {
      String firstDay = bar.start.day.toString().padLeft(2, '0');
      String lastDay = bar.end.day.toString().padLeft(2, '0');
      modalTitle = '$firstDay-$lastDay ${_months[bar.end.month - 1]} ${bar.end.year}';
    } else if (_graphPeriod == 'day') {
      String padDay = bar.start.day.toString().padLeft(2, '0');
      modalTitle = '$padDay ${_fullWeekdays[bar.start.weekday]} - ${_months[bar.start.month - 1]} ${bar.start.year}';
    }

    Map<String, Map<String, dynamic>> groupedData = {};

    for (var r in bar.records) {
      String groupKey = '';
      String displayLabel = '';

      if (_graphPeriod == 'year') {
        groupKey = r.date.month.toString();
        displayLabel = _fullMonths[r.date.month - 1];
      } else if (_graphPeriod == 'month' || _graphPeriod == 'week') {
        groupKey = r.date.day.toString();
        String dayNum = r.date.day.toString().padLeft(2, '0');
        String dayName = _weekdays[r.date.weekday];
        displayLabel = '$dayNum $dayName';
      } else if (_graphPeriod == 'day') {
        groupKey = 'Total';
        displayLabel = 'Total';
      }

      if (!groupedData.containsKey(groupKey)) {
        groupedData[groupKey] = {'label': displayLabel, 'episodes': 0, 'runtime': 0};
      }
      
      groupedData[groupKey]!['episodes'] += 1;
      groupedData[groupKey]!['runtime'] += r.runtime;
    }

    var sortedKeys = groupedData.keys.toList()..sort((a, b) {
      if (a == 'Total') return 0;
      return int.parse(a).compareTo(int.parse(b));
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.8,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        modalTitle,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${bar.episodes} Episodes • ${bar.watchTime > 0 ? '${(bar.watchTime / 60).toStringAsFixed(1)}h' : '0h'}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: sortedKeys.length,
                    itemBuilder: (context, index) {
                      final key = sortedKeys[index];
                      final data = groupedData[key]!;
                      
                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.play_circle_outline, color: Theme.of(context).colorScheme.primary),
                        ),
                        title: Text(data['label'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('${data['episodes']} Ep', style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text('${data['runtime']} min', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
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
            onPressed: _isLoading ? null : () async {
              setState(() => _isLoading = true);
              await Future.wait([
                _loadProfileData(),
                _loadGraphData(reset: true),
              ]);
              if (mounted) setState(() => _isLoading = false);
            },
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
              onRefresh: () async {
                await Future.wait([
                  _loadProfileData(),
                  _loadGraphData(reset: true),
                ]);
              },
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
                          onPressed: () async {
                            setState(() => _isLoading = true);
                            await Future.wait([
                              _loadProfileData(),
                              _loadGraphData(reset: true),
                            ]);
                            if (mounted) setState(() => _isLoading = false);
                          },
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
              onRefresh: () async {
                await Future.wait([
                  _loadProfileData(),
                  _loadGraphData(reset: true),
                ]);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    _buildProfileHeader(colorScheme),
                    const SizedBox(height: 32),
                    _buildStatsSection(colorScheme),
                    const SizedBox(height: 32),
                    _buildGraphSection(colorScheme),
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

  Widget _buildGraphSection(ColorScheme colorScheme) {
    double maxVal = _graphData.fold(0.0, (m, b) => math.max(m, _graphMetric == 'episodes' ? b.episodes.toDouble() : b.watchTime.toDouble()));
    if (maxVal == 0) maxVal = 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Watch History',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 4,
                child: SegmentedButton<String>(
                  showSelectedIcon: false,
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    padding: WidgetStateProperty.all(EdgeInsets.zero),
                  ),
                  segments: const [
                    ButtonSegment(value: 'day', label: Text('D', style: TextStyle(fontSize: 12))),
                    ButtonSegment(value: 'week', label: Text('W', style: TextStyle(fontSize: 12))),
                    ButtonSegment(value: 'month', label: Text('M', style: TextStyle(fontSize: 12))),
                    ButtonSegment(value: 'year', label: Text('Y', style: TextStyle(fontSize: 12))),
                  ],
                  selected: {_graphPeriod},
                  onSelectionChanged: (Set<String> newSelection) {
                    setState(() {
                      _graphPeriod = newSelection.first;
                      _loadGraphData(reset: true);
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: SegmentedButton<String>(
                  showSelectedIcon: false,
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    padding: WidgetStateProperty.all(EdgeInsets.zero),
                  ),
                  segments: const [
                    ButtonSegment(value: 'episodes', label: Text('Eps', style: TextStyle(fontSize: 12))),
                    ButtonSegment(value: 'watchTime', label: Text('Time', style: TextStyle(fontSize: 12))),
                  ],
                  selected: {_graphMetric},
                  onSelectionChanged: (Set<String> newSelection) {
                    setState(() => _graphMetric = newSelection.first);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 220,
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                dragDevices: {
                  PointerDeviceKind.touch,
                  PointerDeviceKind.mouse,
                  PointerDeviceKind.trackpad,
                },
              ),
              child: ListView.builder(
                controller: _graphScrollController,
                scrollDirection: Axis.horizontal,
                reverse: false, 
                itemCount: _graphData.length + (_isGraphLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _graphData.length) {
                    return Container(
                      width: 60,
                      alignment: Alignment.center,
                      child: const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    );
                  }
                  
                  final bar = _graphData[index];
                  final val = _graphMetric == 'episodes' ? bar.episodes : bar.watchTime;
                  final height = (val / maxVal) * 140; 
                  
                  Widget barWidget = InkWell(
                    onTap: () => _showBarDetails(bar, context),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 44,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            _graphMetric == 'episodes' 
                                ? '$val' 
                                : (val > 0 ? '${(val / 60).toStringAsFixed(1)}h' : '0'),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).textTheme.bodySmall?.color,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: height > 0 ? height : 4, 
                            decoration: BoxDecoration(
                              color: val > 0 
                                  ? colorScheme.primary 
                                  : colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            bar.label,
                            style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(context).textTheme.bodySmall?.color,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );

                  if (_graphPeriod != 'year') {
                    bool yearChanged = index == 0 || _graphData[index].start.year != _graphData[index - 1].start.year;
                    if (yearChanged) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(bottom: 6, left: 8, right: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${bar.start.year}', 
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          barWidget,
                        ],
                      );
                    }
                  }

                  return barWidget;
                },
              ),
            ),
          ),
        ],
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
              ).then((_) {
                _loadProfileData();
                _loadGraphData(reset: true);
              });
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
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              dragDevices: {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
                PointerDeviceKind.trackpad,
              },
            ),
            child: ListView.builder(
              controller: _carouselScrollController,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              itemCount: _followedSeries!.length + (_isCarouselLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= _followedSeries!.length) {
                  return Container(
                    width: 80,
                    alignment: Alignment.center,
                    child: const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
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
                      ).then((_) {
                        _loadProfileData();
                        _loadGraphData(reset: true);
                      });
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
        ),
      ],
    );
  }
}
