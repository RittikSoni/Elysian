import 'package:elysian/data/data.dart';
import 'package:elysian/providers/providers.dart';
import 'package:elysian/models/models.dart';
import 'package:elysian/models/home_screen_section.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elysian/widgets/widgets.dart';

class HomeScreen extends StatefulWidget {
  final Function(int)? onNavigateToTab;

  const HomeScreen({super.key, this.onNavigateToTab});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
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

    // Initialize providers if not already initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final linksProvider = context.read<LinksProvider>();
      final listsProvider = context.read<ListsProvider>();
      final layoutProvider = context.read<HomeScreenLayoutProvider>();

      if (!linksProvider.isInitialized) {
        linksProvider.initialize();
      }
      if (!listsProvider.isInitialized) {
        listsProvider.initialize();
      }
      if (!layoutProvider.isInitialized) {
        layoutProvider.initialize();
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
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: Size(MediaQuery.of(context).size.width, 50),
        child: CustomAppBar(
          scrollOffset: _scrollOffset,
          onNavigateToTab: widget.onNavigateToTab,
        ),
      ),
      body: Consumer<HomeScreenLayoutProvider>(
        builder: (context, layoutProvider, child) {
          if (layoutProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final visibleSections = layoutProvider.visibleSections;

          return CustomScrollView(
            controller: _scrollController,
            slivers: [
              // Build sections dynamically based on layout configuration
              ...visibleSections.map((section) => _buildSection(section)),
              // Tagline (always at the end)
              SliverToBoxAdapter(
                child: Builder(
                  builder: (context) {
                    final theme = Theme.of(context);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20.0),
                      child: Center(
                        child: Text(
                          'Made with ❤️ in India',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              SliverPadding(padding: const EdgeInsets.only(bottom: 20.0)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSection(HomeScreenSection section) {
    switch (section.type) {
      case HomeSectionType.header:
        return _buildHeaderSection(section);

      case HomeSectionType.userList:
        return _buildUserListSection(section);

      case HomeSectionType.favorites:
        return Consumer<LinksProvider>(
          builder: (context, linksProvider, child) {
            return SliverToBoxAdapter(
              key: PageStorageKey(section.id),
              child: FavoritesSection(
                favoriteLinks: linksProvider.favoriteLinks,
                onRefresh: () => linksProvider.loadLinks(forceRefresh: true),
              ),
            );
          },
        );

      case HomeSectionType.recentActivity:
        return Consumer<LinksProvider>(
          builder: (context, linksProvider, child) {
            return SliverToBoxAdapter(
              key: PageStorageKey(section.id),
              child: RecentActivitySection(
                recentLinks: linksProvider.recentLinks.take(10).toList(),
                onRefresh: () => linksProvider.loadLinks(forceRefresh: true),
              ),
            );
          },
        );

      case HomeSectionType.suggestions:
        return Consumer<LinksProvider>(
          builder: (context, linksProvider, child) {
            return SliverToBoxAdapter(
              key: PageStorageKey(section.id),
              child: SuggestionsSection(
                suggestedLinks: linksProvider.suggestedLinks.take(10).toList(),
                onRefresh: () => linksProvider.loadLinks(forceRefresh: true),
              ),
            );
          },
        );

      case HomeSectionType.savedLinks:
        return Consumer<LinksProvider>(
          builder: (context, linksProvider, child) {
            final savedLinks = linksProvider.allLinks;
            if (savedLinks.isEmpty) {
              return const SliverToBoxAdapter(child: SizedBox.shrink());
            }
            return SliverToBoxAdapter(
              key: PageStorageKey(section.id),
              child: SavedLinksList(
                savedLinks: savedLinks,
                title: section.title,
                onRefresh: () => linksProvider.loadLinks(forceRefresh: true),
                enableSwipeActions: false,
              ),
            );
          },
        );
    }
  }

  Widget _buildHeaderSection(HomeScreenSection section) {
    final linkId = section.config?['linkId'] as String?;

    if (linkId != null) {
      return Consumer<LinksProvider>(
        builder: (context, linksProvider, child) {
          try {
            final link = linksProvider.allLinks.firstWhere(
              (l) => l.id == linkId,
            );

            return SliverToBoxAdapter(
              key: PageStorageKey(section.id),
              child: CustomFeaturedHeader(savedLink: link),
            );
          } catch (e) {
            // Link not found, fallback to default
            return SliverToBoxAdapter(
              key: PageStorageKey(section.id),
              child: ContentHeader(featuredContent: sintelContent),
            );
          }
        },
      );
    }

    // Default featured content
    return SliverToBoxAdapter(
      key: PageStorageKey(section.id),
      child: ContentHeader(featuredContent: sintelContent),
    );
  }

  Widget _buildUserListSection(HomeScreenSection section) {
    final listId = section.config?['listId'] as String?;
    if (listId == null) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final layoutStyle = section.layoutStyle;

    return Consumer2<LinksProvider, ListsProvider>(
      builder: (context, linksProvider, listsProvider, child) {
        final list = listsProvider.getListById(listId);
        if (list == null) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }

        final listLinks = linksProvider.allLinks
            .where((link) => link.listIds.contains(listId))
            .toList();

        if (listLinks.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }

        return SliverToBoxAdapter(
          key: PageStorageKey(section.id),
          child: UserListSectionWidget(
            list: list,
            links: listLinks,
            layoutStyle: layoutStyle,
            onRefresh: () => linksProvider.loadLinks(forceRefresh: true),
          ),
        );
      },
    );
  }
}
