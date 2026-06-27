extends Control
class_name Enemy

enum Action {
	ATTACK,
	BUFF,
	DEFEND,
	SECRET,
	PROHIBITED,
	POISONED
}
enum BuffType { ATTACK, DEFEND, NONE }
enum DieCondition {
	NONE,
	NO_OTHER_TYPES,
	LAST_OF_TYPE,
	NO_OTHER_ENEMIES,
	NO_OTHER_NON_TYPE_ENEMIES
}

@export var behavior: EnemyBehavior

var _GameController: GameController
var _BattleController: BattleController

signal OnDie
signal OnFocus
signal EnemyActionsEnded

@export_group("Logic")
@export var is_boss: bool = false
@export var die_condition := DieCondition.NONE
@export var can_spawn_single := true
@export var min_layer: int = 1
@export var weight_spawn: float = 100.0

@export_group("Enemy Stats")
@export var max_hp: float = 100.0
@export var current_hp: float = 100.0
@export var damage: float = 10.0
@export var damage_reduction: float = 25.0
@export var thorns_damage: float = 0.0
@export var buff: BuffType = BuffType.NONE
@export var buff_multiplier: float = 1.5

@export_group("SFX")
@export var SpawnSFX: Array[AudioStreamPlayer2D]
@export var DieSFX: Array[AudioStreamPlayer2D]

var is_defending := false
var poisoned_damage := 0
var focusable := true
var actives_tweens := {}

@onready var Actions: HBoxContainer = $Actions
@onready var HealthBar: ProgressBar = $ProgressBar
@onready var FocusTexture: TextureRect = $TextureRect
@onready var _SubViewport: SubViewport = $SubViewport

var actions_to_do: Array[Action] = []
var particles_pool: Array[GPUParticles2D] = []

const DISSOLVE_DURATION := 0.75

func _ready() -> void:
	_BattleController = get_parent().get_parent()
	_BattleController.PlayerActionsEnded.connect(execute_actions)
	_GameController = get_tree().current_scene
	HealthBar.max_value = max_hp
	HealthBar.value = current_hp

	for i in Actions.get_child_count():
		var node := Actions.get_child(i)
		_GameController.cache_original_material(node)
		node.show()

	actions_to_do = decide_actions()

func die() -> Tween:
	
	if DieSFX.size() > 0:
		DieSFX.pick_random().play()
	
	focusable = false

	var tween := _GameController._dissolve_out(
		self,
		DISSOLVE_DURATION,
		null,
		false
	)
	
	for child in Actions.get_children():
		_GameController._dissolve_out(child, DISSOLVE_DURATION, null, false)

	OnDie.emit(self)

	return tween

func should_die_from_condition(enemies) -> bool:
	var self_type := get_enemy_type(self)
	
	if self_type == "Ghost" and _GameController.remove_ghosts > 0:
		return true

	match die_condition:
		DieCondition.NONE:
			return false

		DieCondition.LAST_OF_TYPE:
			for enemy in enemies:
				if enemy == self:
					continue
				if enemy.focusable and get_enemy_type(enemy) == self_type:
					return false
			return true

		DieCondition.NO_OTHER_ENEMIES:
			for enemy in enemies:
				if enemy != self and enemy.focusable:
					return false
			return true

		DieCondition.NO_OTHER_NON_TYPE_ENEMIES:
			for enemy in enemies:
				if enemy == self:
					continue
				if not enemy.focusable:
					continue
				if get_enemy_type(enemy) != self_type:
					return false
			return true

		DieCondition.NO_OTHER_TYPES:
			for enemy in enemies:
				if enemy == self:
					continue
				if not enemy.focusable:
					continue
				if get_enemy_type(enemy) != self_type:
					return false
			return true

	return false

func get_enemy_type(enemy: Enemy) -> String:
	var regex := RegEx.new()
	regex.compile("[^A-Za-z]")
	return regex.sub(enemy.name, "", true)

