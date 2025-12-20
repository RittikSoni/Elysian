import 'dart:ui';
import 'package:elysian/data/data.dart';
import 'package:elysian/models/models.dart';
import 'package:elysian/services/storage_service.dart';
import 'package:elysian/services/link_handler.dart';
import 'package:elysian/widgets/thumbnail_image.dart';
import 'package:elysian/utils/app_themes.dart';
import 'package:elysian/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elysian/widgets/widgets.dart';

class SearchScreen extends StatefulWidget {
  final Function(int)? onNavigateToTab;

  const SearchScreen({super.key, this.onNavigateToTab});

  @override
  SearchScreenState createState() => SearchScreenState();
}

class SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Content> _contentResults = [];
  List<SavedLink> _linkResults = [];
  bool _isSearching = false;
  List<String> _recentSearches = [];
  late ScrollController _scrollController;
  double _scrollOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()
      ..addListener(() {
        setState(() {
          _scrollOffset = _scrollController.offset;
        });
      });
    // _searchController.addListener(_onSearchChanged);
    _loadRecentSearches();
  }

  Future<void> _loadRecentSearches() async {
    final searches = await StorageService.getRecentSearches();
    setState(() {
      _recentSearches = searches;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _contentResults = [];
        _linkResults = [];
      });
    } else {
      setState(() {
        _isSearching = true;
        _performSearch(query);
      });
    }
  }

  Future<void> _performSearch(String query) async {
    // Save to recent searches
    await StorageService.addRecentSearch(query);
    await _loadRecentSearches();

    // Search content
    final allContent = [...previews, ...myList, ...originals, ...trending];
    final contentResults = allContent
        .where(
          (content) =>
              content.name.toLowerCase().contains(query) ||
              content.description.toLowerCase().contains(query),
        )
        .toList();

    // Search saved links (including notes)
    final allLinks = await StorageService.getSavedLinks();
    final linkResults = allLinks
        .where(
          (link) =>
              link.title.toLowerCase().contains(query) ||
              (link.description?.toLowerCase().contains(query) ?? false) ||
              (link.notes?.toLowerCase().contains(query) ?? false) ||
              link.url.toLowerCase().contains(query),
        )
        .toList();

    if (mounted) {
      setState(() {
        _contentResults = contentResults;
        _linkResults = linkResults;
      });
    }
  }

  int _getCrossAxisCount(BuildContext context) {
    if (Responsive.isDesktop(context)) {
      return 6;
    } else if (Responsive.isTablet(context)) {
      return 4;
    } else {
      return 3;
    }
  }

  double _getMaxWidth(BuildContext context) {
    if (Responsive.isDesktop(context)) {
      return 1200.0;
    } else if (Responsive.isTablet(context)) {
      return 800.0;
    } else {
      return double.infinity;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    final maxWidth = _getMaxWidth(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: Responsive.isMobile(context)
          ? null
          : PreferredSize(
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
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 40.0 : 20.0,
                vertical: isDesktop ? 120.0 : 100.0,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _searchController,
                    builder: (context, value, child) {
                      return TextField(
                        controller: _searchController,
                        onEditingComplete: _onSearchChanged,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16.0,
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.grey[900],
                          hintText: 'Search for a show, movie, genre, etc.',
                          hintStyle: TextStyle(color: Colors.grey[600]),
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Colors.grey,
                          ),
                          suffixIcon: value.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.clear,
                                    color: Colors.grey,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4.0),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: isDesktop ? 20.0 : 16.0,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          if (!_isSearching)
            SliverPadding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 40.0 : 20.0,
              ),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Recent Searches
                        if (_recentSearches.isNotEmpty) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Recent Searches',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20.0,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextButton(
                                onPressed: () async {
                                  await StorageService.clearRecentSearches();
                                  await _loadRecentSearches();
                                },
                                child: const Text(
                                  'Clear',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12.0),
                          Wrap(
                            spacing: 10.0,
                            runSpacing: 10.0,
                            children: [
                              ..._recentSearches.map(
                                (search) => GestureDetector(
                                  onTap: () {
                                    _searchController.text = search;
                                    _performSearch(search);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16.0,
                                      vertical: 8.0,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[800],
                                      borderRadius: BorderRadius.circular(4.0),
                                      border: Border.all(
                                        color: Colors.grey[700]!,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.history,
                                          color: Colors.grey,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          search,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14.0,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 30.0),
                        ],
                        const Text(
                          'Popular Searches',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20.0),
                        Wrap(
                          spacing: 10.0,
                          runSpacing: 10.0,
                          children: [
                            ...previews
                                .take(isDesktop ? 12 : 6)
                                .map(
                                  (content) => _SearchChip(content: content),
                                ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          else if (_contentResults.isEmpty && _linkResults.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search_off,
                      size: isDesktop ? 80.0 : 64.0,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(height: 16.0),
                    Text(
                      'No results found',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: isDesktop ? 20.0 : 18.0,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 40.0 : 20.0,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Saved Links Section
                  if (_linkResults.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Saved Links',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16.0),
                          SizedBox(
                            height: 200,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _linkResults.length,
                              itemBuilder: (context, index) {
                                final link = _linkResults[index];
                                return _buildLinkCard(link, isDesktop);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  // Content Section
                  if (_contentResults.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Content',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16.0),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: _getCrossAxisCount(context),
                                  childAspectRatio: 0.7,
                                  crossAxisSpacing: 10.0,
                                  mainAxisSpacing: 10.0,
                                ),
                            itemCount: _contentResults.length,
                            itemBuilder: (context, index) {
                              final content = _contentResults[index];
                              return GestureDetector(
                                onTap: () {
                                  // Handle content tap
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(4.0),
                                    image: DecorationImage(
                                      image: AssetImage(content.imageUrl),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ]),
              ),
            ),
          SliverPadding(padding: EdgeInsets.only(bottom: 20.0)),
        ],
      ),
    );
  }

  Widget _buildLinkCard(SavedLink link, bool isDesktop) {
    return GestureDetector(
      onTap: () {
        LinkHandler.openLink(
          context,
          link.url,
          linkType: link.type,
          title: link.title,
          description: link.description,
          linkId: link.id, // Pass linkId to track views
        );
      },
      child: Consumer<AppStateProvider>(
        builder: (context, appState, _) {
          final isLiquidGlass = appState.themeType == AppThemeType.liquidGlass;
          final theme = Theme.of(context);

          if (isLiquidGlass) {
            final liquidGlass = theme.extension<LiquidGlassTheme>();
            final blur = liquidGlass?.blurIntensity ?? 15.0;
            final opacity = liquidGlass?.glassOpacity ?? 0.18;
            final borderOpacity = liquidGlass?.borderOpacity ?? 0.25;

            return Container(
              width: isDesktop ? 300 : 250,
              margin: const EdgeInsets.only(right: 12.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(
                  color: Colors.white.withValues(alpha: borderOpacity),
                  width: 1.5,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: opacity),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: _buildLinkCardContent(link, isDesktop),
                  ),
                ),
              ),
            );
          } else {
            return Container(
              width: isDesktop ? 300 : 250,
              margin: const EdgeInsets.only(right: 12.0),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: _buildLinkCardContent(link, isDesktop),
            );
          }
        },
      ),
    );
  }

  Widget _buildLinkCardContent(SavedLink link, bool isDesktop) {
    return Row(
      children: [
        // Thumbnail
        ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(8.0),
            bottomLeft: Radius.circular(8.0),
          ),
          child: ThumbnailImage(link: link, width: 120, height: 200),
        ),
        // Content
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  link.title,
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.light
                        ? Colors.black87
                        : Colors.white,
                    fontSize: 16.0,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (link.description != null) ...[
                  const SizedBox(height: 8.0),
                  Text(
                    link.description!,
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.light
                          ? Colors.grey[700]
                          : Colors.grey[400],
                      fontSize: 12.0,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 8.0),
                Text(
                  _getLinkTypeLabel(link.type),
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.light
                        ? Colors.grey[600]
                        : Colors.grey[500],
                    fontSize: 11.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _getLinkTypeLabel(LinkType type) {
    switch (type) {
      case LinkType.youtube:
        return 'YouTube';
      case LinkType.instagram:
        return 'Instagram';
      case LinkType.vimeo:
        return 'Vimeo';
      case LinkType.googledrive:
        return 'Google Drive';
      case LinkType.directVideo:
        return 'Video';
      case LinkType.web:
        return 'Web';
      case LinkType.unknown:
        return 'Link';
    }
  }
}

class _SearchChip extends StatelessWidget {
  final Content content;

  const _SearchChip({required this.content});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Handle chip tap - could populate search field
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(4.0),
          border: Border.all(color: Colors.grey[800]!),
        ),
        child: Text(
          content.name,
          style: const TextStyle(color: Colors.white, fontSize: 14.0),
        ),
      ),
    );
  }
}
