class PhotoViewerNavPreference {
  PhotoViewerNavPreference._();

  /// Global preference for whether navigation arrows are displayed in photo viewers.
  /// When changed, it persists across all photo viewers (Shared Photo Feed & Shared Gallery).
  static bool showArrows = true;
}
