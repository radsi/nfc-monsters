extends Node
class_name GameController

@onready var FadeColorRect: ColorRect = $ColorRect2
@onready var DamageEffect: TextureRect = $DamageEffect
@onready var PaperBG: TextureRect = $Map/OldPaperPiece
@onready var MapNodes = $Map/OldPaperPiece/Container/Nodes
@onready var GameMenu = $MarginContainer
@onready var MoneyLabel = $MarginContainer/VBoxContainer/MarginContainer/money
@onready var HealthBar: ProgressBar = $MarginContainer2/PlayerHealthBar
@onready var GameOverMenu: MapMenu = $Map/OldPaperPiece/Menus/GameOver

var last_map_pos
var doin_animation = false

@onready var paper_sfx: AudioStreamPlayer2D = $paper
@onready var whoosh_sfx: AudioStreamPlayer2D = $whoosh

var _action_original_materials := {}
var _active_tweens := {}

@onready var DissolveShader = preload("res://scripts/shaders/dissolve black.tres")
@onready var Grunts := []
@onready var GruntSFX = $grunt

var layer = 1

var completed_events = []

var current_hash

var damage = 100
var fist_damage = 100
var armor = 0
var thorns = 0
var remove_ghosts = 0
var poison = 0

var player_health = 100
var max_player_health = 100
var max_cards_use = 3
var pending_buff = 0
var luck = 0
var money_multiplier = 1
var shop_price = 100

var operators = {
	"+": func(a, b): return a + b,
	"-": func(a, b): return a - b,
	"*": func(a, b): return a * b,
	"/": func(a, b): return a / b,
	"%": func(a, b): return a + (a * b / 100.0),
	0: func(a, b): return a + b,
	1: func(a, b): return a - b,
	2: func(a, b): return a * b,
	3: func(a, b): return a / b,
	4: func(a, b): return a + (a * b / 100.0)
}

func _ready() -> void:
	if NfcUsage.nfc_plugin:
		NfcUsage.start_reading()
	
	var hp_data = Gamemanager.get_player_health()
	player_health = hp_data[0]
	max_player_health = hp_data[1]
	
	MoneyLabel.text = str(Gamemanager.coins)
	PaperBG.position.y = -2500
	GameMenu.position.y = 900
	HealthBar.get_parent().position.y = -300
	FadeColorRect.show()
	HealthBar.value = player_health
	HealthBar.max_value = max_player_health
	
	doin_animation = true
	
	var player_items = Gamemanager.get_player_items()
	
	var dir := DirAccess.open("res://sounds/grunts")

	if dir:
		for file in dir.get_files():
			if file.get_extension() in ["ogg", "wav", "mp3"]:
				Grunts.append(load("res://sounds/grunts/%s" % file))
	
	var tween = create_tween()
	
	tween.tween_property(FadeColorRect, "color", Color(0,0,0,0), 2).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
	
	tween.tween_callback(func():
		paper_sfx.play()
	)
	
	tween.tween_property(PaperBG, "position", Vector2(PaperBG.position.x, -1592), 1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func():
		get_tree().create_timer(0.5).timeout.connect(func():
			whoosh_sfx.play()
		)
	)
	tween.tween_property(HealthBar.get_parent(), "position", Vector2(HealthBar.get_parent().position.x, 0), 1).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func():
		get_tree().create_timer(0.5).timeout.connect(func():
			whoosh_sfx.play()
		)
	)
	tween.tween_property(GameMenu, "position", Vector2(GameMenu.position.x, 0), 1 if player_items.size() > 0 else 0.6).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	
	tween.finished.connect(
		func() -> void: 
			FadeColorRect.hide();
			doin_animation = false
	)

func _update_coins():
	create_tween().tween_method(
		func(v): MoneyLabel.text = str(int(v)),
		int(MoneyLabel.text),
		Gamemanager.coins,
		0.5
	)

var hp_tween: Tween
var damage_tween: Tween

