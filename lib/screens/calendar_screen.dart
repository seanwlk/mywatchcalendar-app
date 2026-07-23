import 'package:flutter/material.dart';
import '../models.dart';
import '../services/api_client.dart';
import '../widgets/episode_card.dart';
import 'episode_info_screen.dart';
import 'series_info_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final _scrollController = ScrollController();
  final List<MapEntry<Series, Episode>> _futureItems = [];
  final List<MapEntry<Series, Episode>> _pastItems = [];

  bool _loadingFuture = false;
  bool _loadingPast = false;
  bool _hasMoreFuture = true;
  bool _hasMorePast = true;
  bool _failed = false;
  int _futurePage = 1;
  int _pastPage = 1;

  static const int _pageSize = 30;
  final Key _centerKey = const ValueKey('calendar-center');

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load(past: false);
    _load(past: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_loadingFuture &&
        _hasMoreFuture &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 120) {
      _load(past: false);
    }
    if (!_loadingPast &&
        _hasMorePast &&
        _scrollController.position.pixels <=
            _scrollController.position.minScrollExtent + 120) {
      _load(past: true);
    }
  }

  Future<void> _load({required bool past}) async {
    if (past ? _loadingPast : _loadingFuture) return;
    setState(() {
      if (past) {
        _loadingPast = true;
      } else {
        _loadingFuture = true;
      }
    });
    final items = await ApiClient.instance.fetchCalendarEpisodes(
      page: past ? _pastPage : _futurePage,
      pageSize: _pageSize,
      direction: past ? 'past' : 'future',
    );
    if (!mounted) return;
    setState(() {
      if (items == null) {
        _failed = _futureItems.isEmpty && _pastItems.isEmpty;
        if (past) {
          _hasMorePast = false;
          _loadingPast = false;
        } else {
          _hasMoreFuture = false;
          _loadingFuture = false;
        }
        return;
      }
      final target = past ? _pastItems : _futureItems;
      if (items.isNotEmpty) {
        target.addAll(items);
        if (past) {
          _pastPage++;
        } else {
          _futurePage++;
        }
      }
      if (past) {
        _hasMorePast = items.length == _pageSize;
        _loadingPast = false;
      } else {
        _hasMoreFuture = items.length == _pageSize;
        _loadingFuture = false;
      }
    });
  }

  Future<void> _refresh() async {
    setState(() {
      _futureItems.clear();
      _pastItems.clear();
      _futurePage = 1;
      _pastPage = 1;
      _hasMoreFuture = true;
      _hasMorePast = true;
      _failed = false;
    });
    await Future.wait([_load(past: false), _load(past: true)]);
  }

  Future<void> _refreshEpisode(
    Series series,
    Episode episode,
    List<MapEntry<Series, Episode>> items,
  ) async {
    final refreshedEpisode = await ApiClient.instance.getEpisode(episode.id);
    final index = items.indexWhere((e) => e.value.id == episode.id);

    if (!mounted) return;

    setState(() {
      if (refreshedEpisode != null && index != -1) {
        items[index] = MapEntry(series, refreshedEpisode);
      }
    });
  }

  Future<void> _toggleWatched(Episode episode) async {
    final bool newStatus = !episode.watched;
    final String episodeId = episode.id;

    setState(() {
      episode.watched = newStatus;
    });

    final success = await ApiClient.instance.markEpisodeWatched(
      episodeId,
      newStatus,
    );

    if (!mounted) return;

    if (!success) {
      setState(() {
        episode.watched = !newStatus;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to update status')));
    }
  }

  String _formatDateLabel(DateTime date) {
    final targetDate = DateTime(date.year, date.month, date.day);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final yesterday = today.add(const Duration(days: -1));

    if (targetDate == today) {
      return 'Today';
    } else if (targetDate == tomorrow) {
      return 'Tomorrow';
    } else if (targetDate == yesterday) {
      return 'Yesterday';
    } else {
      return targetDate.toLocal().toString().split(' ')[0];
    }
  }

  Widget _buildItem(
    MapEntry<Series, Episode> entry,
    bool showDayChip,
    List<MapEntry<Series, Episode>> items,
    DateTime today,
  ) {
    final episode = entry.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showDayChip)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: Chip(
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: const VisualDensity(
                  horizontal: -2,
                  vertical: -3,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                label: Text(
                  _formatDateLabel(episode.airDate),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        EpisodeCard(
          series: entry.key,
          episode: episode,
          today: today,
          onSeriesTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SeriesInfoScreen(series: entry.key),
              ),
            );

            _refreshEpisode(entry.key, entry.value, items);
          },
          onEpisodeTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    EpisodeInfoScreen(series: entry.key, episode: entry.value),
              ),
            );

            _refreshEpisode(entry.key, entry.value, items);
          },
          onMarkWatched: () => _toggleWatched(episode),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final bool isEmpty =
        !_loadingFuture &&
        !_loadingPast &&
        _futureItems.isEmpty &&
        _pastItems.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: (_loadingFuture || _loadingPast) ? null : _refresh,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: isEmpty
          ? RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.sizeOf(context).height * 0.25),
                  Center(
                    child: Column(
                      children: [
                        Icon(
                          _failed ? Icons.cloud_off : Icons.event_available,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _failed
                              ? "Couldn't load the calendar"
                              : 'No episodes on your calendar yet',
                        ),
                        const SizedBox(height: 12),
                        if (_failed)
                          FilledButton.icon(
                            onPressed: _refresh,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : CustomScrollView(
              controller: _scrollController,
              center: _centerKey,
              slivers: [
                SliverOpacity(
                  opacity: 0.7,
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, idx) {
                      if (idx >= _pastItems.length) {
                        return const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(child: LinearProgressIndicator()),
                        );
                      }
                      final entry = _pastItems[idx];
                      final date = entry.value.airDate;
                      bool showChip = false;
                      if (idx == _pastItems.length - 1) {
                        showChip = true;
                      } else {
                        final prevDate = _pastItems[idx + 1].value.airDate;
                        showChip =
                            date.day != prevDate.day ||
                            date.month != prevDate.month;
                      }
                      return _buildItem(entry, showChip, _pastItems, today);
                    }, childCount: _pastItems.length + (_loadingPast ? 1 : 0)),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Divider(thickness: 2, height: 1),
                  ),
                ),
                SliverList(
                  key: _centerKey,
                  delegate: SliverChildBuilderDelegate(
                    (context, idx) {
                      if (idx >= _futureItems.length) {
                        return const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final entry = _futureItems[idx];
                      final date = entry.value.airDate;

                      bool showChip = false;
                      if (idx == 0) {
                        showChip = true;
                      } else {
                        final prevDate = _futureItems[idx - 1].value.airDate;
                        showChip =
                            date.day != prevDate.day ||
                            date.month != prevDate.month;
                      }
                      return _buildItem(entry, showChip, _futureItems, today);
                    },
                    childCount: _futureItems.length + (_loadingFuture ? 1 : 0),
                  ),
                ),
              ],
            ),
    );
  }
}
