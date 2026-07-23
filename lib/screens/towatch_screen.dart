import 'package:flutter/material.dart';
import '../models.dart';
import '../services/api_client.dart';
import '../services/widget_updater.dart';
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
  bool _failed = false;
  int _page = 1;
  int _loadSeq = 0;
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
    if (_loading) return;
    final token = _loadSeq;
    final requestedPage = _page;
    setState(() => _loading = true);
    try {
      final nextItems = await ApiClient.instance.fetchUnwatchedEpisodes(
        page: requestedPage,
        pageSize: _pageSize,
      );
      // Dropped if the widget is gone or a refresh superseded this load.
      if (!mounted || token != _loadSeq) return;
      setState(() {
        if (nextItems == null) {
          _failed = _items.isEmpty;
          _hasMore = false;
        } else {
          _failed = false;
          if (nextItems.isNotEmpty) {
            _items.addAll(nextItems);
            _page += 1;
          }
          if (nextItems.length < _pageSize) _hasMore = false;
        }
      });
      // Reuse the data just fetched to refresh the home-screen widget,
      // avoiding a duplicate /unwatched round trip at launch. An empty
      // first page publishes too, so the widget clears when everything
      // has been watched.
      if (requestedPage == 1 && nextItems != null) {
        WidgetUpdater.publish(nextItems.take(30).toList());
      }
    } finally {
      if (mounted && token == _loadSeq) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    _loadSeq++; // drop any in-flight page load
    setState(() {
      _page = 1;
      _items.clear();
      _hasMore = true;
      _loading = false;
    });
    await _loadNextPage();
  }

  Future<void> _refreshLastEpisode(Series series, Episode episode) async {
    final nextEpisode = await ApiClient.instance.getNextUnwatchedEpisode(
      series.id,
    );

    if (!mounted) return;
    if (nextEpisode?.id == episode.id) return;

    final index = _items.indexWhere((e) => e.value.id == episode.id);
    if (index == -1) return;

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

    final removed = _items[index];
    setState(() => _items.removeAt(index));

    final success = await ApiClient.instance.markEpisodeWatched(
      episode.id,
      true,
    );
    if (!mounted) return;

    if (!success) {
      setState(() {
        // Skip the rollback if a refresh already restored the row.
        if (!_items.any((e) => e.value.id == removed.value.id)) {
          _items.insert(index.clamp(0, _items.length), removed);
        }
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to update status')));
      return;
    }

    // Success: pull the next unwatched episode for this series back into list.
    final next = await ApiClient.instance.getNextUnwatchedEpisode(series.id);
    if (!mounted || next == null) return;
    // A refresh may have completed meanwhile and already contain it.
    if (_items.any((e) => e.value.id == next.id)) return;
    setState(
      () =>
          _items.insert(index.clamp(0, _items.length), MapEntry(series, next)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('To-Watch'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _refresh,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        edgeOffset: 0,
        onRefresh: _refresh,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (!_loading && _items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.25),
          Center(
            child: Column(
              children: [
                Icon(
                  _failed ? Icons.cloud_off : Icons.check_circle_outline,
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  _failed
                      ? "Couldn't reach the server"
                      : 'Nothing left to watch',
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
      );
    }

    return ListView.builder(
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
                builder: (_) =>
                    EpisodeInfoScreen(series: entry.key, episode: entry.value),
              ),
            );

            _refreshLastEpisode(entry.key, entry.value);
          },
          onMarkWatched: () => _markWatched(entry.value, entry.key),
        );
      },
    );
  }
}
