extends Control

@export_file("*.tscn") var game_scene_path: String = "res://control.tscn"

@onready var button_box: VBoxContainer = $CenterContainer/VBoxContainer
@onready var start_button: Button = $CenterContainer/VBoxContainer/Start
@onready var characters_button: Button = $CenterContainer/VBoxContainer/Characters
@onready var exit_button: Button = $CenterContainer/VBoxContainer/EXIT

const CHARACTER_SCENE: String = "res://character.tscn"

var character_layout: Array[Dictionary] = []
var changing_scene: bool = false


func _ready() -> void:
	if game_scene_path.is_empty():
		game_scene_path = "res://control.tscn"

	_store_character_layout()

	_style_button(start_button, Color("#95efd0"))
	_style_button(characters_button, Color("#d7b9f5"))
	_style_button(exit_button, Color("#ffc1d3"))

	button_box.add_theme_constant_override("separation", 24)

	if not start_button.pressed.is_connected(_on_start_pressed):
		start_button.pressed.connect(_on_start_pressed)

	if not characters_button.pressed.is_connected(_on_characters_pressed):
		characters_button.pressed.connect(_on_characters_pressed)

	if not exit_button.pressed.is_connected(_on_exit_pressed):
		exit_button.pressed.connect(_on_exit_pressed)

	characters_button.tooltip_text = ""

	resized.connect(_update_layout)
	_update_layout()


func _style_button(button: Button, color: Color) -> void:
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 32)

	for key in [
		"font_color",
		"font_hover_color",
		"font_pressed_color",
		"font_focus_color"
	]:
		button.add_theme_color_override(
			key,
			Color("#302333")
		)

	var normal := StyleBoxFlat.new()

	normal.bg_color = color
	normal.border_color = Color("#302333")
	normal.set_border_width_all(4)
	normal.set_corner_radius_all(30)

	normal.shadow_color = color.darkened(0.35)
	normal.shadow_size = 4
	normal.shadow_offset = Vector2(0, 7)

	normal.content_margin_left = 28
	normal.content_margin_right = 28
	normal.content_margin_top = 16
	normal.content_margin_bottom = 16

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = color.lightened(0.15)
	hover.border_color = Color("#705284")

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = color.darkened(0.10)
	pressed.shadow_size = 1
	pressed.shadow_offset = Vector2(0, 2)
	pressed.content_margin_top = 20
	pressed.content_margin_bottom = 12

	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Color("#fff6d9")
	focus.set_border_width_all(3)
	focus.set_corner_radius_all(30)

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", focus)


func _update_layout() -> void:
	var button_width: float = minf(
		clampf(size.x * 0.56, 240.0, 420.0),
		size.x * 0.90
	)

	button_box.custom_minimum_size.x = button_width

	for child in button_box.get_children():
		if child is Button:
			child.custom_minimum_size = Vector2(
				button_width,
				88.0
			)

	_layout_characters()


func _store_character_layout() -> void:
	character_layout.clear()

	var animation_root := get_node_or_null("AnimationPlayer")

	if animation_root == null:
		return

	for character in animation_root.get_children():
		if character is Node2D:
			character_layout.append({
				"node": character,
				"position": character.position,
				"scale": character.scale
			})


func _layout_characters() -> void:
	var factor: float = minf(
		size.x / 720.0,
		size.y / 1280.0
	)

	var bottom_center := Vector2(size.x * 0.5, size.y)

	for entry in character_layout:
		var character: Node2D = entry["node"]
		var original_position: Vector2 = entry["position"]
		var original_scale: Vector2 = entry["scale"]

		character.position = bottom_center + (
			original_position - Vector2(360, 1280)
		) * factor

		character.scale = original_scale * factor


func _on_start_pressed() -> void:
	if changing_scene:
		return

	if not ResourceLoader.exists(game_scene_path):
		_show_notice("Scene not found: " + game_scene_path)
		return

	GameData.score = 0
	GameData.continuing_level = false

	get_tree().paused = false
	_open_scene(game_scene_path)


func _on_characters_pressed() -> void:
	if changing_scene:
		return

	get_tree().paused = false
	_open_scene(CHARACTER_SCENE)


func _on_exit_pressed() -> void:
	get_tree().quit()


func _open_scene(path: String) -> void:
	if changing_scene:
		return

	if not ResourceLoader.exists(path):
		_show_notice("Scene not found: " + path)
		return

	changing_scene = true

	var error := get_tree().change_scene_to_file(path)

	if error != OK:
		changing_scene = false
		_show_notice("Failed to open scene: " + path)


func _show_notice(text: String) -> void:
	var notice := get_node_or_null("Notice") as AcceptDialog

	if notice == null:
		notice = AcceptDialog.new()
		notice.name = "Notice"
		notice.title = "WARI WARI"
		add_child(notice)

	notice.dialog_text = text
	notice.popup_centered()
