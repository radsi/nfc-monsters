extends Control
class_name MapMenu

signal shown_on_paper
signal hidden_from_paper
signal show_animation_started
signal hide_animation_started
signal animation_finished
signal showing_mid_animation
signal hidding_mid_animation

const ANIM_DURATION := 1.0
const ANIM_DELAY := 0.25
const PAPER_HIDDEN_Y := -2500.0
const PAPER_VISIBLE_Y := -1592.0

@export var _GameController: GameController

@export var NodesContainer: Control
@export var SFX: Array[AudioStreamPlayer2D]
@export var PaperBG: TextureRect
@export var GameBG: ColorRect

var layer_colors := ["#a24654", "#ffffff"]

func _ready() -> void:
	var backbutton = find_child("backbutton")

	if backbutton:
		backbutton.input_event.connect(
			func(_viewport, event, _shape_idx):
				if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:
					hide_on_paper()
		)

	hide()

func _play_sfx(id: int) -> void:
	if id >= 0 and id < SFX.size():
		SFX[id].play()

func _stop_sfx(id: int) -> void:
	if id >= 0 and id < SFX.size():
		SFX[id].stop()

func show_on_paper(skip_anim := false) -> void:
	if _GameController.doin_animation and skip_anim == false:
		return

	show_animation_started.emit()

	if skip_anim == true:
		NodesContainer.hide()
		show()

		showing_mid_animation.emit()
		shown_on_paper.emit()
		animation_finished.emit()
		print(global_position)
		return

	_GameController.doin_animation = true

	var tween := create_tween()

	tween.tween_callback(func():
		_play_sfx(0)
	)

	tween.tween_property(
		PaperBG,
		"global_position:y",
		PAPER_HIDDEN_Y,
		ANIM_DURATION
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	tween.tween_callback(func():
		NodesContainer.hide()
		show()
		showing_mid_animation.emit()
	)

	tween.tween_interval(ANIM_DELAY)

	tween.tween_callback(func():
		_play_sfx(0)
	)

	tween.tween_property(
		PaperBG,
		"global_position:y",
		PAPER_VISIBLE_Y,
		ANIM_DURATION
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	tween.tween_callback(func():
		_GameController.doin_animation = false
		shown_on_paper.emit()
		animation_finished.emit()
	)

func hide_on_paper(skip_anim = false) -> void:
	if _GameController.doin_animation:
		return

	hide_animation_started.emit()
	
	if skip_anim == true:
		hide()

		hidding_mid_animation.emit()
		hidden_from_paper.emit()
		animation_finished.emit()
		return
		
	Gamemanager.save_map_state(NodesContainer.current_pos, NodesContainer.visited_nodes, NodesContainer.config.seed, _GameController.layer)

	_GameController.doin_animation = true

	var tween := create_tween()

	tween.tween_callback(func():
		_play_sfx(0)
	)

	tween.tween_property(
		PaperBG,
		"global_position:y",
		PAPER_HIDDEN_Y,
		ANIM_DURATION
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	tween.tween_callback(func():
		hidding_mid_animation.emit()
		NodesContainer.show()
		hide()
	)

	tween.tween_interval(ANIM_DELAY)

	tween.tween_callback(func():
		_play_sfx(0)
	)

	tween.tween_property(
		PaperBG,
		"global_position:y",
		_GameController.last_map_pos.y,
		ANIM_DURATION
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	tween.tween_callback(func():
		_GameController.doin_animation = false
		hidden_from_paper.emit()
		animation_finished.emit()
	)

func change_layer_after_boss(layer_index: int) -> void:
	if _GameController.doin_animation:
		return

	hide_on_paper()

	var new_color: Color = Color(layer_colors[layer_index-1])

	var mat := GameBG.material as ShaderMaterial
	if mat == null:
		_GameController.doin_animation = false
		return

	var start_color_1: Color = mat.get_shader_parameter("colour_1")
	var start_color_2: Color = mat.get_shader_parameter("colour_2")
	
	NodesContainer.reset_map_for_new_floor()

	var tween := create_tween()

	tween.tween_method(
		func(t: float):
			mat.set_shader_parameter("colour_1", start_color_1.lerp(start_color_2, t))
			mat.set_shader_parameter("colour_2", start_color_2.lerp(new_color, t)),
		0.0,
		1.0,
		1.2
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	await tween.finished

	show_on_paper()

	_GameController.doin_animation = false
