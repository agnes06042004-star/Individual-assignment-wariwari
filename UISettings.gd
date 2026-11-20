extends Node

const SAVE_PATH := "user://wari_audio.cfg"

const BUTTON_COLORS := {
	"Start": "#95efd0",
	"Characters": "#d7b9f5",
	"EXIT": "#ffc1d3",
	"BackButton": "#d7b9f5",
	"PreviousButton": "#d7b9f5",
	"NextButton": "#95efd0",
	"SelectButton": "#95efd0",
	"SkillButton": "#fff0b5"
}

var music_enabled: bool = true
var sfx_enabled: bool = true

var music_button: Button
var sfx_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_ensure_bus("Music")
	_ensure_bus("SFX")

	var config := ConfigFile.new()

	if config.load(SAVE_PATH) == OK:
		music_enabled = bool(
			config.get_value("audio", "music", true)
		)

		sfx_enabled = bool(
			config.get_value("audio", "sfx", true)
		)

	_apply_audio()

	get_tree().node_added.connect(_on_node_added)
	_scan(get_tree().root)


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return

	AudioServer.add_bus()

	var index: int = AudioServer.bus_count - 1

	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, "Master")


func _scan(node: Node) -> void:
	_on_node_added(node)

	for child in node.get_children():
		_scan(child)


func _on_node_added(node: Node) -> void:
	# Route the existing audio players.
	if node is AudioStreamPlayer:
		if (
			node.is_in_group("sfx")
			or str(node.name) in [
				"CorrectSound",
				"WrongSound",
				"EndSound",
				"ClickSound",
				"SkillSound"
			]
		):
			node.bus = "SFX"

		elif (
			node.is_in_group("music")
			or node.name == &"AudioStreamPlayer"
		):
			node.bus = "Music"

	# Apply the button design after scene initialization.
	if node is Button:
		if BUTTON_COLORS.has(str(node.name)):
			call_deferred("_style_named_button", node)

	# Add audio controls only to the main menu.
	if node is Control:
		if node.scene_file_path.get_file() == "main_menu.tscn":
			call_deferred("_add_toolbar", node)


func _style_named_button(button) -> void:
	if not is_instance_valid(button):
		return

	var color := Color(
		BUTTON_COLORS[str(button.name)]
	)

	_style_button(button, color)

	if str(button.name) in [
		"PreviousButton",
		"NextButton",
		"SelectButton",
		"BackButton"
	]:
		button.add_theme_font_size_override(
			"font_size",
			22
		)


func _style_button(
	button: Button,
	color: Color
) -> void:
	button.mouse_default_cursor_shape = \
		Control.CURSOR_POINTING_HAND

	button.add_theme_font_size_override("font_size", 26)

	for key in [
		"font_color",
		"font_hover_color",
		"font_pressed_color",
		"font_focus_color"
	]:
		button.add_theme_color_override(
			key,
			Color("#493451")
		)

	button.add_theme_color_override(
		"font_disabled_color",
		Color("#817689")
	)

	var normal := StyleBoxFlat.new()

	normal.bg_color = color
	normal.border_color = Color("#725481")

	normal.set_border_width_all(3)
	normal.set_corner_radius_all(20)

	normal.shadow_color = color.darkened(0.28)
	normal.shadow_size = 2
	normal.shadow_offset = Vector2(0, 5)

	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = color.lightened(0.12)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = color.darkened(0.08)
	pressed.shadow_offset = Vector2(0, 1)

	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color("#ddd3e8")
	disabled.border_color = Color("#b1a1bd")
	disabled.shadow_size = 0
	disabled.shadow_offset = Vector2.ZERO

	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Color("#9b71d1")
	focus.set_border_width_all(3)
	focus.set_corner_radius_all(20)

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_stylebox_override("focus", focus)


