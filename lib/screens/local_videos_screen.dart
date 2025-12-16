import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:elysian/widgets/widgets.dart';
import 'package:elysian/video_player/video_player_full.dart';
import 'package:elysian/widgets/watch_party_room_dialog.dart';

class LocalVideo {
  final String path;
  final String name;
  final File file;
  String? thumbnailPath;
  int? duration; // in milliseconds
  int? fileSize; // in bytes

  LocalVideo({
    required this.path,
    required this.name,
    required this.file,
    this.thumbnailPath,
    this.duration,
    this.fileSize,
  });
}

class LocalVideosScreen extends StatefulWidget {
  final Function(int)? onNavigateToTab;
  
  const LocalVideosScreen({super.key, this.onNavigateToTab});

  @override
  State<LocalVideosScreen> createState() => _LocalVideosScreenState();
}

class _LocalVideosScreenState extends State<LocalVideosScreen> {
  late ScrollController _scrollController;
  double _scrollOffset = 0.0;
  List<LocalVideo> _videos = [];
  bool _isLoading = false;
  bool _hasPermission = false;
  String? _errorMessage;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()
      ..addListener(() {
        setState(() {
          _scrollOffset = _scrollController.offset;
        });
      });
    _checkPermissionsAndScan();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _checkPermissionsAndScan() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      PermissionStatus status = PermissionStatus.denied;
      
      if (Platform.isAndroid) {
        // For Android 13+ (API 33+), use READ_MEDIA_VIDEO
        // For older versions, use READ_EXTERNAL_STORAGE
        final androidInfo = await Permission.videos.status;
        
        if (androidInfo.isGranted) {
          status = PermissionStatus.granted;
        } else {
          // Request the appropriate permission
          final result = await Permission.videos.request();
          if (!result.isGranted) {
            // Fallback to storage permission for older Android
            final storageResult = await Permission.storage.request();
            status = storageResult;
          } else {
            status = result;
          }
        }
      } else if (Platform.isIOS) {
        // iOS - use photos permission
        status = await Permission.photos.request();
      }
      
