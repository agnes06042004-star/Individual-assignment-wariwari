extends Node

const SAVE_PATH := "user://wari_characters.json"

const IDS := [
	"yeonjun",
	"beomgyu",
	"taehyun",
	"hueningkai",
	"soobin"
]

const NAMES := {
	"yeonjun": "HWANG CHOON",
	"beomgyu": "BAMGEUT",
	"taehyun": "DA-GO-NYANG",
	"hueningkai": "HHMNYARING",
	"soobin": "CHOIYONGMEONG"
}

const SKILLS := {
	"yeonjun": "Score Boost",
	"beomgyu": "Auto Hit",
	"taehyun": "Shield",
	"hueningkai": "Time Gift",
	"soobin": "Time Freeze"
}

const UNLOCK_EXP := [50, 100, 150]

var selected: String = "yeonjun"

var experience: Dictionary = {
	"yeonjun": 0,
	"beomgyu": 0,
	"taehyun": 0,
	"hueningkai": 0,
	"soobin": 0
}


func _ready() -> void:
	load_data()


func get_level(id: String) -> int:
	var value: int = int(experience.get(id, 0))

	if value >= UNLOCK_EXP[2]:
		return 3

	if value >= UNLOCK_EXP[1]:
		return 2

	if value >= UNLOCK_EXP[0]:
		return 1

	return 0


func get_description(id: String) -> String:
	var level: int = get_level(id)
	var power: int = maxi(level, 1)
	var description: String = ""

	match id:
		"yeonjun":
			description = (
				"Your next %d correct hits earn 10 points each."
				% power
			)

		"beomgyu":
			description = (
				"Automatically hit %d targets."
				% power
			)

		"taehyun":
			description = (
				"Block %d incorrect-hit penalties."
				% power
			)

		"hueningkai":
			description = (
				"Add %d seconds to the countdown."
				% power
			)

		"soobin":
			description = (
				"Freeze the countdown for %d seconds."
				% power
			)

	if level == 0:
		return "LOCKED — Requires 50 EXP\n\n" + description

	return description + "\n\nOnce per level."


func get_next_unlock_exp(id: String) -> int:
	var level: int = get_level(id)

	if level >= 3:
		return UNLOCK_EXP[2]

	return UNLOCK_EXP[level]


func select_character(id: String) -> void:
	if not IDS.has(id):
		return

	selected = id
	save_data()


func add_exp(id: String, amount: int) -> void:
	if not IDS.has(id):
		return

	experience[id] = int(experience[id]) + maxi(amount, 0)
	save_data()


func save_data() -> void:
	var file := FileAccess.open(
		SAVE_PATH,
		FileAccess.WRITE
	)

	if file == null:
		push_error("Could not save character progress.")
		return

	file.store_string(JSON.stringify({
		"selected": selected,
		"experience": experience
	}))

	file.close()


func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file := FileAccess.open(
		SAVE_PATH,
		FileAccess.READ
	)

	if file == null:
		return

	var data = JSON.parse_string(file.get_as_text())
	file.close()

	if not data is Dictionary:
		return

	var saved_selected = data.get("selected")

	if saved_selected is String:
		if IDS.has(saved_selected):
			selected = saved_selected

	var saved_exp = data.get("experience")

	if saved_exp is Dictionary:
		for id in IDS:
			var value = saved_exp.get(id, 0)

			if value is int or value is float:
				if is_finite(float(value)):
					experience[id] = maxi(0, int(value))
