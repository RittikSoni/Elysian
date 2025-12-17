import 'package:flutter/material.dart';
import 'package:elysian/models/watch_party_models.dart';
import 'package:elysian/providers/providers.dart';
import 'package:elysian/widgets/watch_party_participants_overlay.dart';
import 'package:provider/provider.dart';

/// Persistent watch party indicator that shows on all screens
class WatchPartyIndicator extends StatelessWidget {
  final WatchPartyRoom room;
  final bool isHost;
  final VoidCallback? onTap;

  const WatchPartyIndicator({
    super.key,
    required this.room,
    required this.isHost,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Position in bottom-right, accounting for bottom nav bar if present
    // Check if bottom nav exists (mobile only, desktop doesn't have it)
    final hasBottomNav = MediaQuery.of(context).size.width < 600;
    final bottomNavHeight = hasBottomNav ? 60.0 : 0.0;
    final safeAreaBottom = MediaQuery.of(context).padding.bottom;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(
          bottom: safeAreaBottom + bottomNavHeight + 12,
          right: 16,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.2),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.amber.withOpacity(0.6),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.people,
              color: Colors.amber,
              size: 14,
            ),
            const SizedBox(width: 5),
            Text(
              'Watch Party',
              style: TextStyle(
                color: Colors.amber,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (isHost) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'HOST',
                  style: TextStyle(
                    color: Colors.amber,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${room.participants.length}',
                style: TextStyle(
                  color: Colors.amber,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Global watch party indicator overlay
class WatchPartyIndicatorOverlay {
  static OverlayEntry? _overlayEntry;
  static bool _isShowing = false;
  static WatchPartyRoom? _currentRoom;
  static bool _currentIsHost = false;

  static void show(BuildContext context, WatchPartyRoom room, bool isHost) {
    // Don't show if room is null or invalid
    if (room.roomId.isEmpty) {
      hide();
      return;
    }
    
    final overlay = Navigator.of(context).overlay;
    if (overlay == null) return;

    // Update current state
    _currentRoom = room;
    _currentIsHost = isHost;

    if (_isShowing && _overlayEntry != null) {
      // Update existing overlay only if room is still valid
      if (_currentRoom != null && _currentRoom!.roomId == room.roomId) {
        _overlayEntry!.markNeedsBuild();
      } else {
        // Room changed or invalid, hide and recreate
        hide();
        show(context, room, isHost);
      }
    } else {
      // Create new overlay
      if (_overlayEntry != null) {
        _overlayEntry!.remove();
      }

      _overlayEntry = OverlayEntry(
        builder: (context) {
          // Check if room is still valid when building
          if (_currentRoom == null || _currentRoom!.roomId != room.roomId) {
            return const SizedBox.shrink();
          }
          return Positioned(
            bottom: 0,
            right: 0,
            child: WatchPartyIndicator(
              room: _currentRoom!,
              isHost: _currentIsHost,
              onTap: () {
                // Open watch party dialog
                final watchPartyProvider = Provider.of<WatchPartyProvider>(
                  context,
                  listen: false,
                );
                // Only show dialog if still in room
                if (watchPartyProvider.isInRoom && watchPartyProvider.currentRoom != null) {
                  _showWatchPartyDialog(context, watchPartyProvider);
                }
              },
            ),
          );
        },
      );

      overlay.insert(_overlayEntry!);
      _isShowing = true;
    }
  }

  static void hide() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _isShowing = false;
    _currentRoom = null;
    _currentIsHost = false;
  }

  static void _showWatchPartyDialog(
    BuildContext context,
    WatchPartyProvider provider,
  ) {
    final room = provider.currentRoom;
    if (room == null) return;

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
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
                isHost: provider.isHost,
                onClose: () {
                  // Use the dialog context to close
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext, rootNavigator: true).pop();
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
                      Navigator.of(dialogContext, rootNavigator: true).pop();
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    // Don't hide indicator when dialog closes - only hide when actually leaving room
  }
}

