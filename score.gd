extends Control

const SUPABASE_URL: String = "https://vtctmostizxyghwhqlkn.supabase.co"
const SUPABASE_KEY: String = "sb_publishable_8SK_c6hJN_xDyRnjc8ge_w_YqadXVvY"

const MAIN_MENU_PATH: String = "res://main_menu.tscn"
const LIMIT: int = 25

@export var score_window_image: Texture2D
@export var finish_button_image: Texture2D

@onready var background: TextureRect = $TextureRect
@onready var exit_button: BaseButton = $ExitButton

var records: Array = []
var ranking_labels: Array[Label] = []

var popup: Control
var panel: PanelContainer
var popup_margin: MarginContainer
var popup_box: VBoxContainer
var button_row: HBoxContainer

var message: Label
var warning_label: Label
var name_input: LineEdit
var submit_button: BaseButton
var close_button: Button
var status_label: Label

var fetch_request: HTTPRequest
var save_request: HTTPRequest
var refresh_timer: Timer

var final_score: int = 0

var submitted: bool = false
var skipped: bool = false
var submitting: bool = false
var loading: bool = false
var leaving: bool = false
var entry_checked: bool = false
var layout_ready: bool = false
var submission_uncertain: bool = false

var notice: String = ""


func _ready() -> void:
	get_tree().paused = false

	GameData.continuing_level = false
	final_score = GameData.score

	scale = Vector2.ONE
	pivot_offset = Vector2.ZERO
	custom_minimum_size = Vector2.ZERO

	set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	background.custom_minimum_size = Vector2.ZERO
	background.scale = Vector2.ONE
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE

	background.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	exit_button.disabled = false
	exit_button.mouse_filter = Control.MOUSE_FILTER_STOP

	if not exit_button.pressed.is_connected(
		_on_exit_button_pressed
	):
		exit_button.pressed.connect(
			_on_exit_button_pressed
		)

	_create_ranking_labels()
	_create_entry_popup()
	_create_network()

	layout_ready = true

	resized.connect(_layout_screen)

	_layout_screen()
	_refresh_ranking()
	popup.hide()

	_load_records()


func _configured() -> bool:
	return SUPABASE_KEY.begins_with("sb_publishable_")


func _headers() -> PackedStringArray:
	return PackedStringArray([
		"apikey: " + SUPABASE_KEY,
		"Content-Type: application/json"
	])


func _qualifies() -> bool:
	if final_score <= 0:
		return false

	if records.size() < LIMIT:
		return true

	return final_score > int(
		records[LIMIT - 1]["score"]
	)


func _completion_message() -> String:
	return (
		"Moa Con Completed Successfully!\n"
		+ "Your Score: %d" % final_score
	)


func _create_network() -> void:
	fetch_request = HTTPRequest.new()
	fetch_request.timeout = 15.0
	add_child(fetch_request)

	fetch_request.request_completed.connect(
		_on_ranking_loaded
	)

	save_request = HTTPRequest.new()
	save_request.timeout = 15.0
	add_child(save_request)

	save_request.request_completed.connect(
		_on_score_saved
	)

	status_label = Label.new()
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.clip_text = true

	status_label.add_theme_color_override(
		"font_color",
		Color.WHITE
	)

	status_label.add_theme_color_override(
		"font_outline_color",
		Color.BLACK
	)

	status_label.add_theme_constant_override(
		"outline_size",
		4
	)

	add_child(status_label)

	status_label.set_anchors_and_offsets_preset(
		Control.PRESET_BOTTOM_WIDE
	)

	refresh_timer = Timer.new()
	refresh_timer.wait_time = 10.0
	add_child(refresh_timer)

	refresh_timer.timeout.connect(_load_records)

	if _configured():
		refresh_timer.start()


func _load_records() -> void:
	if loading or submitting or leaving:
		return

	if not _configured():
		status_label.text = "Set SUPABASE_KEY in score.gd."
		_offer_entry_after_error()
		return

	loading = true

	if notice.is_empty():
		status_label.text = "Loading leaderboard..."

	var url: String = SUPABASE_URL \
		+ "/rest/v1/leaderboard" \
		+ "?select=player_name,score" \
		+ "&order=score.desc,created_at.asc,id.asc" \
		+ "&limit=25"

	var error: Error = fetch_request.request(
		url,
		_headers()
	)

	if error != OK:
		loading = false

		_show_network_status(
			"Could not connect. Retrying..."
		)

		_offer_entry_after_error()


func _show_network_status(text: String) -> void:
	if notice.is_empty():
		status_label.text = text
	else:
		status_label.text = notice + " " + text


