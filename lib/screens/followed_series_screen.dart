import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'series_info_screen.dart';
import '../models.dart';
import '../services/api_client.dart';

class FollowedSeriesScreen extends StatefulWidget {
  const FollowedSeriesScreen({super.key});

  @override
  State<FollowedSeriesScreen> createState() => _FollowedSeriesScreenState();
}

class _FollowedSeriesScreenState extends State<FollowedSeriesScreen> {
  final _scrollController = ScrollController();
  final List<FollowedSeriesItem> _items = [];
  bool _loading = false;
  bool _hasMore = true;
  bool _failed = false;
  int _page = 1;
  int _loadSeq = 0;
  static const int _pageSize = 100;

  bool _isGridView = false;

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
      final nextItems = await ApiClient.instance.fetchFollowedSeries(
        page: requestedPage,
        pageSize: _pageSize,
      );

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
    } finally {
      if (mounted && token == _loadSeq) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    _loadSeq++;
    setState(() {
      _page = 1;
      _items.clear();
      _hasMore = true;
      _loading = false;
      _failed = false;
    });
    await _loadNextPage();
  }

  Widget _buildProgressBar(FollowedSeriesItem item) {
    final double progress = item.progress.total > 0
        ? (item.progress.watched / item.progress.total)
        : 0.0;

    return Container(
      height: 6,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.2),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress.clamp(0.0, 1.0),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: item.isDropped ? Colors.red : Colors.green,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  Series _createPlaceholderSeries(FollowedSeriesItem item) {
    return Series(
      id: item.id,
      title: item.title,
      posterUrl: item.posterUrl,
      description: '',
      releaseDate: DateTime.now(),
      seasons: [],
      isFollowed: true,
      isDropped: item.isDropped,
    );
  }

  Widget _buildListItem(FollowedSeriesItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  SeriesInfoScreen(series: _createPlaceholderSeries(item)),
            ),
          ).then((_) => _refresh());
        },
        child: Column(
          children: [
            Row(
              children: [
                CachedNetworkImage(
                  imageUrl: item.posterUrl,
                  width: 80,
                  height: 120,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => const SizedBox(
                    width: 80,
                    height: 120,
                    child: Icon(Icons.broken_image),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${item.progress.watched} / ${item.progress.total} Episodes',
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            _buildProgressBar(item),
          ],
        ),
      ),
    );
  }

  Widget _buildGridItem(FollowedSeriesItem item) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  SeriesInfoScreen(series: _createPlaceholderSeries(item)),
            ),
          ).then((_) => _refresh());
        },
        child: Column(
          children: [
            Expanded(
              child: CachedNetworkImage(
                imageUrl: item.posterUrl,
                width: double.infinity,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) =>
                    const Center(child: Icon(Icons.broken_image)),
              ),
            ),
            _buildProgressBar(item),
          ],
        ),
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
                  _failed ? Icons.cloud_off : Icons.video_library_outlined,
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  _failed
                      ? "Couldn't reach the server"
                      : 'You are not following any series yet.',
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

    return CustomScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (_isGridView)
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 150,
                childAspectRatio: 2 / 3.2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildGridItem(_items[index]),
                childCount: _items.length,
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildListItem(_items[index]),
                childCount: _items.length,
              ),
            ),
          ),

        // Render the loading indicator safely at the bottom of either view
        if (_loading && _items.isNotEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: LinearProgressIndicator()),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Followed Series'),
        actions: [
          IconButton(
            icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
            tooltip: _isGridView ? 'List View' : 'Grid View',
            onPressed: () {
              setState(() {
                _isGridView = !_isGridView;
              });
            },
          ),
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
}
