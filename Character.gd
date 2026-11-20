extends Control

@onready var name_label: Label = $NameLabel
@onready var skill_label: Label = $SkillLabel
@onready var exp_label: Label = $ExpLabel
@onready var level_label: Label = $LevelLabel

@onready var select_button: Button = $SelectButton
@onready var back_button: Button = $BackButton
@onready var previous_button: Button = $PreviousButton
@onready var next_button: Button = $NextButton

var holder: Node2D
var portrait: TextureRect

var index: int = 0
var badges: Array[Label] = []
var exp_bar: ProgressBar

var character_transforms: Dictionary = {}
var layout_ready: bool = false


func _ready() -> void:
	get_tree().paused = false

	portrait = get_node_or_null(
		"VBoxContainer/Portrait"
	) as TextureRect

	if portrait == null:
		portrait = get_node_or_null("Portrait") as TextureRect

	if portrait == null:
		push_error("Portrait node not found.")
		return

	holder = portrait.get_node_or_null(
		"CharacterHolder"
	) as Node2D

	if holder == null:
		push_error("CharacterHolder node not found.")
		return

	index = maxi(
		0,
		CharacterData.IDS.find(CharacterData.selected)
	)

	previous_button.pressed.connect(_previous)
	next_button.pressed.connect(_next)
	select_button.pressed.connect(_select)
	back_button.pressed.connect(_back)

	level_label.hide()

	for label in [name_label, skill_label, exp_label]:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_color_override(
			"font_color",
			Color("#63467d")
		)

	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.clip_text = true

	skill_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	skill_label.clip_text = true

	exp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	exp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	_prepare_background()
	_create_progress()

	layout_ready = true

	resized.connect(_layout_character_page)

	_refresh()
	_layout_character_page()


func _prepare_background() -> void:
	var inverse: Transform2D = \
		get_global_transform().affine_inverse()

	for child in holder.get_children():
		if child is Node2D:
			character_transforms[child] = \
				inverse * child.get_global_transform()

	if portrait.get_parent() != self:
		portrait.reparent(self, false)

	portrait.custom_minimum_size = Vector2.ZERO
	portrait.scale = Vector2.ONE
	portrait.pivot_offset = Vector2.ZERO

	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_SCALE
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE

	portrait.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	move_child(portrait, 0)

	holder.transform = Transform2D.IDENTITY

	var old_container := get_node_or_null(
		"VBoxContainer"
	) as Control

	if old_container != null:
		old_container.hide()

	scale = Vector2.ONE
	pivot_offset = Vector2.ZERO

	set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)


func _create_progress() -> void:
	exp_bar = ProgressBar.new()
	exp_bar.show_percentage = false
	exp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var track := StyleBoxFlat.new()
	track.bg_color = Color("#e5dfeb")
	track.set_corner_radius_all(12)

	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("#a9e8d4")
	fill.set_corner_radius_all(12)

	exp_bar.add_theme_stylebox_override("background", track)
	exp_bar.add_theme_stylebox_override("fill", fill)

	add_child(exp_bar)

	move_child(exp_label, get_child_count() - 1)

	for i in range(3):
		var badge := Label.new()

		badge.text = str(i + 1)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE

		add_child(badge)
		badges.append(badge)


func _place_ui(
	node: Control,
	rect: Rect2,
	font_size: int = 0
) -> void:
	var ratio: Vector2 = size / Vector2(720.0, 1280.0)

	node.set_anchors_and_offsets_preset(
		Control.PRESET_TOP_LEFT
	)

	node.scale = Vector2.ONE
	node.pivot_offset = Vector2.ZERO

	node.position = rect.position * ratio
	node.size = rect.size * ratio

	if font_size > 0:
		var factor: float = minf(ratio.x, ratio.y)

		node.add_theme_font_size_override(
			"font_size",
			maxi(10, roundi(font_size * factor))
		)


