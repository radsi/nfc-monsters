extends EventData

func custom_event_script(caller) -> void:
	var _GameController: GameController = caller._GameController
	
	var rng := RandomNumberGenerator.new()
	rng.seed = _GameController.current_hash

	if 0 == 0:
		EnemyToFightAfterEvent = load("res://prefabs/enemies/knight.tscn")
		items_data.clear()
		return
	
	force_condition_satisfied = true
