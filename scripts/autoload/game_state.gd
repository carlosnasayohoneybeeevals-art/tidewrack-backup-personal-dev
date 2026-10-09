extends Node
## GameState — global save/load and story flags.
##
## Autoloaded as `GameState`. Holds the narrative flags set by dialogue
## choices and persists them to user://save.json so "Continue" works.

signal state_changed

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 2
const DEFAULT_SCENE := "res://scenes/game.tscn"
const TEMP_PATH := SAVE_PATH + ".tmp"

## Story flags set during play, e.g. {"trusted_edith": true}.
var flags: Dictionary = {}
## Path of the scene the player should resume into.
var current_scene: String = "res://scenes/game.tscn"


func set_flag(name: String, value: Variant) -> void:
	flags[name] = value
	state_changed.emit()


func get_flag(name: String, default: Variant = false) -> Variant:
	return flags.get(name, default)


func new_game() -> void:
	flags.clear()
	Journal.clear(false)
	current_scene = DEFAULT_SCENE
	Journal.entries_changed.emit()
	state_changed.emit()


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> bool:
	var payload := {
		"version": SAVE_VERSION,
		"scene": current_scene,
		"flags": flags,
		"journal_entries": Journal.entries(),
	}
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		push_error("GameState: could not open save file for writing.")
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		DirAccess.remove_absolute(TEMP_PATH)
		return false
	# Replace only after a successful write; a failed write preserves the old save.
	var replace_error := DirAccess.rename_absolute(TEMP_PATH, SAVE_PATH)
	if replace_error != OK:
		push_error("GameState: could not replace save file.")
		DirAccess.remove_absolute(TEMP_PATH)
		return false
	return true


func load_game() -> bool:
	if not has_save():
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("GameState: could not open save file for reading.")
		return false
	var text := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("GameState: save file is corrupt.")
		return false

	var data: Dictionary = parsed
	var version: Variant = data.get("version", 1)
	if typeof(version) not in [TYPE_INT, TYPE_FLOAT] or (version != 1 and version != SAVE_VERSION):
		push_error("GameState: unsupported save version.")
		return false
	var scene: Variant = data.get("scene", DEFAULT_SCENE)
	if not scene is String or scene not in [DEFAULT_SCENE, "res://scenes/lamp_room.tscn"]:
		push_error("GameState: invalid resume scene.")
		return false
	var loaded_flags: Variant = data.get("flags", {})
	# Validate before replacing any live state. Legacy malformed flags keep the
	# original fallback to an empty dictionary; all valid flag values survive.
	flags = loaded_flags if typeof(loaded_flags) == TYPE_DICTIONARY else {}
	current_scene = scene
	# v1 had no journal data. Never infer discoveries from ambiguous story flags.
	Journal.restore(data.get("journal_entries", []) if version == SAVE_VERSION else [], false)
	Journal.entries_changed.emit()
	state_changed.emit()
	return true


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)
