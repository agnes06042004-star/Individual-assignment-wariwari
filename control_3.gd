extends Control

const FAILED_POPUP = preload("res://RunFailed.gd")

const NORMAL_IMAGE = preload("res://Images/Object/moa.png")
const GLOW_IMAGE = preload("res://Images/Object/moa_light.png")

const HWANG_CHOON_SKILL = preload(
	"res://Images/Skills/hwang_choon.png"
)

const BAMGEUT_SKILL = preload(
	"res://Images/Skills/bamgeut.png"
)

const DA_GO_NYANG_SKILL = preload(
	"res://Images/Skills/da_go_nyang.png"
)

const HHMNYARING_SKILL = preload(
	"res://Images/Skills/hhmnyaring.png"
)

const CHOIYONGMEONG_SKILL = preload(
	"res://Images/Skills/choiyongmeong.png"
)

const GAME_DURATION: float = 5.0
const CLEAR_EXP: int = 10

const NEXT_SCENES := {
	"control": "res://control2.tscn",
	"control2": "res://control3.tscn",
	"control3": "res://control4.tscn",
	"control4": ""
}

@onready var grid: GridContainer = \
	$CenterContainer/GridContainer

@onready var time_label: Label = \
	$HUD/RingIcon/TimeLabel

@onready var score_label: Label = \
	$HUD/ScoreLabel

@onready var skill_button: Button = \
	$HUD/SkillButton

@onready var correct_sound: AudioStreamPlayer = $CorrectSound
@onready var wrong_sound: AudioStreamPlayer = $WrongSound
@onready var end_sound: AudioStreamPlayer = $EndSound

var buttons: Array[TextureButton] = []
var character_layout: Array[Dictionary] = []

var highlighted_index: int = -1
var score: int = 0
var time_left: float = GAME_DURATION

var playing: bool = false
var game_finished: bool = false
var exp_awarded: bool = false

var active_character: String = ""
var active_skill_level: int = 0

var skill_used: bool = false
var freeze_left: float = 0.0
var boosted_hits: int = 0
var shields: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

	_store_character_layout()
	resized.connect(_layout_characters)
	_layout_characters()

	for child in grid.get_children():
		if not child is TextureButton:
			push_error(
				"%s must be a TextureButton." % child.name
			)
			return

		buttons.append(child as TextureButton)

	if buttons.is_empty():
		push_error("No game buttons found.")
		return

	for i in range(buttons.size()):
		var button: TextureButton = buttons[i]

		# Keep the existing size and position.
		button.process_mode = Node.PROCESS_MODE_PAUSABLE

		button.texture_normal = NORMAL_IMAGE
		button.texture_hover = null
		button.texture_pressed = null
		button.texture_disabled = null
		button.texture_focused = null

		button.disabled = false
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_STOP

		button.button_down.connect(
			_on_item_pressed.bind(i)
		)

	# Continue the score from the previous level.
	if GameData.continuing_level:
		score = GameData.score
	else:
		score = 0
		GameData.score = 0

	GameData.continuing_level = false

	active_character = CharacterData.selected

	active_skill_level = CharacterData.get_level(
		active_character
	)

	skill_button.process_mode = Node.PROCESS_MODE_PAUSABLE
	skill_button.pressed.connect(_use_skill)

	time_left = GAME_DURATION
	playing = true
	game_finished = false
	exp_awarded = false

	skill_used = false
	freeze_left = 0.0
	boosted_hits = 0
	shields = 0

	_update_hud()
	_highlight_random()


func _process(delta: float) -> void:
	if not playing:
		return

	var countdown_delta: float = delta

	# Freeze the countdown while allowing gameplay.
	if freeze_left > 0.0:
		var frozen_time: float = minf(
			freeze_left,
			countdown_delta
		)

		freeze_left -= frozen_time
		countdown_delta -= frozen_time

	time_left = maxf(
		time_left - countdown_delta,
		0.0
	)

	_update_hud()

	if time_left <= 0.0:
		if score <= 0:
			_show_failed()
		else:
			_complete_level()


func _highlight_random() -> void:
	if buttons.size() == 1:
		highlighted_index = 0

	elif highlighted_index < 0:
		highlighted_index = randi_range(
			0,
			buttons.size() - 1
		)

	else:
		var next_index: int = randi_range(
			0,
			buttons.size() - 2
		)

		if next_index >= highlighted_index:
			next_index += 1

		highlighted_index = next_index

	for i in range(buttons.size()):
		if i == highlighted_index:
			buttons[i].texture_normal = GLOW_IMAGE
		else:
			buttons[i].texture_normal = NORMAL_IMAGE


func _on_item_pressed(index: int) -> void:
	if not playing or get_tree().paused:
		return

	if time_left <= 0.0:
		return

	if index == highlighted_index:
		_add_correct_score()
		_highlight_random()

	else:
		wrong_sound.play()

		if shields > 0:
			shields -= 1

		else:
			score = maxi(score - 1, 0)
			GameData.score = score

			if score == 0:
				_show_failed()
				return

	_update_hud()