      if (status.isGranted || status.isLimited) {
        setState(() {
          _hasPermission = true;
        });
        await _scanForVideos();
      } else {
        setState(() {
          _hasPermission = false;
          _errorMessage = 'Storage permission is required to scan for videos. Please grant permission in settings.';
        });
      }
    } catch (e) {
      debugPrint('Permission error: $e');
      setState(() {
        _hasPermission = false;
        _errorMessage = 'Error checking permissions: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _scanForVideos() async {
    setState(() {
      _isScanning = true;
      _videos = [];
      _errorMessage = null;
    });

    try {
      final List<LocalVideo> videos = [];
      
      // Get common video directories
      final directories = await _getVideoDirectories();
      
      if (directories.isEmpty) {
        setState(() {
          _errorMessage = 'No video directories found. Make sure you have videos on your device.';
          _isScanning = false;
        });
        return;
      }
      
      debugPrint('Scanning ${directories.length} directories for videos...');
      
      for (final directory in directories) {
        if (await directory.exists()) {
          await _scanDirectory(directory, videos);
        } else {
          debugPrint('Directory does not exist: ${directory.path}');
        }
      }

      debugPrint('Total videos found: ${videos.length}');

      // Sort by name
      videos.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      setState(() {
        _videos = videos;
        _isScanning = false;
      });

      if (videos.isEmpty) {
        setState(() {
          _errorMessage = 'No videos found in scanned directories. Try placing videos in Movies, Download, or DCIM folders.';
        });
      } else {
        // Generate thumbnails in background
        _generateThumbnails();
      }
    } catch (e, stackTrace) {
      debugPrint('Error scanning for videos: $e');
      debugPrint('Stack trace: $stackTrace');
      setState(() {
        _errorMessage = 'Error scanning for videos: $e';
        _isScanning = false;
      });
    }
  }

  Future<List<Directory>> _getVideoDirectories() async {
    final List<Directory> directories = [];
    
    try {
      if (Platform.isAndroid) {
        // Android - scan common video directories
        final externalStorage = await getExternalStorageDirectory();
        if (externalStorage != null) {
          // Get the root of external storage
          final storagePath = externalStorage.path;
          // Navigate to /storage/emulated/0 or similar
          final parts = storagePath.split('/');
          String rootPath = '/';
          for (int i = 0; i < parts.length - 1; i++) {
            if (parts[i].isNotEmpty) {
              rootPath += '${parts[i]}/';
            }
          }
          
          // Common video directories on Android
          final commonDirs = [
            '/storage/emulated/0/Movies',
            '/storage/emulated/0/Download',
            '/storage/emulated/0/DCIM',
            '/storage/emulated/0/Pictures',
            '/storage/emulated/0/Videos',
            '$rootPath/Movies',
            '$rootPath/Download',
            '$rootPath/DCIM',
            '$rootPath/Pictures',
            '$rootPath/Videos',
          ];
          
          for (final dirPath in commonDirs) {
            final dir = Directory(dirPath);
            if (await dir.exists()) {
              directories.add(dir);
              debugPrint('Found directory: $dirPath');
            }
          }
          
          // Also try the parent directory approach
          final parent = externalStorage.parent;
          final parentDirs = [
            Directory('${parent.path}/Movies'),
            Directory('${parent.path}/Download'),
            Directory('${parent.path}/DCIM'),
            Directory('${parent.path}/Pictures'),
            Directory('${parent.path}/Videos'),
          ];
          
          for (final dir in parentDirs) {
            if (await dir.exists() && !directories.contains(dir)) {
              directories.add(dir);
              debugPrint('Found directory: ${dir.path}');
            }
          }
        }
      } else if (Platform.isIOS) {
        // iOS - use app documents directory
        final appDocDir = await getApplicationDocumentsDirectory();
        directories.add(appDocDir);
      }
    } catch (e) {
      debugPrint('Error getting directories: $e');
    }

    debugPrint('Total directories to scan: ${directories.length}');
    return directories;
  }

  Future<void> _scanDirectory(Directory dir, List<LocalVideo> videos) async {
    try {
      if (!await dir.exists()) {
        debugPrint('Directory does not exist: ${dir.path}');
        return;
      }
      
      int count = 0;
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          try {
            final path = entity.path.toLowerCase();
            if (path.contains('.')) {
              final extension = path.split('.').last;
              if (_isVideoFile(extension)) {
                final video = LocalVideo(
                  path: entity.path,
                  name: entity.path.split('/').last,
                  file: entity,
                );
                try {
                  video.fileSize = await entity.length();
                } catch (e) {
                  debugPrint('Error getting file size for ${entity.path}: $e');
                }
                videos.add(video);
                count++;
                if (count % 10 == 0) {
                  debugPrint('Found $count videos so far...');
                }
              }
            }
          } catch (e) {
            debugPrint('Error processing file ${entity.path}: $e');
          }
        }
      }
      debugPrint('Scanned ${dir.path}: found $count videos');
    } catch (e) {
      debugPrint('Error scanning directory ${dir.path}: $e');
    }
  }

  bool _isVideoFile(String extension) {
    const videoExtensions = [
      'mp4', 'avi', 'mkv', 'mov', 'wmv', 'flv', 'webm',
      'm4v', '3gp', 'ts', 'mts', 'm2ts', 'vob'
    ];
    return videoExtensions.contains(extension);
  }

  Future<void> _generateThumbnails() async {
    for (final video in _videos) {
      if (video.thumbnailPath == null && mounted) {
        try {
          final thumbnail = await VideoThumbnail.thumbnailFile(
            video: video.path,
            thumbnailPath: (await getTemporaryDirectory()).path,
            imageFormat: ImageFormat.JPEG,
            maxWidth: 300,
            quality: 75,
            timeMs: 1000,
          );
          
          if (mounted && thumbnail != null) {
            setState(() {
              video.thumbnailPath = thumbnail;
            });
          }
        } catch (e) {
          debugPrint('Error generating thumbnail for ${video.name}: $e');
          // Continue with other videos even if one fails
        }
      }
    }
  }


  void _playVideo(LocalVideo video) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            RSNewVideoPlayerScreen(
          mediaUrl: video.path,
          title: video.name,
          url: video.path,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  void _startWatchParty(LocalVideo video) {
    // Local videos are now automatically streamed!
    // The host's device will stream the video over the network
    // so participants don't need the file on their device
    _showWatchPartyDialog(video);
  }

  void _showWatchPartyDialog(LocalVideo video) {
    showDialog<dynamic>(
      context: context,
      builder: (context) => WatchPartyRoomDialog(
        videoUrl: video.path,
        videoTitle: video.name,
        currentPosition: Duration.zero,
        isPlaying: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: theme.scaffoldBackgroundColor,
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
                      Icon(
                        Icons.video_library,
                        color: theme.colorScheme.onSurface,
                        size: 28.0,
                      ),
                      const SizedBox(width: 12.0),
                      Text(
                        'Local Videos',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 28.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    _videos.isEmpty && !_isLoading
                        ? 'No videos found on your device'
                        : 'Found ${_videos.length} video${_videos.length != 1 ? 's' : ''}',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                      fontSize: 16.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading || _isScanning)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                    ),
                    const SizedBox(height: 24.0),
                    Text(
                      _isScanning ? 'Scanning for videos...' : 'Loading...',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                        fontSize: 16.0,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (_errorMessage != null && !_hasPermission)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 80.0,
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                      const SizedBox(height: 24.0),
                      Text(
                        'Permission Required',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 24.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12.0),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                          fontSize: 16.0,
                        ),
                      ),
                  const SizedBox(height: 32.0),
                  ElevatedButton(
                    onPressed: _checkPermissionsAndScan,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32.0,
                        vertical: 16.0,
                      ),
                    ),
                    child: const Text(
                      'Grant Permission',
                      style: TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (Platform.isAndroid) ...[
                    const SizedBox(height: 16.0),
                    TextButton(
                      onPressed: () async {
                        await openAppSettings();
                      },
                      child: Text(
                        'Open Settings',
                        style: TextStyle(
                          color: Colors.amber,
                          fontSize: 14.0,
                        ),
                      ),
                    ),
                  ],
                    ],
                  ),
                ),
              ),
            )
          else if (_videos.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.video_library_outlined,
                      size: 80.0,
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                    const SizedBox(height: 24.0),
                    Text(
                      'No Videos Found',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 24.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12.0),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40.0),
                      child: Text(
                        'Videos on your device will appear here',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                          fontSize: 16.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32.0),
                    ElevatedButton.icon(
                      onPressed: _scanForVideos,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32.0,
                          vertical: 16.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(20.0),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16.0,
                  mainAxisSpacing: 16.0,
                  childAspectRatio: 0.7,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final video = _videos[index];
                    return _VideoCard(
                      video: video,
                      theme: theme,
                      isDark: isDark,
                      onTap: () => _playVideo(video),
                      onWatchParty: () => _startWatchParty(video),
                    );
                  },
                  childCount: _videos.length,
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _videos.isNotEmpty
          ? FloatingActionButton(
              onPressed: _scanForVideos,
              backgroundColor: Colors.amber,
              child: const Icon(Icons.refresh, color: Colors.black),
            )
          : null,
    );
  }
}

