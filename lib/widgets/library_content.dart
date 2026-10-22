import 'package:flutter/material.dart';

class LibraryPageConfig {
  const LibraryPageConfig({
    required this.compact,
    required this.hasNowPlayingPanel,
    required this.title,
    required this.trackCount,
    required this.onCreatePlaylist,
    required this.body,
    required this.error,
    required this.onDismissError,
    required this.queueOpen,
    required this.queuePanel,
  });

  final bool compact;
  final bool hasNowPlayingPanel;
  final String title;
  final int trackCount;
  final VoidCallback onCreatePlaylist;
  final Widget body;
  final String? error;
  final VoidCallback onDismissError;
  final bool queueOpen;
  final Widget queuePanel;
}
