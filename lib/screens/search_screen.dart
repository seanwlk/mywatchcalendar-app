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
  bool _hasMore = false;
  int _page = 1;
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
    // Cancel the previous timer if the user keeps typing
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    // Start a new timer
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    _currentQuery = query.trim();
    _page = 1;
    _hasMore = true;
    _results.clear();
    if (_currentQuery.isEmpty) {
      setState(() {});
      return;
    }
    await _loadNextPage();
  }

  Future<void> _loadNextPage() async {
    if (_currentQuery.isEmpty) return;
    setState(() => _loading = true);
    final nextResults = await ApiClient.instance.searchSeries(
      query: _currentQuery,
      page: _page,
      pageSize: _pageSize,
    );
    setState(() {
      _loading = false;
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
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _results.length + (_loading ? 1 : 0),
              itemBuilder: (context, idx) {
                if (idx >= _results.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (_results.isEmpty) return const SizedBox.shrink();

                final s = _results[idx];

                return ListTile(
                  leading: SizedBox(
                    width: 50,
                    child: Image.network(
                      s.posterUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(Icons.broken_image),
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
