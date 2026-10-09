# Tidewrack — Game Design Document

Concise and living. For story canon see [`narrative-bible.md`](narrative-bible.md);
for schedule see [`milestones.md`](milestones.md).

## Pillars

1. **The fog keeps its secrets.** Discovery is slow, earned, and atmospheric.
2. **Words over combat.** The game is exploration + reading + choices. No fail
   states, no timers, no death.
3. **A place you tend.** The lighthouse is a home and a job; verbs are keeper's
   verbs — light the lamp, log the night, work the radio.

## Core loop

Explore a location → find a document, recording, or object → read/hear it in a
branching conversation → make a choice that sets a flag → the world (and later,
who answers you) responds. Repeat across locations toward the water.

## Systems

| System | State | Notes |
|--------|-------|-------|
| Branching dialogue | ✅ vertical slice | JSON graphs, choices set flags. |
| Save / load        | ✅ persistence | Single slot, version 2: scene, story flags, journal IDs; see below. |
| Menus + settings   | ✅ vertical slice | Title, pause, volume, fullscreen. |
| Player movement    | ✅ vertical slice | Top-down; wall collision pending. |
| Journal            | ⏳ demo           | Discovery storage persists; gameplay discovery wiring and reader UI pending. |
| Second location    | ⏳ demo           | The lamp room. |
| Controller + remap  | ⏳ demo          | Currently keyboard-only, built-in actions. |
| Localization        | ⏳ press build    | String extraction + translation tables. |
| Accessibility       | ⏳ press build    | Text scale, dyslexia-friendly font, no-flash. |
| Steam integration   | ⏳ launch         | Achievements, cloud saves. |

## Save / load and Continue persistence

The game uses one manual save slot at `user://save.json`. Pause → Save records
`GameState.current_scene` from the active scene and writes version 2 with
`scene`, `flags`, and `journal_entries`. The journal stores discovery IDs in
first-discovered order, without duplicates. Story flag values, including an
explicit `false`, remain independent of journal state.

Continue loads the saved state and starts the saved scene from its beginning.
It restores the scene path, story flags, and journal IDs; it does **not** restore
player position, the current dialogue node, scene-local once-only interaction
state, or settings. Only the ground-floor and lamp-room scene paths are accepted.
The lamp room remains a scaffold without a playable save/Continue flow.

The journal is an autoload, so entries survive scene changes during a session.
Disk persistence covers IDs supplied through `Journal.discover(id)`; production
callers and the reader UI are still pending. Dialogue content and existing
story-flag hooks are unchanged. Loading replaces journal state rather than
merging it with unsaved discoveries, and does not replay entry-added events.

New Game clears in-memory flags and journal entries and resets the scene to the
ground floor. It leaves the previous disk save available until an explicit Save
replaces it. Main Menu and Quit do not autosave. Delete Save removes the disk
slot without clearing the active session.

Version 1 and unversioned saves load with their existing flags and scene and an
empty journal; missing scene defaults to the ground floor. No discoveries are
inferred from story flags. Loading does not rewrite the file; the next Save
upgrades it to version 2. Missing or non-dictionary flags retain the existing
empty-dictionary fallback. Missing or non-array journal data becomes empty;
non-string and blank IDs are discarded, duplicates collapse in first-seen
order, and unknown nonblank IDs are retained unchanged.

Invalid JSON, unsupported versions, or invalid scene paths fail before changing
live state. Continue is enabled by file existence, so a corrupt save can still
show an enabled button; failed loading currently leaves the menu visible without
a user-facing error. Saves are written and flushed to a temporary sibling file
before replacing the previous slot. A failed write preserves the previous save;
backup recovery and guarantees against power loss are not implemented.

For the five regression cases and their expected results, see
[`journal-save-regression.md`](journal-save-regression.md). The baseline trace
and remaining launch work are in [`save-journal-review.md`](save-journal-review.md).

## Interaction design

Proximity-based: walk near an object, a prompt appears, press Enter. Dialogue
uses a typewriter reveal with press-to-skip; choices are keyboard-navigable and
focus the first option automatically. Movement is locked during conversation.

## Art & audio direction

Placeholder primitives today. Target: muted, desaturated palette (slate, kelp,
lamp-gold as the one warm accent — `#ffd466`); hand-painted 2D; a sound bed of
foghorn, surf, and radio static carrying most of the mood. Concept art and
final assets are produced per-milestone (see the tracker's `art` label).

## Out of scope (YAGNI)

No inventory economy, no crafting, no procedural generation, no multiplayer.
