extends MapMenu
class_name BattleController

signal PlayerActionsEnded

@onready var EnemiesContainer: GridContainer = $GridContainer
@onready var CardsContainer: HBoxContainer = $VBoxContainer/HBoxContainer
@onready var ActionsButton: Button = $VBoxContainer/Execute

@onready var DissolveShader_purple = preload("res://scripts/shaders/dissolve purple.tres")

var focused_enemy: Enemy = null
var used_cards = []
var waiting_summon = false
var summoned_card = []
var summon_index = -1
var killed_enemies = 0
var pending_enemy_actions = 0
var battle_turn = 0
var enemy_action_queue = []
var actives_tweens = {}
var is_boss = false

var temp_armor = 0

const DISSOLVE_DURATION = 0.25

const ACTION_DELAY = 0.75
var _executing = false

var combat_rng := RandomNumberGenerator.new()

func _ready() -> void:
	super._ready()
	
	var spellsummon = CardsContainer.find_child("SpellSummon")
	_GameController.cache_original_material(spellsummon.get_child(1))
	
	ActionsButton.text = "Cast spells (%d/%d)" % [
		used_cards.size(),
		_GameController.max_cards_use
	]

	hidden_from_paper.connect(func():
		NfcUsage.disconnect("nfc_detected", Callable(self, "_on_nfc_detected"))
		cleanup_battle()
	)
	
	shown_on_paper.connect(func():
		_GameController._action_original_materials.clear()
		NfcUsage.connect("nfc_detected", Callable(self, "_on_nfc_detected"))
		var enemies = EnemiesContainer.get_children()
		for e: Enemy in enemies:
			if e.should_die_from_condition(enemies):
				e.die()
			elif e.SpawnSFX.size() > 0:
				e.SpawnSFX.pick_random().play()
	)
	
	show_animation_started.connect(func():
		roll_enemies()
		_on_enemy_focus(EnemiesContainer.get_children()[0])
	)

func cleanup_battle() -> void:
	_executing = false
	is_boss = false

	focused_enemy = null

	used_cards.clear()
	summoned_card = []
	waiting_summon = false
	summon_index = -1

	pending_enemy_actions = 0
	enemy_action_queue.clear()

	battle_turn = 0
	killed_enemies = 0

	ActionsButton.disabled = false
	ActionsButton.text = "Cast spells (0/%d)" % _GameController.max_cards_use
	
	if not summoned_card.is_empty(): _GameController.max_cards_use -= 1

	for enemy: Enemy in EnemiesContainer.get_children():
		enemy.queue_free()

	for child in CardsContainer.get_children():
		if not child.name.begins_with("Spell"):
			continue

		child.modulate = Color.WHITE
		child.scale = Vector2.ONE

		var label = child.find_child("Label")
		if label:
			label.hide()
			label.text = ""

		child.hide()

	var summon := CardsContainer.find_child("SpellSummon")
	if summon:
		var base_icon = summon.get_child(0)
		var summoned_icon = summon.get_child(1)

		if summoned_icon:
			summoned_icon.hide()

			if _GameController._action_original_materials.has(summoned_icon):
				summoned_icon.material = _GameController._action_original_materials[summoned_icon]

		if base_icon:
			base_icon.show()

			if _GameController._action_original_materials.has(base_icon):
				base_icon.material = _GameController._action_original_materials[base_icon]

		summon.hide()

func _start_enemy_turn() -> void:
	enemy_action_queue.clear()

	for enemy: Enemy in EnemiesContainer.get_children():
		if not enemy.focusable:
			continue

		for action in enemy.actions_to_do:
			enemy_action_queue.append({
				"enemy": enemy,
				"action": action
			})

	if enemy_action_queue.is_empty():
		_on_enemy_turn_finished()
		return

	_run_enemy_action_queue()

func _run_enemy_action_queue() -> void:
	if enemy_action_queue.is_empty():
		for enemy: Enemy in EnemiesContainer.get_children():
			if enemy.focusable:
				enemy.finish_turn()

		_on_enemy_turn_finished()
		return

	var data = enemy_action_queue.pop_front()

	var enemy: Enemy = data.enemy
	var action: Enemy.Action = data.action

	if not is_instance_valid(enemy) or not enemy.focusable:
		_run_enemy_action_queue()
		return

	await enemy.execute_single_action(action)

	await get_tree().create_timer(ACTION_DELAY).timeout

	_run_enemy_action_queue()

