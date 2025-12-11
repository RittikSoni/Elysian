import 'package:elysian/models/models.dart';
import 'package:elysian/services/link_parser.dart';
import 'package:elysian/services/storage_service.dart';
import 'package:elysian/video_player/yt_full.dart';
import 'package:elysian/video_player/video_player_full.dart';
import 'package:elysian/widgets/thumbnail_image.dart';
import 'package:elysian/widgets/multi_list_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elysian/providers/providers.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:elysian/widgets/small_video_player.dart';

class VideoDetailScreen extends StatefulWidget {
  final SavedLink link;

  const VideoDetailScreen({
    super.key,
    required this.link,
  });

  @override
  State<VideoDetailScreen> createState() => _VideoDetailScreenState();
}

class _VideoDetailScreenState extends State<VideoDetailScreen> {
  List<SavedLink> _relatedVideos = [];
  bool _isFavorite = false;
  List<String> _currentListIds = [];

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.link.isFavorite;
    _currentListIds = List.from(widget.link.listIds);
    _loadLinkDetails();
  }

  Future<void> _loadLinkDetails() async {
    // Reload link from storage to get latest listIds
    try {
      final allLinks = await StorageService.getSavedLinks();
      final updatedLink = allLinks.firstWhere(
        (link) => link.id == widget.link.id || link.url == widget.link.url,
        orElse: () => widget.link,
      );
      _currentListIds = List.from(updatedLink.listIds);
      if (mounted) {
        setState(() {
          _isFavorite = updatedLink.isFavorite;
        });
        // Load related videos after getting updated listIds
        _loadRelatedVideos();
      }
    } catch (e) {
      // Keep using widget.link if not found, but still load related videos
      if (mounted) {
        _loadRelatedVideos();
      }
    }
  }

  Future<void> _loadRelatedVideos() async {
    try {
      final allLinks = await StorageService.getSavedLinks();
      
      // Get the primary list (first list ID, or default list)
      final primaryListId = _currentListIds.isNotEmpty 
          ? _currentListIds.first 
          : StorageService.defaultListId;
      
      // Get videos ONLY from the primary list, excluding current video
      final relatedLinks = allLinks
          .where((link) =>
              link.id != widget.link.id &&
              link.listIds.contains(primaryListId))
          .toList();

      // Sort by date (latest first)
      relatedLinks.sort((a, b) => b.savedAt.compareTo(a.savedAt));

      if (mounted) {
        setState(() {
          _relatedVideos = relatedLinks;
        });
      }
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _toggleFavorite() async {
    final updatedLink = widget.link.copyWith(isFavorite: !_isFavorite);
    await StorageService.saveLink(updatedLink);
    setState(() => _isFavorite = !_isFavorite);
    
    // Refresh links provider
    if (mounted) {
      final linksProvider = Provider.of<LinksProvider>(context, listen: false);
      linksProvider.loadLinks(forceRefresh: true);
    }
  }

  Future<void> _showListPicker() async {
    List<String> selectedListIds = List.from(_currentListIds);
    
    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.grey[900],
            title: const Text(
              'Select Lists',
              style: TextStyle(color: Colors.white),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: MultiListPicker(
                selectedListIds: selectedListIds,
                onSelectionChanged: (newSelection) {
                  setDialogState(() {
                    selectedListIds = newSelection;
                  });
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, selectedListIds),
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );

    if (result != null && result.isNotEmpty) {
      final updatedLink = widget.link.copyWith(listIds: result);
      await StorageService.saveLink(updatedLink);
      setState(() => _currentListIds = result);
      _loadRelatedVideos(); // Reload to show updated related videos
      
      // Refresh links provider
      if (mounted) {
        final linksProvider = Provider.of<LinksProvider>(context, listen: false);
        linksProvider.loadLinks(forceRefresh: true);
      }
    }
  }

  Future<void> _showNotesEditor() async {
    final controller = TextEditingController(text: widget.link.notes ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Edit Notes',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          maxLines: 5,
          decoration: InputDecoration(
            hintText: 'Add your notes...',
            hintStyle: TextStyle(color: Colors.grey[600]),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.amber),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null) {
      final updatedLink = widget.link.copyWith(notes: result.isEmpty ? null : result);
      await StorageService.saveLink(updatedLink);
      
      // Refresh links provider
      if (mounted) {
        final linksProvider = Provider.of<LinksProvider>(context, listen: false);
        linksProvider.loadLinks(forceRefresh: true);
      }
    }
  }

  Future<void> _shareLink() async {
    await Share.share(
      widget.link.url,
      subject: widget.link.title,
    );
  }

  void _openFullScreen(Duration? initialPosition) {
    final linkType = widget.link.type;
    
    if (linkType == LinkType.youtube) {
      final videoId = LinkParser.extractYouTubeVideoId(widget.link.url);
      if (videoId != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => YTFull(
              videoId: videoId,
              title: widget.link.title,
              description: widget.link.description,
              url: widget.link.url,
              listIds: widget.link.listIds,
              initialPosition: initialPosition,
              autoEnterPiP: false,
            ),
          ),
        );
      }
    } else if (linkType.canPlayInbuilt) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RSNewVideoPlayerScreen(
            mediaUrl: widget.link.url,
            url: widget.link.url,
            listIds: widget.link.listIds,
            initialPosition: initialPosition,
            autoEnterPiP: false,
            title: widget.link.title,
            onError: () async {
              final uri = Uri.parse(widget.link.url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
        ),
      );
    } else {
      // Open externally
      _openExternally();
    }
  }

  void _enterPiP(Duration? initialPosition) {
    final linkType = widget.link.type;
    
    // Navigate to full screen player and auto-enter PiP
    if (linkType == LinkType.youtube) {
      final videoId = LinkParser.extractYouTubeVideoId(widget.link.url);
      if (videoId != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => YTFull(
              videoId: videoId,
              title: widget.link.title,
              description: widget.link.description,
              url: widget.link.url,
              listIds: widget.link.listIds,
              initialPosition: initialPosition,
              autoEnterPiP: true,
            ),
          ),
        );
      }
    } else if (linkType.canPlayInbuilt) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RSNewVideoPlayerScreen(
            mediaUrl: widget.link.url,
            url: widget.link.url,
            listIds: widget.link.listIds,
            initialPosition: initialPosition,
            autoEnterPiP: true,
            onError: () async {
              final uri = Uri.parse(widget.link.url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
        ),
      );
    }
  }

  Future<void> _openExternally() async {
    final uri = Uri.parse(widget.link.url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            expandedHeight: isTablet ? 400 : 300,
            pinned: true,
            backgroundColor: Colors.black,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  _isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: _isFavorite ? Colors.red : Colors.white,
                ),
                onPressed: _toggleFavorite,
                tooltip: _isFavorite ? 'Remove from favorites' : 'Add to favorites',
              ),
              IconButton(
                icon: const Icon(Icons.share, color: Colors.white),
                onPressed: _shareLink,
                tooltip: 'Share',
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _buildVideoPlayerOrThumbnail(),
            ),
          ),
          
          // Content
          SliverToBoxAdapter(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isTablet = constraints.maxWidth > 600;
                final horizontalPadding = isTablet 
                    ? constraints.maxWidth * 0.1 
                    : 16.0;
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title and Actions
                    Padding(
                      padding: EdgeInsets.all(horizontalPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.link.title,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isTablet ? 32 : 24,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 12),
                          
                          // Meta info - Wrap on small screens
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (widget.link.duration != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[800],
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.access_time,
                                        color: Colors.white70,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        widget.link.duration!,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey[800],
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  widget.link.type.name.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (widget.link.viewCount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: Colors.amber.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.play_arrow,
                                        color: Colors.amber,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${widget.link.viewCount}x',
                                        style: const TextStyle(
                                          color: Colors.amber,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          
                          // Action Buttons
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _openFullScreen(null),
                                  icon: const Icon(Icons.play_arrow, size: 24),
                                  label: const Text(
                                    'Play',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    elevation: 2,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey[900],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.grey[700]!,
                                    width: 1,
                                  ),
                                ),
                                child: IconButton(
                                  onPressed: _showListPicker,
                                  icon: const Icon(Icons.playlist_add, color: Colors.white),
                                  tooltip: 'Add to Lists',
                                  iconSize: 24,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey[900],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.grey[700]!,
                                    width: 1,
                                  ),
                                ),
                                child: IconButton(
                                  onPressed: _showNotesEditor,
                                  icon: const Icon(Icons.note_add, color: Colors.white),
                                  tooltip: 'Edit Notes',
                                  iconSize: 24,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          
                          // Description
                          if (widget.link.description != null &&
                              widget.link.description!.isNotEmpty) ...[
                            Text(
                              widget.link.description!,
                              style: TextStyle(
                                color: Colors.grey[300],
                                fontSize: isTablet ? 16 : 14,
                                height: 1.6,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                          
                          // Notes
                          if (widget.link.notes != null &&
                              widget.link.notes!.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[900],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.amber.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.note,
                                        color: Colors.amber,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Notes',
                                        style: TextStyle(
                                          color: Colors.amber,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    widget.link.notes!,
                                    style: TextStyle(
                                      color: Colors.grey[200],
                                      fontSize: isTablet ? 15 : 14,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ],
                      ),
                    ),
                
                    // Related Videos Section
                    if (_relatedVideos.isNotEmpty) ...[
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.playlist_play,
                              color: Colors.amber,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'More from this list',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isTablet ? 24 : 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: isTablet ? 240 : 200,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                          itemCount: _relatedVideos.length,
                          itemBuilder: (context, index) {
                            final video = _relatedVideos[index];
                            final cardWidth = isTablet ? 180.0 : 150.0;
                            final cardHeight = isTablet ? 120.0 : 100.0;
                            
                            return GestureDetector(
                              onTap: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => VideoDetailScreen(
                                      link: video,
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                width: cardWidth,
                                margin: const EdgeInsets.only(right: 16),
                                decoration: BoxDecoration(
                                  color: Colors.grey[900],
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(12),
                                      ),
                                      child: Stack(
                                        children: [
                                          ThumbnailImage(
                                            link: video,
                                            width: cardWidth,
                                            height: cardHeight,
                                          ),
                                          Positioned.fill(
                                            child: Container(
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
                                          ),
                                          Positioned(
                                            bottom: 8,
                                            right: 8,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withOpacity(0.7),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: video.duration != null
                                                  ? Text(
                                                      video.duration!,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    )
                                                  : const SizedBox.shrink(),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.all(10.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                video.title,
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: isTablet ? 13 : 12,
                                                  fontWeight: FontWeight.bold,
                                                  height: 1.3,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (video.viewCount > 0) ...[
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.play_arrow,
                                                    color: Colors.amber,
                                                    size: 12,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '${video.viewCount}x',
                                                    style: TextStyle(
                                                      color: Colors.grey[400],
                                                      fontSize: 10,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      SizedBox(height: horizontalPadding),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPlayerOrThumbnail() {
    // Check if video can be played in-app
    final canPlayInApp = widget.link.type.canPlayInbuilt;
    
    if (canPlayInApp) {
      // Show small video player
      return SmallVideoPlayer(
        link: widget.link,
        onFullScreen: _openFullScreen,
        onPiP: _enterPiP,
      );
    } else {
      // Show thumbnail that opens externally on tap
      return GestureDetector(
        onTap: () async {
          final uri = Uri.parse(widget.link.url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            ThumbnailImage(
              link: widget.link,
              width: double.infinity,
              height: 300,
            ),
            // Play button overlay
            const Center(
              child: Icon(
                Icons.play_circle_filled,
                color: Colors.white,
                size: 64,
              ),
            ),
          ],
        ),
      );
    }
  }
}