func _layout_character_page() -> void:
	if not layout_ready:
		return

	if size.x <= 0.0 or size.y <= 0.0:
		return

	_place_ui(name_label, Rect2(392, 194, 270, 42), 22)
	_place_ui(skill_label, Rect2(401, 349, 263, 222), 18)

	_place_ui(exp_bar, Rect2(396, 674, 280, 36))
	_place_ui(exp_label, Rect2(396, 674, 280, 36), 20)

	_place_ui(select_button, Rect2(470, 893, 148, 64), 22)
	_place_ui(back_button, Rect2(30, 28, 149, 60), 22)

	_place_ui(
		previous_button,
		Rect2(42, 1073, 135, 64),
		20
	)

	_place_ui(
		next_button,
		Rect2(555, 1069, 129, 62),
		24
	)

	for i in range(badges.size()):
		_place_ui(
			badges[i],
			Rect2(394 + 106 * i, 823, 86, 44),
			22
		)

	var ratio: Vector2 = size / Vector2(720.0, 1280.0)
	var uniform: float = minf(ratio.x, ratio.y)

	for child in character_transforms:
		if not is_instance_valid(child):
			continue

		var original: Transform2D = \
			character_transforms[child]

		child.transform = Transform2D(
			original.x * uniform,
			original.y * uniform,
			original.origin * ratio
		)


func _refresh() -> void:
	var id: String = CharacterData.IDS[index]
	var level: int = CharacterData.get_level(id)
	var xp: int = int(CharacterData.experience.get(id, 0))

	name_label.text = CharacterData.NAMES[id]

	skill_label.text = "%s\n%s" % [
		CharacterData.SKILLS[id],
		CharacterData.get_description(id).replace("\n\n", "\n")
	]

	exp_bar.max_value = CharacterData.get_next_unlock_exp(id)
	exp_bar.value = mini(xp, int(exp_bar.max_value))

	if level >= 3:
		exp_label.text = "MAX"
	else:
		exp_label.text = "%d / %d" % [
			xp,
			int(exp_bar.max_value)
		]

	for i in range(badges.size()):
		var unlocked: bool = level >= i + 1

		var style := StyleBoxFlat.new()

		style.bg_color = (
			Color("#a9e8d4")
			if unlocked
			else Color("#d9d5df")
		)

		style.border_color = (
			Color("#68bda2")
			if unlocked
			else Color("#aaa2b5")
		)

		style.set_border_width_all(1)
		style.set_corner_radius_all(12)

		badges[i].add_theme_stylebox_override(
			"normal",
			style
		)

		badges[i].add_theme_color_override(
			"font_color",
			Color("#355d50") if unlocked else Color("#92899c")
		)

	select_button.disabled = CharacterData.selected == id

	select_button.text = (
		"Selected"
		if select_button.disabled
		else "Select"
	)

	_show_character(id)


func _show_character(id: String) -> void:
	for child in holder.get_children():
		if child is CanvasItem:
			child.hide()

		_animate(child, false)

	var character: Node = holder.get_node_or_null(
		NodePath(str(CharacterData.NAMES[id]))
	)

	if character == null:
		character = holder.get_node_or_null(
			NodePath(id.capitalize())
		)

	if character == null:
		push_error(
			"Character not found: " + str(CharacterData.NAMES[id])
		)
		return

	if character is CanvasItem:
		character.show()

	_animate(character, true)


func _animate(node: Node, enabled: bool) -> void:
	if node is AnimatedSprite2D:
		var sprite := node as AnimatedSprite2D

		if not enabled:
			sprite.pause()
		elif sprite.sprite_frames != null:
			var animations := \
				sprite.sprite_frames.get_animation_names()

			if not animations.is_empty():
				if sprite.sprite_frames.has_animation(
					sprite.animation
				):
					sprite.play()
				else:
					sprite.play(animations[0])

	for child in node.get_children():
		_animate(child, enabled)


func _previous() -> void:
	index = wrapi(
		index - 1,
		0,
		CharacterData.IDS.size()
	)

	_refresh()


func _next() -> void:
	index = wrapi(
		index + 1,
		0,
		CharacterData.IDS.size()
	)

	_refresh()


func _select() -> void:
	CharacterData.select_character(
		CharacterData.IDS[index]
	)

	_refresh()


func _back() -> void:
	get_tree().paused = false

	var error: Error = get_tree().change_scene_to_file(
		"res://main_menu.tscn"
	)

	if error != OK:
		push_error("Failed to open main menu.")
