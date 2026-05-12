# RaidSnapshot

Records snapshots of raid composition during an event — who joined, who left, when zones changed, and the largest party size reached during the session. Useful for loot accountability and post-raid review.

## Preview

![RaidSnapshot](image/imagename.png)

## Features

- Per-event session logging written to `Documents/Addon/RaidSnapshot/RaidsSnaps/`.
- Tracks player joins, leaves, and zone transitions.
- Captures the peak-population frame for the raid.
- Class mapping support (`classmappings.lua`) so logs include readable class info.
- Event picker combo box to select which raid to record.

## Usage

Open the window, pick the event you're running, and start a session. Snapshot files are saved locally and can be reviewed any time.
