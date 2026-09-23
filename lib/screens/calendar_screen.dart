import 'package:flutter/material.dart';
import '../models.dart';
import '../services/api_client.dart';
import '../services/settings_service.dart';
import '../widgets/episode_card.dart';
import '../widgets/watch_history_modal.dart';
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

  late String _viewType; 
  DateTime _currentDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    
    _viewType = SettingsService.instance.calendarViewType;
    
    _scrollController.addListener(_onScroll);
    
    Future.wait([
      _load(past: false),
      _load(past: true),
    ]).then((_) {
      if (mounted && _viewType != 'timeline') {
        _checkNeedMoreData();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_viewType != 'timeline') return;

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

  Future<void> _checkNeedMoreData() async {
    DateTime startOfPeriod;
    DateTime endOfPeriod;
    
    if (_viewType == 'month') {
      startOfPeriod = DateTime(_currentDate.year, _currentDate.month, 1);
      endOfPeriod = DateTime(_currentDate.year, _currentDate.month + 1, 0);
    } else {
      int diff = _currentDate.weekday - 1;
      startOfPeriod = DateTime(_currentDate.year, _currentDate.month, _currentDate.day - diff);
      endOfPeriod = startOfPeriod.add(const Duration(days: 6));
    }

    int fetchCount = 0;
    while (_hasMoreFuture && _futureItems.isNotEmpty && fetchCount < 5) {
      final maxDate = _futureItems.last.value.airDate?.toLocal();
      if (maxDate != null && maxDate.isBefore(endOfPeriod)) {
        await _load(past: false);
        fetchCount++;
      } else {
        break;
      }
    }

    fetchCount = 0;
    while (_hasMorePast && _pastItems.isNotEmpty && fetchCount < 5) {
      final minDate = _pastItems.last.value.airDate?.toLocal();
      if (minDate != null && minDate.isAfter(startOfPeriod)) {
        await _load(past: true);
        fetchCount++;
      } else {
        break;
      }
    }
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
    if (_viewType != 'timeline') {
      _checkNeedMoreData();
    }
  }

  Future<void> _refreshEpisode(Series series, Episode episode, {VoidCallback? onUpdate}) async {
    final refreshedEpisode = await ApiClient.instance.getEpisode(episode.id);
    if (!mounted) return;

    if (refreshedEpisode != null) {
      setState(() {
        int pastIdx = _pastItems.indexWhere((e) => e.value.id == episode.id);
        if (pastIdx != -1) {
          _pastItems[pastIdx] = MapEntry(series, refreshedEpisode);
        }
        int futIdx = _futureItems.indexWhere((e) => e.value.id == episode.id);
        if (futIdx != -1) {
          _futureItems[futIdx] = MapEntry(series, refreshedEpisode);
        }
      });
      onUpdate?.call();
    }
  }

  void _handleMarkWatchedLongPress(Series series, Episode episode, {VoidCallback? onUpdate}) {
    WatchHistoryModal.show(
      context, 
      series, 
      episode,
      onChanged: () => _refreshEpisode(series, episode, onUpdate: onUpdate),
    );
  }

  Future<void> _toggleWatched(Series series, Episode episode, {VoidCallback? onUpdate}) async {
    if (episode.watched && episode.rewatchCount > 1) {
      _handleMarkWatchedLongPress(series, episode, onUpdate: onUpdate);
      return;
    }

    final bool newStatus = !episode.watched;
    final String episodeId = episode.id;

    setState(() {
      episode.watched = newStatus;
      episode.rewatchCount += newStatus ? 1 : -1;
    });
    
    onUpdate?.call();

    final success = await ApiClient.instance.markEpisodeWatched(
      episodeId,
      newStatus,
    );

    if (!mounted) return;

    if (!success) {
      setState(() {
        episode.watched = !newStatus;
        episode.rewatchCount += !newStatus ? 1 : -1;
      });
      onUpdate?.call();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to update status')));
    }
  }

  void _changeDate(int dir) {
    setState(() {
      if (_viewType == 'month') {
        _currentDate = DateTime(_currentDate.year, _currentDate.month + dir, 1);
      } else {
        _currentDate = _currentDate.add(Duration(days: 7 * dir));
      }
    });
    _checkNeedMoreData();
  }

  String _formatDateLabel(DateTime? date) {
    if (date == null) return 'TBD';
    final localDate = date.toLocal();
    final targetDate = DateTime(localDate.year, localDate.month, localDate.day);
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final difference = targetDate.difference(today).inDays;

    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Tomorrow';
    } else if (difference == -1) {
      return 'Yesterday';
    } else {
      final weekday = DateConstants.weekdaysFull[targetDate.weekday];
      final month = DateConstants.monthsShort[targetDate.month];
      final day = targetDate.day;

      if (targetDate.year != today.year) {
        return '$weekday, $day $month ${targetDate.year}';
      }
      return '$weekday, $day $month';
    }
  }

  Map<DateTime, List<MapEntry<Series, Episode>>> _getGroupedItems() {
    final map = <DateTime, List<MapEntry<Series, Episode>>>{};
    for (var item in [..._pastItems, ..._futureItems]) {
      if (item.value.airDate == null) continue;
      final d = item.value.airDate!.toLocal();
      final dateKey = DateTime(d.year, d.month, d.day);
      map.putIfAbsent(dateKey, () => []).add(item);
    }
    return map;
  }

  void _showDayEpisodes(DateTime date, DateTime today) {
    final initialEps = _getGroupedItems()[date] ?? [];
    if (initialEps.isEmpty) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final freshEpisodes = _getGroupedItems()[date] ?? [];
            
            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              minChildSize: 0.3,
              maxChildSize: 0.9,
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
                            _formatDateLabel(date),
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: freshEpisodes.length,
                        itemBuilder: (context, index) {
                          return _buildItem(
                            freshEpisodes[index], 
                            false, 
                            today,
                            onUpdate: () => setModalState(() {}),
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
      },
    );
  }

  Widget _buildItem(
    MapEntry<Series, Episode> entry,
    bool showDayChip,
    DateTime today, {
    VoidCallback? onUpdate,
  }) {
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
          showAirTime: true,
          onSeriesTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SeriesInfoScreen(series: entry.key),
              ),
            );
            _refreshEpisode(entry.key, entry.value, onUpdate: onUpdate);
          },
          onEpisodeTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    EpisodeInfoScreen(series: entry.key, episode: entry.value),
              ),
            );
            _refreshEpisode(entry.key, entry.value, onUpdate: onUpdate);
          },
          onMarkWatched: () => _toggleWatched(entry.key, episode, onUpdate: onUpdate),
          onMarkWatchedLongPress: () => _handleMarkWatchedLongPress(entry.key, episode, onUpdate: onUpdate),
        ),
      ],
    );
  }

  Widget _buildTimelineView(DateTime today) {
    return CustomScrollView(
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
              final date = entry.value.airDate?.toLocal();
              bool showChip = false;
              
              if (idx == _pastItems.length - 1) {
                showChip = true;
              } else {
                final prevDate = _pastItems[idx + 1].value.airDate?.toLocal();
                showChip =
                    date?.day != prevDate?.day ||
                    date?.month != prevDate?.month || 
                    date?.year != prevDate?.year;
              }
              return _buildItem(entry, showChip, today);
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
              final date = entry.value.airDate?.toLocal();

              bool showChip = false;
              if (idx == 0) {
                showChip = true;
              } else {
                final prevDate = _futureItems[idx - 1].value.airDate?.toLocal();
                showChip =
                    date?.day != prevDate?.day ||
                    date?.month != prevDate?.month ||
                    date?.year != prevDate?.year;
              }
              return _buildItem(entry, showChip, today);
            },
            childCount: _futureItems.length + (_loadingFuture ? 1 : 0),
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarBox(DateTime cellDate, DateTime today, List<MapEntry<Series, Episode>> dayEps) {
    final theme = Theme.of(context);
    final isToday = cellDate.isAtSameMomentAs(today);
    
    final int maxDisplay = _viewType == 'month' ? 3 : 15;

    return InkWell(
      onTap: dayEps.isEmpty ? null : () => _showDayEpisodes(cellDate, today),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.1), width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Container(
                margin: const EdgeInsets.all(4),
                padding: const EdgeInsets.all(4),
                decoration: isToday 
                    ? BoxDecoration(color: theme.colorScheme.primary, shape: BoxShape.circle) 
                    : null,
                child: Text(
                  '${cellDate.day}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isToday ? theme.colorScheme.onPrimary : null,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ClipRect(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ...dayEps.take(maxDisplay).map((ep) {
                      final isWatched = ep.value.watched;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 2, left: 2, right: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: isWatched 
                              ? Colors.green.withValues(alpha: 0.2) 
                              : theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                          border: Border(
                            left: BorderSide(
                              color: isWatched ? Colors.green : theme.colorScheme.primary, 
                              width: 2
                            )
                          ),
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(2), 
                            bottomRight: Radius.circular(2)
                          ),
                        ),
                        child: Text(
                          ep.key.title,
                          style: TextStyle(
                            fontSize: 9,
                            decoration: isWatched ? TextDecoration.lineThrough : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }),
                    if (dayEps.length > maxDisplay)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '+${dayEps.length - maxDisplay} more', 
                          style: const TextStyle(fontSize: 8, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthView(DateTime today, Map<DateTime, List<MapEntry<Series, Episode>>> groupedItems) {
    int daysInMonth = DateTime(_currentDate.year, _currentDate.month + 1, 0).day;
    int firstWeekday = DateTime(_currentDate.year, _currentDate.month, 1).weekday; 
    int totalCells = daysInMonth + firstWeekday - 1;

    return Column(
      children: [
        _buildCalendarHeader(
          title: '${DateConstants.monthsFull[_currentDate.month]} ${_currentDate.year}'
        ),
        _buildWeekdaysRow(),
        Expanded(
          child: GridView.builder(
            padding: EdgeInsets.zero,
            itemCount: totalCells,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 0.55, 
            ),
            itemBuilder: (context, index) {
              if (index < firstWeekday - 1) return const SizedBox();
              
              int day = index - firstWeekday + 2;
              DateTime cellDate = DateTime(_currentDate.year, _currentDate.month, day);
              List<MapEntry<Series, Episode>> dayEps = groupedItems[cellDate] ?? [];

              return _buildCalendarBox(cellDate, today, dayEps);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildWeekView(DateTime today, Map<DateTime, List<MapEntry<Series, Episode>>> groupedItems) {
    int diff = _currentDate.weekday - 1;
    DateTime monday = DateTime(_currentDate.year, _currentDate.month, _currentDate.day - diff);
    DateTime sunday = monday.add(const Duration(days: 6));

    String monthStr = monday.month == sunday.month 
        ? DateConstants.monthsShort[monday.month] 
        : '${DateConstants.monthsShort[monday.month]} - ${DateConstants.monthsShort[sunday.month]}';

    return Column(
      children: [
        _buildCalendarHeader(
          title: '${monday.day} - ${sunday.day} $monthStr ${monday.year}'
        ),
        _buildWeekdaysRow(),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: List.generate(7, (index) {
              DateTime cellDate = monday.add(Duration(days: index));
              List<MapEntry<Series, Episode>> dayEps = groupedItems[cellDate] ?? [];

              return Expanded(
                child: _buildCalendarBox(cellDate, today, dayEps),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarHeader({required String title}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _changeDate(-1),
          ),
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              if (_loadingFuture || _loadingPast)
                 const Padding(
                   padding: EdgeInsets.only(left: 8.0),
                   child: SizedBox(
                     width: 12, 
                     height: 12, 
                     child: CircularProgressIndicator(strokeWidth: 2)
                   ),
                 )
            ],
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => _changeDate(1),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdaysRow() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: List.generate(7, (index) {
          return Expanded(
            child: Text(
              DateConstants.weekdaysShort[index + 1].toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          );
        }),
      ),
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

    IconData getHeaderIcon() {
      if (_viewType == 'month') return Icons.calendar_month;
      if (_viewType == 'week') return Icons.view_week;
      return Icons.view_timeline;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(getHeaderIcon()),
            tooltip: 'View Type',
            onSelected: (val) {
              setState(() {
                _viewType = val;
                if (val != 'timeline') {
                   _currentDate = DateTime.now();
                }
              });
              SettingsService.instance.updateCalendarViewType(val);
              if (val != 'timeline') _checkNeedMoreData();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'timeline',
                child: Row(children: [Icon(Icons.view_timeline), SizedBox(width: 8), Text('Timeline')]),
              ),
              const PopupMenuItem(
                value: 'month',
                child: Row(children: [Icon(Icons.calendar_month), SizedBox(width: 8), Text('Month')]),
              ),
              const PopupMenuItem(
                value: 'week',
                child: Row(children: [Icon(Icons.view_week), SizedBox(width: 8), Text('Week')]),
              ),
            ],
          ),
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
          : Builder(
              builder: (context) {
                if (_viewType == 'timeline') {
                  return _buildTimelineView(today);
                } 
                
                final groupedItems = _getGroupedItems();
                if (_viewType == 'month') {
                  return _buildMonthView(today, groupedItems);
                }
                return _buildWeekView(today, groupedItems);
              },
            )
    );
  }
}
