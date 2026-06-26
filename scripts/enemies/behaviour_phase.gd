class_name BehaviorPhase
extends Resource

enum ConditionType {
	ALWAYS,
	HP_BELOW,
	HP_ABOVE,
	TURN_ABOVE,
	TURN_EXACT,
	TURN_UNDER,
	HAS_BUFF,
	NO_BUFF
}

@export var label: String = "Phase"
@export var condition_type: ConditionType = ConditionType.ALWAYS
@export var condition_value: float = 0.5

@export_group("Action Weights")
@export var force_actions: bool = false
@export var weight_attack:  int = 100
@export var weight_buff:    int = 100
@export var weight_defend:  int = 100
@export var weight_secret:  int = 100
@export var weight_prohibited: int = 100
