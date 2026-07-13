extends Enemy

func _execute_secret_action() -> void:
	super._execute_secret_action()
	
	_BattleController.randomize_player_actions = true

func _ready() -> void:
	super._ready()
	
	OnDie.connect(func(): create_tween().tween_property($whispers, "volume_db", -100.0, 1.5))
	
	await get_tree().create_timer(1).timeout
	
	$whispers.play()
