# Save / Continue review for Sprint 29

Baseline inspected: main at `8c9b1e4`.

## What actually survived before this patch

| State | Behavior |
| --- | --- |
| Story flags | Whole dictionary saved, including explicit false values and unknown keys. Node and choice set_flag hooks both work. |
| Scene path | Saved by ground-floor pause Save; Continue instantiates that scene from the beginning. |
| Journal | Not saved. Journal script was not an autoload and no code called discover. The July dev-log overstates discovery integration. |
| Player position, interactable _used, dialogue cursor | Not saved. Scene-local state restarts. |
| Settings | Runtime only; no settings file. |
| Menu / quitting | No autosave. New Game resets memory but leaves the existing disk save until Save overwrites it. |

The stair currently starts placeholder dialogue, not a scene transition. The
lamp-room scene has no player, save menu, or puzzle. Saving its path through
GameState is supported, but it is not yet a playable Continue destination.

## Changes and compatibility contract

- Register Journal before GameState. Store ordered unique IDs under
  `journal_entries` in save version 2; preserve scene and flags fields.
- Explicit `journal_entry` metadata on a dialogue node or choice records a
  discovery independently of story flags. The keeper-log text node discovers
  `entry_keeper_log`; repeat reading is idempotent. No reader UI is included.
- Missing version is treated as v1. v1 loads flags and scene, replaces the
  journal with an empty list, and upgrades only on the next explicit Save.
  No retroactive discoveries are guessed from skeptic/believer/trusted_edith.
- Missing/non-array journal data becomes empty. Non-string/blank items are
  dropped, duplicates retain their first position, and unknown IDs are kept.
  Valid IDs are opaque and are not renamed or whitespace-normalized.
- Load replaces rather than merges journal state. Restoration/reset emits
  entries_changed, never entry_added. List access returns a copy.
- Invalid JSON, future/invalid versions, and invalid resume scenes return false
  before changing live state. Resume scenes currently allow only game and
  lamp_room; extend this list when shipping new scenes.
- Preserve the old fallback for missing/non-dictionary flags (empty dictionary).
  Valid flag dictionaries, including false values and nested JSON data, survive.
  JSON numbers follow Godot's existing JSON conversion to floating point.
- Save writes and flushes a sibling temporary file before replacement; failed
  writes leave the existing save intact. This is not a backup/recovery system
  or a guarantee against every power-loss/filesystem failure.
- Continue displays a failure dialog rather than silently doing nothing.
  has_save still checks existence, not validity. Delete Save remains disk-only;
  New Game remains a memory reset, not deletion of the last save.

## Verification

Run `python3 tests/validate_dialogue.py` and
`python3 tests/run_save_tests.py /path/to/godot` (Godot 4.3+).
The runner copies the project into a temporary directory and overrides user://;
never run destructive save tests against player data. Expected error logs come
from deliberate corrupt/version/path/write-failure cases; exit status is the gate.

Automated checks cover unique discovery, empty IDs, defensive copies, ordered
round trip, unknown IDs, explicit-false and nested flags, scene restoration,
New Game, repeated loading, missing-version/v1 upgrades, malformed journal
values, invalid envelopes, truncated JSON, real dialogue node discovery and
choice flags, a blocked write preserving the old save, disk-only deletion, and
save/load across two separate engine processes.

## Before calling this launch-ready

- Manually exercise title Continue, error dialog, pause Save, menu return,
  New Game then Continue, and repeated log reading with keyboard/controller.
- On each shipping OS, verify replacement of an existing save, full disk,
  permission denial, interruption during write/replacement, and leftover temp
  files. Linux headless blocked-open coverage does not prove power-loss safety.
- Check representative real older saves and decide whether an empty migrated
  journal is acceptable; old builds contain no authoritative discovery history.
- Add the journal reader UI, including unknown-entry fallback and refresh after
  reset/load. Decide whether read/unread and selected entry need persistence.
- Finish lamp-room traversal and saving there. Define checkpoint vs exact-resume
  behavior for position, once-only interactions, and mid-dialogue progress.
- Confirm the existing manual-save-only UX is intended; Main Menu/Quit do not
  save, and starting New Game does not immediately replace the old disk save.
- Decide backup/recovery and future-version UX policy before supporting cloud
  saves or multiple simultaneous game instances. Neither is implemented here.
