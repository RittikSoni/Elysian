import 'package:elysian/assets.dart';
import 'package:elysian/widgets/widgets.dart';
import 'package:flutter/material.dart';

class CustomAppBar extends StatelessWidget {
  final double scrollOffset;
  final Function(int)? onNavigateToTab;

  const CustomAppBar({
    super.key,
    this.scrollOffset = 0.0,
    this.onNavigateToTab,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 24.0),
      color: Colors.black.withValues(
        alpha: (scrollOffset / 350).clamp(0, 1).toDouble(),
      ),
      child: Responsive(
        mobile: _MobileCustomAppBar(onNavigateToTab: onNavigateToTab),
        desktop: _DesktopCustomAppBar(onNavigateToTab: onNavigateToTab),
      ),
    );
  }
}

class _MobileCustomAppBar extends StatelessWidget {
  final Function(int)? onNavigateToTab;

  const _MobileCustomAppBar({this.onNavigateToTab});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Row(
        children: [
          GestureDetector(
            onTap: () => onNavigateToTab?.call(0),
            child: Image.asset(Assets.logo0),
          ),
          const SizedBox(width: 12.0),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _AppBarButton(
                  onTap: () {},
                  title: 'TV Shows',
                ),
                _AppBarButton(
                  onTap: () {},
                  title: 'Movies',
                ),
                _AppBarButton(
                  onTap: () {},
                  title: 'My List',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopCustomAppBar extends StatelessWidget {
  final Function(int)? onNavigateToTab;

  const _DesktopCustomAppBar({this.onNavigateToTab});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Row(
        children: [
          GestureDetector(
            onTap: () => onNavigateToTab?.call(0),
            child: Image.asset(Assets.logo1),
          ),
          const SizedBox(width: 12.0),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _AppBarButton(
                  onTap: () => onNavigateToTab?.call(0),
                  title: 'Home',
                ),
                _AppBarButton(
                  onTap: () {},
                  title: 'TV Shows',
                ),
                _AppBarButton(
                  onTap: () {},
                  title: 'Movies',
                ),
                _AppBarButton(
                  onTap: () {},
                  title: 'My List',
                ),
                _AppBarButton(
                  onTap: () => onNavigateToTab?.call(2),
                  title: 'Latest',
                ),
              ],
            ),
          ),
          const Spacer(),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => onNavigateToTab?.call(1),
                  icon: const Icon(Icons.search),
                  iconSize: 28.0,
                  color: Colors.white,
                ),
                _AppBarButton(
                  onTap: () {},
                  title: 'KIDS',
                ),
                _AppBarButton(
                  onTap: () {},
                  title: 'DVD',
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {},
                  icon: const Icon(Icons.card_giftcard),
                  iconSize: 28.0,
                  color: Colors.white,
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {},
                  icon: const Icon(Icons.notifications),
                  iconSize: 28.0,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AppBarButton extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _AppBarButton({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16.0,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}
