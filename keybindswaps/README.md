# keybindswaps

Automatically swaps the keybind on your mode action-bar slot when a specific glider becomes active, and reverts the keybind when the glider ends. Lets you keep different action-bar bindings per glider without manual rebinding.

## Preview

![keybindswaps](image/imagename.png)

## Features

- Monitors player buffs to detect glider activation.
- Profile-based swap configuration (saved via `ks_profiles`).
- Auto-reverts when the "Preparing Glider" debuff appears.
- Cooldown protection prevents accidental rapid re-swaps.
- Optional debug mode to verify swaps in chat.

## Installation

1. Copy the `keybindswaps` folder into your ArcheRage `addon` directory.
2. Launch the game — the addon loads automatically.

## Usage

Configure glider profiles via the in-game UI (`ui.lua`). When a profiled glider activates, the bound key changes; when the glider ends, the original bind is restored.
