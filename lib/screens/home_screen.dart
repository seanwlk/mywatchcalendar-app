import 'package:flutter/material.dart';
import 'towatch_screen.dart';
import 'calendar_screen.dart';
import 'search_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  final String username;
  final VoidCallback onLogout;

  const HomeScreen({
    super.key,
    required this.username,
    required this.onLogout,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  final Set<int> _visited = <int>{0};

  Widget _page(int i) {
    if (!_visited.contains(i)) return const SizedBox.shrink();
    switch (i) {
      case 0:
        return const ToWatchScreen();
      case 1:
        return const CalendarScreen();
      case 2:
        return const SearchScreen();
      default:
        return ProfileScreen(
          username: widget.username,
          onLogout: widget.onLogout,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: List.generate(4, _page)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() {
          _visited.add(i);
          _index = i;
        }),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.playlist_add),
            label: 'To-Watch',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today),
            label: 'Calendar',
          ),
          NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
