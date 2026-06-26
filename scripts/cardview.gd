extends Node

@onready var card_view: Button = $VBoxContainer/HBoxContainer2/GridContainer/CardView
@onready var loading_circle: Button = $ColorRect/GridContainer/LoadingCircle/LoadingCircle
@onready var locked_icon: Resource = preload("res://sprites/spells/material-symbols--lock.png")
@onready var upgrade_label: Button = $VBoxContainer/HBoxContainer2/GridContainer/HBoxContainer/upgradebutton
@onready var level_label: Label = $VBoxContainer/HBoxContainer2/GridContainer/HBoxContainer/Label
@onready var print_viewport: SubViewport = $SubViewport

var spell_sprite: Sprite2D

var card_descriptions := {
	"SpellHit": "Hit with your tight fist!",
	"SpellDefend": "Block 5% of the damage.",
	"SpellDiscount": "25% off in the store... cheapskate...",
	"SpellHealth": "Restore 25% of your health points.",
	"SpellStruck": "Caste a powerfull magic attack.",
	"SpellGamble": "Deal damage equal to your current health points (20%), restore 50% of your max health points (40%) or nothing (40%).",
	"SpellBuff": "Buff the effect of your next card +10%",
	"SpellSummon": "Summon a spell that plays every turn automatically."
}

var card_data := {"level": 0}

var upgrade_level := 0
var upgrade_cost := 100

func _ready() -> void:
	spell_sprite = card_view.get_node(NodePath(Gamemanager.card_to_view["name"]))

	card_data = Gamemanager.card_to_view

	spell_sprite.show()
	
	print_viewport.find_child(spell_sprite.name).show()

	$VBoxContainer/HBoxContainer2/GridContainer2/Label.text = card_descriptions[Gamemanager.card_to_view["name"]]

	upgrade_level = Gamemanager.get_card_upgrade_level(Gamemanager.card_to_view["name"])

	#for button: Button in $VBoxContainer/HBoxContainer2/GridContainer2/GridContainer.get_children():

		#if not Gamemanager.types_unlocked.has(button.name.substr(6)):
		#	button.icon = locked_icon
		#	continue

	#	button.pressed.connect(_on_pressed.bind(button))

	NfcUsage.nfc_write_error.connect(_on_nfc_error)

func _on_nfc_error(error):
	loading_circle.hide()
	$ColorRect/GridContainer/Label.text = "An error has ocurred!"

func _process(delta: float) -> void:
	loading_circle.rotation += 2.0 * delta

func _on_pressed(button):
	pass
	#spell_sprite.modulate = button.modulate
	#print_viewport.find_child(spell_sprite.name).modulate = button.modulate
	#card_data["type"] = button.name.substr(6)

func _on_nfcbutton_pressed() -> void:
	$ColorRect.show()
	loading_circle.show()

	NfcUsage.write_nfc(JSON.stringify(card_data))

func _on_cancelbutton_pressed() -> void:
	$ColorRect.hide()
	NfcUsage.cancel_write()

func _on_backbutton_pressed() -> void:
	Gamemanager.return_scene()

func _on_printbutton_pressed() -> void:
	var img := print_viewport.get_texture().get_image()

	var img_path := "user://card.png"
	var pdf_path := "user://card.pdf"

	img.save_png(img_path)

	if NfcUsage.nfc_plugin == null:
		return
	NfcUsage.export_image_to_pdf_and_share(img_path, pdf_path)
