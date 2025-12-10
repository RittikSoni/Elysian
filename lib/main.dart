import 'dart:async';
import 'package:elysian/utils/kroute.dart';
import 'package:elysian/widgets/list_selection_dialog.dart';
import 'package:elysian/services/link_parser.dart';
import 'package:elysian/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart' as sharing;
import 'screens/screens.dart';

void main() => runApp(Elysian());

class Elysian extends StatefulWidget {
  const Elysian({super.key});

  @override
  State<Elysian> createState() => _ElysianState();
}

class _ElysianState extends State<Elysian> {
  StreamSubscription? _intentMediaStreamSubscription;

  @override
  void initState() {
    super.initState();
    _handleInitialSharedIntent();
    _handleIncomingSharedIntents();
  }

  void _handleInitialSharedIntent() async {
    // Check if app was opened via share intent
    try {
      final initialMedia = await sharing.ReceiveSharingIntent.instance
          .getInitialMedia();
      if (initialMedia.isNotEmpty) {
        // Process text/URL shares
        for (final media in initialMedia) {
          if (media.type == sharing.SharedMediaType.text ||
              media.type == sharing.SharedMediaType.url) {
            _processSharedContent(media.path);
            break; // Process first text/URL share
          }
        }
      }
    } catch (e) {
      // Handle error
    }
  }

  void _handleIncomingSharedIntents() {
    // Listen for share intents while app is running
    try {
      _intentMediaStreamSubscription = sharing.ReceiveSharingIntent.instance
          .getMediaStream()
          .listen(
            (List<sharing.SharedMediaFile> sharedMedia) {
              if (sharedMedia.isNotEmpty) {
                // Process text/URL shares
                for (final media in sharedMedia) {
                  if (media.type == sharing.SharedMediaType.text ||
                      media.type == sharing.SharedMediaType.url) {
                    _processSharedContent(media.path);
                    break; // Process first text/URL share
                  }
                }
              }
            },
            onError: (err) {
              // Handle error
            },
          );
    } catch (e) {
      // Handle error
    }
  }

  void _processSharedContent(String sharedText) {
    // Clean the shared text (remove extra whitespace, newlines)
    final cleanedText = sharedText.trim();

    // Validate if it's a YouTube or Instagram link
    if (!LinkParser.isValidLink(cleanedText)) {
      // Show error if invalid link
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && navigatorKey.currentContext != null) {
          ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
            const SnackBar(
              content: Text('Please share a valid YouTube or Instagram link'),
              backgroundColor: Colors.red,
            ),
          );
        }
      });
      return;
    }

    // Show list selection dialog
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && navigatorKey.currentContext != null) {
        final context = navigatorKey.currentContext!;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => ListSelectionDialog(
            sharedUrl: cleanedText,
            sharedTitle: _extractTitleFromUrl(cleanedText),
            onLinkSaved: () {
              // Refresh links provider when link is saved
              final linksProvider = Provider.of<LinksProvider>(
                context,
                listen: false,
              );
              linksProvider.loadLinks(forceRefresh: true);
            },
          ),
        );
      }
    });
  }

  String _extractTitleFromUrl(String url) {
    final type = LinkParser.parseLinkType(url);
    if (type != null) {
      return LinkParser.generateTitleFromUrl(url, type);
    }
    return 'Shared Link';
  }

  @override
  void dispose() {
    _intentMediaStreamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LinksProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => ListsProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => AppStateProvider()..initialize()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          scaffoldBackgroundColor: Colors.black,
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        title: 'Elysian',
        navigatorKey: navigatorKey,
        navigatorObservers: [routeObserver],
        home: const BottomNav(),
      ),
    );
  }
}
