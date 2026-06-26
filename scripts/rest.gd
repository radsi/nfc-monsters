extends MapMenu

@onready var ButtonsContainer: HBoxContainer = $VBoxContainer/HBoxContainer
@onready var WaitingCardLabel: Label = $VBoxContainer/HBoxContainer2/Upgrade/Label
@onready var completed_timer: Timer = $CompletedTimer
@onready var card_view: Button = $VBoxContainer/HBoxContainer2/Upgrade/CardView

var waiting_card := false
var ignore_clicks := false

var waiting_dots := [
	"Waiting card   ",
	"Waiting card.  ",
	"Waiting card.. ",
	"Waiting card..."
]

var waiting_index := 0
var waiting_timer := 0.0

func _ready() -> void:
	super._ready()
	
	shown_on_paper.connect(func():
		_play_sfx(1)
		NfcUsage.connect("nfc_detected", Callable(self, "_on_nfc_detected"))
		)
	
	hidden_from_paper.connect(func():
		NfcUsage.disconnect("nfc_detected", Callable(self, "_on_nfc_detected"))
		_stop_sfx(1)
		waiting_card = false
		ignore_clicks = false
		waiting_index = 0
		waiting_timer = 0.0

		$VBoxContainer/HBoxContainer2.hide()

		for button in ButtonsContainer.get_children():
			button.show()

			if button.material:
				button.material.set_shader_parameter("dissolve_value", 1.0)

		card_view.hide()
	)
	
	for child in ButtonsContainer.get_children():
		var area = child.get_child(1)
		
		if area:
			area.input_event.connect(func(viewport, event, shape_idx):
				_on_input(area, event, shape_idx)
			)

func _process(delta: float) -> void:
	if not waiting_card:
		return

	waiting_timer += delta
	if waiting_timer < 0.4:
		return

	waiting_timer = 0.0
	WaitingCardLabel.text = waiting_dots[waiting_index]
	waiting_index = (waiting_index + 1) % waiting_dots.size()

func _on_input(area: Area2D, event, shape_idx):
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed and ignore_clicks == false:
		ignore_clicks = true
		var button = area.get_parent()
		Callable(self, button.name).call()
		
		var tween = create_tween()

		tween.tween_method(
			func(value: float): button.material.set_shader_parameter("dissolve_value", value),
			1.0, 0.0, 2.0
		)
		
		if button.name != "Upgrade": return
		
		tween.finished.connect(func():
			ButtonsContainer.hide()
			$VBoxContainer/HBoxContainer2.show()
			
			_GameController._dissolve_in(WaitingCardLabel, 2, _GameController._action_original_materials)
			
			var tween2 = create_tween()
			tween2.tween_method(
				func(value: float): ButtonsContainer.get_child(0).material.set_shader_parameter("dissolve_value", value),
				0.0, 1.0, 2.0
			)
		)

func _on_nfc_detected(tag_id: String) -> void:
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

func _on_completed_timer_timeout() -> void:
	hide_on_paper()

func Sleep():
	var new_hp = clamp((_GameController.max_player_health * 0.25) + _GameController.player_health, 0, _GameController.max_player_health)
	_GameController.add_hp(new_hp, "+")
	
	Gamemanager.unlock_spell("SpellHealth")
	
	_play_sfx(2)
	
	completed_timer.start(1.5)

func Upgrade():
	if not NfcUsage.nfc_plugin:
		return
	
	NfcUsage.start_reading()
	waiting_card = true
