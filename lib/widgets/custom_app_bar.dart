import 'package:elysian/assets.dart';
import 'package:elysian/widgets/widgets.dart';
import 'package:flutter/material.dart';

class CustomAppBar extends StatelessWidget {
  final double scrollOffset;

  const CustomAppBar({Key? key, this.scrollOffset = 0.0}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 24.0),
      color: Colors.black.withOpacity(
        (scrollOffset / 350).clamp(0, 1).toDouble(),
      ),
      child: Responsive(
        mobile: _MobileCustomAppBar(),
        desktop: _DesktopCustomAppBar(),
      ),
    );
  }
}

class _MobileCustomAppBar extends StatelessWidget {
  const _MobileCustomAppBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Row(
        children: [
          Image.asset(Assets.logo0),
          const SizedBox(width: 12.0),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _AppBarButton(
                  // ignore: avoid_print
                  onTap: () => print('TV Shows'),
                  title: 'TV Shows',
                ),
                _AppBarButton(
                  // ignore: avoid_print
                  onTap: () => print('Movies'),
                  title: 'Movies',
                ),
                _AppBarButton(
                  // ignore: avoid_print
                  onTap: () => print('My List'),
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
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Row(
        children: [
          Image.asset(Assets.logo1),
          const SizedBox(width: 12.0),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _AppBarButton(
                  // ignore: avoid_print
                  onTap: () => print('Home'),
                  title: 'Home',
                ),
                _AppBarButton(
                  // ignore: avoid_print
                  onTap: () => print('TV Shows'),
                  title: 'TV Shows',
                ),
                _AppBarButton(
                  // ignore: avoid_print
                  onTap: () => print('Movies'),
                  title: 'Movies',
                ),
                _AppBarButton(
                  // ignore: avoid_print
                  onTap: () => print('My List'),
                  title: 'My List',
                ),
                _AppBarButton(
                  // ignore: avoid_print
                  onTap: () => print('Latest'),
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
                  onPressed: () => print('search'),
                  icon: Icon(Icons.search),
                  iconSize: 28.0,
                  color: Colors.white,
                ),
                _AppBarButton(
                  // ignore: avoid_print
                  onTap: () => print('KIDS'),
                  title: 'KIDS',
                ),
                _AppBarButton(
                  // ignore: avoid_print
                  onTap: () => print('DVD'),
                  title: 'DVD',
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => print('Giftcard'),
                  icon: Icon(Icons.card_giftcard),
                  iconSize: 28.0,
                  color: Colors.white,
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => print('notification'),
                  icon: Icon(Icons.notifications),
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
  final Function onTap;

  const _AppBarButton({Key? key, required this.title, required this.onTap})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap,
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
