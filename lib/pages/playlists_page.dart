import 'package:flutter/material.dart';

import '../widgets/library_content.dart';
import '../widgets/middle_content_panel.dart';

class PlaylistsPage extends StatelessWidget {
  const PlaylistsPage({required this.config, super.key});
  final LibraryPageConfig config;

  @override
  Widget build(BuildContext context) =>
      MiddleContentPanel(section: 'Playlists', config: config);
}
