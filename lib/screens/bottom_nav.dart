import 'package:elysian/screens/home_screen.dart';
import 'package:elysian/screens/search_screen.dart';
import 'package:elysian/screens/coming_soon_screen.dart';
import 'package:elysian/screens/local_videos_screen.dart';
import 'package:elysian/screens/more_screen.dart';
import 'package:elysian/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elysian/widgets/widgets.dart';

class BottomNav extends StatefulWidget {
  const BottomNav({super.key});

  @override
  BottomNavState createState() => BottomNavState();
}

class BottomNavState extends State<BottomNav> {
  int _currentIndex = 0;

  void _changeTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void refreshHomeScreen() {
    // Refresh providers instead of calling removed method
    final linksProvider = context.read<LinksProvider>();
    final listsProvider = context.read<ListsProvider>();
    linksProvider.loadLinks(forceRefresh: true);
    listsProvider.loadLists(forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      HomeScreen(onNavigateToTab: _changeTab),
      SearchScreen(
        key: PageStorageKey('searchScreen'),
        onNavigateToTab: _changeTab,
      ),
      ComingSoonScreen(
        key: PageStorageKey('comingSoonScreen'),
        title: 'Coming Soon',
      ),
      LocalVideosScreen(
        key: PageStorageKey('localVideosScreen'),
        onNavigateToTab: _changeTab,
      ),
      MoreScreen(
        key: PageStorageKey('moreScreen'),
        onNavigateToTab: _changeTab,
      ),
    ];

    final Map<String, IconData> icons = const {
      'Home': Icons.home,
      'Search': Icons.search,
      'Coming Soon': Icons.queue_play_next,
      'Local Videos': Icons.video_library,
      'More': Icons.menu,
    };

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: !Responsive.isDesktop(context)
          ? BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.black,
              items: icons
                  .map(
                    (title, icon) => MapEntry(
                      title,
                      BottomNavigationBarItem(
                        icon: Icon(icon, size: 30.0),
                        label: title,
                      ),
                    ),
                  )
                  .values
                  .toList(),
              currentIndex: _currentIndex,
              selectedItemColor: Colors.white,
              selectedFontSize: 11.0,
              unselectedFontSize: 11.0,
              unselectedItemColor: Colors.grey,
              onTap: (index) => setState(() {
                _currentIndex = index;
              }),
            )
          : null,
    );
  }
}