func _offer_entry_after_error() -> void:
	if entry_checked or submitting or submitted or skipped:
		return

	if final_score <= 0:
		return

	popup.show()

	message.text = (
		"Your Score: %d\n" % final_score
		+ "Leaderboard unavailable."
	)


func _on_ranking_loaded(
	result: int,
	code: int,
	_response_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	loading = false

	if leaving:
		return

	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_show_network_status(
			"Network: %d | HTTP: %d. Retrying..."
			% [result, code]
		)

		_offer_entry_after_error()
		return

	var data: Variant = JSON.parse_string(
		body.get_string_from_utf8()
	)

	if not data is Array:
		_show_network_status(
			"Invalid leaderboard response."
		)

		_offer_entry_after_error()
		return

	records.clear()

	for item in data:
		if not item is Dictionary:
			continue

		if not item.get("player_name") is String:
			continue

		var value: Variant = item.get("score")

		if not (value is int or value is float):
			continue

		if not is_finite(float(value)):
			continue

		records.append({
			"name": str(item["player_name"]),
			"score": int(value)
		})

		if records.size() >= LIMIT:
			break

	_refresh_ranking()

	if notice.is_empty():
		status_label.text = "Online leaderboard"
	else:
		status_label.text = notice

	if not entry_checked and not submitting:
		entry_checked = true

		popup.visible = (
			not submitted
			and not skipped
			and _qualifies()
		)

		if popup.visible:
			message.text = _completion_message()
			name_input.grab_focus()


func _create_ranking_labels() -> void:
	for i in range(LIMIT):
		var label := Label.new()

		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.clip_text = true

		label.add_theme_color_override(
			"font_color",
			Color("#38294f")
		)

		add_child(label)
		ranking_labels.append(label)


func _refresh_ranking() -> void:
	for i in range(ranking_labels.size()):
		if i >= records.size():
			ranking_labels[i].text = "—"
			continue

		var entry: Dictionary = records[i]

		if i < 3:
			ranking_labels[i].text = "%s\n%d" % [
				entry["name"],
				int(entry["score"])
			]
		else:
			ranking_labels[i].text = "%s  %d" % [
				entry["name"],
				int(entry["score"])
			]


func _create_entry_popup() -> void:
	popup = Control.new()
	add_child(popup)

	popup.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	var shade := ColorRect.new()
	shade.color = Color(0.06, 0.02, 0.13, 0.7)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP

	popup.add_child(shade)

	shade.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE

	popup.add_child(center)

	center.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	panel = PanelContainer.new()
	center.add_child(panel)

	if score_window_image != null:
		var picture := TextureRect.new()

		picture.texture = score_window_image
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_SCALE
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE

		panel.add_child(picture)

		panel.add_theme_stylebox_override(
			"panel",
			StyleBoxEmpty.new()
		)
	else:
		var style := StyleBoxFlat.new()

		style.bg_color = Color("#fff4df")
		style.border_color = Color("#a988d5")
		style.set_border_width_all(5)
		style.set_corner_radius_all(28)

		panel.add_theme_stylebox_override(
			"panel",
			style
		)

	popup_margin = MarginContainer.new()
	panel.add_child(popup_margin)

	popup_box = VBoxContainer.new()
	popup_margin.add_child(popup_box)

	message = Label.new()
	message.text = _completion_message()

	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.mouse_filter = Control.MOUSE_FILTER_IGNORE

	message.add_theme_color_override(
		"font_color",
		Color("#554073")
	)

	popup_box.add_child(message)

	name_input = LineEdit.new()
	name_input.placeholder_text = "Enter your name"
	name_input.max_length = 16

	name_input.add_theme_color_override(
		"font_color",
		Color("#302c32")
	)

	var input_style := StyleBoxFlat.new()

	input_style.bg_color = Color("#f3f3f3")
	input_style.border_color = Color("#c3bbce")
	input_style.set_border_width_all(2)
	input_style.set_corner_radius_all(12)
	input_style.content_margin_left = 12

	name_input.add_theme_stylebox_override(
		"normal",
		input_style
	)

	name_input.add_theme_stylebox_override(
		"focus",
		input_style
	)

	popup_box.add_child(name_input)

	warning_label = Label.new()

	warning_label.text = (
		"Closing this window will not save your result."
	)

	warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warning_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	warning_label.add_theme_color_override(
		"font_color",
		Color("#87565d")
	)

	popup_box.add_child(warning_label)

	button_row = HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	popup_box.add_child(button_row)

	if finish_button_image != null:
		var image_button := TextureButton.new()

		image_button.texture_normal = finish_button_image
		image_button.ignore_texture_size = true

		image_button.stretch_mode = \
			TextureButton.STRETCH_KEEP_ASPECT_CENTERED

		submit_button = image_button
	else:
		var text_button := Button.new()
		text_button.text = "Finish"

		_style_button(
			text_button,
			Color("#98efd4"),
			Color("#bdffe9"),
			Color("#70d5b8")
		)

		submit_button = text_button

	submit_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	submit_button.size_flags_stretch_ratio = 1.0

	submit_button.mouse_default_cursor_shape = \
		Control.CURSOR_POINTING_HAND

	button_row.add_child(submit_button)

	close_button = Button.new()
	close_button.text = "Close"

	close_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_button.size_flags_stretch_ratio = 1.0

	close_button.mouse_default_cursor_shape = \
		Control.CURSOR_POINTING_HAND

	_style_button(
		close_button,
		Color("#e0c5f3"),
		Color("#eedcff"),
		Color("#c9a5e3")
	)

	button_row.add_child(close_button)

	submit_button.pressed.connect(_submit_score)
	close_button.pressed.connect(_close_entry_popup)

	name_input.text_submitted.connect(
		_on_name_submitted
	)


func _style_button(
	button: Button,
	normal_color: Color,
	hover_color: Color,
	pressed_color: Color
) -> void:
	for state in [
		"normal",
		"hover",
		"pressed",
		"disabled"
	]:
		var style := StyleBoxFlat.new()

		style.bg_color = normal_color
		style.border_color = Color("#806198")
		style.set_border_width_all(2)
		style.set_corner_radius_all(16)

		match state:
			"hover":
				style.bg_color = hover_color
			"pressed":
				style.bg_color = pressed_color
			"disabled":
				style.bg_color = Color("#d8d1df")

		button.add_theme_stylebox_override(
			state,
			style
		)

	for color_name in [
		"font_color",
		"font_hover_color",
		"font_pressed_color"
	]:
		button.add_theme_color_override(
			color_name,
			Color("#49345d")
		)


func _on_name_submitted(_value: String) -> void:
	_submit_score()


func _submit_score() -> void:
	if submitted or skipped or submitting or leaving:
		return

	if not _configured():
		message.text = "Set SUPABASE_KEY in score.gd."
		return

	var player_name: String = name_input.text.strip_edges()

	if player_name.is_empty():
		message.text = "Please enter your name."
		name_input.grab_focus()
		return

	if final_score <= 0 or final_score > 100000:
		message.text = "Invalid score."
		return

	submitting = true

	submit_button.disabled = true
	close_button.disabled = true
	exit_button.disabled = true
	name_input.editable = false

	warning_label.text = "Please wait for submission to finish."
	message.text = "Submitting score..."

	var payload: String = JSON.stringify({
		"p_name": player_name,
		"p_score": final_score
	})

	var error: Error = save_request.request(
		SUPABASE_URL + "/rest/v1/rpc/submit_score",
		_headers(),
		HTTPClient.METHOD_POST,
		payload
	)

	if error != OK:
		_submission_error(
			"Could not start submission.\nPlease try again.",
			false
		)


func _submission_error(
	text: String,
	uncertain: bool
) -> void:
	submitting = false
	submission_uncertain = submission_uncertain or uncertain

	submit_button.disabled = false
	close_button.disabled = false
	exit_button.disabled = false
	name_input.editable = true

	message.text = text

	if submission_uncertain:
		warning_label.text = (
			"The result may already be saved.\n"
			+ "Closing will not submit it again."
		)
	else:
		warning_label.text = (
			"Closing this window will not save your result."
		)


func _on_score_saved(
	result: int,
	code: int,
	_response_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	if leaving:
		return

	if result != HTTPRequest.RESULT_SUCCESS:
		_submission_error(
			"Submission could not be confirmed.\n"
			+ "Your result may already have been saved.",
			true
		)
		return

	if code < 200 or code >= 300:
		_submission_error(
			"Submission failed (HTTP %d).\nPlease try again."
			% code,
			code >= 500
		)
		return

	var accepted: Variant = JSON.parse_string(
		body.get_string_from_utf8()
	)

	if not accepted is bool:
		_submission_error(
			"Unexpected server response.\n"
			+ "Your result may already have been saved.",
			true
		)
		return

	submitting = false
	submitted = true
	entry_checked = true

	exit_button.disabled = false

	name_input.release_focus()
	popup.hide()

	if accepted:
		notice = "Result saved!"
	else:
		notice = "Result did not enter the Top 25."

	status_label.text = notice
	_load_records()


func _close_entry_popup() -> void:
	if submitting or leaving:
		return

	skipped = true
	entry_checked = true

	name_input.release_focus()
	popup.hide()

	if submission_uncertain:
		notice = "Closed. Previous submission could not be confirmed."
	else:
		notice = "Your result was not recorded."

	status_label.text = notice

	_load_records()


func _layout_screen() -> void:
	if not layout_ready:
		return

	if size.x <= 0.0 or size.y <= 0.0:
		return

	background.scale = Vector2.ONE

	background.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE

	var ratio: Vector2 = size / Vector2(720.0, 1280.0)

	var font_scale: float = minf(
		ratio.x,
		ratio.y
	)

	var podiums: Array[Rect2] = [
		Rect2(0.39, 0.15, 0.22, 0.16),
		Rect2(0.10, 0.19, 0.23, 0.13),
		Rect2(0.66, 0.19, 0.23, 0.13)
	]

	for i in range(ranking_labels.size()):
		var rect: Rect2

		if i < 3:
			rect = podiums[i]
		else:
			var slot: int = i - 3
			var row: int = slot % 11

			var column: int = floori(
				float(slot) / 11.0
			)

			rect = Rect2(
				0.105 + 0.48 * column,
				0.393 + 0.043 * row,
				0.365,
				0.039
			)

		ranking_labels[i].position = rect.position * size
		ranking_labels[i].size = rect.size * size

		var base_font: float = 23.0 if i < 3 else 20.0

		ranking_labels[i].add_theme_font_size_override(
			"font_size",
			maxi(10, roundi(base_font * font_scale))
		)

	exit_button.set_anchors_and_offsets_preset(
		Control.PRESET_TOP_LEFT
	)

	exit_button.scale = Vector2.ONE
	exit_button.pivot_offset = Vector2.ZERO
	exit_button.custom_minimum_size = Vector2.ZERO

	if exit_button is TextureButton:
		exit_button.ignore_texture_size = true

		exit_button.stretch_mode = \
			TextureButton.STRETCH_KEEP_ASPECT_CENTERED

	var button_size: float = 88.0 * font_scale
	var edge: float = 16.0 * font_scale

	exit_button.position = Vector2(
		size.x - button_size - edge,
		edge
	)

	exit_button.size = Vector2.ONE * button_size

	panel.custom_minimum_size.x = minf(
		size.x * 0.88,
		520.0 * font_scale
	)

	message.add_theme_font_size_override(
		"font_size",
		maxi(12, roundi(28.0 * font_scale))
	)

	warning_label.add_theme_font_size_override(
		"font_size",
		maxi(11, roundi(20.0 * font_scale))
	)

	name_input.add_theme_font_size_override(
		"font_size",
		maxi(12, roundi(26.0 * font_scale))
	)

	name_input.custom_minimum_size.y = 60.0 * font_scale

	submit_button.custom_minimum_size = Vector2(
		0.0,
		68.0 * font_scale
	)

	close_button.custom_minimum_size = Vector2(
		0.0,
		68.0 * font_scale
	)

	if submit_button is Button:
		submit_button.add_theme_font_size_override(
			"font_size",
			maxi(12, roundi(24.0 * font_scale))
		)

	close_button.add_theme_font_size_override(
		"font_size",
		maxi(12, roundi(24.0 * font_scale))
	)

	button_row.add_theme_constant_override(
		"separation",
		maxi(8, roundi(16.0 * font_scale))
	)

	for side in ["left", "right", "top", "bottom"]:
		popup_margin.add_theme_constant_override(
			"margin_" + side,
			maxi(8, roundi(30.0 * font_scale))
		)

	popup_box.add_theme_constant_override(
		"separation",
		maxi(6, roundi(14.0 * font_scale))
	)

	status_label.add_theme_font_size_override(
		"font_size",
		maxi(10, roundi(18.0 * font_scale))
	)

	status_label.offset_left = 8.0 * font_scale
	status_label.offset_right = -8.0 * font_scale
	status_label.offset_top = -34.0 * font_scale
	status_label.offset_bottom = -4.0 * font_scale


func _on_exit_button_pressed() -> void:
	if leaving or submitting:
		return

	if not ResourceLoader.exists(MAIN_MENU_PATH):
		status_label.text = "Main menu scene not found."
		return

	leaving = true

	refresh_timer.stop()
	fetch_request.cancel_request()
	save_request.cancel_request()

	GameData.continuing_level = false
	get_tree().paused = false

	var error: Error = get_tree().change_scene_to_file(
		MAIN_MENU_PATH
	)

	if error != OK:
		leaving = false

		if _configured():
			refresh_timer.start()

		status_label.text = "Could not open main menu."
