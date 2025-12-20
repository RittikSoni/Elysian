import 'package:flutter/material.dart';
import 'package:elysian/utils/app_info.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'About',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // App Logo/Icon Section
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.amber, Colors.amber.shade700],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withValues(alpha: 0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.play_circle_filled,
                      size: 70,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Elysian',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Version ${AppInfo.fullVersion}',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),

            // App Description
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.amber, size: 24),
                        const SizedBox(width: 12),
                        Text(
                          'About Elysian',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Elysian is your ultimate video streaming companion. Watch your favorite content, organize playlists, and enjoy synchronized watch parties with friends and family.',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Features Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Features',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _FeatureItem(
                    icon: Icons.video_library,
                    title: 'Video Streaming',
                    description: 'Stream videos from multiple sources',
                    theme: theme,
                    isDark: isDark,
                  ),
                  _FeatureItem(
                    icon: Icons.people,
                    title: 'Watch Parties',
                    description: 'Sync and watch with friends in real-time',
                    theme: theme,
                    isDark: isDark,
                  ),
                  _FeatureItem(
                    icon: Icons.playlist_play,
                    title: 'Playlists',
                    description: 'Organize your favorite content',
                    theme: theme,
                    isDark: isDark,
                  ),
                  _FeatureItem(
                    icon: Icons.favorite,
                    title: 'Favorites',
                    description: 'Save and access your loved content',
                    theme: theme,
                    isDark: isDark,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Developer Info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.code, color: Colors.amber, size: 24),
                        const SizedBox(width: 12),
                        Text(
                          '',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _InfoRow(
                      icon: Icons.business,
                      label: 'Made with ❤️ in',
                      value: 'Delhi, India',
                      theme: theme,
                    ),
                    const SizedBox(height: 12),
                    _InfoRow(
                      icon: Icons.email_outlined,
                      label: 'Email',
                      value: 'contact.kingrittik@gmail.com',
                      theme: theme,
                      onTap: () => _launchEmail('contact.kingrittik@gmail.com'),
                    ),
                    // const SizedBox(height: 12),
                    // _InfoRow(
                    //   icon: Icons.language,
                    //   label: 'Website',
                    //   value: 'www.elysian.app',
                    //   theme: theme,
                    //   onTap: () => _launchUrl('https://www.elysian.app'),
                    // ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Legal & Links
            // Padding(
            //   padding: const EdgeInsets.symmetric(horizontal: 24),
            //   child: Column(
            //     children: [
            //       _LinkButton(
            //         icon: Icons.description,
            //         title: 'Terms of Service',
            //         theme: theme,
            //         isDark: isDark,
            //         onTap: () => _launchUrl(''),
            //       ),
            //       const SizedBox(height: 12),
            //       _LinkButton(
            //         icon: Icons.privacy_tip,
            //         title: 'Privacy Policy',
            //         theme: theme,
            //         isDark: isDark,
            //         onTap: () => _launchUrl(''),
            //       ),
            //       const SizedBox(height: 12),
            //       _LinkButton(
            //         icon: Icons.bug_report,
            //         title: 'Report a Bug',
            //         theme: theme,
            //         isDark: isDark,
            //         onTap: () => _launchEmail(
            //           'contact.kingrittik@gmail.com',
            //           subject: 'Bug Report',
            //         ),
            //       ),
            //     ],
            //   ),
            // ),
            const SizedBox(height: 32),

            // Copyright
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                '© 2025 Kingrittik. All rights reserved.',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }

  Future<void> _launchEmail(String email, {String? subject}) async {
    try {
      final uri = Uri(
        scheme: 'mailto',
        path: email,
        query: subject != null
            ? 'subject=${Uri.encodeComponent(subject)}'
            : null,
      );
      await launchUrl(uri);
    } catch (e) {
      debugPrint('Error launching email: $e');
    }
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final ThemeData theme;
  final bool isDark;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.theme,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.amber, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final ThemeData theme;
  final VoidCallback? onTap;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.theme,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            icon,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: onTap != null
                    ? Colors.amber
                    : theme.colorScheme.onSurface,
                fontSize: 14,
                fontWeight: onTap != null ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
          if (onTap != null)
            Icon(Icons.open_in_new, color: Colors.amber, size: 16),
        ],
      ),
    );
  }
}

class _LinkButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final ThemeData theme;
  final bool isDark;
  final VoidCallback onTap;

  const _LinkButton({
    required this.icon,
    required this.title,
    required this.theme,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.amber, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}