class _VideoCard extends StatelessWidget {
  final LocalVideo video;
  final ThemeData theme;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onWatchParty;

  const _VideoCard({
    required this.video,
    required this.theme,
    required this.isDark,
    required this.onTap,
    required this.onWatchParty,
  });

  String _formatFileSize(int? bytes) {
    if (bytes == null) return 'Unknown size';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (video.thumbnailPath != null)
                      Image.file(
                        File(video.thumbnailPath!),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildPlaceholder(),
                      )
                    else
                      _buildPlaceholder(),
                    // Play button overlay
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.7),
                          ],
                        ),
                      ),
                    ),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.play_circle_filled,
                            color: Colors.white,
                            size: 48,
                            shadows: [
                              Shadow(
                                color: Colors.black54,
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Watch party button
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                onWatchParty();
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(
                                      Icons.people,
                                      color: Colors.black,
                                      size: 16,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Watch Party',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Video info
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.name,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 14.0,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4.0),
                  if (video.fileSize != null)
                    Text(
                      _formatFileSize(video.fileSize),
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                        fontSize: 12.0,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: isDark ? Colors.grey[900] : Colors.grey[200],
      child: Center(
        child: Icon(
          Icons.video_library,
          size: 48,
          color: theme.colorScheme.onSurface.withOpacity(0.3),
        ),
      ),
    );
  }
}