func _on_enemy_action_finished() -> void:
	pending_enemy_actions -= 1

	if pending_enemy_actions <= 0:
		_on_enemy_turn_finished()

func _on_enemy_turn_finished() -> void: 
	_executing = false 
	battle_turn += 1 
	ActionsButton.disabled = false 
	
	for child in CardsContainer.get_children(): 
		if child.name.begins_with("Spell"): 
			var label = child.find_child("Label") 
			if label: 
				label.hide() 
				child.modulate = Color.WHITE 
				child.scale = Vector2.ONE 
				_GameController._dissolve_out(child, DISSOLVE_DURATION, child) 
	
	used_cards.clear() 
	summoned_card = [] 
	waiting_summon = false 
	ActionsButton.text = "Cast spells (0/%d)" % _GameController.max_cards_use
	
	_GameController.armor -= temp_armor
	temp_armor = 0

func roll_enemies() -> void:
	
	combat_rng.seed = _GameController.current_hash
	
	var enemies_prefab: Array[PackedScene] = get_scenes("res://prefabs/enemies")

	var available: Array[PackedScene] = []
	var weights: Array[float] = []

	for scene in enemies_prefab:
		var enemy: Enemy = scene.instantiate()

		if enemy == null:
			continue

		if enemy.min_layer > _GameController.layer:
			enemy.queue_free()
			continue

		if enemy.is_boss:
			if not (is_boss and enemy.min_layer == _GameController.layer):
				enemy.queue_free()
				continue

		available.append(scene)
		weights.append(enemy.weight_spawn)

		enemy.queue_free()

	if available.is_empty():
		return

	var enemy_count := 1
	
	if is_boss == true:
		var count_roll := combat_rng.randf()
		
		if count_roll < 0.45:
			enemy_count = 1
		elif count_roll < 0.80:
			enemy_count = 2
		else:
			enemy_count = 3

	enemy_count = min(enemy_count, available.size())

	EnemiesContainer.columns = clamp(enemy_count, 1, 4)

	for _i in enemy_count:
		var total_weight := 0.0

		for w in weights:
			total_weight += w

		var roll := combat_rng.randf() * total_weight
		var cumulative := 0.0

		for j in available.size():
			cumulative += weights[j]

			if roll <= cumulative:
				var selected_enemy = available[j].instantiate()

				EnemiesContainer.add_child(selected_enemy)
				
				selected_enemy.OnFocus.connect(_on_enemy_focus)
				selected_enemy.OnDie.connect(_on_enemy_die)

				available.remove_at(j)
				weights.remove_at(j)

				break
	
	if EnemiesContainer.get_child_count() == 1:
		var first_enemy: Enemy = EnemiesContainer.get_child(0)

		if not first_enemy.can_spawn_single:
			var first_type := first_enemy.get_enemy_type(first_enemy)

			for i in range(available.size()):
				var candidate: Enemy = available[i].instantiate()

				if candidate.get_enemy_type(candidate) != first_type:
					EnemiesContainer.add_child(candidate)

					candidate.OnFocus.connect(_on_enemy_focus)
					candidate.OnDie.connect(_on_enemy_die)

					EnemiesContainer.columns = 2

					available.remove_at(i)
					weights.remove_at(i)

					break

				candidate.queue_free()


func _on_enemy_die(enemy: Enemy) -> void:
	killed_enemies += 1

	var enemies = EnemiesContainer.get_children()

	for e in enemies:
		if e.focusable and e.should_die_from_condition(enemies):
			e.die()

	if killed_enemies >= EnemiesContainer.get_child_count():
		await get_tree().create_timer(Enemy.DISSOLVE_DURATION).timeout
		
		Gamemanager.add_coins(50 * _GameController.money_multiplier)
		_GameController._update_coins()
		
		if is_boss:
			change_layer_after_boss(_GameController.layer)
			_GameController.layer += 1
		else:
			hide_on_paper()

		return

	for child: Enemy in EnemiesContainer.get_children():
		if child.focusable:
			_on_enemy_focus(child)
			break


