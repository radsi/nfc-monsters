extends MapMenu
class_name RandomEvents

class EventEntry:
	var scene: PackedScene
	var data: EventData

@export var _ItemsManager: ItemsManager

@onready var WaitingCardLabel: Label = $ColorRect/HBoxContainer2/Upgrade/Label
@onready var card_view: Button = $ColorRect/HBoxContainer2/Upgrade/CardView
@onready var completed_timer: Timer = $CompletedTimer

var event_finished := false

enum EventStatus
{
	NONE,
	REPLACING_ITEM
}

var events_path := "res://prefabs/events"
var events: Array[EventEntry] = []
var vanilla_events: Array = ["shop", "combat"]
var selected_vanilla_event := ""

var current_event: EventData
var event_status: EventStatus = EventStatus.NONE

var waiting_card = false
var waiting_index := 0
var waiting_timer := 0.0
var waiting_dots := [
	"Waiting card   ",
	"Waiting card.  ",
	"Waiting card.. ",
	"Waiting card..."
]

func _ready() -> void:
	shown_on_paper.connect(func():
		NfcUsage.connect("nfc_detected", Callable(self, "_on_nfc_detected"))
		)
	
	hidding_mid_animation.connect(func():
		if selected_vanilla_event == "":
			return
		var vanilla = PaperBG.get_child(1).find_child(selected_vanilla_event)
		vanilla.hide_on_paper(true)
		)
	
	showing_mid_animation.connect(func():
		selected_vanilla_event = ""

		var selected = pick_weighted_event()

		if selected == null:
			var vanilla = PaperBG.get_child(1).find_child(selected_vanilla_event)
			vanilla.show_on_paper(true)

			return

		current_event = selected.data

		var instance: EventData = selected.scene.instantiate()
		add_child(instance)

		current_event = instance
		
		if current_event.has_method("custom_event_script"):
			current_event.custom_event_script(self)

		current_event.YesButton.input_event.connect(func(_viewport, event, _shape_idx):
			_on_input(current_event.YesButton, event)
		)
		
		if current_event.NoButton == null: return

		current_event.NoButton.input_event.connect(func(_viewport, event, _shape_idx):
			_on_input(current_event.NoButton, event)
		)
	)
	
	hidden_from_paper.connect(func():
		NfcUsage.disconnect("nfc_detected", Callable(self, "_on_nfc_detected"))
		event_finished = false
		if selected_vanilla_event == "":
			current_event.queue_free()
		)
	
	load_events()
	
	if events.is_empty():
		return
	
	_ItemsManager.ItemAdded.connect(_on_item_added)
	_ItemsManager.ItemRemoved.connect(_on_item_removed)

func _on_input(area: Area2D, event):
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed and not event_finished:
		_choose_option(area.get_parent().name)

func _process(delta: float) -> void:
	if not waiting_card:
		return

	waiting_timer += delta
	if waiting_timer < 0.4:
		return

	waiting_timer = 0.0
	WaitingCardLabel.text = waiting_dots[waiting_index]
	waiting_index = (waiting_index + 1) % waiting_dots.size()

func _on_nfc_detected(tag_id: String) -> void:
	
	if not waiting_card: return
	
	var data = JSON.parse_string(tag_id)
	if data == null:
		return
		
	var new_level = data.get("level") + 1
	data.set("level", new_level)
	
	NfcUsage.write_nfc(JSON.stringify(data))
	NfcUsage.stop_reading()
	waiting_card = false

	_GameController._dissolve_in(card_view, 1, _GameController._action_original_materials, _GameController.DissolveShader, card_view.get_node(data.get("name")))
	
	var label_tween = _GameController._dissolve_out(WaitingCardLabel, 1)
	
	label_tween.finished.connect(func():
		_GameController._dissolve_in(WaitingCardLabel, 1, _GameController._action_original_materials)
		WaitingCardLabel.text = format_spell_data_name(data.get("name")) + " upgraded to level " + str(int(new_level)) + "!" 
		)
	
	Gamemanager.unlock_item(4)
	
	completed_timer.start(3)

func format_spell_data_name(spell_name: String) -> String:
	return "Spell " + spell_name.split("Spell")[1].to_lower()

