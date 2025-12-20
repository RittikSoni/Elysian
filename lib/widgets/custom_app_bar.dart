// ignore_for_file: use_build_context_synchronously

import 'dart:ui';
import 'package:elysian/assets.dart';
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
import 'package:elysian/utils/app_themes.dart';
import 'package:provider/provider.dart';
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
    return Consumer<AppStateProvider>(
      builder: (context, appState, _) {
        final isLiquidGlass = appState.themeType == AppThemeType.liquidGlass;
        final isLight = appState.themeType == AppThemeType.light;
        final theme = Theme.of(context);
        final liquidGlass = theme.extension<LiquidGlassTheme>();

        final scrollAlpha = (scrollOffset / 350).clamp(0, 1).toDouble();

        Widget appBarContent = Responsive(
          mobile: _MobileCustomAppBar(onNavigateToTab: onNavigateToTab),
          desktop: _DesktopCustomAppBar(onNavigateToTab: onNavigateToTab),
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
                padding: const EdgeInsets.symmetric(
                  vertical: 10.0,
                  horizontal: 24.0,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(
                    alpha: opacity * (0.3 + scrollAlpha * 0.7),
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white.withValues(alpha: border),
                      width: 1.5,
                    ),
                  ),
                ),
                child: appBarContent,
              ),
            ),
          );
        } else if (isLight) {
          // Light mode - light background with opacity
          return Container(
            padding: const EdgeInsets.symmetric(
              vertical: 10.0,
              horizontal: 24.0,
            ),
            color: Colors.white.withValues(alpha: scrollAlpha),
            child: appBarContent,
          );
        } else {
          // Dark mode
          return Container(
            padding: const EdgeInsets.symmetric(
              vertical: 10.0,
              horizontal: 24.0,
            ),
            color: Colors.black.withValues(alpha: scrollAlpha),
            child: appBarContent,
          );
        }
      },
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
                  onTap: () {
                    onNavigateToTab?.call(2);
                  },
                  title: 'Chat',
                ),
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
            icon: const Icon(Icons.celebration),
            iconSize: 28.0,

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

                IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    onNavigateToTab?.call(2);
                  },
                  icon: const Icon(Icons.chat_bubble),
                  iconSize: 28.0,
                  color: Colors.white,
                ),

                IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => _showWatchPartyDialog(context),
                  icon: const Icon(Icons.celebration),
                  iconSize: 28.0,
                  tooltip: 'Watch Party',
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    onNavigateToTab?.call(4);
                  },
                  icon: const Icon(Icons.person),
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

void _showWatchPartyDialog(BuildContext context) async {
  final watchPartyProvider = Provider.of<WatchPartyProvider>(
    context,
    listen: false,
  );

  // Check if already in a room
  if (watchPartyProvider.isInRoom) {
    final room = watchPartyProvider.currentRoom;
    if (room != null) {
      debugPrint(
        'WatchParty: Showing dialog for room ${room.roomId}, videoUrl: ${room.videoUrl}, isHost: ${watchPartyProvider.isHost}',
      );
      // Show watch party screen (participants, chat, etc.)
      showDialog(
        context: context,
        barrierColor: Colors.black87,
        barrierDismissible: true,
        builder: (dialogContext) => Consumer<WatchPartyProvider>(
          builder: (context, provider, child) {
            // Get the latest room state
            final currentRoom = provider.currentRoom;
            if (currentRoom == null) {
              // Room was closed, close dialog
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext, rootNavigator: true).pop();
                }
              });
              return const SizedBox.shrink();
            }

            return Dialog(
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
                      room: currentRoom,
                      isHost: provider.isHost,
                      onClose: () {
                        // Close dialog using the dialog context
                        if (dialogContext.mounted) {
                          Navigator.of(
                            dialogContext,
                            rootNavigator: true,
                          ).pop();
                        }
                      },
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
                        onPressed: () {
                          if (dialogContext.mounted) {
                            Navigator.of(
                              dialogContext,
                              rootNavigator: true,
                            ).pop();
                          }
                        },
                      ),
                    ),
                    // Option to navigate to video if playing
                    if (currentRoom.videoUrl.isNotEmpty)
                      Positioned(
                        bottom: 20,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              // Close watch party screen using dialog context
                              if (dialogContext.mounted) {
                                Navigator.of(
                                  dialogContext,
                                  rootNavigator: true,
                                ).pop();
                              }
                              // Small delay to ensure dialog is closed
                              await Future.delayed(
                                const Duration(milliseconds: 100),
                              );
                              // Navigate to video player using original context (not dialog context)
                              if (!context.mounted) return;
                              final allLinks =
                                  await StorageService.getSavedLinks();
                              try {
                                final link = allLinks.firstWhere(
                                  (l) => l.url == currentRoom.videoUrl,
                                  orElse: () => SavedLink(
                                    id: '',
                                    url: currentRoom.videoUrl,
                                    title: currentRoom.videoTitle,
                                    type:
                                        LinkParser.parseLinkType(
                                          currentRoom.videoUrl,
                                        ) ??
                                        LinkType.unknown,
                                    listIds: [],
                                    savedAt: DateTime.now(),
                                  ),
                                );

                                // Use root navigator for video navigation
                                final rootNavigator = Navigator.of(
                                  context,
                                  rootNavigator: true,
                                );
                                if (link.type == LinkType.youtube) {
                                  rootNavigator.push(
                                    MaterialPageRoute(
                                      builder: (context) => YTFull(
                                        url: link.url,
                                        title: link.title.isNotEmpty
                                            ? link.title
                                            : currentRoom.videoTitle,
                                        listIds: link.listIds,
                                      ),
                                    ),
                                  );
                                } else if (link.type.canPlayInbuilt) {
                                  rootNavigator.push(
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          RSNewVideoPlayerScreen(
                                            url: link.url,
                                            title: link.title.isNotEmpty
                                                ? link.title
                                                : currentRoom.videoTitle,
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
            );
          },
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