func _add_correct_score() -> void:
	if boosted_hits > 0:
		score += 10
		boosted_hits -= 1
	else:
		score += 5

	GameData.score = score
	correct_sound.play()


func _use_skill() -> void:
	if not playing or get_tree().paused:
		return

	if time_left <= 0.0:
		return

	if skill_used or active_skill_level <= 0:
		return

	skill_used = true

	_show_skill_flash()

	match active_character:
		"yeonjun":
			# HWANG CHOON: Score Boost.
			boosted_hits = active_skill_level

		"beomgyu":
			# BAMGEUT: Auto Hit.
			for i in range(active_skill_level):
				_add_correct_score()
				_highlight_random()

		"taehyun":
			# DA-GO-NYANG: Shield.
			shields = active_skill_level

		"hueningkai":
			# HHMNYARING: Time Gift.
			time_left += float(active_skill_level)

		"soobin":
			# CHOIYONGMEONG: Time Freeze.
			freeze_left = float(active_skill_level)

	_update_hud()


func _show_skill_flash() -> void:
	var texture: Texture2D

	match active_character:
		"yeonjun":
			texture = HWANG_CHOON_SKILL
		"beomgyu":
			texture = BAMGEUT_SKILL
		"taehyun":
			texture = DA_GO_NYANG_SKILL
		"hueningkai":
			texture = HHMNYARING_SKILL
		"soobin":
			texture = CHOIYONGMEONG_SKILL

	if texture == null:
		return

	var layer := CanvasLayer.new()
	layer.name = "SkillFlash"
	layer.layer = 50
	add_child(layer)

	var screen := Control.new()
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(screen)

	screen.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	var picture := TextureRect.new()
	picture.texture = texture
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE

	picture.stretch_mode = \
		TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(picture)

	var view: Vector2 = \
		get_viewport().get_visible_rect().size

	picture.size = view * Vector2(0.86, 0.48)
	picture.position = (view - picture.size) * 0.5
	picture.pivot_offset = picture.size * 0.5

	picture.scale = Vector2(0.75, 0.75)
	picture.modulate.a = 0.0

	var tween := create_tween()

	# Appear and expand.
	tween.tween_property(
		picture,
		"modulate:a",
		1.0,
		0.10
	)

	tween.parallel().tween_property(
		picture,
		"scale",
		Vector2.ONE,
		0.16
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Remain visible briefly.
	tween.tween_interval(0.25)

	# Fade out.
	tween.tween_property(
		picture,
		"modulate:a",
		0.0,
		0.18
	)

	tween.tween_callback(layer.queue_free)


func _update_hud() -> void:
	time_label.text = "%02d" % int(ceil(time_left))
	score_label.text = str(score)

	skill_button.disabled = (
		not playing
		or skill_used
		or active_skill_level <= 0
	)

	if active_skill_level <= 0:
		skill_button.text = "Skill Locked"

	elif skill_used:
		skill_button.text = "Skill Used"

	else:
		skill_button.text = "%s Lv.%d" % [
			CharacterData.SKILLS[active_character],
			active_skill_level
		]


func _award_character_exp() -> void:
	if exp_awarded:
		return

	exp_awarded = true

	CharacterData.add_exp(
		active_character,
		CLEAR_EXP
	)


func _complete_level() -> void:
	if game_finished:
		return

	game_finished = true
	playing = false

	GameData.score = score

	_award_character_exp()
	_disable_targets()
	_update_hud()

	var current_level: String = \
		scene_file_path.get_file().get_basename()

	if not NEXT_SCENES.has(current_level):
		push_error(
			"Unknown level scene: " + current_level
		)
		return

	var next_path: String = NEXT_SCENES[current_level]

	if next_path.is_empty():
		GameData.continuing_level = false
		end_sound.play()

		call_deferred(
			"_change_scene",
			"res://score.tscn"
		)

	else:
		GameData.continuing_level = true

		call_deferred(
			"_change_scene",
			next_path
		)


func _change_scene(path: String) -> void:
	if not ResourceLoader.exists(path):
		GameData.continuing_level = false
		push_error("Scene not found: " + path)
		return

	var error := get_tree().change_scene_to_file(path)

	if error != OK:
		GameData.continuing_level = false
		push_error("Failed to open scene: " + path)


func _show_failed() -> void:
	if game_finished:
		return

	game_finished = true
	playing = false
	score = 0

	GameData.score = 0
	GameData.continuing_level = false

	_disable_targets()
	_update_hud()

	end_sound.play()

	var failure_popup = FAILED_POPUP.new()
	add_child(failure_popup)


func _disable_targets() -> void:
	for button in buttons:
		button.texture_normal = NORMAL_IMAGE
		button.disabled = true


func _store_character_layout() -> void:
	var animation_root := get_node_or_null(
		"AnimationPlayer"
	)

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

	var bottom_center := Vector2(
		size.x * 0.5,
		size.y
	)

	for entry in character_layout:
		var character: Node2D = entry["node"]
		var original_position: Vector2 = entry["position"]
		var original_scale: Vector2 = entry["scale"]

		character.position = bottom_center + (
			original_position - Vector2(360, 1280)
		) * factor

		character.scale = original_scale * factor