func _add_toolbar(scene) -> void:
	if not is_instance_valid(scene):
		return

	if scene.has_node("AudioSettingsLayer"):
		return

	var layer := CanvasLayer.new()
	layer.name = "AudioSettingsLayer"
	layer.layer = 20
	layer.process_mode = Node.PROCESS_MODE_ALWAYS

	scene.add_child(layer)

	var screen := Control.new()
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE

	layer.add_child(screen)

	screen.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	var row := HBoxContainer.new()
	screen.add_child(row)

	row.set_anchors_and_offsets_preset(
		Control.PRESET_TOP_RIGHT
	)

	row.offset_left = -170
	row.offset_right = -24
	row.offset_top = 24
	row.offset_bottom = 88

	row.add_theme_constant_override("separation", 18)

	music_button = Button.new()
	music_button.name = "MusicToggle"

	sfx_button = Button.new()
	sfx_button.name = "SfxToggle"

	for button in [music_button, sfx_button]:
		button.custom_minimum_size = Vector2(64, 64)
		button.expand_icon = true

		button.add_theme_constant_override(
			"icon_max_width",
			36
		)

		row.add_child(button)

	music_button.pressed.connect(_toggle_music)
	sfx_button.pressed.connect(_toggle_sfx)

	_refresh_icons()


func _toggle_music() -> void:
	music_enabled = not music_enabled

	_apply_audio()
	_save_settings()
	_refresh_icons()


func _toggle_sfx() -> void:
	sfx_enabled = not sfx_enabled

	_apply_audio()
	_save_settings()
	_refresh_icons()


func _apply_audio() -> void:
	AudioServer.set_bus_mute(
		AudioServer.get_bus_index("Music"),
		not music_enabled
	)

	AudioServer.set_bus_mute(
		AudioServer.get_bus_index("SFX"),
		not sfx_enabled
	)


func _save_settings() -> void:
	var config := ConfigFile.new()

	config.set_value(
		"audio",
		"music",
		music_enabled
	)

	config.set_value(
		"audio",
		"sfx",
		sfx_enabled
	)

	if config.save(SAVE_PATH) != OK:
		push_warning("Could not save audio settings.")


func _refresh_icons() -> void:
	if is_instance_valid(music_button):
		music_button.icon = _make_icon(
			true,
			music_enabled
		)

		music_button.tooltip_text = (
			"Music: On"
			if music_enabled
			else "Music: Off"
		)

		_style_button(
			music_button,
			Color("#a6ecd7")
			if music_enabled
			else Color("#f5c2d2")
		)

	if is_instance_valid(sfx_button):
		sfx_button.icon = _make_icon(
			false,
			sfx_enabled
		)

		sfx_button.tooltip_text = (
			"Sound Effects: On"
			if sfx_enabled
			else "Sound Effects: Off"
		)

		_style_button(
			sfx_button,
			Color("#d8c5f2")
			if sfx_enabled
			else Color("#f5c2d2")
		)


func _make_icon(
	is_music: bool,
	enabled: bool
) -> Texture2D:
	var shape: String

	if is_music:
		shape = (
			'<path d="M24 34V12L44 8V30M24 18L44 14"/>'
			+ '<ellipse cx="17" cy="36" rx="7" ry="5" fill="#493451"/>'
			+ '<ellipse cx="37" cy="32" rx="7" ry="5" fill="#493451"/>'
		)
	else:
		shape = (
			'<path d="M9 22H18L29 12V44L18 34H9Z" fill="#493451"/>'
			+ '<path d="M36 21Q44 28 36 35M42 14Q56 28 42 42"/>'
		)

	if not enabled:
		shape += (
			'<path d="M8 8L48 48" stroke="#fff4df" stroke-width="9"/>'
			+ '<path d="M8 8L48 48" stroke="#bd5274" stroke-width="5"/>'
		)

	var svg: String = (
		'<svg xmlns="http://www.w3.org/2000/svg" '
		+ 'width="56" height="56" viewBox="0 0 56 56">'
		+ '<g fill="none" stroke="#493451" stroke-width="4" '
		+ 'stroke-linecap="round" stroke-linejoin="round">'
		+ shape
		+ '</g></svg>'
	)

	var picture := Image.new()

	if picture.load_svg_from_string(svg) != OK:
		return null

	return ImageTexture.create_from_image(picture)
