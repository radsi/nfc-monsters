extends Node

@onready var error_sfx = $error
@onready var nfc_error_panel = $ColorRect2
@onready var error_timer = $ErrorTimer

@onready var spells_container = $VBoxContainer/SpellsContainer
@onready var items_container = $VBoxContainer/ItemsContainer
@onready var change_button = $VBoxContainer/HBoxContainer/changebutton

@onready var change_button_sprites = [
	preload("res://sprites/UI/ep--arrow-left-bold.png"),
	preload("res://sprites/UI/ep--arrow-right-bold.png")
]

@onready var item_ui_entry = preload("res://prefabs/ItemUIEntry.tscn")

func _ready() -> void:
	_setup_nfc()
	_setup_spells()
	_setup_items()


func _setup_nfc() -> void:
	if NfcUsage.nfc_plugin:
		NfcUsage.nfc_plugin.start_reading()
		NfcUsage.nfc_detected.connect(_on_nfc_detected)


func _setup_spells() -> void:
	var unlocked_spells = Gamemanager.get_unlocked_spells()

	for button in spells_container.get_children():
		if not unlocked_spells.has(button.name):
			button.get_child(0).show()
			button.get_child(1).hide()
			continue
		
		if Gamemanager.pending_unlocks.has(button.name):
			button.get_child(2).show()
			Gamemanager.pending_unlocks.erase(button.name)

		button.pressed.connect(_on_spell_button_pressed.bind(button))


func _setup_items() -> void:
	var items := load_all_items()
	var unlocked_items = Gamemanager.get_unlocked_items()

	var container := items_container.get_child(0).get_child(0)

	for item: ItemData in items:
		var entry = item_ui_entry.instantiate()
		container.add_child(entry)

		if not unlocked_items.has(item.id):
			continue
		
		if Gamemanager.pending_unlocks.has(item.id):
			entry.get_child(0).get_child(0).show()
			Gamemanager.pending_unlocks.erase(item.id)

		_apply_item_data(entry, item)


func _apply_item_data(entry: Node, item: ItemData) -> void:
	entry.get_child(0).texture = item.icon
	entry.get_child(1).get_child(0).text = item.name
	entry.get_child(2).get_child(0).text = item.description

func load_all_items() -> Array[ItemData]:
	var result: Array[ItemData] = []
	var dir := DirAccess.open("res://prefabs/items")

	if dir == null:
		return result

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var res := load("res://prefabs/items/" + file_name)
			if res is ItemData:
				result.append(res)

		file_name = dir.get_next()

	dir.list_dir_end()
	return result


func _show_error_panel(duration: float = 2.0) -> void:
	nfc_error_panel.show()
	error_timer.stop()
	error_timer.wait_time = duration
	error_timer.start()


func _on_spell_button_pressed(button) -> void:
	Gamemanager.card_to_view["name"] = button.name
	Gamemanager.change_scene("res://scenes/cardview.tscn")


func _on_backbutton_pressed() -> void:
	Gamemanager.return_scene()


func _on_nfc_detected(tag_id: String) -> void:
	var parsed_data = JSON.parse_string(tag_id)

	if typeof(parsed_data) != TYPE_DICTIONARY or not parsed_data.has("name"):
		error_sfx.play()
		_show_error_panel()
		return

	Gamemanager.card_to_view = parsed_data
	Gamemanager.change_scene("res://scenes/cardview.tscn")


func _on_error_timer_timeout() -> void:
	nfc_error_panel.hide()

var showing_items := false

func _on_changebutton_pressed() -> void:
	showing_items = !showing_items

	change_button.icon = change_button_sprites[0] if showing_items else change_button_sprites[1]

	spells_container.visible = not showing_items
	items_container.visible = showing_items
