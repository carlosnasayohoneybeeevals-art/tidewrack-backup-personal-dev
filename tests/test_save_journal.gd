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
	for legacy in [{"version": 1, "flags": flags}, {"flags": flags}]:
		write_save(legacy)
		check(GameState.load_game(), "legacy migration")
		check(GameState.flags == JSON.parse_string(JSON.stringify(flags)) and Journal.entries().is_empty(), "legacy flags and empty journal")
		check(GameState.save_game() and GameState.load_game(), "legacy resave")
	for bad in [null, 4, "entry", {}, ["b", "a", "b", null, 7, "", " ", "unknown"]]:
		write_save({"version": 2, "journal_entries": bad, "flags": flags})
		check(GameState.load_game(), "tolerant journal restore")
		check(GameState.flags == JSON.parse_string(JSON.stringify(flags)), "bad journal cannot erase flags")
		check(Journal.entries() == (["b", "a", "unknown"] if bad is Array else []), "journal sanitization")
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
	check(not Journal.has("entry_keeper_log"), "not discovered before reading")
	DialogueManager.advance()
	check(Journal.has("entry_keeper_log"), "actual log node discovers")
	DialogueManager.advance()
	DialogueManager.choose(0)
	DialogueManager.advance()
	DialogueManager.advance()
	DialogueManager.choose(1)
	DialogueManager.advance()
	check(GameState.get_flag("skeptic") == true and GameState.get_flag("trusted_edith", true) == false, "real choice flags")
	check(GameState.save_game(), "save real dialogue state")
	GameState.new_game()
	check(GameState.load_game() and Journal.has("entry_keeper_log"), "restore real discovery")
	# A blocked temporary path must leave the previous save intact.
	DirAccess.make_dir_absolute(GameState.TEMP_PATH)
	Journal.discover("not_written")
	check(not GameState.save_game(), "write failure reported")
	DirAccess.remove_absolute(GameState.TEMP_PATH)
	check(GameState.load_game() and not Journal.has("not_written"), "write failure preserves disk save")
	GameState.delete_save()
	check(not GameState.has_save() and Journal.has("entry_keeper_log"), "delete affects disk only")
	print("Save/journal checks: %d failure(s)" % failures)
	get_tree().quit(1 if failures else 0)
