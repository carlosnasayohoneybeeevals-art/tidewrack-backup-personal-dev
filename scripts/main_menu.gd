extends Control
## MainMenu — title screen. Built in code so the .tscn stays trivial.

const GAME_SCENE := "res://scenes/game.tscn"

var _continue_button: Button


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#0f1a22")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "TIDEWRACK"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.modulate = Color("#ffd466")
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Cape Marrow Light"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.modulate = Color(1, 1, 1, 0.6)
	vbox.add_child(subtitle)

	vbox.add_child(_spacer(24))

	var new_button := _make_button("New Game")
	new_button.pressed.connect(_on_new_game)
	vbox.add_child(new_button)

	_continue_button = _make_button("Continue")
	_continue_button.disabled = not GameState.has_save()
	_continue_button.pressed.connect(_on_continue)
	vbox.add_child(_continue_button)

	var settings_button := _make_button("Settings")
	settings_button.pressed.connect(_on_settings)
	vbox.add_child(settings_button)

	var quit_button := _make_button("Quit")
	quit_button.pressed.connect(_on_quit)
	vbox.add_child(quit_button)

	new_button.grab_focus()


func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(220, 44)
	button.add_theme_font_size_override("font_size", 22)
	return button


func _spacer(height: int) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer


func _on_new_game() -> void:
	GameState.new_game()
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_continue() -> void:
	if GameState.load_game():
		get_tree().change_scene_to_file(GameState.current_scene)


func _on_settings() -> void:
	var settings := preload("res://scenes/ui/settings.tscn").instantiate()
	add_child(settings)


func _on_quit() -> void:
	get_tree().quit()
