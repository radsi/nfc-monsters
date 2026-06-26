extends Resource
class_name ItemData

enum ItemType
{
	Buff,
	Special,
	Secret,
	Cardboard
}

enum Operator
{
	Add,
	Substract,
	Multiply,
	Divide,
	Percentage
}

@export var id: int
@export var name: String
@export var price: int
@export var icon: Texture2D
@export var type: ItemType
@export var weight: int
@export var description: String
@export var variables: Array[String]
@export var ammounts: Array[int]
@export var operators: Array[Operator]
@export var unique: bool
@export var event_only: bool
@export var min_layer: int
