extends Node

var failures := 0
var discoveries := 0


func check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + label)


func write_save(value: Variant) -> void:
	var file := FileAccess.open(GameState.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(value))
	file.close()


func _ready() -> void:
	if OS.get_environment("TIDEWRACK_TEST_SAVE") != "1":
		push_error("Run through tests/run_save_tests.py to protect real saves.")
		get_tree().quit(1)
		return
	Journal.entry_added.connect(func(_id): discoveries += 1)
	if "--write-fixture" in OS.get_cmdline_user_args():
		GameState.new_game()
		Journal.discover("cold_start")
		GameState.set_flag("trusted_edith", false)
		check(GameState.save_game(), "cold save")
		get_tree().quit(failures)
		return
	if "--read-fixture" in OS.get_cmdline_user_args():
		check(GameState.load_game(), "cold load")
		check(Journal.has("cold_start") and GameState.get_flag("trusted_edith", true) == false, "cold process restoration")
		get_tree().quit(failures)
		return
	GameState.delete_save()
	check(not GameState.load_game(), "missing save")
	GameState.new_game()
	Journal.discover("")
	Journal.discover("   ")
	Journal.discover("entry_a")
	Journal.discover("entry_a")
	Journal.discover("future_content")
	check(discoveries == 2, "unique, nonblank discoveries")
	var copy := Journal.entries()
	copy.clear()
	check(Journal.entries().size() == 2, "defensive copy")
	var flags := {"trusted_edith": false, "skeptic": true, "radioed_tom": true,
		"lamp_relit": false, "custom": {"number": 7, "list": [1, "two", null]}}
	GameState.flags = flags.duplicate(true)
	GameState.current_scene = "res://scenes/lamp_room.tscn"
	check(GameState.save_game(), "write v2")
	GameState.new_game()
	check(Journal.entries().is_empty() and GameState.flags.is_empty(), "new game reset")
	check(GameState.load_game(), "load v2")
	check(GameState.flags == JSON.parse_string(JSON.stringify(flags)), "all story values survive")
	check(GameState.current_scene == "res://scenes/lamp_room.tscn", "resume scene")
	check(Journal.entries() == ["entry_a", "future_content"], "ordered round trip")
	check(discoveries == 2, "load does not replay discoveries")
	Journal.discover("unsaved")
	check(GameState.load_game() and not Journal.has("unsaved"), "load replaces rather than merges")
	# Exercise New Game immediately after a successful populated disk load.
	write_save({"version": 2, "scene": "res://scenes/lamp_room.tscn",
		"flags": flags, "journal_entries": ["log_01", "log_02"]})
	check(GameState.load_game(), "new game baseline loads")
	check(Journal.entries() == ["log_01", "log_02"], "new game baseline journal populated")
	check(GameState.flags == JSON.parse_string(JSON.stringify(flags)), "new game baseline flags populated")
	check(GameState.current_scene == "res://scenes/lamp_room.tscn", "new game baseline nondefault scene")
	var saved_before_reset := FileAccess.get_file_as_string(GameState.SAVE_PATH)
	GameState.new_game()
	check(Journal.entries().is_empty(), "new game after load clears journal")
	check(GameState.flags.is_empty(), "new game after load clears flags")
	check(GameState.current_scene == "res://scenes/game.tscn", "new game after load restores default scene")
	check(FileAccess.get_file_as_string(GameState.SAVE_PATH) == saved_before_reset, "new game leaves disk save unchanged")
	print("New Game after populated load: journal=%s flags=%s scene=%s" % [JSON.stringify(Journal.entries()), JSON.stringify(GameState.flags), GameState.current_scene])
	var replacement_cases := {
		"empty_v2": {"version": 2, "journal_entries": []},
		"legacy_v1": {"version": 1},
		"unversioned": {},
		"different_populated_v2": {"version": 2, "journal_entries": ["log_03"]},
	}
	for label in replacement_cases:
		# No New Game/clear between these loads: each must replace the prior state.
		write_save({"version": 2, "scene": "res://scenes/lamp_room.tscn",
			"flags": {"old_flag": true}, "journal_entries": ["log_01", "log_02"]})
		check(GameState.load_game(), "%s: populated save loads" % label)
		check(Journal.entries() == ["log_01", "log_02"], "%s: populated baseline" % label)
		var next_save: Dictionary = replacement_cases[label].duplicate(true)
		next_save["scene"] = "res://scenes/game.tscn"
		next_save["flags"] = {"trusted_edith": false}
		write_save(next_save)
		var expected: Array = ["log_03"] if label == "different_populated_v2" else []
		var loaded := GameState.load_game()
		var replaced: bool = Journal.entries() == expected
		check(loaded, "%s: replacement save loads" % label)
		check(replaced, "%s: journal replaced exactly" % label)
		check(not Journal.has("log_01") and not Journal.has("log_02"), "%s: prior IDs absent" % label)
		check(GameState.current_scene == "res://scenes/game.tscn", "%s: replacement scene" % label)
		check(GameState.flags == {"trusted_edith": false}, "%s: replacement flags" % label)
		check(GameState.load_game() and Journal.entries() == expected, "%s: repeated load does not accumulate" % label)
		print("Sequential load [%s]: load=%s replaced=%s entries=%s" % [label, loaded, replaced, JSON.stringify(Journal.entries())])
	for legacy in [{"version": 1, "flags": flags}, {"flags": flags}]:
		write_save(legacy)
		check(GameState.load_game(), "legacy migration")
		check(GameState.flags == JSON.parse_string(JSON.stringify(flags)) and Journal.entries().is_empty(), "legacy flags and empty journal")
		check(GameState.save_game() and GameState.load_game(), "legacy resave")
	var malformed_cases := {
		"missing": null,
		"null": null,
		"number": 4,
		"string": "entry",
		"object": {"entry": true},
		"boolean": true,
		"invalid_items_only": [null, 7, false, {}, [], "", "   "],
		"mixed_number": ["log_01", 42],
		"invalid_first": [42, "log_01"],
		"invalid_middle": ["log_01", 42, "log_02"],
		"mixed_null": ["log_01", null],
		"mixed_boolean": ["log_01", true],
		"mixed_object": ["log_01", {}],
		"mixed_array": ["log_01", []],
		"mixed_blank": ["log_01", ""],
		"mixed_whitespace": ["log_01", "   "],
	}
	for saved_scene in ["res://scenes/game.tscn", "res://scenes/lamp_room.tscn"]:
		for label in malformed_cases:
			# Seed different live values to prove loading replaces stale state.
			GameState.flags = {"unsaved_only": true}
			GameState.current_scene = "res://scenes/game.tscn" if saved_scene.ends_with("lamp_room.tscn") else "res://scenes/lamp_room.tscn"
			Journal.restore(["stale_entry"])
			var fixture := {"version": 2, "scene": saved_scene, "flags": flags}
			if label != "missing":
				fixture["journal_entries"] = malformed_cases[label]
			write_save(fixture)
			var loaded := GameState.load_game()
			var empty := Journal.entries().is_empty()
			var scene_preserved: bool = GameState.current_scene == saved_scene
			var flags_preserved: bool = GameState.flags == JSON.parse_string(JSON.stringify(flags))
			check(loaded, "%s: load succeeds" % label)
			check(empty, "%s: journal empty" % label)
			check(scene_preserved, "%s: saved scene restored" % label)
			check(flags_preserved, "%s: saved flags restored" % label)
			print("Malformed journal [%s / %s]: load=%s empty=%s scene=%s flags=%s" % [label, saved_scene.get_file(), loaded, empty, scene_preserved, flags_preserved])
	# Fully valid arrays still deduplicate and retain unknown IDs in order.
	write_save({"version": 2, "journal_entries": ["b", "a", "b", "unknown"], "flags": flags})
	check(GameState.load_game(), "valid journal loads")
	check(GameState.flags == JSON.parse_string(JSON.stringify(flags)), "valid journal preserves flags")
	check(Journal.entries() == ["b", "a", "unknown"], "valid journal deduplicates and retains unknown IDs")
	for bad in [null, [], {"version": 3}, {"version": "2"}, {"version": 1.5}, {"scene": 42}, {"scene": "res://scenes/main_menu.tscn"}]:
		var before := Journal.entries()
		write_save(bad)
		check(not GameState.load_game(), "reject invalid envelope")
		check(Journal.entries() == before and GameState.flags == JSON.parse_string(JSON.stringify(flags)), "failed load preserves live state")
	var file := FileAccess.open(GameState.SAVE_PATH, FileAccess.WRITE)
	file.store_string('{"version":')
	file.close()
	check(not GameState.load_game(), "truncated JSON")
	GameState.new_game()
	check(DialogueManager.start("res://data/dialogue/keeper_intro.json", "logbook"), "start real dialogue")
	DialogueManager.advance()
	DialogueManager.advance()
	DialogueManager.choose(0)
	DialogueManager.advance()
	DialogueManager.advance()
	DialogueManager.choose(1)
	DialogueManager.advance()
	check(GameState.get_flag("skeptic") == true and GameState.get_flag("trusted_edith", true) == false, "real choice flags")
	check(Journal.entries().is_empty(), "dialogue does not implicitly discover entries")
	Journal.discover("test_entry")
	check(GameState.save_game(), "save flags and independent journal state")
	GameState.new_game()
	check(GameState.load_game() and Journal.has("test_entry"), "restore independent discovery")
	check(GameState.get_flag("skeptic") == true and GameState.get_flag("trusted_edith", true) == false, "choice flags survive load")
	# A blocked temporary path must leave the previous save intact.
	DirAccess.make_dir_absolute(GameState.TEMP_PATH)
	Journal.discover("not_written")
	check(not GameState.save_game(), "write failure reported")
	DirAccess.remove_absolute(GameState.TEMP_PATH)
	check(GameState.load_game() and not Journal.has("not_written"), "write failure preserves disk save")
	GameState.delete_save()
	check(not GameState.has_save() and Journal.has("test_entry"), "delete affects disk only")
	print("Save/journal checks: %d failure(s)" % failures)
	get_tree().quit(1 if failures else 0)
