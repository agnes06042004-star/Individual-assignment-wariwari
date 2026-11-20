extends CanvasLayer

const FIRST_LEVEL := "res://control.tscn"
const MAIN_MENU := "res://main_menu.tscn"

var message: Label
var panel: PanelContainer
var buttons: HBoxContainer
var busy: bool = false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	var screen := Control.new()
	add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.07, 0.025, 0.14, 0.78)
	screen.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel = PanelContainer.new()
	center.add_child(panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#fff3e1")
	style.border_color = Color("#a58acc")
	style.set_border_width_all(5)
	style.set_corner_radius_all(28)
	panel.add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 26)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 28)
	margin.add_child(box)
	message = Label.new()
	message.text = "Moa Con Failed TT TT"
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.add_theme_color_override("font_color", Color("#624573"))
	message.add_theme_font_size_override("font_size", 30)
	box.add_child(message)
	buttons = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 18)
	box.add_child(buttons)
	var restart := _make_button("Restart", Color("#a8ecd1"))
	var exit_button := _make_button("Exit", Color("#f4bdd0"))
	buttons.add_child(restart)
	buttons.add_child(exit_button)
	restart.pressed.connect(_navigate.bind(FIRST_LEVEL))
	exit_button.pressed.connect(_navigate.bind(MAIN_MENU))
	get_viewport().size_changed.connect(_layout)
	_layout()
	get_tree().paused = true


func _make_button(text: String, color: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 72)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 26)
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(state, Color("#392d43"))
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("#72567e")
	style.set_border_width_all(3)
	style.set_corner_radius_all(18)
	button.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = color.lightened(0.12)
	button.add_theme_stylebox_override("hover", hover)
	var pressed := style.duplicate() as StyleBoxFlat
	pressed.bg_color = color.darkened(0.12)
	button.add_theme_stylebox_override("pressed", pressed)
	return button


func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	panel.custom_minimum_size.x = minf(view.x * 0.88, 540.0)


func _navigate(path: String) -> void:
	if busy:
		return
	if not ResourceLoader.exists(path):
		message.text = "Scene not found: " + path
		return
	busy = true
	var old_score: int = GameData.score
	var old_continuing: bool = GameData.continuing_level
	GameData.score = 0
	GameData.continuing_level = false
	get_tree().paused = false
	var error := get_tree().change_scene_to_file(path)
	if error != OK:
		GameData.score = old_score
		GameData.continuing_level = old_continuing
		get_tree().paused = true
		busy = false
		message.text = "Could not open scene. Please try again."
