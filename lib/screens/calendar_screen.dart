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
  int _futurePage = 1;
  int _pastPage = 1;

  static const int _pageSize = 30;
  final Key _centerKey = const ValueKey('calendar-center');

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadFuture();
    _loadPast();
  }

  void _onScroll() {
    if (!_loadingFuture &&
        _hasMoreFuture &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 120) {
      _loadFuture();
    }
    if (!_loadingPast &&
        _hasMorePast &&
        _scrollController.position.pixels <=
            _scrollController.position.minScrollExtent + 120) {
      _loadPast();
    }
  }

  Future<void> _loadFuture() async {
    if (_loadingFuture) return;
    setState(() => _loadingFuture = true);
    try {
      final items = await ApiClient.instance.fetchCalendarEpisodes(
        page: _futurePage,
        pageSize: _pageSize,
        direction: 'future',
      );
      if (!mounted) return;
      setState(() {
        if (items.isNotEmpty) {
          _futureItems.addAll(items);
          _futurePage++;
        }
        _hasMoreFuture = items.length == _pageSize;
        _loadingFuture = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loadingFuture = false);
    }
  }

  Future<void> _loadPast() async {
    if (_loadingPast) return;
    setState(() => _loadingPast = true);
    try {
      final items = await ApiClient.instance.fetchCalendarEpisodes(
        page: _pastPage,
        pageSize: _pageSize,
        direction: 'past',
      );
      if (!mounted) return;
      setState(() {
        if (items.isNotEmpty) {
          _pastItems.addAll(items);
          _pastPage++;
        }
        _hasMorePast = items.length == _pageSize;
        _loadingPast = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loadingPast = false);
    }
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
    return Scaffold(
      appBar: AppBar(title: const Text('Calendar')),
      body: CustomScrollView(
        controller: _scrollController,
        center: _centerKey,
        slivers: [
          SliverList(
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
                    date.day != prevDate.day || date.month != prevDate.month;
              }
              return Opacity(
                opacity: 0.7,
                child: _buildItem(entry, showChip, _pastItems, today),
              );
            }, childCount: _pastItems.length + (_loadingPast ? 1 : 0)),
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Divider(thickness: 2, height: 1),
            ),
          ),
          SliverList(
            key: _centerKey,
            delegate: SliverChildBuilderDelegate((context, idx) {
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
                    date.day != prevDate.day || date.month != prevDate.month;
              }
              return _buildItem(entry, showChip, _futureItems, today);
            }, childCount: _futureItems.length + (_loadingFuture ? 1 : 0)),
          ),
        ],
      ),
    );
  }
}
