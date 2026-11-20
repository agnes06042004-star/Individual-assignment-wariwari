extends Control

@export_file("*.tscn") var title_scene_path: String = "res://main_menu.tscn"

@onready var menu_button: TextureButton = $MenuButton
@onready var popup_root: Control = $PopupRoot
@onready var shade: ColorRect = $PopupRoot/Shade
@onready var center: CenterContainer = $PopupRoot/CenterContainer

@onready var menu_panel: PanelContainer = \
	$PopupRoot/CenterContainer/MenuPanel

@onready var window_image: TextureRect = \
	$PopupRoot/CenterContainer/MenuPanel/WindowImage

@onready var menu_control: Control = \
	$PopupRoot/CenterContainer/MenuPanel/MenuControl

@onready var restart_button: TextureButton = \
	$PopupRoot/CenterContainer/MenuPanel/MenuControl/RestartButton

@onready var resume_button: TextureButton = \
	$PopupRoot/CenterContainer/MenuPanel/MenuControl/ResumeButton

@onready var exit_button: TextureButton = \
	$PopupRoot/CenterContainer/MenuPanel/MenuControl/ExitButton

var menu_open: bool = false
var previous_pause_state: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_control.mouse_filter = Control.MOUSE_FILTER_IGNORE

	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	menu_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	for button in [
		menu_button,
		restart_button,
		resume_button,
		exit_button
	]:
		button.process_mode = Node.PROCESS_MODE_ALWAYS
		button.disabled = false
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	popup_root.hide()

	menu_button.pressed.connect(_open_menu)
	restart_button.pressed.connect(_restart_game)
	resume_button.pressed.connect(_close_menu)
	exit_button.pressed.connect(_exit_to_title)


func _open_menu() -> void:
	if menu_open:
		return

	print("Menu pressed")

	previous_pause_state = get_tree().paused
	menu_open = true

	popup_root.show()
	menu_button.hide()
	get_tree().paused = true


func _close_menu() -> void:
	if not menu_open:
		return

	print("Resume pressed")

	menu_open = false
	popup_root.hide()
	menu_button.show()

	get_tree().paused = previous_pause_state


func _restart_game() -> void:
	print("Restart pressed")

	var was_paused := get_tree().paused
	get_tree().paused = false

	var error := get_tree().reload_current_scene()

	if error != OK:
		push_error("Failed to restart the game.")
		get_tree().paused = was_paused


func _exit_to_title() -> void:
	print("Exit pressed")

	if not ResourceLoader.exists(title_scene_path):
		push_error("Title scene not found: " + title_scene_path)
		return

	var was_paused := get_tree().paused
	get_tree().paused = false

	var error := get_tree().change_scene_to_file(title_scene_path)

	if error != OK:
		push_error("Failed to open the title scene.")
		get_tree().paused = was_paused
