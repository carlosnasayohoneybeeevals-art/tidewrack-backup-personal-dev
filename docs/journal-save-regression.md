# Journal / save regression cases

These five cases cover the persistence contract in [GDD.md](GDD.md#save--load-and-continue-persistence).
Use disposable saves. Run the automated checks with Godot 4.3+:

```bash
python3 tests/run_save_tests.py /path/to/godot
python3 tests/validate_dialogue.py
```

The runner isolates `user://` in a temporary project. Intentional invalid-save
and write-failure checks log errors; the test process must exit successfully
with zero failed checks. Production discovery wiring is not part of this patch:
seed entries through `Journal.discover(id)` in the test harness, without editing
dialogue data. Automated coverage uses the persistence API; manual Continue
checks below also exercise the title menu and scene transition.

## 1. Save / Continue round trip preserves journal and story flags

**Setup:** Start a new session on the ground floor. Seed two journal IDs through
the API. Play the existing logbook conversation, choosing the skeptic response
and then keeping the information private, setting `skeptic=true` and
`trusted_edith=false`.

**Steps:** Save, return to the title, and Continue. Repeat after fully closing
and reopening the game. In the harness, also exercise the lamp-room path as a
stored value and include unknown flag keys and nested JSON flag values.

**Expected:** Both IDs return in their original order. Story flags retain their
values, especially explicit `false`. Continue starts the saved scene; it does
not restore player position or dialogue progress. Loading fires no entry-added
notifications. Scene-local state is rebuilt.

**Coverage:** Automated round trip, existing dialogue choices, nested flags,
scene-path restoration, and separate-process persistence. Manually verify the
actual title-menu transition; lamp-room gameplay remains unfinished.

## 2. Older saves load and upgrade without losing story flags

**Setup:** Create disposable version 1 and unversioned saves containing valid
scene paths and flags, but no journal field. Seed an unrelated in-memory journal
entry before loading each fixture.

**Steps:** Load each save, inspect state, then Save and load again. Also exercise
a legacy save with no scene and fixtures with missing/non-dictionary flags.

**Expected:** Valid flags and scene survive. The journal becomes empty, removing
stale in-memory discoveries; flags never imply discoveries. A missing scene
uses the ground floor. Missing/non-dictionary flags use the historical empty
fallback. Loading alone leaves the file untouched; the next Save produces
version 2, which loads successfully with the same valid flags.

**Coverage:** Automated v1/unversioned migration, default scene, and resave.
Manually inspect file contents before/after load and test representative real
older saves, including the legacy malformed-flags fallback.

## 3. New Game, repeated load, and deletion keep state boundaries clear

**Setup:** Save a session with story flags and journal entries. Add another
entry without saving.

**Steps:** Load twice, start New Game, then return to the title and Continue
without saving the new session. Separately, delete the disk save while a loaded
session is active.

**Expected:** Load replaces entries rather than merging: the unsaved entry
vanishes and repeated loads do not accumulate entries. New Game clears journal
and flags and resets the scene, but leaves the previous disk slot intact.
Continue can therefore restore that old session. Delete Save removes the slot
without clearing live entries. Main Menu and Quit do not autosave.

**Coverage:** Automated replacement, repeated load, New Game reset, and disk-only
deletion. Manually check New Game → Main Menu → Continue and quit behavior.

## 4. Duplicate and malformed journal data cannot corrupt story state

**Setup:** Discover the same ID twice, a second ID, and empty/whitespace-only
IDs. Separately, prepare version 2 saves with missing, null, scalar, or object
journal fields and an array such as `["b", "a", "b", null, 7, "", " ", "unknown"]`.
Keep valid story flags in every save.

**Steps:** Inspect entries and notifications after discovery. Mutate the array
returned by `Journal.entries()`. Load each fixture and save/load the normalized
result.

**Expected:** Discovery retains unique nonblank IDs in first-seen order and
emits entry-added only for new entries. Mutating the returned array does not
change the journal. Non-array journal data becomes empty; the example array
becomes `["b", "a", "unknown"]`. Unknown IDs are preserved, and valid IDs are
not trimmed or renamed. Story flags are unaffected. Restore does not replay
discovery notifications.

**Coverage:** Automated deduplication, blank IDs, defensive copies, malformed
journal shapes, unknown IDs, and flag preservation. Manually verify the
normalized fixtures through an additional resave cycle if changing sanitization.

## 5. Rejected loads and failed writes preserve recoverable state

**Setup:** Keep a known-good saved session and a distinct live state. Use
separate disposable fixtures for missing files, truncated JSON, non-object
payloads, invalid/future versions, and invalid scene values. For a write-failure
check, restore the good save and block creation of `save.json.tmp`.

**Steps:** Attempt each invalid load. Attempt Save with the blocked temporary
path, then unblock it and reload the previous good save. Manually exercise
Continue with a corrupt file and test write/replace failures on each shipping OS.

**Expected:** Invalid loads return false before altering live flags, scene, or
journal. Missing saves cannot Continue; corrupt files may leave Continue enabled
because availability checks file existence. Failed loading stays at the menu;
there is currently no user-facing error dialog. Failed Save reports failure and
the old disk save remains loadable. No truncated replacement is accepted as a
successful save.

**Coverage:** Automated missing/corrupt/version/scene rejection and blocked-open
preservation of the previous save. Manual gates: verify live scene preservation,
menu behavior, full disk, permission denial, replacement failure, interruption,
and leftover temporary files on each shipping OS. Headless tests do not establish
power-loss safety or provide backup recovery.
