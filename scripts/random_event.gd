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

var waiting_replace_target = null

var rng: RandomNumberGenerator

@export var event_scenes: Array[PackedScene]

func _ready() -> void:
	
	rng = RandomNumberGenerator.new()
	
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
		
		if current_event.bg_music != null:
			bg_music = current_event.bg_music
		else:
			bg_music = null
		
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
		if selected_vanilla_event == "" and current_event != null:
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
	
	if current_event.has_method("custom_event_choose"):
		current_event.custom_event_choose(option, self)
	
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
		if current_event.ignore_sprite_dissolve:
			if target_texture is Button:
				target_texture.icon = sprite
			else:
				target_texture.texture = sprite
		else:
			var sprite_tween = _GameController._dissolve_out(target_texture, 0.5, null, false)

			sprite_tween.finished.connect(func():
				if target_texture is Button:
					target_texture.icon = sprite
				else:
					target_texture.texture = sprite

				_GameController._dissolve_in(
					target_texture,
					0.5,
					_GameController._action_original_materials
				)
			)

	if not is_no:
		for action in current_event.types:
			call_deferred(current_event.EventTypes.keys()[action])

	completed_timer.start(2)

var general_label_shown := false

func _dissolve_general_label(is_no: bool):
	var satisfied := is_condition_satisfied()

	var new_text := current_event.YesResponse

	if is_no:
		new_text = current_event.NoResponse
	elif satisfied and current_event.ConditionResponse != "":
		new_text = current_event.ConditionResponse
	elif not satisfied and current_event.FalseConditionResponse != "":
		new_text = current_event.FalseConditionResponse

	if not general_label_shown:
		general_label_shown = true

		current_event.GeneralLabel.text = new_text

		_GameController._dissolve_in(
			current_event.GeneralLabel,
			1,
			_GameController._action_original_materials
		)

		return

	var tween = _GameController._dissolve_out(
		current_event.GeneralLabel,
		0.5,
		null,
		false
	)

	if tween == null:
		current_event.GeneralLabel.text = new_text

		_GameController._dissolve_in(
			current_event.GeneralLabel,
			0.5,
			_GameController._action_original_materials
		)
		return

	tween.finished.connect(func():
		current_event.GeneralLabel.text = new_text

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
			"GIVE_ITEM":
				if current_event.force_condition_satisfied: return true
			"REPLACE_ITEM":
				if current_event.items_data.size() == 0 or _ItemsManager.get_current_items().has(current_event.items_data[0]): return true
			"GIVE_EFFECT":
				var total_cost := 0

				for i in current_event.effect_types.size():
					if current_event.effect_types[i] == current_event.EffectTypes.MONEY and current_event.effect_values[i] < 0:
						total_cost += current_event.effect_values[i]

				return Gamemanager.coins >= -total_cost
	
	return false

func _on_item_added():
	pass

func _on_item_removed():
	if event_status == EventStatus.REPLACING_ITEM and waiting_replace_target != null:
		_ItemsManager.add_item(waiting_replace_target)
		waiting_replace_target = null
		event_status = EventStatus.NONE

func load_events() -> void:
	events.clear()

	for scene in event_scenes:
		if scene == null:
			continue

		if not _is_event_valid(scene):
			continue

		var entry := EventEntry.new()
		entry.scene = scene

		var instance := scene.instantiate() as EventData
		if instance == null:
			continue

		entry.data = instance
		events.append(entry)

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
	if not is_condition_satisfied():
		return

	for i in range(0, current_event.items_data.size() - 1, 2):
		var original = current_event.items_data[i]
		var target = current_event.items_data[i + 1]

		if _ItemsManager.get_current_items().has(original):
			waiting_replace_target = target
			event_status = EventStatus.REPLACING_ITEM
			_ItemsManager.remove_item(_ItemsManager.all_items[_ItemsManager.get_current_items().find(original)])
			return

func GIVE_ITEM():
	if current_event.items_data.size() == 0: return
	_ItemsManager.add_item(current_event.items_data[0])
	Gamemanager.unlock_item(current_event.items_data[0].id)

func REMOVE_ITEM():
	if current_event.items_data.size() == 0: return
	_ItemsManager.remove_item(_ItemsManager.all_items[_ItemsManager.get_current_items().find(current_event.items_data)])

func GIVE_EFFECT():
	if current_event.effect_types.size() == 0: return
	for i in current_event.effect_types.size():
		match current_event.effect_types[i]:
			current_event.EffectTypes.HP:
				_GameController.add_hp(current_event.effect_values[i], "+")
			current_event.EffectTypes.MONEY:
				if not is_condition_satisfied(): return
				Gamemanager.add_coins(current_event.effect_values[i])
				_GameController._update_coins()
			current_event.EffectTypes.UPGRADE:
				start_card_upgrade()


func _on_completed_timer_timeout() -> void:
	if current_event.EnemyToFightAfterEvent != null:
		var battle_node: BattleController = NodesContainer.get_parent().get_child(1).get_child(2)
		battle_node.force_enemy = current_event.EnemyToFightAfterEvent
		battle_node.force_enemy_ammount = current_event.EnemiesAmmount
		battle_node.force_item_after_fight = current_event.items_data
		battle_node.show_on_paper()
		
		battle_node.showing_mid_animation.connect(func():
			hide_on_paper(true)
			current_event.queue_free()
			)
		
		battle_node.shown_on_paper.connect(func():
			battle_node.showing_mid_animation.disconnect(func(): 
				hide_on_paper(true)
				current_event.queue_free()
			)
		)
		
		return

	hide_on_paper()
