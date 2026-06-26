extends MapMenu

@onready var RandomMessageLabel: Label = $MarginContainer/VBoxContainer/Label/Label

const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"
const RandomMessages := ["Try harder next time...", "Come on...", "Try upgrading your cards", "Too bad", "Ouch"]

var doing_fade := false

func _ready() -> void:
	super._ready()
	showing_mid_animation.connect(_on_showing_mid_animation)

func _on_showing_mid_animation() -> void:
	RandomMessageLabel.text = RandomMessages.pick_random()
	Gamemanager.clear_game_state()

	for menu: MapMenu in get_parent().get_children():
		if menu != self:
			menu.hide()

func _on_area_2d_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if doing_fade:
		return

	if not ((event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed):
		return

	doing_fade = true
	Gamemanager.coming_back_from_game = true

	_GameController.FadeColorRect.show()

	var tween := create_tween()

	tween.tween_property(
		_GameController.FadeColorRect,
		"color",
		Color(0,0,0,1),
		2.0
	).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)

	await tween.finished

	Gamemanager.change_scene(MAIN_MENU_SCENE)
