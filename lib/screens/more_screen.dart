import 'package:flutter/material.dart';
import 'package:elysian/widgets/widgets.dart';
import 'package:elysian/services/storage_service.dart';
import 'package:elysian/screens/lists_management_screen.dart';
import 'package:elysian/screens/saved_links_screen.dart';

class MoreScreen extends StatefulWidget {
  final Function(int)? onNavigateToTab;
  
  const MoreScreen({super.key, this.onNavigateToTab});

  @override
  MoreScreenState createState() => MoreScreenState();
}

class MoreScreenState extends State<MoreScreen> {
  late ScrollController _scrollController;
  double _scrollOffset = 0.0;
  bool _useInbuiltPlayer = true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()
      ..addListener(() {
        setState(() {
          _scrollOffset = _scrollController.offset;
        });
      });
    _loadPlayerPreference();
  }

  Future<void> _loadPlayerPreference() async {
    final useInbuilt = await StorageService.isInbuiltPlayer();
    setState(() {
      _useInbuiltPlayer = useInbuilt;
    });
  }

  Future<void> _togglePlayerPreference(bool value) async {
    await StorageService.setPlayerPreference(value);
    setState(() {
      _useInbuiltPlayer = value;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: Size(MediaQuery.of(context).size.width, 50),
        child: CustomAppBar(
          scrollOffset: _scrollOffset,
          onNavigateToTab: widget.onNavigateToTab,
        ),
      ),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 100.0, left: 20.0, right: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 60.0,
                        height: 60.0,
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                        child: const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 40.0,
                        ),
                      ),
                      const SizedBox(width: 16.0),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Profile Name',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4.0),
                            Text(
                              'Manage profiles',
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 16.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
              child: Column(
                children: [
                  _MoreMenuItem(
                    icon: Icons.notifications_outlined,
                    title: 'Notifications',
                    onTap: () {},
                  ),
                  _MoreMenuItem(
                    icon: Icons.account_circle_outlined,
                    title: 'Account',
                    onTap: () {},
                  ),
                  _MoreMenuItem(
                    icon: Icons.lock_outline,
                    title: 'Privacy',
                    onTap: () {},
                  ),
                  _MoreMenuItem(
                    icon: Icons.security,
                    title: 'Security',
                    onTap: () {},
                  ),
                  _MoreMenuItem(
                    icon: Icons.payment,
                    title: 'Payment',
                    onTap: () {},
                  ),
                  _MoreMenuItem(
                    icon: Icons.help_outline,
                    title: 'Help & Support',
                    onTap: () {},
                  ),
                  _MoreMenuItem(
                    icon: Icons.info_outline,
                    title: 'About',
                    onTap: () {},
                  ),
                  _MoreMenuItem(
                    icon: Icons.playlist_play,
                    title: 'My Lists',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ListsManagementScreen(),
                        ),
                      );
                    },
                  ),
                  _MoreMenuItem(
                    icon: Icons.link,
                    title: 'Saved Links',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SavedLinksScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'App Settings',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14.0,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12.0),
                  _MoreMenuItem(
                    icon: Icons.language,
                    title: 'Language',
                    subtitle: 'English',
                    onTap: () {},
                  ),
                  _MoreMenuItem(
                    icon: Icons.brightness_6,
                    title: 'Appearance',
                    subtitle: 'Dark',
                    onTap: () {},
                  ),
                  _MoreMenuItem(
                    icon: Icons.play_arrow,
                    title: 'Autoplay',
                    subtitle: 'On',
                    onTap: () {},
                  ),
                  _PlayerPreferenceItem(
                    icon: Icons.video_library,
                    title: 'Video Player',
                    subtitle: _useInbuiltPlayer ? 'Inbuilt' : 'External',
                    value: _useInbuiltPlayer,
                    onChanged: _togglePlayerPreference,
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Center(
                child: TextButton(
                  onPressed: () {
                    // Handle sign out
                  },
                  child: const Text(
                    'Sign Out',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16.0,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.only(bottom: 20.0),
          ),
        ],
      ),
    );
  }
}

class _MoreMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _MoreMenuItem({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Row(
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 28.0,
            ),
            const SizedBox(width: 16.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16.0,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4.0),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14.0,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.grey[600],
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerPreferenceItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PlayerPreferenceItem({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Row(
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 28.0,
            ),
            const SizedBox(width: 16.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16.0,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4.0),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14.0,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: Colors.red,
            ),
          ],
        ),
      ),
    );
  }
}