func _update_hp_bar(value, max_value, healthBar: ProgressBar):
	healthBar.max_value = max_value

	if hp_tween:
		hp_tween.kill()
	if damage_tween:
		damage_tween.kill()

	var start_hp = healthBar.value
	
	if value < start_hp and healthBar == HealthBar:
		damage_tween = create_tween()
		DamageEffect.self_modulate.a = 1

		damage_tween.tween_property(
			DamageEffect,
			"self_modulate:a",
			0.0,
			1.0
		)

	hp_tween = create_tween()

	hp_tween.tween_method(
		func(_value: float):
			healthBar.value = _value
			healthBar.get_child(0).text = str(roundi(value)) + "/" + str(roundi(max_value)),
		start_hp,
		value,
		0.5
	)
	
	await hp_tween.finished
	
	if value <= 0 and healthBar == HealthBar:
		get_tree().paused = true
		GruntSFX.stream = Grunts.pick_random()
		GruntSFX.play()
		await get_tree().create_timer(1).timeout
		GameOverMenu.show_on_paper()

func add_hp(hp, operator):
	var new_value = operators[operator].call(player_health, hp)
	player_health = clamp(new_value, 0, max_player_health)
	_update_hp_bar(player_health, max_player_health, HealthBar)

func _apply_player_damage(amount: float) -> void:
	var actual = amount * (1.0 - armor / 100.0)
	add_hp(actual, "-")

func apply_item_effect(item: ItemData, is_removing = false):
	for n in item.variables.size():
		var _variable = get(item.variables[n])
		var result = operators[item.operators[n]].call(_variable, item.ammounts[n] if not is_removing else -item.ammounts[n])
		set(item.variables[n], result)
		if item.variables[n] == "max_player_health": player_health = clamp(max_player_health - player_health, 0, max_player_health)
		_update_hp_bar(player_health, max_player_health, HealthBar)

func _dissolve_in(node: CanvasItem, duration: float, _action_original_materials: Dictionary, dissolveShader = DissolveShader, node_to_show: Node = null) -> void:
	if _active_tweens.has(node):
		_active_tweens[node].kill()

	if !_action_original_materials.has(node):
		var original_material = node.material
		_action_original_materials[node] = original_material.duplicate() if original_material else null

	var dissolve_mat: ShaderMaterial = dissolveShader.duplicate()
	dissolve_mat.set_shader_parameter("dissolve_value", 0.0)

	node.material = dissolve_mat
	node.visible = true
	node.show()

	if node_to_show:
		node_to_show.show()

	var tween := create_tween()
	_active_tweens[node] = tween

	tween.tween_method(
		func(v: float):
			dissolve_mat.set_shader_parameter("dissolve_value", v),
		0.0,
		1.0,
		duration
	)

	tween.finished.connect(func():
		if _action_original_materials.has(node):
			node.material = _action_original_materials[node]
		_active_tweens.erase(node)
	)
	
func _dissolve_out(node: CanvasItem, duration: float, node_to_hide: Node = null, set_original_material = true, dissolveShader = DissolveShader) -> Tween:
	if not node.visible:
		return null

	if _active_tweens.has(node):
		_active_tweens[node].kill()

	if !_action_original_materials.has(node):
		var original_material = node.material
		_action_original_materials[node] = original_material.duplicate() if original_material else null

	var dissolve_mat: ShaderMaterial = dissolveShader.duplicate()
	dissolve_mat.set_shader_parameter("dissolve_value", 1.0)

	node.material = dissolve_mat

	var tween := create_tween()
	_active_tweens[node] = tween

	tween.tween_method(
		func(v: float):
			dissolve_mat.set_shader_parameter("dissolve_value", v),
		1.0,
		0.0,
		duration
	)

	tween.finished.connect(func():
		if node_to_hide:
			node_to_hide.hide()

		if set_original_material and _action_original_materials.has(node):
			node.material = _action_original_materials[node]

		_active_tweens.erase(node)
	)

	return tween

func cache_original_material(node: CanvasItem):
	_action_original_materials[node] = node.material.duplicate() if node.material else null