func _on_enemy_focus(enemyobj: Enemy) -> void:
	if not enemyobj.focusable: return
	focused_enemy = enemyobj

	for enemy in EnemiesContainer.get_children():
		enemy.FocusTexture.visible = enemy == enemyobj


func _on_nfc_detected(tag_id: String) -> void:
	
	if _executing: return
	
	var data = JSON.parse_string(tag_id)
	if data == null:
		return

	var cardname = data.get("name")
	
	if used_cards.size() >= _GameController.max_cards_use:
		if (cardname != "SpellSummon" or not used_cards.has(data)) and not waiting_summon:
			return
	
	if cardname == "SpellDiscount": return

	if cardname == "SpellSummon":
		if not used_cards.has(data):
			used_cards.append(data)
		if summon_index == -1: summon_index = used_cards.size()

		var spellsummon = CardsContainer.find_child(cardname)

		CardsContainer.move_child(spellsummon, summon_index)

		var tween_out = _GameController._dissolve_out(spellsummon.get_child(1), DISSOLVE_DURATION, spellsummon.get_child(1), DissolveShader_purple)
		var do_show_in = func():
			_GameController._dissolve_in(spellsummon, DISSOLVE_DURATION, _GameController._action_original_materials, _GameController.DissolveShader, spellsummon.get_child(0))

		if tween_out:
			tween_out.finished.connect(do_show_in)
		else:
			do_show_in.call()

		waiting_summon = true
		summoned_card = []
		
		_GameController.max_cards_use += 1

		ActionsButton.text = "Cast spells (%d/%d)" % [
			used_cards.size(),
			_GameController.max_cards_use
		]
		return

	if waiting_summon:
		waiting_summon = false
		summoned_card = data

		var spellsummon = CardsContainer.find_child("SpellSummon")
		var summon_texture = spellsummon.get_child(1)
		
		var source_texture = CardsContainer.find_child(cardname).get_child(0)

		summon_texture.texture = source_texture.texture
		var original_material = null

		if source_texture.material:
			original_material = source_texture.material.duplicate()

		summon_texture.material = original_material

		var tween = _GameController._dissolve_out(spellsummon, DISSOLVE_DURATION, spellsummon.get_child(0), _GameController.DissolveShader)
		if tween:
			tween.finished.connect(func():
				_GameController._dissolve_in(summon_texture, DISSOLVE_DURATION, _GameController._action_original_materials, DissolveShader_purple)
			)
		else:
			_GameController._dissolve_in(summon_texture, DISSOLVE_DURATION, _GameController._action_original_materials, DissolveShader_purple)
		return

	add_card_to_actions(data)


func add_card_to_actions(card) -> void:
	used_cards.append(card)

	var spell = CardsContainer.find_child(card.get("name"))

	fix_summon_position()

	var used_count = used_cards.count(card)

	if used_count == 1:
		CardsContainer.move_child(spell, used_cards.size())
		_GameController._dissolve_in(spell, DISSOLVE_DURATION, _GameController._action_original_materials)
	else:
		var count_text = spell.find_child("Label")
		count_text.show()
		count_text.text = "x" + str(used_count)

	ActionsButton.text = "Cast spells (%d/%d)" % [
		used_cards.size(),
		_GameController.max_cards_use
	]

func _on_execute_pressed() -> void:
	if _executing or killed_enemies >= EnemiesContainer.get_child_count():
		return
	_executing = true
	ActionsButton.disabled = true

	var queue: Array = []
	for card in used_cards:
		if card.get("name") == "SpellSummoned" and summoned_card != []:
			queue.append(summoned_card)
		else:
			queue.append(card)

	_run_action_queue(queue)

