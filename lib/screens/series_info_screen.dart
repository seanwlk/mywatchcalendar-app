import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
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
  final ScreenshotController _screenshotController = ScreenshotController();

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
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isDataAvailable = false;
          });
        }
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

  Future<void> _generateAndShareCard() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sharing...')),
    );

    try {
      await precacheImage(
        CachedNetworkImageProvider(_currentSeries.posterUrl),
        context,
      );

      final capturedImage = await _screenshotController.captureFromWidget(
        _buildShareCardWidget(),
        delay: const Duration(milliseconds: 100),
      );

      final directory = await getTemporaryDirectory();
      final imagePath = '${directory.path}/share_series.png';
      final imageFile = File(imagePath);
      await imageFile.writeAsBytes(capturedImage);

      await SharePlus.instance.share(
        ShareParams(
          text: _currentSeries.title,
          files: [XFile(imagePath)],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to generate image')),
      );
    }
  }

  Widget _buildShareCardWidget() {
    final totalEpisodes = _currentSeries.seasons.fold<int>(
      0,
      (sum, season) => sum + season.episodes.length,
    );
    return Container(
      width: 400,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image(
              image: CachedNetworkImageProvider(_currentSeries.posterUrl),
              width: double.infinity,
              height: 250,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _currentSeries.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Released: ${_currentSeries.releaseDate?.toLocal().toString().split(' ')[0] ?? 'TBD'}',
            style: const TextStyle(color: Colors.grey, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            'Seasons: ${_currentSeries.seasons.length} | Episodes: $totalEpisodes',
            style: const TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
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
      widget.series.isFollowed = !currentlyFollowed;
    });

    final success = await ApiClient.instance.followSeries(
      series.id,
      !currentlyFollowed,
    );

    if (!mounted) return;

    if (!success) {
      setState(() {
        series.isFollowed = currentlyFollowed;
        widget.series.isFollowed = currentlyFollowed;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
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

  Color _getStatusColor(String status, BuildContext context) {
    final s = status.toLowerCase();
    if (s.contains('return') || s.contains('airing')) {
      return Colors.green.withValues(alpha: 0.2);
    } else if (s.contains('ended') || s.contains('cancel')) {
      return Colors.red.withValues(alpha: 0.2);
    }
    return Theme.of(context).colorScheme.surfaceContainerHighest;
  }

  Future<void> _sendToClipBoard(String? clipText, BuildContext context) async {
    if (clipText == null || clipText.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No data available to copy'),
        ),
      );
      return;
    }
    await Clipboard.setData(
      ClipboardData(text: clipText),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open link')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link')),
        );
      }
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
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: const BackButton(color: Colors.white),
                actions: [
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    onSelected: (value) async {
                      if (value == 'copy') {
                        await _sendToClipBoard(_currentSeries.title, context);
                      } else if (value == 'share') {
                        await _generateAndShareCard();
                      } else if (value == 'open_tmdb') {
                        final tmdbId = _currentSeries.externalIds?.tmdb;
                        if (tmdbId != null && tmdbId.toString().isNotEmpty) {
                          await _openUrl('https://www.themoviedb.org/tv/$tmdbId');
                        } else {
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('TMDB ID not available')));
                        }
                      } else if (value == 'open_imdb') {
                        final imdbId = _currentSeries.externalIds?.imdb;
                        if (imdbId != null && imdbId.toString().isNotEmpty) {
                          await _openUrl('https://www.imdb.com/title/$imdbId/');
                        } else {
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('IMDb ID not available')));
                        }
                      } else if (value == 'copy_tmdb') {
                        await _sendToClipBoard(_currentSeries.externalIds?.tmdb?.toString(), context);
                      } else if (value == 'copy_imdb') {
                        await _sendToClipBoard(_currentSeries.externalIds?.imdb?.toString(), context);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'share',
                        child: Row(
                          children: [
                            Icon(Icons.share, size: 20),
                            SizedBox(width: 12),
                            Text('Share'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'copy',
                        child: Row(
                          children: [
                            Icon(Icons.copy, size: 20),
                            SizedBox(width: 12),
                            Text('Copy title'),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'open_tmdb',
                        child: Row(
                          children: [
                            Icon(Icons.open_in_browser, size: 20),
                            SizedBox(width: 12),
                            Text('Open in TMDB'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'open_imdb',
                        child: Row(
                          children: [
                            Icon(Icons.open_in_browser, size: 20),
                            SizedBox(width: 12),
                            Text('Open in IMDb'),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'copy_tmdb',
                        child: Row(
                          children: [
                            Icon(Icons.numbers, size: 20),
                            SizedBox(width: 12),
                            Text('Copy TMDB ID'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'copy_imdb',
                        child: Row(
                          children: [
                            Icon(Icons.numbers, size: 20),
                            SizedBox(width: 12),
                            Text('Copy IMDb ID'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
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
                      Row(
                        children: [
                          Text('Started airing ${_currentSeries.releaseDate?.toLocal().toString().split(' ')[0] ?? 'TBD'}'),
                          const SizedBox(width: 12),
                          if (_currentSeries.status != null &&
                              _currentSeries.status!.isNotEmpty)
                            Chip(
                              label: Text(_currentSeries.status!),
                              labelStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              padding: EdgeInsets.zero,
                              visualDensity: const VisualDensity(
                                horizontal: 0,
                                vertical: -4,
                              ),
                              side: BorderSide.none,
                              backgroundColor: _getStatusColor(
                                _currentSeries.status!,
                                context,
                              ),
                            ),
                        ],
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