func decide_actions() -> Array[Action]:
	is_defending = false

	var phase := _get_active_phase()
	if phase == null:
		actions_to_do = [Action.ATTACK]
		_highlight_action([Action.ATTACK])
		return actions_to_do

	var weights: Array = [
		phase.weight_attack,
		phase.weight_buff,
		phase.weight_defend,
		phase.weight_secret,
		phase.weight_prohibited
	]

	var chosen_indices: Array[int] = _weighted_random(weights, phase.force_actions)
	if poisoned_damage != 0 and current_hp > 0:
		chosen_indices.append(Action.POISONED)

	actions_to_do.clear()

	for idx in chosen_indices:
		var action := idx as Action

		match action:
			Action.BUFF:
				_apply_buff()

			Action.DEFEND:
				_apply_defend()

			Action.ATTACK, Action.SECRET, Action.PROHIBITED, Action.POISONED:
				actions_to_do.append(action)

	_highlight_action(chosen_indices)

	return actions_to_do

func _apply_buff() -> void:
	match buff:
		BuffType.NONE:
			buff = BuffType.ATTACK
		BuffType.ATTACK:
			buff = BuffType.DEFEND
		BuffType.DEFEND:
			buff = BuffType.NONE

func _apply_defend() -> void:
	is_defending = true

func _get_active_phase() -> BehaviorPhase:
	if behavior == null or behavior.phases.is_empty():
		return null

	var hp_ratio := current_hp / max_hp

	for phase in behavior.phases:
		match phase.condition_type:
			BehaviorPhase.ConditionType.TURN_EXACT:
				if _BattleController.battle_turn == int(phase.condition_value):
					return phase
			BehaviorPhase.ConditionType.HP_ABOVE:
				if hp_ratio > phase.condition_value:
					return phase
			BehaviorPhase.ConditionType.HP_BELOW:
				if hp_ratio < phase.condition_value:
					return phase
			BehaviorPhase.ConditionType.TURN_ABOVE:
				if _BattleController.battle_turn > int(phase.condition_value):
					return phase
			BehaviorPhase.ConditionType.TURN_UNDER:
				if _BattleController.battle_turn < int(phase.condition_value):
					return phase
			BehaviorPhase.ConditionType.HAS_BUFF:
				if buff != BuffType.NONE:
					return phase
			BehaviorPhase.ConditionType.NO_BUFF:
				if buff == BuffType.NONE:
					return phase
			BehaviorPhase.ConditionType.ALWAYS:
				return phase
	return null

func _weighted_random(weights: Array, force_actions: bool) -> Array[int]:
	var selected: Array[int] = []

	var available_indices: Array[int] = []
	for i in range(weights.size()):
		available_indices.append(i)

	var available_weights: Array = weights.duplicate()

	var i := available_weights.size() - 1
	while i >= 0:
		if force_actions and weights[i] > 0:
			selected.append(i)
		if available_weights[i] <= 0:
			available_weights.remove_at(i)
			available_indices.remove_at(i)
		i -= 1
	
	if force_actions:
		return selected

	if available_indices.is_empty():
		return [Action.ATTACK]

	var count := mini(randi_range(1, 3), available_indices.size())

	for _n in count:
		var total := 0.0
		for w in available_weights:
			total += w

		var roll := randf() * total
		var cumulative := 0.0

		for j in range(available_weights.size()):
			cumulative += available_weights[j]
			if roll <= cumulative:
				selected.append(available_indices[j])
				available_indices.remove_at(j)
				available_weights.remove_at(j)
				break

	return selected

func _highlight_action(action_indices: Array[int]) -> void:
	for i in range(Actions.get_child_count()):
		var node := Actions.get_child(i)
		var should_show := action_indices.has(i)

		if should_show:
			node.show()
			print(node.name)
			_GameController._dissolve_in(node, DISSOLVE_DURATION, _GameController._action_original_materials)
		else:
			var tween := _GameController._dissolve_out(node, DISSOLVE_DURATION, node, true)
			if tween:
				tween.finished.connect(func():
					node.hide()
				)
			else:
				node.hide()

func _highlight_active_action(action: Action) -> void:
	for i in range(Actions.get_child_count()):
		var child := Actions.get_child(i)
		var is_active := i == int(action)

		if actives_tweens.has(child):
			actives_tweens[child].kill()
			actives_tweens.erase(child)

		if is_active:
			child.scale = Vector2.ONE

			var scale_tween := create_tween()
			actives_tweens[child] = scale_tween

			scale_tween.tween_property(
				child, "scale", Vector2(1.25, 1.25), 0.18
			).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

			scale_tween.tween_property(
				child, "scale", Vector2(0.92, 0.92), 0.12
			).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

			scale_tween.tween_property(
				child, "scale", Vector2.ONE, 0.18
			).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

			scale_tween.finished.connect(func(): actives_tweens.erase(child))

		else:
			var tween := create_tween()
			actives_tweens[child] = tween

			tween.tween_property(child, "scale", Vector2.ONE, 0.15)
			tween.finished.connect(func(): actives_tweens.erase(child))

