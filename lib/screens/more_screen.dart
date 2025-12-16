import 'package:flutter/material.dart';
import 'package:elysian/widgets/widgets.dart';
import 'package:elysian/providers/providers.dart';
import 'package:elysian/services/export_import_service.dart';
import 'package:elysian/screens/lists_management_screen.dart';
import 'package:elysian/screens/saved_links_screen.dart';
import 'package:elysian/screens/statistics_screen.dart';
import 'package:elysian/screens/about_screen.dart';
import 'package:elysian/screens/help_support_screen.dart';
import 'package:elysian/screens/coming_soon_screen.dart';
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
    
    // Initialize app state provider if needed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appStateProvider = context.read<AppStateProvider>();
      if (!appStateProvider.isLoadingPlayerPreference) {
        appStateProvider.initialize();
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
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                        child: Icon(
                          Icons.person,
                          color: theme.colorScheme.onSurface,
                          size: 40.0,
                        ),
                      ),
                      const SizedBox(width: 16.0),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Profile Name',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontSize: 24.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4.0),
                            Text(
                              'Manage profiles',
                              style: TextStyle(
                                color: theme.colorScheme.primary,
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
                    onTap: () {
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder: (context, animation, secondaryAnimation) =>
                              const ComingSoonScreen(title: 'Notifications'),
                          transitionsBuilder: (context, animation, secondaryAnimation, child) {
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
                          pageBuilder: (context, animation, secondaryAnimation) =>
                              const ComingSoonScreen(title: 'Account'),
                          transitionsBuilder: (context, animation, secondaryAnimation, child) {
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
                          pageBuilder: (context, animation, secondaryAnimation) =>
                              const ComingSoonScreen(title: 'Privacy'),
                          transitionsBuilder: (context, animation, secondaryAnimation, child) {
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
                          pageBuilder: (context, animation, secondaryAnimation) =>
                              const ComingSoonScreen(title: 'Security'),
                          transitionsBuilder: (context, animation, secondaryAnimation, child) {
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
                          pageBuilder: (context, animation, secondaryAnimation) =>
                              const ComingSoonScreen(title: 'Payment'),
                          transitionsBuilder: (context, animation, secondaryAnimation, child) {
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
                          pageBuilder: (context, animation, secondaryAnimation) =>
                              const HelpSupportScreen(),
                          transitionsBuilder: (context, animation, secondaryAnimation, child) {
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
                          pageBuilder: (context, animation, secondaryAnimation) =>
                              const AboutScreen(),
                          transitionsBuilder: (context, animation, secondaryAnimation, child) {
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
                          pageBuilder: (context, animation, secondaryAnimation) =>
                              const ListsManagementScreen(),
                          transitionsBuilder: (context, animation, secondaryAnimation, child) {
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
                          pageBuilder: (context, animation, secondaryAnimation) =>
                              const SavedLinksScreen(),
                          transitionsBuilder: (context, animation, secondaryAnimation, child) {
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
                          builder: (context) => const Center(
                            child: CircularProgressIndicator(),
                          ),
                        );

                        // Export to file
                        final filePath = await ExportImportService.exportToFile();
                        
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
                        final shared = await ExportImportService.shareExportedFile(filePath);
                        
                        if (context.mounted) {
                          if (shared) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Export file created and ready to share!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Export file created. You can find it in your downloads.'),
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
                        final isValid = await ExportImportService.isValidElysianFile(filePath);
                        if (!isValid) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Invalid file format. Please select a valid .elysian export file.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        // Show loading
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => const Center(
                            child: CircularProgressIndicator(),
                          ),
                        );

                        // Import from file
                        final importResult = await ExportImportService.importFromFile(filePath);
                        
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
                                content: Text(importResult.message ?? 'Data imported successfully!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          }
                        } else {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(importResult.error ?? 'Error importing data'),
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
                          pageBuilder: (context, animation, secondaryAnimation) =>
                              const StatisticsScreen(),
                          transitionsBuilder: (context, animation, secondaryAnimation, child) {
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
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
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
                      return _MoreMenuItem(
                        icon: Icons.brightness_6,
                        title: 'Appearance',
                        subtitle: appStateProvider.isDarkMode ? 'Dark' : 'Light',
                        onTap: () {
                          appStateProvider.setThemePreference(!appStateProvider.isDarkMode);
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
                        subtitle: appStateProvider.isInbuiltPlayer ? 'Inbuilt' : 'External',
                        value: appStateProvider.isInbuiltPlayer,
                        onChanged: (value) => appStateProvider.setPlayerPreference(value),
                      );
                    },
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
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                    );
                  },
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
    final theme = Theme.of(context);
    
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Row(
          children: [
            Icon(
              icon,
              color: theme.colorScheme.onSurface,
              size: 28.0,
            ),
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
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                        fontSize: 14.0,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurface.withOpacity(0.5),
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
            Icon(
              icon,
              color: theme.colorScheme.onSurface,
              size: 28.0,
            ),
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
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
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
              activeColor: Colors.amber,
            ),
          ],
        ),
      ),
    );
  }
}

