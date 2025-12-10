import 'package:elysian/main.dart';
import 'package:elysian/models/content_model.dart';
import 'package:elysian/widgets/add_link_dialog.dart';
import 'package:flutter/material.dart';

class ContentList extends StatelessWidget {
  final String title;
  final List<Content> contentList;
  final bool isOriginals;

  const ContentList({
    super.key,
    required this.title,
    required this.contentList,
    required this.isOriginals,
  });

  Future<void> _showAddToLinkDialog(BuildContext context, {Content? content}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AddLinkDialog(
        initialTitle: content?.name,
      ),
    );
    
    if (result == true) {
      // Refresh home screen
      onLinkSavedCallback?.call();
    }
  }
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (title == 'My List')
                  IconButton(
                    icon: const Icon(Icons.add, color: Colors.white, size: 20),
                    onPressed: () => _showAddToLinkDialog(context),
                    tooltip: 'Add Link to List',
                  ),
              ],
            ),
          ),
          SizedBox(
            height: isOriginals ? 550.0 : 220.0,
            child: ListView.builder(
              padding: EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
              scrollDirection: Axis.horizontal,
              itemCount: contentList.length,
              itemBuilder: (BuildContext context, int index) {
                final Content content = contentList[index];
                return GestureDetector(
                  onLongPress: () {
                    // Show add to list menu on long press
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.grey[900],
                      builder: (context) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.playlist_add, color: Colors.white),
                              title: Text(
                                'Add "${content.name}" to List',
                                style: const TextStyle(color: Colors.white),
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                _showAddToLinkDialog(context, content: content);
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.close, color: Colors.white),
                              title: const Text('Cancel', style: TextStyle(color: Colors.white)),
                              onTap: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  onTap: () {},
                  child: Stack(
                    children: [
                      Container(
                        margin: EdgeInsets.symmetric(horizontal: 8.0),
                        height: isOriginals ? 400.0 : 200.0,
                        width: isOriginals ? 200.0 : 130.0,
                        decoration: BoxDecoration(
                          image: DecorationImage(
                            image: AssetImage(content.imageUrl),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      // Add button overlay
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _showAddToLinkDialog(context, content: content),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.add,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