func _run_action_queue(queue: Array) -> void:
	if killed_enemies >= EnemiesContainer.get_child_count(): return
		
	if queue.is_empty():
		summon_index = -1
		_executing = false
		_start_enemy_turn()
		return

		used_cards.clear()
		summoned_card = []
		waiting_summon = false

		ActionsButton.text = "Cast spells (0/%d)" % _GameController.max_cards_use
		return

	var card = queue.pop_front()

	var total_count := 0
	for c in queue:
		if c.get("name") == card.get("name"):
			total_count += 1

	total_count += 1

	_highlight_active_card(card.get("name"), total_count)

	_execute_card(card)

	await get_tree().create_timer(ACTION_DELAY).timeout

	_run_action_queue(queue)


func _execute_card(card) -> void:
	var cardname = card.get("name")

	if cardname == "SpellHit":
		var damage = (25 + (10 * card.get("level")))
		damage *= _GameController.fist_damage / 100.0
		damage += _GameController.pending_buff

		focused_enemy.receive_damage(damage)
		_GameController.pending_buff = 0

	elif cardname == "SpellDefend":
		_GameController.armor += 5 + (2 * card.get("level"))
		temp_armor += 5 + (2 * card.get("level"))

	elif cardname == "SpellHealth":
		_GameController.add_hp(25, "%")

	elif cardname == "SpellStruck":
		focused_enemy.receive_damage((50 + (10 * card.get("level"))) + _GameController.pending_buff)
		_GameController.pending_buff = 0

	elif cardname == "SpellGamble":
		var chance = combat_rng.randi() % 101
		chance -= _GameController.luck

		if chance <= 20:
			focused_enemy.receive_damage(_GameController.player_health + _GameController.pending_buff)
			_GameController.pending_buff = 0

		elif chance <= 60:
			_GameController.add_hp(50, "%")

		_GameController.luck = 0

	elif cardname == "SpellBuff":
		_GameController.pending_buff += 10
		_GameController.luck += 10

	elif cardname == "SpellSummon":
		_execute_card(summoned_card)

func _highlight_active_card(cardname: String, total: int) -> void:
	var active_spell = CardsContainer.find_child(cardname)
	var total_label = active_spell.find_child("Label")

	if total == 1:
		total_label.hide()
	else:
		total_label.text = "x" + str(total - 1)

	for child in CardsContainer.get_children():
		var is_active := child.name == cardname

		if actives_tweens.has(child):
			actives_tweens[child].kill()
			actives_tweens.erase(child)

		var tween := create_tween()
		tween.set_parallel(true)
		actives_tweens[child] = tween

		if is_active:
			child.scale = Vector2.ONE

			tween.tween_property(
				child,
				"modulate",
				Color(1, 1, 1, 1.0),
				0.15
			)

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

			if total == 1:
				scale_tween.finished.connect(func():
					actives_tweens.erase(child)
					if not is_instance_valid(child):
						return
					var fade := create_tween()
					actives_tweens[child] = fade
					fade.tween_property(child, "modulate", Color(1, 1, 1, 0.5), 0.15)
					fade.finished.connect(func(): actives_tweens.erase(child))
				)
			else:
				scale_tween.finished.connect(func(): actives_tweens.erase(child))

		else:
			tween.tween_property(child, "modulate", Color(1, 1, 1, 0.5), 0.15)
			tween.tween_property(child, "scale", Vector2.ONE, 0.15)
			tween.finished.connect(func(): actives_tweens.erase(child))

func _card_targets_enemy(cardname: String) -> bool:
	return cardname in ["SpellHit", "SpellStruck", "SpellGamble"]

func get_scenes(path: String) -> Array[PackedScene]:
	var scenes: Array[PackedScene] = []

	var dir = DirAccess.open(path)
	if dir == null:
		return scenes

	dir.list_dir_begin()

	var file_name = dir.get_next()

	while file_name != "":
		if !dir.current_is_dir():
			if file_name.ends_with(".tscn") or file_name.ends_with(".scn"):
				var scene = load(path + "/" + file_name) as PackedScene
				if scene:
					scenes.append(scene)

		file_name = dir.get_next()

	dir.list_dir_end()

	return scenes


func fix_summon_position():
	var summon = CardsContainer.find_child("SpellSummon")
	if summon:
		CardsContainer.move_child(summon, summon_index)


func _on_area_2d_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:
		_on_execute_pressed()
