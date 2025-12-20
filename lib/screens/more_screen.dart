// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:elysian/widgets/widgets.dart';
import 'package:elysian/providers/providers.dart';
import 'package:elysian/services/export_import_service.dart';
import 'package:elysian/services/storage_service.dart';
import 'package:elysian/services/auth_service.dart';
import 'package:elysian/utils/app_themes.dart';
import 'package:elysian/screens/lists_management_screen.dart';
import 'package:elysian/screens/saved_links_screen.dart';
import 'package:elysian/screens/statistics_screen.dart';
import 'package:elysian/screens/about_screen.dart';
import 'package:elysian/screens/help_support_screen.dart';
import 'package:elysian/screens/coming_soon_screen.dart';
import 'package:elysian/screens/home_screen_customization_screen.dart';
import 'package:elysian/screens/chat_list_screen.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

class MoreScreen extends StatefulWidget {
  final Function(int)? onNavigateToTab;

  const MoreScreen({super.key, this.onNavigateToTab});

  @override
  MoreScreenState createState() => MoreScreenState();
}

class MoreScreenState extends State<MoreScreen> {
  late ScrollController _scrollController;
  double _scrollOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()
      ..addListener(() {
        // Only update if offset changed significantly (performance optimization)
        final newOffset = _scrollController.offset;
        if ((newOffset - _scrollOffset).abs() > 1.0) {
          setState(() {
            _scrollOffset = newOffset;
          });
        }
      });

