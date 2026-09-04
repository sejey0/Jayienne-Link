# Jayienne Link - Agent Guidelines & Project Rules

## 1. UI Rule: Strict Ban on Emojis in App UI
- **NEVER use Unicode emojis** (e.g. ⭐, 🌐, ✨, 🔒, 💖, 🚀, 💡, 🎲, 🎯) in user-facing UI text, button labels, dialogs, banners, badges, or notifications.
- **Always use Flutter's Material Icons** (`Icon(Icons.<name>)`) or SVG assets instead.
- If an icon is needed beside text, use `ElevatedButton.icon`, `TextButton.icon`, or a `Row` containing an `Icon` widget alongside a clean `Text` widget.

## 2. Performance & Tooling Rule
- **DO NOT run `flutter analyze`** during iterative development turns as it is too slow. Verify syntax and logic through targeted inspection and clean code practices.

## 3. UI Button Design & Color Consistency Rule
- **Primary / Standard Action Buttons (e.g. Spin, Add, Accept, Confirm):**
  - Must consistently apply the signature romantic gradient:
    `LinearGradient(colors: [Color(0xFFFF758C), Color(0xFFA18CD1)], begin: Alignment.topLeft, end: Alignment.bottomRight)`
  - Rounded corners: `BorderRadius.circular(14)` (up to `18`–`20` for full-width hero buttons).
  - Soft glowing drop shadow: `BoxShadow(color: Color(0xFFFF758C).withValues(alpha: 0.3), blurRadius: 8, offset: Offset(0, 2))`.
  - Typography & Foreground: Crisp white text with `FontWeight.bold`.
- **Reject, Error, or Destructive Action Buttons (e.g. Reject, Delete, Reset):**
  - Must use the identical rounded shape, shadow depth, padding, and bold typography as the standard buttons, but with the color shifted to a rich rose-crimson alert gradient:
    `LinearGradient(colors: [Color(0xFFFF5252), Color(0xFFD81B60)], begin: Alignment.topLeft, end: Alignment.bottomRight)` (or `[Color(0xFFFF4D6D), Color(0xFFC2185B)]`) with matching shadow `Color(0xFFFF5252).withValues(alpha: 0.3)`.
  - If outlined/secondary: use `Border.all(color: Color(0xFFFF5252).withValues(alpha: 0.45), width: 1.2)` with light tinted background `Color(0xFFFF5252).withValues(alpha: 0.1)`.
- **Disabled State:**
  - Background: `isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade300`, no gradient, no drop shadow, disabled text color (`Colors.grey.shade500`/`Colors.grey.shade600`).

## 4. Modal / Dialog Confirmation Rule
- **Confirmation Required for Sensitive / Irreversible Actions:**
  - Any button triggering a destructive, irreversible, or partner-affecting action (e.g. Rejecting a decision, Deleting an item/option, Resetting data/debug, Clearing states, Marking as done / unlocking turn) **MUST present a confirmation modal / dialog** before executing the action.
- **Modal Design Standards:**
  - **No Emojis:** Strictly prohibited. Use themed Material Icons in a soft circular badge at the top or leading of the dialog header.
  - **Clear Contextual Messaging:** State clearly what is being changed/discarded and how it impacts the user and partner.
  - **Cancel / Dismiss Action:** Clear "Cancel" button using secondary styling (`OutlinedButton` or neutral `TextButton`).
  - **Confirm Action Button:**
    - For destructive / reject / reset actions: Rose-crimson alert gradient button (`[Color(0xFFFF5252), Color(0xFFD81B60)]`) with bold white text.
    - For positive / milestone actions (e.g. Mark Done & Unlock): Romantic signature gradient button (`[Color(0xFFFF758C), Color(0xFFA18CD1)]`) with bold white text.
  - **Corner Radius:** `BorderRadius.circular(22)` to `24` for modern cohesive appearance matching the app's aesthetic.

