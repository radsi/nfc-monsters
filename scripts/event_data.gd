extends Control
class_name EventData

enum EventTypes {
	REPLACE_ITEM,
	GIVE_ITEM,
	GIVE_EFFECT,
	REMOVE_ITEM,
}

enum EffectTypes {
	HP,
	MONEY,
	UPGRADE
}

@export_group("Logic")
@export var id: String
@export var weight: int
@export var unique: bool
@export var min_layer: int = 1
@export var types: Array[EventTypes]
@export var items_data: Array[ItemData]
@export var effect_types: Array[EffectTypes]
@export var effect_values: Array[int]
@export var ActiveParticles: Array[GPUParticles2D]
@export var DeactiveParticles: Array[GPUParticles2D]

@onready var GeneralLabel: Label = $Label

@export_group("Nodes")
@export var YesButton: Area2D
@export var NoButton: Area2D
@export var NoResponse: String
@export var ConditionResponse: String
@export var YesResponse: String
@export var YesSFX: AudioStreamPlayer2D
@export var NoSFX: AudioStreamPlayer2D
@export var YesSprite: CompressedTexture2D
@export var NoSprite: CompressedTexture2D