    // Initialize app state provider if needed (only if not already initialized)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final appStateProvider = context.read<AppStateProvider>();
        // Only initialize if not already loaded
        if (appStateProvider.isLoadingPlayerPreference == false &&
            appStateProvider.isLoadingTheme == false) {
          // Already initialized, skip
          return;
        }
        // Don't call initialize here as it might cause rebuilds
        // The provider should be initialized at app startup
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
              padding: const EdgeInsets.only(
                top: 100.0,
                left: 20.0,
                right: 20.0,
              ),
              child: Consumer<ChatProvider>(
                builder: (context, chatProvider, child) {
                  final authService = AuthService();
                  final isSignedIn = chatProvider.currentUserEmail != null;
                  final userEmail = isSignedIn
                      ? chatProvider.currentUserEmail
                      : authService.userEmail;
                  final userDisplayName = isSignedIn
                      ? chatProvider.currentUserDisplayName
                      : authService.userDisplayName;
                  final userPhotoUrl = authService.userPhotoUrl;

                  return InkWell(
                    onTap: () {
                      if (isSignedIn) {
                        // Show account details dialog
                        _showAccountDetailsDialog(context, authService);
                      } else {
                        // Navigate to sign in or show sign in dialog
                        _showSignInPrompt(context);
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: ThemeAwareContainer(
                      padding: const EdgeInsets.all(16.0),
                      borderRadius: BorderRadius.circular(12.0),
                      child: Row(
                        children: [
                          // Profile Avatar
                          if (userPhotoUrl != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(30.0),
                              child: Image.network(
                                userPhotoUrl,
                                width: 60.0,
                                height: 60.0,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 60.0,
                                    height: 60.0,
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary,
                                      borderRadius: BorderRadius.circular(30.0),
                                    ),
                                    child: Center(
                                      child: Text(
                                        _getUserInitial(
                                          userDisplayName,
                                          userEmail,
                                        ),
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 24.0,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            )
                          else
                            Container(
                              width: 60.0,
                              height: 60.0,
                              decoration: BoxDecoration(
                                color: isSignedIn
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurface.withValues(
                                        alpha: 0.3,
                                      ),
                                borderRadius: BorderRadius.circular(30.0),
                              ),
                              child: Center(
                                child: Text(
                                  isSignedIn
                                      ? _getUserInitial(
                                          userDisplayName,
                                          userEmail,
                                        )
                                      : '?',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 24.0,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(width: 16.0),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isSignedIn
                                      ? (userDisplayName ??
                                            userEmail?.split('@').first ??
                                            'User')
                                      : 'Guest User',
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface,
                                    fontSize: 24.0,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4.0),
                                Text(
                                  isSignedIn
                                      ? (userEmail ?? 'No email')
                                      : 'Tap to sign in',
                                  style: TextStyle(
                                    color: isSignedIn
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurface
                                              .withValues(alpha: 0.6),
                                    fontSize: 16.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            isSignedIn ? Icons.chevron_right : Icons.login,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 20.0,
              ),
              child: Column(
                children: [
                  _MoreMenuItem(
                    icon: Icons.notifications_outlined,
                    title: 'Notifications',
                    onTap: () {
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder:
                              (context, animation, secondaryAnimation) =>
                                  const ComingSoonScreen(
                                    title: 'Notifications',
                                  ),
                          transitionsBuilder:
                              (context, animation, secondaryAnimation, child) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: child,
                                );
                              },
                          transitionDuration: const Duration(milliseconds: 200),
                        ),
                      );
                    },
                  ),
                  _MoreMenuItem(
                    icon: Icons.account_circle_outlined,
                    title: 'Account',
                    onTap: () {
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder:
                              (context, animation, secondaryAnimation) =>
                                  const ComingSoonScreen(title: 'Account'),
                          transitionsBuilder:
                              (context, animation, secondaryAnimation, child) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: child,
                                );
                              },
                          transitionDuration: const Duration(milliseconds: 200),
                        ),
                      );
                    },
                  ),
                  _MoreMenuItem(
                    icon: Icons.lock_outline,
                    title: 'Privacy',
                    onTap: () {
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder:
                              (context, animation, secondaryAnimation) =>
                                  const ComingSoonScreen(title: 'Privacy'),
                          transitionsBuilder:
                              (context, animation, secondaryAnimation, child) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: child,
                                );
                              },
                          transitionDuration: const Duration(milliseconds: 200),
                        ),
                      );
                    },
                  ),
                  _MoreMenuItem(
                    icon: Icons.security,
                    title: 'Security',
                    onTap: () {
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder:
                              (context, animation, secondaryAnimation) =>
                                  const ComingSoonScreen(title: 'Security'),
                          transitionsBuilder:
                              (context, animation, secondaryAnimation, child) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: child,
                                );
                              },
                          transitionDuration: const Duration(milliseconds: 200),
                        ),
                      );
                    },
                  ),
                  _MoreMenuItem(
                    icon: Icons.payment,
                    title: 'Payment',
                    onTap: () {
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder:
                              (context, animation, secondaryAnimation) =>
                                  const ComingSoonScreen(title: 'Payment'),
                          transitionsBuilder:
                              (context, animation, secondaryAnimation, child) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: child,
                                );
                              },
                          transitionDuration: const Duration(milliseconds: 200),
                        ),
                      );
                    },
                  ),
                  _MoreMenuItem(
                    icon: Icons.help_outline,
                    title: 'Help & Support',
                    onTap: () {
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder:
                              (context, animation, secondaryAnimation) =>
                                  const HelpSupportScreen(),
                          transitionsBuilder:
                              (context, animation, secondaryAnimation, child) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: child,
                                );
                              },
                          transitionDuration: const Duration(milliseconds: 200),
                        ),
                      );
                    },
                  ),
                  _MoreMenuItem(
                    icon: Icons.info_outline,
                    title: 'About',
                    onTap: () {
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder:
                              (context, animation, secondaryAnimation) =>
                                  const AboutScreen(),
                          transitionsBuilder:
                              (context, animation, secondaryAnimation, child) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: child,
                                );
                              },
                          transitionDuration: const Duration(milliseconds: 200),
                        ),
                      );
                    },
                  ),
                  _MoreMenuItem(
                    icon: Icons.playlist_play,
                    title: 'My Lists',
                    onTap: () {
                      // Use fade transition to prevent screen fluctuation
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder:
                              (context, animation, secondaryAnimation) =>
                                  const ListsManagementScreen(),
                          transitionsBuilder:
                              (context, animation, secondaryAnimation, child) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: child,
                                );
                              },
                          transitionDuration: const Duration(milliseconds: 200),
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
                        PageRouteBuilder(
                          pageBuilder:
                              (context, animation, secondaryAnimation) =>
                                  const SavedLinksScreen(),
                          transitionsBuilder:
                              (context, animation, secondaryAnimation, child) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: child,
                                );
                              },
                          transitionDuration: const Duration(milliseconds: 200),
                        ),
                      );
                    },
                  ),
                  _MoreMenuItem(
                    icon: Icons.dashboard_customize,
                    title: 'Customize Home Screen',
                    onTap: () {
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder:
                              (context, animation, secondaryAnimation) =>
                                  const HomeScreenCustomizationScreen(),
                          transitionsBuilder:
                              (context, animation, secondaryAnimation, child) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: child,
                                );
                              },
                          transitionDuration: const Duration(milliseconds: 200),
                        ),
                      );
                    },
                  ),
                  _MoreMenuItem(
                    icon: Icons.upload_file,
                    title: 'Export Data',
                    onTap: () async {
                      try {
                        // Show loading
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) =>
                              const Center(child: CircularProgressIndicator()),
                        );

                        // Export to file
                        final filePath =
                            await ExportImportService.exportToFile();

                        // Close loading
                        if (context.mounted) {
                          Navigator.pop(context);
                        }

                        if (filePath == null) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Error creating export file'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                          return;
                        }

                        // Share the file
                        final shared =
                            await ExportImportService.shareExportedFile(
                              filePath,
                            );

                        if (context.mounted) {
                          if (shared) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Export file created and ready to share!',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Export file created. You can find it in your downloads.',
                                ),
                                backgroundColor: Colors.amber,
                              ),
                            );
                          }
                        }
                      } catch (e) {
                        if (context.mounted) {
                          Navigator.pop(context); // Close loading if still open
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error exporting data: $e')),
                          );
                        }
                      }
                    },
                  ),
                  _MoreMenuItem(
                    icon: Icons.download,
                    title: 'Import Data',
                    onTap: () async {
                      try {
                        // Pick file using file_picker (use FileType.any since .elysian is custom)
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.any,
                          dialogTitle: 'Select Elysian Export File (.elysian)',
                        );

                        if (result == null || result.files.isEmpty) {
                          return; // User cancelled
                        }

                        final filePath = result.files.single.path;
                        if (filePath == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Error: Could not access file'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        // Validate file format before importing
                        final isValid =
                            await ExportImportService.isValidElysianFile(
                              filePath,
                            );
                        if (!isValid) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Invalid file format. Please select a valid .elysian export file.',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        // Show loading
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) =>
                              const Center(child: CircularProgressIndicator()),
                        );

                        // Import from file
                        final importResult =
                            await ExportImportService.importFromFile(filePath);

                        // Close loading
                        if (context.mounted) {
                          Navigator.pop(context);
                        }

                        if (importResult.success) {
                          // Refresh providers
                          final linksProvider = context.read<LinksProvider>();
                          final listsProvider = context.read<ListsProvider>();
                          await Future.wait([
                            linksProvider.loadLinks(forceRefresh: true),
                            listsProvider.loadLists(forceRefresh: true),
                          ]);

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  importResult.message ??
                                      'Data imported successfully!',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } else {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  importResult.error ?? 'Error importing data',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      } catch (e) {
                        if (context.mounted) {
                          Navigator.pop(context); // Close loading if still open
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error importing data: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                  ),
                  _MoreMenuItem(
                    icon: Icons.analytics,
                    title: 'Statistics',
                    onTap: () {
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder:
                              (context, animation, secondaryAnimation) =>
                                  const StatisticsScreen(),
                          transitionsBuilder:
                              (context, animation, secondaryAnimation, child) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: child,
                                );
                              },
                          transitionDuration: const Duration(milliseconds: 200),
                        ),
                      );
                    },
                  ),
                  _MoreMenuItem(
                    icon: Icons.delete_forever,
                    title: 'Reset All Data',
                    subtitle: 'Delete all saved links and lists',
                    onTap: () async {
                      // Show confirmation dialog
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: Colors.grey[900],
                          title: const Text(
                            'Reset All Data',
                            style: TextStyle(color: Colors.white),
                          ),
                          content: const Text(
                            'This will permanently delete all your saved links, lists, and home screen customizations. This action cannot be undone.\n\nAre you sure you want to continue?',
                            style: TextStyle(color: Colors.white70),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Delete All'),
                            ),
                          ],
                        ),
                      );

                      if (confirmed != true) {
                        return; // User cancelled
                      }

                      // Show second confirmation for safety
                      final doubleConfirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: Colors.grey[900],
                          title: const Text(
                            'Final Confirmation',
                            style: TextStyle(color: Colors.red),
                          ),
                          content: const Text(
                            'This is your last chance. All your data will be permanently deleted. Are you absolutely sure?',
                            style: TextStyle(color: Colors.white70),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Yes, Delete Everything'),
                            ),
                          ],
                        ),
                      );

                      if (doubleConfirmed != true) {
                        return; // User cancelled
                      }

                      try {
                        // Show loading
                        if (context.mounted) {
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => const Center(
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }

                        // Reset all data
                        await StorageService.resetAllData();

                        // Sign out from authentication
                        final authService = AuthService();
                        await authService.signOut();

                        // Clear chat providers
                        final chatProvider = context.read<ChatProvider>();
                        await chatProvider.signOut();

                        // Refresh all providers
                        final linksProvider = context.read<LinksProvider>();
                        final listsProvider = context.read<ListsProvider>();
                        final layoutProvider = context
                            .read<HomeScreenLayoutProvider>();

                        await Future.wait([
                          linksProvider.loadLinks(forceRefresh: true),
                          listsProvider.loadLists(forceRefresh: true),
                          layoutProvider.resetToDefault(),
                        ]);

                        // Close loading
                        if (context.mounted) {
                          Navigator.pop(context);
                        }

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'All data has been reset successfully',
                              ),
                              backgroundColor: Colors.green,
                              duration: Duration(seconds: 3),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          Navigator.pop(context); // Close loading if still open
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error resetting data: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 20.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'App Settings',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
                  Consumer<AppStateProvider>(
                    builder: (context, appStateProvider, child) {
                      String themeSubtitle;
                      switch (appStateProvider.themeType) {
                        case AppThemeType.light:
                          themeSubtitle = 'Light';
                          break;
                        case AppThemeType.dark:
                          themeSubtitle = 'Dark';
                          break;
                        case AppThemeType.liquidGlass:
                          themeSubtitle = 'Liquid Glass';
                          break;
                      }

                      return _MoreMenuItem(
                        icon: Icons.brightness_6,
                        title: 'Appearance',
                        subtitle: themeSubtitle,
                        onTap: () {
                          _showThemeSelectionDialog(context, appStateProvider);
                        },
                      );
                    },
                  ),
                  _MoreMenuItem(
                    icon: Icons.play_arrow,
                    title: 'Autoplay',
                    subtitle: 'On',
                    onTap: () {},
                  ),
                  Consumer<AppStateProvider>(
                    builder: (context, appStateProvider, child) {
                      return _PlayerPreferenceItem(
                        icon: Icons.video_library,
                        title: 'Video Player',
                        subtitle: appStateProvider.isInbuiltPlayer
                            ? 'Inbuilt'
                            : 'External',
                        value: appStateProvider.isInbuiltPlayer,
                        onChanged: (value) =>
                            appStateProvider.setPlayerPreference(value),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          Consumer<ChatProvider>(
            builder: (context, chatProvider, child) {
              final isSignedIn = chatProvider.currentUserEmail != null;

              if (!isSignedIn) {
                return const SliverToBoxAdapter(child: SizedBox.shrink());
              }

              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Center(
                    child: TextButton(
                      onPressed: () async {
                        // Show confirmation dialog
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: Colors.grey[900],
                            title: const Text(
                              'Sign Out',
                              style: TextStyle(color: Colors.white),
                            ),
                            content: const Text(
                              'Are you sure you want to sign out?',
                              style: TextStyle(color: Colors.white70),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber,
                                  foregroundColor: Colors.black,
                                ),
                                child: const Text('Sign Out'),
                              ),
                            ],
                          ),
                        );

                        if (confirmed == true && context.mounted) {
                          try {
                            // Show loading
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) => const Center(
                                child: CircularProgressIndicator(),
                              ),
                            );

                            // Sign out
                            await chatProvider.signOut();

                            // Close loading
                            if (context.mounted) {
                              Navigator.pop(context);
                            }

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Signed out successfully'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              Navigator.pop(context); // Close loading
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error signing out: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        }
                      },
                      child: Text(
                        'Sign Out',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 16.0,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          // Tagline
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0),
              child: Center(
                child: Builder(
                  builder: (context) {
                    final theme = Theme.of(context);
                    return Text(
                      'Made with ❤️ in India',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.5,
                        ),
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          SliverPadding(padding: EdgeInsets.only(bottom: 20.0)),
        ],
      ),
    );
  }

  String _getUserInitial(String? displayName, String? email) {
    if (displayName != null && displayName.isNotEmpty) {
      return displayName[0].toUpperCase();
    }
    if (email != null && email.isNotEmpty) {
      return email[0].toUpperCase();
    }
    return 'U';
  }

  void _showAccountDetailsDialog(
    BuildContext context,
    AuthService authService,
  ) {
    final userEmail = authService.userEmail;
    final userDisplayName = authService.userDisplayName;
    final userPhotoUrl = authService.userPhotoUrl;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Account Details',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 8),
            // Profile Photo
            if (userPhotoUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(50),
                child: Image.network(
                  userPhotoUrl,
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Center(
                        child: Text(
                          _getUserInitial(userDisplayName, userEmail),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              )
            else
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Center(
                  child: Text(
                    _getUserInitial(userDisplayName, userEmail),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            // Display Name
            if (userDisplayName != null && userDisplayName.isNotEmpty)
              Text(
                userDisplayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            const SizedBox(height: 8),
            // Email
            if (userEmail != null)
              Text(
                userEmail,
                style: TextStyle(color: Colors.grey[400], fontSize: 14),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showSignInPrompt(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.login, color: Colors.amber),
            SizedBox(width: 8),
            Text('Sign In Required', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          'Please sign in to access your profile and use chat features.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close this dialog
              // Navigate to chat list screen which has sign-in functionality
              if (context.mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ChatListScreen()),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
            ),
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
  }

  void _showThemeSelectionDialog(
    BuildContext context,
    AppStateProvider appStateProvider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(
          'Select Theme',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ThemeOption(
              title: 'Light',
              description: 'Clean and bright',
              icon: Icons.light_mode,
              themeType: AppThemeType.light,
              isSelected: appStateProvider.themeType == AppThemeType.light,
              onTap: () {
                appStateProvider.setThemeType(AppThemeType.light);
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 12),
            _ThemeOption(
              title: 'Dark',
              description: 'Easy on the eyes',
              icon: Icons.dark_mode,
              themeType: AppThemeType.dark,
              isSelected: appStateProvider.themeType == AppThemeType.dark,
              onTap: () {
                appStateProvider.setThemeType(AppThemeType.dark);
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 12),
            _ThemeOption(
              title: 'Liquid Glass',
              description: 'Apple-inspired glassmorphism',
              icon: Icons.blur_on,
              themeType: AppThemeType.liquidGlass,
              isSelected:
                  appStateProvider.themeType == AppThemeType.liquidGlass,
              onTap: () {
                appStateProvider.setThemeType(AppThemeType.liquidGlass);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final AppThemeType themeType;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.title,
    required this.description,
    required this.icon,
    required this.themeType,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface,
              size: 28,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: theme.colorScheme.primary),
          ],
        ),
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
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.onSurface, size: 28.0),
            const SizedBox(width: 16.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 16.0,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4.0),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                        fontSize: 14.0,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
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
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.onSurface, size: 28.0),
            const SizedBox(width: 16.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 16.0,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4.0),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
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
              activeThumbColor: Colors.amber,
            ),
          ],
        ),
      ),
    );
  }
}
