import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models.dart';
import '../services/api_client.dart';
import 'series_info_screen.dart';
import 'dart:async';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  Timer? _debounce;
  final _queryController = TextEditingController();
  final _scrollController = ScrollController();
  final List<Series> _results = [];
  bool _loading = false;
  bool _failed = false;
  bool _hasMore = false;
  int _page = 1;
  int _searchSeq = 0;
  static const int _pageSize = 30;
  String _currentQuery = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.dispose();
    _queryController.dispose();
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

  void _search(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    final seq = ++_searchSeq;
    setState(() {
      _currentQuery = query.trim();
      _page = 1;
      _hasMore = true;
      _loading = false;
      _failed = false;
      _results.clear();
    });
    if (_currentQuery.isEmpty) return;
    await _loadNextPage(seq);
  }

  Future<void> _loadNextPage([int? seq]) async {
    final token = seq ?? _searchSeq;
    if (_currentQuery.isEmpty || _loading) return;

    setState(() => _loading = true);
    final nextResults = await ApiClient.instance.searchSeries(
      query: _currentQuery,
      page: _page,
      pageSize: _pageSize,
    );

    if (!mounted || token != _searchSeq) return;

    setState(() {
      _loading = false;
      if (nextResults == null) {
        _failed = _results.isEmpty;
        _hasMore = false;
        return;
      }
      _failed = false;
      _results.addAll(nextResults);
      if (nextResults.length == _pageSize) {
        _page += 1;
        _hasMore = true;
      } else {
        _hasMore = false;
      }
    });
  }

  Future<void> _toggleFollow(Series series) async {
    final bool currentlyFollowed = series.isFollowed;

    setState(() {
      series.isFollowed = !currentlyFollowed;
    });

    final success = await ApiClient.instance.followSeries(
      series.id,
      !currentlyFollowed,
    );

    if (!success && mounted) {
      // Rollback
      setState(() {
        series.isFollowed = currentlyFollowed;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to ${currentlyFollowed ? 'unfollow' : 'follow'} series',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool showEmptyState =
        _currentQuery.isNotEmpty && !_loading && _results.isEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _queryController,
              onChanged: _search,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search series...',
              ),
            ),
          ),
          Expanded(
            child: showEmptyState
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _failed ? Icons.cloud_off : Icons.search_off,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _failed
                              ? "Couldn't reach the server"
                              : 'No results for "$_currentQuery"',
                        ),
                        if (_failed) ...[
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: () => _performSearch(_currentQuery),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ],
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: _results.length + (_loading ? 1 : 0),
                    itemBuilder: (context, idx) {
                      if (idx >= _results.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final s = _results[idx];

                      return ListTile(
                        leading: SizedBox(
                          width: 50,
                          child: CachedNetworkImage(
                            imageUrl: s.posterUrl,
                            fit: BoxFit.cover,
                            memCacheWidth: 150,
                            errorWidget: (_, _, _) =>
                                const Icon(Icons.broken_image),
                          ),
                        ),
                        title: Text(s.title),
                        subtitle: Text(s.startDate.year.toString()),
                        trailing: IconButton(
                          icon: Icon(
                            s.isFollowed
                                ? Icons.check_box_rounded
                                : Icons.add_box_outlined,
                            color: s.isFollowed ? Colors.red : null,
                          ),
                          onPressed: () => _toggleFollow(s),
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SeriesInfoScreen(series: s),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
