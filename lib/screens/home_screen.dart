import 'package:elysian/data/data.dart';
import 'package:elysian/main.dart';
import 'package:elysian/models/models.dart';
import 'package:elysian/services/storage_service.dart';
import 'package:elysian/widgets/saved_links_list.dart';
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

  @override
  void initState() {
    _scrollController = ScrollController()
      ..addListener(() {
        setState(() {
          _scollOffset = _scrollController.offset;
        });
        // context.bloc<AppBarCubit>().setOffset(_scrollController.offset);
      });
    _loadSavedLinks();
    super.initState();

    // Register refresh callback
    onLinkSavedCallback = refreshLinks;
  }

  Future<void> _loadSavedLinks() async {
    try {
      final links = await StorageService.getSavedLinks();
      setState(() {
        _savedLinks = links;
      });
    } catch (e) {
      // Handle error silently
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload links when screen becomes visible again
    _loadSavedLinks();
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
            key: PageStorageKey('savedLinks'),
            child: SavedLinksList(
              savedLinks: _savedLinks,
              title: 'Saved Links',
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
