import 'package:flutter/material.dart';
import '../models.dart';
import '../services/api_client.dart';
import '../widgets/episode_card.dart';
import 'episode_info_screen.dart';
import 'series_info_screen.dart';

class ToWatchScreen extends StatefulWidget {
  const ToWatchScreen({super.key});

  @override
  State<ToWatchScreen> createState() => _ToWatchScreenState();
}

class _ToWatchScreenState extends State<ToWatchScreen> {
  final _scrollController = ScrollController();
  final List<MapEntry<Series, Episode>> _items = [];
  bool _loading = false;
  bool _hasMore = true;
  int _page = 1;
  static const int _pageSize = 30;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadNextPage();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_loading &&
        _hasMore &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 120) {
      _loadNextPage();
    }
  }

  Future<void> _loadNextPage() async {
    setState(() => _loading = true);
    final nextItems = await ApiClient.instance.fetchUnwatchedEpisodes(
      page: _page,
      pageSize: _pageSize,
    );

    if (!mounted) return;

    setState(() {
      _loading = false;
      if (nextItems.isNotEmpty) {
        _items.addAll(nextItems);
        _page += 1;
      }
      if (nextItems.length < _pageSize) {
        _hasMore = false;
      }
    });
  }

  Future<void> _refresh() async {
    setState(() {
      _page = 1;
      _items.clear();
      _hasMore = true;
    });
    await _loadNextPage();
  }

  Future<void> _refreshLastEpisode(Series series, Episode episode) async {
    final nextEpisode = await ApiClient.instance.getNextUnwatchedEpisode(
      series.id,
    );

    if (!mounted) return;

    final index = _items.indexWhere((e) => e.value.id == episode.id);
    if (nextEpisode?.id == episode.id) return;
    setState(() {
      if (nextEpisode != null) {
        _items[index] = MapEntry(series, nextEpisode);
      } else {
        _items.removeAt(index);
      }
    });
  }

  Future<void> _markWatched(Episode episode, Series series) async {
    final index = _items.indexWhere((entry) => entry.value.id == episode.id);
    if (index == -1) return;

    final success = await ApiClient.instance.markEpisodeWatched(
      episode.id,
      true,
    );

    if (success) {
      _refreshLastEpisode(series, episode);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('To-Watch')),
      body: RefreshIndicator(
        edgeOffset: 0,
        onRefresh: _refresh,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          controller: _scrollController,
          itemCount: _items.length + (_loading ? 1 : 0),
          itemBuilder: (context, idx) {
            if (idx >= _items.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: LinearProgressIndicator()),
              );
            }
            final entry = _items[idx];
            return EpisodeCard(
              series: entry.key,
              episode: entry.value,
              onSeriesTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SeriesInfoScreen(series: entry.key),
                  ),
                );

                _refreshLastEpisode(entry.key, entry.value);
              },
              onEpisodeTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EpisodeInfoScreen(
                      series: entry.key,
                      episode: entry.value,
                    ),
                  ),
                );

                _refreshLastEpisode(entry.key, entry.value);
              },
              onMarkWatched: () => _markWatched(entry.value, entry.key),
            );
          },
        ),
      ),
    );
  }
}