func execute_single_action(action: Action) -> void:
	if action == Action.PROHIBITED: return
	
	_highlight_active_action(action)

	await get_tree().create_timer(0.2).timeout

	var icon := Actions.get_child(int(action))

	var tween = _GameController._dissolve_out(
		icon,
		0.25,
		icon
	)

	if tween:
		await tween.finished
	match action:
		Action.ATTACK:
			var actual_damage := damage

			if buff == BuffType.ATTACK:
				actual_damage *= buff_multiplier

			_GameController._apply_player_damage(actual_damage)

		Action.SECRET:
			await _execute_secret_action()
		
		Action.POISONED:
			receive_damage(poisoned_damage, true)

		Action.PROHIBITED:
			pass

func execute_actions() -> void:
	await get_tree().create_timer(0.5).timeout

	for action in actions_to_do:
		match action:
			Action.ATTACK:
				var actual_damage := damage

				if buff == BuffType.ATTACK:
					actual_damage *= buff_multiplier

				_GameController._apply_player_damage(actual_damage)
				
				if _GameController.thorns != 0:
					receive_damage(actual_damage * _GameController.thorns / 100)

			Action.SECRET:
				await _execute_secret_action()

	actions_to_do = decide_actions()

	EnemyActionsEnded.emit()

func _execute_secret_action() -> void:
	if randi() % 2 == 0:
		var actual_damage := damage * 2.0
		if buff == BuffType.ATTACK:
			actual_damage *= buff_multiplier
		_GameController._apply_player_damage(actual_damage)
	else:
		var heal_amount := max_hp * 0.15
		current_hp = minf(current_hp + heal_amount, max_hp)
		buff = BuffType.DEFEND
		_GameController._update_hp_bar(current_hp, max_hp, HealthBar)

func finish_turn() -> void:
	await dissolve_current_actions()
	actions_to_do = decide_actions()

func dissolve_current_actions() -> void:
	var tweens: Array[Tween] = []

	for icon in Actions.get_children():
		if not icon.visible:
			continue

		var tween = _GameController._dissolve_out(
			icon,
			0.25,
			icon
		)

		if tween:
			tweens.append(tween)

	for tween in tweens:
		await tween.finished

func receive_damage(amount: float, is_poison = false) -> void:
	if actions_to_do.has(Action.PROHIBITED): return
	
	var actual := amount
	if is_defending:
		actual *= (1.0 - damage_reduction / 100.0)
	if buff == BuffType.DEFEND:
		actual *= (1.0 - (damage_reduction * buff_multiplier) / 100.0)
		
	_SubViewport.get_child(0).text = str(int(actual))

	current_hp -= actual
	current_hp = maxf(current_hp, 0.0)
	
	if thorns_damage != 0:
		_GameController._apply_player_damage(amount * thorns_damage / 100)
	
	_GameController._update_hp_bar(current_hp, max_hp, HealthBar)
	
	if _GameController.poison > 0 and poisoned_damage == 0:
		poisoned_damage += _GameController.poison
		_SubViewport.get_child(0).text = str(int(poisoned_damage))
	
	_damage_feedback(Color.RED if not is_poison else Color.SEA_GREEN, self.self_modulate)

	if current_hp <= 0.0:
		die()

func _damage_feedback(color_feedback = Color.RED, color_original = Color.BLACK):
	var damage_texture = _SubViewport.get_texture()
	var emitter_found = false
	
	if particles_pool.is_empty():
		particles_pool.append($GPUParticles2D)
	
	for particle: GPUParticles2D in particles_pool:
		if emitter_found: break
		if not particle.emitting:
			particle.texture = damage_texture
			particle.restart()
			emitter_found = true
	
	if not emitter_found:
		var new_particle = particles_pool[0].duplicate()
		add_child(new_particle)
		new_particle.texture = damage_texture
		new_particle.restart()
		particles_pool.append(new_particle)
	
	var tween := create_tween()

	tween.tween_property(
		self,
		"self_modulate",
		color_feedback,
		0.08
	)

	tween.tween_property(
		self,
		"self_modulate",
		color_original,
		0.12
	)

func _on_area_2d_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:
		OnFocus.emit(self)