func _choose_option(option):
	for particle: GPUParticles2D in current_event.ActiveParticles:
		particle.emitting = false

	for particle: GPUParticles2D in current_event.DeactiveParticles:
		particle.emitting = false

	event_finished = true

	var is_no = option == "NO"
	var target_texture = current_event.get_child(0)
	
	if current_event.GeneralLabel != null:
		_dissolve_general_label(is_no)
	
	var sprite = current_event.NoSprite if is_no else current_event.YesSprite
	var sfx = current_event.NoSFX if is_no else current_event.YesSFX

	if sfx:
		sfx.play()

	if sprite:
		if target_texture is Button:
			target_texture.icon = sprite
		else:
			target_texture.texture = sprite

	if not is_no:
		for action in current_event.types:
			print(current_event.EventTypes.keys()[action])
			call_deferred(current_event.EventTypes.keys()[action])

	completed_timer.start(2)

func _dissolve_general_label(is_no: bool):
	var tween = _GameController._dissolve_out(
		current_event.GeneralLabel,
		0.5,
		null,
		false
	)

	tween.finished.connect(func():
		current_event.GeneralLabel.text = (
			current_event.NoResponse
			if is_no
			else current_event.ConditionResponse if is_condition_satisfied()
			else current_event.YesResponse
		)

		_GameController._dissolve_in(
			current_event.GeneralLabel,
			0.5,
			_GameController._action_original_materials
		)
	)

func is_condition_satisfied() -> bool:
	_GameController.completed_events.append(current_event.id)
	for action in current_event.types:
		var action_name = current_event.EventTypes.keys()[action]
		match action_name:
			"REPLACE_ITEM":
				if current_event.items_data.size() == 0 or _ItemsManager.get_current_items().has(current_event.items_data[0]): return true
	
	return false

func _on_item_added():
	pass

func _on_item_removed():
	if event_status == EventStatus.REPLACING_ITEM and current_event.items_data.size() >= 2:
		_ItemsManager.add_item(current_event.items_data[1])

func load_events() -> void:
	var dir := DirAccess.open(events_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tscn"):
			var scene := load(events_path.path_join(file_name)) as PackedScene
			if scene and _is_event_valid(scene):
				var entry := EventEntry.new()
				entry.scene = scene
				var instance: EventData = scene.instantiate()
				entry.data = instance
				events.append(entry)

		file_name = dir.get_next()

	dir.list_dir_end()

func _is_event_valid(scene: PackedScene) -> bool:
	var instance := scene.instantiate()
	if instance == null:
		return false

	var valid := true

	if instance.min_layer > _GameController.layer:
		valid = false

	if not valid:
		instance.queue_free()

	return valid

func pick_weighted_event() -> EventEntry:
	var rng := RandomNumberGenerator.new()
	rng.seed = _GameController.current_hash

	if rng.randi() % 2 == 0:
		selected_vanilla_event = vanilla_events[rng.randi() % vanilla_events.size()]
		NfcUsage.disconnect("nfc_detected", Callable(self, "_on_nfc_detected"))
		return null

	if events.is_empty():
		return null

	var total_weight := 0

	for e in events:
		if e.data.unique and _GameController.completed_events.has(e.data.id):
			continue

		total_weight += e.data.weight

	var roll := rng.randi_range(1, total_weight)

	for e in events:
		if e.data.unique and _GameController.completed_events.has(e.data.id):
			continue

		roll -= e.data.weight

		if roll <= 0:
			return e

	return events[events.size() - 1]


func start_card_upgrade():
	if NfcUsage.nfc_plugin:
		NfcUsage.start_reading()
	
	waiting_card = true
	
	$ColorRect.show()
	_GameController._dissolve_in(WaitingCardLabel, 2, _GameController._action_original_materials)
	_GameController._dissolve_in($ColorRect/HBoxContainer2/Upgrade, 2, _GameController._action_original_materials)

func REPLACE_ITEM():
	if not is_condition_satisfied(): return
	_ItemsManager.remove_item(current_event.items_data[0])
	event_status = EventStatus.REPLACING_ITEM

func GIVE_ITEM():
	print(current_event.items_data.size())
	if current_event.items_data.size() == 0: return
	_ItemsManager.add_item(current_event.items_data[0])

func REMOVE_ITEM():
	if current_event.items_data.size() == 0: return
	_ItemsManager.remove_item(_ItemsManager.get_current_items().find(current_event.items_data[0]))

func GIVE_EFFECT():
	if current_event.effect_types.size() == 0: return
	for i in current_event.effect_types.size():
		match current_event.effect_types[i]:
			current_event.EffectTypes.HP:
				_GameController.add_hp(current_event.effect_values[i], "+")
			current_event.EffectTypes.MONEY:
				Gamemanager.add_coins(current_event.effect_values[i])
				_GameController._update_coins()
			current_event.EffectTypes.UPGRADE:
				start_card_upgrade()


func _on_completed_timer_timeout() -> void:
	hide_on_paper()
