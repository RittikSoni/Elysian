import 'package:elysian/data/data.dart';
import 'package:elysian/providers/providers.dart';
import 'package:elysian/widgets/saved_links_list.dart';
import 'package:elysian/widgets/user_lists_widget.dart';
import 'package:elysian/widgets/list_content_section.dart';
import 'package:elysian/widgets/favorites_section.dart';
import 'package:elysian/widgets/recent_activity_section.dart';
import 'package:elysian/widgets/suggestions_section.dart';
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
      
      if (!linksProvider.isInitialized) {
        linksProvider.initialize();
      }
      if (!listsProvider.isInitialized) {
        listsProvider.initialize();
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
    // Use Consumer widgets for selective rebuilds (performance optimization)
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
            child: ContentHeader(featuredContent: sintelContent),
          ),
          SliverPadding(
            padding: const EdgeInsets.only(top: 0),
            sliver: SliverToBoxAdapter(
              child: Previews(
                key: const PageStorageKey('previews'),
                title: 'previews',
                contentList: previews,
              ),
            ),
          ),
          // User Lists - only rebuilds when lists change
          Consumer<ListsProvider>(
            builder: (context, listsProvider, child) {
              return SliverToBoxAdapter(
                key: const PageStorageKey('userLists'),
                child: UserListsWidget(
                  onRefresh: () => listsProvider.loadLists(forceRefresh: true),
                ),
              );
            },
          ),
          // Favorites Section - only rebuilds when favorites change
          Consumer<LinksProvider>(
            builder: (context, linksProvider, child) {
              return SliverToBoxAdapter(
                key: const PageStorageKey('favorites'),
                child: FavoritesSection(
                  favoriteLinks: linksProvider.favoriteLinks,
                  onRefresh: () => linksProvider.loadLinks(forceRefresh: true),
                ),
              );
            },
          ),
          // Recent Activity - only rebuilds when recent links change
          Consumer<LinksProvider>(
            builder: (context, linksProvider, child) {
              return SliverToBoxAdapter(
                key: const PageStorageKey('recentActivity'),
                child: RecentActivitySection(
                  recentLinks: linksProvider.recentLinks.take(10).toList(),
                  onRefresh: () => linksProvider.loadLinks(forceRefresh: true),
                ),
              );
            },
          ),
          // Smart Suggestions - only rebuilds when suggestions change
          Consumer<LinksProvider>(
            builder: (context, linksProvider, child) {
              return SliverToBoxAdapter(
                key: const PageStorageKey('suggestions'),
                child: SuggestionsSection(
                  suggestedLinks: linksProvider.suggestedLinks.take(10).toList(),
                  onRefresh: () => linksProvider.loadLinks(forceRefresh: true),
                ),
              );
            },
          ),
          // Separate sections for each list - optimized with Consumer
          Consumer2<LinksProvider, ListsProvider>(
            builder: (context, linksProvider, listsProvider, child) {
              final userLists = listsProvider.allLists;
              final allLinks = linksProvider.allLinks;
              
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final list = userLists[index];
                    final listLinks = allLinks
                        .where((link) => link.listIds.contains(list.id))
                        .toList();
                    if (listLinks.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return ListContentSection(
                      key: PageStorageKey('list_${list.id}'),
                      list: list,
                      links: listLinks,
                      onRefresh: () => linksProvider.loadLinks(forceRefresh: true),
                    );
                  },
                  childCount: userLists.length,
                ),
              );
            },
          ),
          // All Saved Links - only rebuilds when links change
          Consumer<LinksProvider>(
            builder: (context, linksProvider, child) {
              final savedLinks = linksProvider.allLinks;
              if (savedLinks.isEmpty) {
                return const SliverToBoxAdapter(child: SizedBox.shrink());
              }
              return SliverToBoxAdapter(
                key: const PageStorageKey('savedLinks'),
                child: SavedLinksList(
                  savedLinks: savedLinks,
                  title: 'All Saved Links',
                  onRefresh: () => linksProvider.loadLinks(forceRefresh: true),
                  enableSwipeActions: false, // Disable swipe for horizontal scrolling
                ),
              );
            },
          ),
          SliverToBoxAdapter(
            key: PageStorageKey('mylist'),
            child: ContentList(
              title: 'My List',
              contentList: myList,
              isOriginals: false,
            ),
          ),
          SliverToBoxAdapter(
            key: PageStorageKey('originals'),
            child: ContentList(
              title: 'Netflix Originals',
              contentList: originals,
              isOriginals: true,
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.only(bottom: 20.0),
            sliver: SliverToBoxAdapter(
              child: ContentList(
                key: PageStorageKey('trending'),
                title: 'Trending',
                contentList: trending,
                isOriginals: false,
              ),
            ),
          ),
          // Tagline
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
          SliverPadding(
            padding: EdgeInsets.only(bottom: 20.0),
          ),
        ],
      ),
    );
  }
}
