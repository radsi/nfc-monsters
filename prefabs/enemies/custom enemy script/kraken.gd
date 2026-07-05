extends Enemy

@onready var inkNode := $ProgressBar/TextureRect

var ink_active := false

func _execute_secret_action() -> void:
	super._execute_secret_action()
	
	if ink_active:
		_GameController._dissolve_out(inkNode, 0.5)
	else:
		_GameController._dissolve_in(inkNode, 0.5, _GameController._action_original_materials)
