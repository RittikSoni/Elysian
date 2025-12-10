import 'package:elysian/screens/home_screen.dart';
import 'package:elysian/screens/search_screen.dart';
import 'package:elysian/screens/coming_soon_screen.dart';
import 'package:elysian/screens/downloads_screen.dart';
import 'package:elysian/screens/more_screen.dart';
import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      HomeScreen(
        key: PageStorageKey('homeScreen'),
        onNavigateToTab: _changeTab,
      ),
      SearchScreen(
        key: PageStorageKey('searchScreen'),
        onNavigateToTab: _changeTab,
      ),
      ComingSoonScreen(
        key: PageStorageKey('comingSoonScreen'),
        onNavigateToTab: _changeTab,
      ),
      DownloadsScreen(
        key: PageStorageKey('downloadsScreen'),
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
      'Downloads': Icons.download,
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
