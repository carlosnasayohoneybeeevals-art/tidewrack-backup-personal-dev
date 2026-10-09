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

**Separate-process result (Godot 4.3, 2026-10-09):** Writer PID 381 exited
successfully before reader PID 397 started. The reader asserted empty initial
journal/flags and the default scene before loading. The saved JSON was:

```json
{
  "flags": {"radioed_tom": true, "skeptic": true, "trusted_edith": false},
  "journal_entries": ["log_01", "log_02"],
  "scene": "res://scenes/lamp_room.tscn",
  "version": 2
}
```

```text
Writer PID=381 failures=0
Reader PID=397 load=true journal=true scene=true flags=true failures=0
```

Both processes exited 0. The reader checked exact ordered journal IDs, the
nondefault saved scene, and the complete flag dictionary including explicit
false. The complete regression suite also finished with zero failures.

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

**New Game after loaded-save verification (Godot 4.3, 2026-10-09):** Load a
version 2 fixture with `["log_01", "log_02"]`, populated flags (including false
and nested values), and `res://scenes/lamp_room.tscn`. Assert all loaded values
before calling `GameState.new_game()` without an intervening clear. Observed:

```text
journal=[] flags={} scene=res://scenes/game.tscn
```

All eight assertions passed: successful load, three populated-state checks,
three reset-state checks, and an unchanged on-disk save. The full suite returned
zero failures and exit code 0. This verifies the New Game state-reset API;
manual title-button/scene-transition coverage remains a separate check.

**Sequential-load verification (Godot 4.3, 2026-10-09):** For each case, first
load a save containing `["log_01", "log_02"]`, then load the second fixture
without New Game or clearing state in between:

| Second save | Journal after load | Result |
| --- | --- | --- |
| Version 2 with `journal_entries: []` | `[]` | PASS |
| Legacy version 1 without journal | `[]` | PASS |
| Unversioned legacy save without journal | `[]` | PASS |
| Version 2 with `["log_03"]` | `["log_03"]` | PASS |

Each case asserts successful loading, exact replacement, absence of both old
IDs, replacement scene/flags, and the same result after another load. All 32
assertions passed; the complete suite returned zero failures and exit code 0.
Entries are replaced, never accumulated across these successful loads.

## 4. Duplicate discovery stores exactly one entry

**Setup:** Start with an empty journal and count `Journal.entry_added` emissions.
Use a disposable save and the single ID `duplicate_test`.

**Steps:** Call `Journal.discover("duplicate_test")` three times. Assert the
journal contains exactly one entry, then Save and inspect the parsed JSON.
Reset in-memory state, load the save, and discover the same ID once more.
Save again and inspect the JSON a second time.

**Expected:** Each in-memory check equals `["duplicate_test"]` with size `1`.
Both saved `journal_entries` arrays equal `["duplicate_test"]` with size `1`.
The first three calls emit entry-added only once; neither loading nor discovering
that already-restored ID emits another entry-added event. Repetition must never
increase the number of stored entries.

Use these explicit assertions in the isolated harness:

```gdscript
GameState.new_game()
for repeat in range(3):
    Journal.discover("duplicate_test")
assert(Journal.entries() == ["duplicate_test"])
assert(Journal.entries().size() == 1)
assert(GameState.save_game())
var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GameState.SAVE_PATH))
assert(saved["journal_entries"] == ["duplicate_test"])
assert(saved["journal_entries"].size() == 1)
GameState.new_game()
assert(GameState.load_game())
Journal.discover("duplicate_test")
assert(Journal.entries() == ["duplicate_test"])
assert(Journal.entries().size() == 1)
assert(GameState.save_game())
saved = JSON.parse_string(FileAccess.get_file_as_string(GameState.SAVE_PATH))
assert(saved["journal_entries"] == ["duplicate_test"])
assert(saved["journal_entries"].size() == 1)
```

**Coverage and result (Godot 4.3, 2026-10-09):** The automated
`_test_duplicate_round_trip()` now performs the dedicated single-ID disk and
signal checks. It discovers the ID three times, saves, clears memory, loads,
rediscovers the ID three times, then saves and loads again. All 14 assertions
passed, including exact single-entry arrays on disk before and after reload.
The `entry_added` count is measured relative to the start of this case:

| Stage | Journal | Total entry_added emissions in this case |
| --- | --- | --- |
| First discovery repeated three times | `["duplicate_test"]` | 1 |
| After save, memory reset, and load | `["duplicate_test"]` | 1 |
| After three rediscoveries and resave/reload | `["duplicate_test"]` | 1 |

Only the initial discovery emits; restoration and rediscovery emit no duplicate
discovery signal. The complete suite returned zero failures and exit code 0.

## 5. Malformed data, rejected loads, and failed writes preserve state

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

**Malformed journal subcase:** Keep valid story flags and load version 2 fixtures
with missing, null, scalar, or object journal fields, then the array
`["b", "a", "b", null, 7, "", " ", "unknown"]`. Non-array fields become empty;
the entire array becomes `[]`. Any invalid item rejects the whole journal,
including `["log_01", 42]`; load still succeeds with saved scene and flags
intact. Fully valid arrays preserve unknown IDs and deduplicate in order. Restore emits no entry-added events. Empty/whitespace-only
discoveries are ignored, and mutating the array returned by `Journal.entries()`
does not alter stored state. These normalization and defensive-copy checks are
automated; also resave/load the normalized fixture when changing sanitization.

**Verified results (Godot 4.3, 2026-10-09):** All 32 malformed-journal fixtures
(16 shapes across both saved scenes) passed all four assertions: load succeeds,
journal is empty, saved scene is restored, and saved flags are restored. This
includes `["log_01", 42]`, invalid elements first/middle/last, and mixed arrays
containing null, boolean, object, array, empty-string, or whitespace items.
The fixtures begin with stale live state. All 128 targeted assertions passed;
the complete suite, including separate-process persistence, finished with zero
failures and exit code 0. Fully valid arrays still preserve unknown IDs and
collapse duplicates in order. Both dialogue graphs also passed validation.
