import 'package:elysian/assets.dart';
import 'package:elysian/models/watch_party_models.dart';
import 'package:elysian/models/models.dart';
import 'package:elysian/screens/lists_management_screen.dart';
import 'package:elysian/services/storage_service.dart';
import 'package:elysian/services/link_parser.dart';
import 'package:elysian/video_player/video_player_full.dart';
import 'package:elysian/video_player/yt_full.dart';
import 'package:elysian/widgets/widgets.dart';
import 'package:elysian/widgets/watch_party_room_dialog.dart';
import 'package:elysian/widgets/watch_party_participants_overlay.dart';
import 'package:elysian/providers/providers.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

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
                _AppBarButton(onTap: () {}, title: 'TV Shows'),
                _AppBarButton(onTap: () {}, title: 'Movies'),
                _AppBarButton(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ListsManagementScreen(),
                      ),
                    );
                  },
                  title: 'My List',
                ),
              ],
            ),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            onPressed: () => _showWatchPartyDialog(context),
            icon: const Icon(Icons.people),
            iconSize: 28.0,
            color: Colors.amber,
            tooltip: 'Watch Party',
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
                _AppBarButton(onTap: () {}, title: 'TV Shows'),
                _AppBarButton(onTap: () {}, title: 'Movies'),
                _AppBarButton(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ListsManagementScreen(),
                      ),
                    );
                  },
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
                _AppBarButton(onTap: () {}, title: 'KIDS'),
                _AppBarButton(onTap: () {}, title: 'DVD'),
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
                IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => _showWatchPartyDialog(context),
                  icon: const Icon(Icons.people),
                  iconSize: 28.0,
                  color: Colors.amber,
                  tooltip: 'Watch Party',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

void _showWatchPartyDialog(BuildContext context) async {
  final watchPartyProvider = Provider.of<WatchPartyProvider>(
    context,
    listen: false,
  );

  // Check if already in a room
  if (watchPartyProvider.isInRoom) {
    final room = watchPartyProvider.currentRoom;
    if (room != null) {
      // Show watch party screen (participants, chat, etc.)
      showDialog(
        context: context,
        barrierColor: Colors.black87,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Container(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
            color: Colors.black,
            child: Stack(
              children: [
                // Watch party participants overlay
                WatchPartyParticipantsOverlay(
                  room: room,
                  isHost: watchPartyProvider.isHost,
                  onClose: () => Navigator.pop(context),
                ),
                // Close button
                Positioned(
                  top: 40,
                  right: 16,
                  child: IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                // Option to navigate to video if playing
                if (room.videoUrl.isNotEmpty)
                  Positioned(
                    bottom: 20,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.pop(context); // Close watch party screen
                          // Navigate to video player
                          final allLinks = await StorageService.getSavedLinks();
                          try {
                            final link = allLinks.firstWhere(
                              (l) => l.url == room.videoUrl,
                              orElse: () => SavedLink(
                                id: '',
                                url: room.videoUrl,
                                title: room.videoTitle,
                                type:
                                    LinkParser.parseLinkType(room.videoUrl) ??
                                    LinkType.unknown,
                                listIds: [],
                                savedAt: DateTime.now(),
                              ),
                            );

                            if (link.type == LinkType.youtube) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => YTFull(
                                    url: link.url,
                                    title: link.title.isNotEmpty
                                        ? link.title
                                        : room.videoTitle,
                                    listIds: link.listIds,
                                  ),
                                ),
                              );
                            } else if (link.type.canPlayInbuilt) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => RSNewVideoPlayerScreen(
                                    url: link.url,
                                    title: link.title.isNotEmpty
                                        ? link.title
                                        : room.videoTitle,
                                    listIds: link.listIds,
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            debugPrint(
                              'Error navigating to watch party video: $e',
                            );
                          }
                        },
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Go to Video'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }
    return;
  }

  // Show create/join dialog
  final room = await showDialog<WatchPartyRoom>(
    context: context,
    builder: (context) => WatchPartyRoomDialog(
      videoUrl: '',
      videoTitle: 'Watch Party',
      currentPosition: Duration.zero,
      isPlaying: false,
    ),
  );

  if (room != null && context.mounted) {
    // If guest joined, they will be navigated to video automatically via provider
    // If host created, show message
    if (watchPartyProvider.isHost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Room created! Open a video to start watching.'),
          backgroundColor: Colors.amber,
        ),
      );
    } else {
      // Guest joined - will be navigated automatically when host starts video
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Joined room! Waiting for host to start video...'),
          backgroundColor: Colors.amber,
        ),
      );
    }
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
