# Auto Roles

Sets your raid role automatically based on the class you are playing.

Made by Koala.

## What it does

If you swap between several classes and have to re-pick your raid role every
time, this remembers the role for each class and sets it for you.

You save a role once per class. After that, whenever you join a raid the addon
reads which class you are on and sets your role to match. Swapping ability sets
mid-session updates it too.

## How to use it

1. Press **ESC** and open **Auto Roles** (it sits in the Combat section).
2. The window shows the class you are currently playing, with a status line:
   - **green** - this class already has a saved role
   - **red** - nothing saved for it yet
3. Tick the role number you want, then press **Save this class**.

That is it. The saved classes are listed at the bottom of the window, with `>`
marking the one you are on right now.

**Forget** removes the saved role for your current class.

## Role numbers

The game's raid roles are shown as number and marker colour rather than names
like "tank" or "healer", because what a raid uses each colour for is its own
convention.

| Number | Colour |
| --- | --- |
| 0 | None (clears your marker) |
| 1 | Green |
| 2 | Pink |
| 3 | Red |
| 4 | Purple |

## Requirements

The shared **globals** folder must be installed, in
`Documents/ArcheRage/Addon/globals/`.

## Notes

- Saved roles are stored per character.
- It only ever sets **your own** role. There is no way for an addon to set
  anyone else's.
- The window follows your UI theme, including dark mode.
