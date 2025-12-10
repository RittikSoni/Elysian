import 'package:elysian/data/data.dart';
import 'package:elysian/main.dart';
import 'package:elysian/models/models.dart';
import 'package:elysian/services/storage_service.dart';
import 'package:elysian/widgets/saved_links_list.dart';
import 'package:elysian/widgets/user_lists_widget.dart';
import 'package:elysian/widgets/list_content_section.dart';
import 'package:elysian/widgets/favorites_section.dart';
import 'package:elysian/widgets/recent_activity_section.dart';
import 'package:elysian/widgets/suggestions_section.dart';
import 'package:flutter/material.dart';
import 'package:elysian/widgets/widgets.dart';

class HomeScreen extends StatefulWidget {
  final Function(int)? onNavigateToTab;

  const HomeScreen({super.key, this.onNavigateToTab});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  late ScrollController _scrollController;
  double _scollOffset = 0.0;
  List<SavedLink> _savedLinks = [];
  List<UserList> _userLists = [];
  List<SavedLink> _favoriteLinks = [];
  List<SavedLink> _recentLinks = [];
  List<SavedLink> _suggestedLinks = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()
      ..addListener(() {
        setState(() {
          _scollOffset = _scrollController.offset;
        });
        // context.bloc<AppBarCubit>().setOffset(_scrollController.offset);
      });
    
    // Register refresh callback
    onLinkSavedCallback = refreshLinks;
    
    // Load data after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSavedLinks();
    });
  }

  Future<void> _loadSavedLinks() async {
    if (_isLoading) return; // Prevent concurrent loads
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Load all data in parallel for better performance
      // Use timeout to prevent hanging indefinitely
      final results = await Future.wait([
        StorageService.getSavedLinks(),
        StorageService.getUserLists(),
        StorageService.getFavoriteLinks(),
        StorageService.getRecentlyViewedLinks(limit: 10),
        StorageService.getSuggestedLinks(limit: 10),
      ]).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          // Return empty lists if timeout
          return [
            <SavedLink>[],
            <UserList>[],
            <SavedLink>[],
            <SavedLink>[],
            <SavedLink>[],
          ];
        },
      );
      
      if (mounted) {
        setState(() {
          _savedLinks = results[0] as List<SavedLink>;
          _userLists = results[1] as List<UserList>;
          _favoriteLinks = results[2] as List<SavedLink>;
          _recentLinks = results[3] as List<SavedLink>;
          _suggestedLinks = results[4] as List<SavedLink>;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading saved links: $e');
      if (mounted) {
        setState(() {
          // Set empty lists on error to prevent UI from breaking
          _savedLinks = [];
          _userLists = [];
          _favoriteLinks = [];
          _recentLinks = [];
          _suggestedLinks = [];
          _isLoading = false;
        });
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Don't reload here - it causes issues during initialization
  }

  // Public method to refresh links (can be called from outside)
  void refreshLinks() {
    _loadSavedLinks();
  }

  @override
  void dispose() {
    onLinkSavedCallback = null;
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
          scrollOffset: _scollOffset,
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
                key: PageStorageKey(
                  'previews',
                ), //(maintain scroll postions) used to maintain the page current state if we change tab it will reamin same as we leave this page
                title: 'previews',
                contentList: previews,
              ),
            ),
          ),
          SliverToBoxAdapter(
            key: PageStorageKey('userLists'),
            child: UserListsWidget(
              onRefresh: _loadSavedLinks,
            ),
          ),
          // Favorites Section
          SliverToBoxAdapter(
            key: PageStorageKey('favorites'),
            child: FavoritesSection(
              favoriteLinks: _favoriteLinks,
              onRefresh: _loadSavedLinks,
            ),
          ),
          // Recent Activity / Continue Watching
          SliverToBoxAdapter(
            key: PageStorageKey('recentActivity'),
            child: RecentActivitySection(
              recentLinks: _recentLinks,
              onRefresh: _loadSavedLinks,
            ),
          ),
          // Smart Suggestions
          SliverToBoxAdapter(
            key: PageStorageKey('suggestions'),
            child: SuggestionsSection(
              suggestedLinks: _suggestedLinks,
              onRefresh: _loadSavedLinks,
            ),
          ),
          // Separate sections for each list
          ..._userLists.map((list) {
            final listLinks = _savedLinks
                .where((link) => link.listIds.contains(list.id))
                .toList();
            if (listLinks.isEmpty) {
              return const SliverToBoxAdapter(child: SizedBox.shrink());
            }
            return SliverToBoxAdapter(
              key: PageStorageKey('list_${list.id}'),
              child: ListContentSection(
                list: list,
                links: listLinks,
                onRefresh: _loadSavedLinks,
              ),
            );
          }).toList(),
          SliverToBoxAdapter(
            key: PageStorageKey('savedLinks'),
            child: SavedLinksList(
              savedLinks: _savedLinks,
              title: 'All Saved Links',
              onRefresh: _loadSavedLinks,
            ),
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
        ],
      ),
    );
  }
}
