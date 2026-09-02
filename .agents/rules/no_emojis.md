# UI Guidelines: Strict Ban on Emojis in Application UI

## Rule Definition
**DO NOT USE EMOJIS ANYWHERE IN THE APP UI.**
In all present and future updates, features, screens, dialogues, snackbars, and buttons across the entire Jayienne Link mobile app, Unicode emojis (e.g., ⭐, 🌐, ✨, 🔒, 💖, 🚀, 💡, etc.) are strictly prohibited.

## Mandatory Implementation
1. **Use Material & Custom Icons Only**:
   - Always use Flutter's built-in `Icon(Icons.<icon_name>)` widget or SVG assets from `assets/icons/`.
   - Examples:
     - Instead of ⭐, use `Icon(Icons.star_rounded)` or `Icon(Icons.favorite_rounded)`.
     - Instead of 🌐, use `Icon(Icons.public_rounded)`.
     - Instead of 🔒, use `Icon(Icons.lock_rounded)`.
     - Instead of ✨, use `Icon(Icons.auto_awesome_rounded)`.
     - Instead of ✏️, use `Icon(Icons.edit_rounded)`.
     - Instead of 🗑️, use `Icon(Icons.delete_rounded)`.
2. **Button & Text Labels**:
   - All button labels, dialog titles, body copy, and tooltips must contain clean, pure text without appended or prepended emojis.
   - Pair text with an `Icon` widget (e.g., using `ElevatedButton.icon`, `TextButton.icon`, or a `Row` containing an `Icon` and `Text`).
3. **Consistency**:
   - This rule applies to all current screens and any future screens or components created in this repository.
