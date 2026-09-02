# Jayienne Link - Agent Guidelines & Project Rules

## 1. UI Rule: Strict Ban on Emojis in App UI
- **NEVER use Unicode emojis** (e.g. ⭐, 🌐, ✨, 🔒, 💖, 🚀, 💡, 🎲, 🎯) in user-facing UI text, button labels, dialogs, banners, badges, or notifications.
- **Always use Flutter's Material Icons** (`Icon(Icons.<name>)`) or SVG assets instead.
- If an icon is needed beside text, use `ElevatedButton.icon`, `TextButton.icon`, or a `Row` containing an `Icon` widget alongside a clean `Text` widget.

## 2. Performance & Tooling Rule
- **DO NOT run `flutter analyze`** during iterative development turns as it is too slow. Verify syntax and logic through targeted inspection and clean code practices.
