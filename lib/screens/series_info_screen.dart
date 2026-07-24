import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models.dart';
import '../services/api_client.dart';
import 'episode_info_screen.dart';

class SeriesInfoScreen extends StatefulWidget {
  final Series series;

  const SeriesInfoScreen({super.key, required this.series});

  @override
  State<SeriesInfoScreen> createState() => _SeriesInfoScreenState();
}

class _SeriesInfoScreenState extends State<SeriesInfoScreen> {
  late Series _currentSeries;
  bool _isLoading = true;
  bool _isDataAvailable = true;

  @override
  void initState() {
    super.initState();
    _currentSeries = widget.series;
    _fetchEnrichedData();
  }

  Future<void> _fetchEnrichedData() async {
    try {
      final enrichedSeries = await ApiClient.instance.fetchSeriesbyId(
        _currentSeries.id,
      );
      if (enrichedSeries == null) {
        setState(() {
          _isLoading = false;
          _isDataAvailable = false;
        });
        return;
      }
      if (mounted) {
        setState(() {
          _currentSeries = enrichedSeries;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleEpisodeWatched(Episode episode) async {
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

  Future<void> _toggleDrop(Series series) async {
    final bool newStatus = !series.isDropped;
    final String seriesId = series.id;

    setState(() {
      series.isDropped = newStatus;
    });

    final success = await ApiClient.instance.changeSeriesStatus(
      seriesId,
      newStatus,
    );

    if (!mounted) return;

    if (!success) {
      setState(() {
        series.isDropped = !newStatus;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to update status')));
    }
  }

  Future<void> _toggleSeasonWatched(Season season) async {
    if (season.episodes.isEmpty) return;

    final bool allWatched = season.episodes.every((e) => e.watched);
    final bool newStatus = !allWatched;

    final episodesToUpdate = season.episodes
        .where((e) => e.watched != newStatus)
        .toList();

    if (episodesToUpdate.isEmpty) return;

    setState(() {
      for (var e in episodesToUpdate) {
        e.watched = newStatus;
      }
    });

    const int maxConcurrent = 4;
    bool hasError = false;
    for (var i = 0; i < episodesToUpdate.length; i += maxConcurrent) {
      final chunk = episodesToUpdate.skip(i).take(maxConcurrent);
      final results = await Future.wait(
        chunk.map(
          (e) => ApiClient.instance.markEpisodeWatched(e.id, newStatus),
        ),
      );
      if (results.any((ok) => !ok)) hasError = true;
    }

    if (!mounted) return;

    if (hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update some episodes.')),
      );
      _fetchEnrichedData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 300,
            child: CachedNetworkImage(
              imageUrl: _currentSeries.posterUrl,
              fit: BoxFit.cover,
              memCacheWidth: 1080,
              errorWidget: (_, _, _) =>
                  const Center(child: Icon(Icons.broken_image)),
            ),
          ),
          CustomScrollView(
            slivers: [
              const SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: BackButton(color: Colors.white),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Text(
                            _currentSeries.title,
                            style: Theme.of(context).textTheme.headlineSmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () =>
                                      _toggleFollow(_currentSeries),
                                  icon: Icon(
                                    _currentSeries.isFollowed
                                        ? Icons.favorite_outline
                                        : Icons.favorite,
                                  ),
                                  label: Text(
                                    _currentSeries.isFollowed
                                        ? 'Unfollow'
                                        : 'Follow',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _toggleDrop(_currentSeries),
                                  icon: Icon(
                                    _currentSeries.isDropped
                                        ? Icons.restart_alt
                                        : Icons.stop_circle_outlined,
                                  ),
                                  label: Text(
                                    _currentSeries.isDropped
                                        ? 'Resume watching'
                                        : 'Stop watching',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Started airing ${_currentSeries.startDate.toLocal().toString().split(' ')[0]}',
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'About',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(_currentSeries.description),
                      const SizedBox(height: 24),
                      Text(
                        'Seasons',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                ),
              ),

              if (_isLoading)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Material(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                )
              else if (!_isDataAvailable)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Material(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'No data available for this show. Follow the series and wait for the backend job to sync the episodes.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, idx) {
                    final season = _currentSeries.seasons[idx];

                    final int totalEpisodes = season.episodes.length;
                    final int watchedEpisodes = season.episodes
                        .where((e) => e.watched)
                        .length;
                    final double progress = totalEpisodes > 0
                        ? (watchedEpisodes / totalEpisodes)
                        : 0.0;
                    final bool allWatched =
                        totalEpisodes > 0 && watchedEpisodes == totalEpisodes;

                    return Material(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      child: ExpansionTile(
                        title: Row(
                          children: [
                            Text(
                              season.number == 0
                                  ? 'Specials'
                                  : 'Season ${season.number}',
                            ),
                            const Spacer(),
                            Text(
                              '$watchedEpisodes/$totalEpisodes',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                            ),
                            IconButton(
                              onPressed: () async {
                                final String statusText = !allWatched
                                    ? 'watched'
                                    : 'unwatched';
                                final String seasonText = season.number == 0
                                    ? 'Specials'
                                    : 'Season ${season.number}';

                                final bool? confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      title: const Text('Confirm Bulk Update'),
                                      content: Text(
                                        'Are you sure you want to mark all episodes in $seasonText as $statusText?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(false),
                                          child: const Text('Cancel'),
                                        ),
                                        FilledButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(true),
                                          child: const Text('Confirm'),
                                        ),
                                      ],
                                    );
                                  },
                                );

                                if (confirm == true) {
                                  _toggleSeasonWatched(season);
                                }
                              },
                              icon: Icon(
                                allWatched
                                    ? Icons.check_circle
                                    : Icons.check_circle_outline,
                                color: allWatched ? Colors.green : null,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Container(
                          margin: const EdgeInsets.only(top: 8),
                          height: 4,
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.grey.withValues(alpha: 0.2),
                            color: allWatched ? Colors.green : Colors.yellow,
                          ),
                        ),
                        children: season.episodes
                            .map((e) => _buildEpisodeTile(e))
                            .toList(),
                      ),
                    );
                  }, childCount: _currentSeries.seasons.length),
                ),

              SliverToBoxAdapter(
                child: ColoredBox(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: SizedBox(
                    height: 20 + MediaQuery.paddingOf(context).bottom,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEpisodeTile(Episode e) {
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: CachedNetworkImage(
          imageUrl: e.imageUrl,
          width: 60,
          height: 40,
          fit: BoxFit.cover,
          memCacheWidth: 180,
          errorWidget: (_, _, _) => const Icon(Icons.broken_image),
        ),
      ),
      title: Text(
        'S${e.season.toString().padLeft(2, '0')}E${e.number.toString().padLeft(2, '0')}',
      ),
      subtitle: Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: IconButton(
        onPressed: () => _toggleEpisodeWatched(e),
        icon: Icon(
          e.watched ? Icons.check_circle : Icons.check_circle_outline,
          color: e.watched ? Colors.green : null,
        ),
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EpisodeInfoScreen(series: _currentSeries, episode: e),
        ),
      ),
    );
  }
}
