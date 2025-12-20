import 'dart:ui';
import 'package:elysian/screens/home_screen.dart';
import 'package:elysian/screens/search_screen.dart';
import 'package:elysian/screens/responsive_chat_screen.dart';
import 'package:elysian/screens/local_videos_screen.dart';
import 'package:elysian/screens/more_screen.dart';
import 'package:elysian/providers/providers.dart';
import 'package:elysian/utils/app_themes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
    // Use IndexedStack to preserve state and prevent rebuilds
    final List<Widget> screens = [
      HomeScreen(onNavigateToTab: _changeTab),
      SearchScreen(
        key: PageStorageKey('searchScreen'),
        onNavigateToTab: _changeTab,
      ),
      ResponsiveChatScreen(
        key: PageStorageKey('chatListScreen'),
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

    return Consumer<AppStateProvider>(
      builder: (context, appState, _) {
        final themeType = appState.themeType;
        final isLiquidGlass = themeType == AppThemeType.liquidGlass;
        final isLight = themeType == AppThemeType.light;
        
        Widget bottomNav = !Responsive.isDesktop(context)
            ? _buildBottomNav(context, themeType, isLiquidGlass, isLight)
            : const SizedBox.shrink();

        return Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: screens,
          ),
          bottomNavigationBar: bottomNav,
        );
      },
    );
  }

  Widget _buildBottomNav(
    BuildContext context,
    AppThemeType themeType,
    bool isLiquidGlass,
    bool isLight,
  ) {
    final theme = Theme.of(context);
    final liquidGlass = theme.extension<LiquidGlassTheme>();
    
    // Determine colors based on theme
    Color backgroundColor;
    Color selectedColor;
    Color unselectedColor;
    
    if (isLiquidGlass) {
      // Glass effect for liquid glass mode
      backgroundColor = Colors.transparent;
      selectedColor = Colors.amber;
      unselectedColor = Colors.white.withOpacity(0.6);
    } else if (isLight) {
      // Light mode - light background
      backgroundColor = Colors.white;
      selectedColor = Colors.amber;
      unselectedColor = Colors.grey[700]!;
    } else {
      // Dark mode
      backgroundColor = Colors.black;
      selectedColor = Colors.amber;
      unselectedColor = Colors.grey;
    }

    final bottomNavBar = BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      backgroundColor: backgroundColor,
      elevation: isLiquidGlass ? 0 : 8,
      items: const {
        'Home': Icons.home,
        'Search': Icons.search,
        'Chat': Icons.chat_bubble_outline,
        'Local Videos': Icons.video_library,
        'More': Icons.menu,
      }
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
      selectedItemColor: selectedColor,
      selectedFontSize: 11.0,
      unselectedFontSize: 11.0,
      unselectedItemColor: unselectedColor,
      onTap: (index) {
        debugPrint('BottomNav: Tab tapped, index: $index, current: $_currentIndex');
        if (mounted) {
          setState(() {
            _currentIndex = index;
          });
        }
      },
    );

    if (isLiquidGlass) {
      // Apply glass effect
      final blur = liquidGlass?.blurIntensity ?? 15.0;
      final opacity = liquidGlass?.glassOpacity ?? 0.18;
      final border = liquidGlass?.borderOpacity ?? 0.25;

      return ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(opacity),
              border: Border(
                top: BorderSide(
                  color: Colors.white.withOpacity(border),
                  width: 1.5,
                ),
              ),
            ),
            child: bottomNavBar,
          ),
        ),
      );
    }

    return bottomNavBar;
  }
}
