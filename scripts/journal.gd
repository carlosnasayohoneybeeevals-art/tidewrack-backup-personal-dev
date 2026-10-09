extends Node
## Ordered, unique discovery IDs. GameState owns disk persistence.

signal entry_added(id: String)
## Emitted after discovery, replacement, or reset; restoration never replays entry_added.
signal entries_changed

var _entries: Array[String] = []


func discover(id: String) -> void:
	if id.strip_edges().is_empty() or id in _entries:
		return
	_entries.append(id)
	entry_added.emit(id)
	entries_changed.emit()


func entries() -> Array[String]:
	return _entries.duplicate()


func has(id: String) -> bool:
	return id in _entries


## Invalid items are ignored; unknown IDs are retained for content compatibility.
## IDs are opaque: do not trim or rename valid IDs on load.
func restore(value: Variant, notify: bool = true) -> void:
	var restored: Array[String] = []
	if value is Array:
		for id in value:
			if id is String and not id.strip_edges().is_empty() and id not in restored:
				restored.append(id)
	_entries = restored
	if notify:
		entries_changed.emit()


func clear(notify: bool = true) -> void:
	restore([], notify)
